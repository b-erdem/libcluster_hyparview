defmodule Cluster.Strategy.HyParView do
  @moduledoc """
  A `libcluster` strategy that uses [HyParView](https://hex.pm/packages/hyparview)
  for membership and connects only the nodes in the local *active view* via
  Erlang distribution.

  The result: partial-mesh BEAM distribution. Each node maintains a small,
  bounded set of `Node.connect/1` peers (the active view), with the rest of
  the cluster reachable through the gossip overlay. This sidesteps the
  `~50–100 nodes` ceiling of full-mesh clusters that other libcluster
  strategies (Gossip, EPMD, Kubernetes) hit at scale.

  ## Pre-flight

  Boot the node with `-connect_all false` so the BEAM doesn't auto-connect
  every reachable peer:

      # rel/vm.args
      -name app@host
      -setcookie shared
      -kernel inet_dist_listen_min 9100
      -kernel inet_dist_listen_max 9200
      +K true
      -connect_all false

  Without `-connect_all false`, Erlang distribution will form a full mesh
  whenever ANY pair of nodes connects — defeating the purpose.

  ## Topology config

      # config/runtime.exs
      config :libcluster,
        topologies: [
          hp_example: [
            strategy: Cluster.Strategy.HyParView,
            config: [
              # Required:
              local_peer: HyParView.Peer.new(node(), {{0, 0, 0, 0}, 4500}),

              # Optional:
              contacts: [
                HyParView.Peer.new(:"app@10.0.0.1", {{10, 0, 0, 1}, 4500})
              ],
              transport: HyParView.Transport.TCP,
              hyparview_config: [
                active_view_size: 5,
                passive_view_size: 30
              ]
            ]
          ]
        ]

  The strategy starts a `HyParView.Server` and subscribes to its events.
  When a peer enters the active view, it calls
  `Cluster.Strategy.connect_nodes/4` for that peer's `:id` (which must be
  the BEAM node atom). When a peer leaves, it calls
  `Cluster.Strategy.disconnect_nodes/4`.

  Peer `:id` must be the BEAM node atom (e.g. `:"app@10.0.0.1"`); the
  `:address` is the HyParView TCP overlay address.
  """

  use GenServer
  use Cluster.Strategy

  alias Cluster.Logger
  alias Cluster.Strategy
  alias Cluster.Strategy.State

  @impl Cluster.Strategy
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl GenServer
  def init([%State{} = state]) do
    Process.flag(:trap_exit, true)
    Logger.info(state.topology, "HyParView strategy starting")

    case start_hyparview(state) do
      {:ok, hp_pid} ->
        # `replay: true` covers the race where the initial JOIN's :peer_up
        # might fire before this subscribe call completes — the strategy
        # gets a current-state snapshot followed by live updates.
        :ok = HyParView.subscribe(hp_pid, self(), replay: true)
        {:ok, %{state: state, hp_pid: hp_pid}}

      {:error, reason} ->
        {:stop, {:hyparview_start_failed, reason}}
    end
  end

  @impl GenServer
  def handle_info({:hyparview, {:peer_up, peer}}, %{state: state} = data) do
    case node_atom(peer.id) do
      nil ->
        Logger.warn(state.topology, "ignoring peer_up for non-atom id: #{inspect(peer.id)}")
        {:noreply, data}

      node ->
        Strategy.connect_nodes(
          state.topology,
          state.connect,
          state.list_nodes,
          [node]
        )

        {:noreply, data}
    end
  end

  def handle_info({:hyparview, {:peer_down, peer}}, %{state: state} = data) do
    case node_atom(peer.id) do
      nil ->
        {:noreply, data}

      node ->
        Strategy.disconnect_nodes(
          state.topology,
          state.disconnect,
          state.list_nodes,
          [node]
        )

        {:noreply, data}
    end
  end

  def handle_info({:EXIT, pid, reason}, %{hp_pid: pid} = data) do
    {:stop, {:hyparview_died, reason}, data}
  end

  def handle_info(_other, data), do: {:noreply, data}

  # ── Internals ───────────────────────────────────────────────────────

  defp start_hyparview(state) do
    config = state.config

    opts =
      [
        peer: Keyword.fetch!(config, :local_peer),
        contacts: Keyword.get(config, :contacts, []),
        transport: Keyword.get(config, :transport, HyParView.Transport.TCP),
        config: Keyword.get(config, :hyparview_config, [])
      ]

    HyParView.start_link(opts)
  end

  @spec node_atom(term()) :: node() | nil
  defp node_atom(id) when is_atom(id), do: id
  defp node_atom(_), do: nil
end
