# libcluster_hyparview

[![Hex.pm](https://img.shields.io/hexpm/v/libcluster_hyparview.svg)](https://hex.pm/packages/libcluster_hyparview)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/libcluster_hyparview)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

A [libcluster](https://hex.pm/packages/libcluster) strategy that uses
[HyParView](https://hex.pm/packages/hyparview) for membership and connects
only the nodes in the local *active view* via Erlang distribution — i.e.
**partial-mesh BEAM distribution**.

## Why

`libcluster` ships several discovery strategies (Gossip, EPMD, Kubernetes,
DNS, etc.) but they all assume a *full mesh*: every discovered node calls
`Node.connect/1` for every other discovered node. That works fine up to
~50–100 nodes; past that you start hitting net_kernel pressure, partial
partitions, and chatty heartbeats.

HyParView gives each node a *bounded* active view of `log(N) + c` peers.
This strategy:

1. Starts a `HyParView.Server` per node.
2. Subscribes to membership events.
3. On `:peer_up`, calls `Cluster.Strategy.connect_nodes/4` for the peer's
   `:id` (a BEAM node atom).
4. On `:peer_down`, calls `Cluster.Strategy.disconnect_nodes/4`.

The result: each node has Erlang-distribution links to a small bounded
set of peers, with the rest of the cluster reachable via the gossip
overlay. Phoenix.PubSub and other distributed primitives that piggyback
on `Node.list/0` get a small mesh; HyParView itself handles failure
detection and view repair beneath them.

## Pre-flight

You **must** boot every node with `-connect_all false`, otherwise BEAM
will full-mesh the cluster the moment any pair connects:

```erlang
%% rel/vm.args
-name app@host
-setcookie shared
-connect_all false
+K true
```

## Configure

```elixir
# config/runtime.exs
config :libcluster,
  topologies: [
    hp_example: [
      strategy: Cluster.Strategy.HyParView,
      config: [
        # Required: peer.id MUST be the BEAM node atom for this node.
        local_peer: HyParView.Peer.new(node(), {{0, 0, 0, 0}, 4500}),

        # Optional: contacts to JOIN. Same shape — id is a node atom.
        contacts: [
          HyParView.Peer.new(:"app@10.0.0.1", {{10, 0, 0, 1}, 4500}),
          HyParView.Peer.new(:"app@10.0.0.2", {{10, 0, 0, 2}, 4500})
        ],

        # Optional: transport (default HyParView.Transport.TCP).
        transport: HyParView.Transport.TCP,

        # Optional: passed straight through to HyParView.Config.new/1.
        hyparview_config: [
          active_view_size: 5,
          passive_view_size: 30,
          shuffle_interval: 30_000
        ]
      ]
    ]
  ]
```

Then in your application supervisor:

```elixir
def start(_type, _args) do
  topologies = Application.fetch_env!(:libcluster, :topologies)

  children = [
    {Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]},
    # ... rest of your supervision tree
  ]

  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end
```

## How it interacts with other libcluster strategies

This strategy is **load-bearing** for `Node.connect`/`disconnect` — don't
combine it with another libcluster strategy targeting the same nodes;
they'll fight each other.

If you want HyParView for the gossip overlay but a *separate* discovery
strategy (Kubernetes-style "find me my fellow pods"), the cleanest pattern
is to use the discovery strategy to populate `:contacts` at startup and
then disable it from making `Node.connect` calls itself. (Future improvement
once the integration shape is clearer.)

## Installation

Add to your deps in `mix.exs`:

```elixir
def deps do
  [
    {:libcluster_hyparview, "~> 0.1"}
  ]
end
```

`:hyparview` (`~> 0.2`) and `:libcluster` (`~> 3.4`) are pulled in
transitively.

## Status

Initial release. The plumbing — `HyParView.Server` startup,
membership-event subscription, `Cluster.Strategy.connect_nodes/4`
wiring — works end-to-end against `HyParView.Transport.TCP` and is
covered by the test suite. Real-world deployment patterns
(multi-region, mixed strategies, partial-mesh + BEAM-dist gating)
will accumulate over follow-up minor versions.

## License

Apache 2.0.
