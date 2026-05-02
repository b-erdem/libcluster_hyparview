defmodule LibclusterHyparview.Test.Capture do
  @moduledoc """
  Test helpers that capture connect/disconnect calls from the strategy
  and let tests mock the "currently connected nodes" list.

  `Cluster.Strategy.connect_nodes/4` and `disconnect_nodes/4` filter
  their target list against the result of `list_nodes` (third MFA):

    * `connect_nodes(_, _, list_mfa, targets)` connects only `targets \\\\
      list_nodes()` — i.e. nodes not already connected.
    * `disconnect_nodes(_, _, list_mfa, targets)` disconnects only
      `targets ∩ list_nodes()` — i.e. nodes that are currently connected.

  In production, `list_nodes` is `{:erlang, :nodes, [:connected]}`. In
  tests we need a controllable mock. This module:

    * Records each `connect/2` and `disconnect/2` call as a tagged message
      to the test process.
    * Maintains a per-test ETS row mapping `test_pid => [nodes]` that
      `list_connected/1` returns, so `disconnect_nodes` actually fires.
  """

  @table __MODULE__

  @doc "Start the ETS table; called from test_helper.exs."
  @spec start_link() :: {:ok, pid()}
  def start_link do
    :ets.new(@table, [:set, :public, :named_table])
    {:ok, self()}
  end

  @doc "Record `nodes` as the currently-connected list for `test_pid`."
  @spec set_connected(pid(), [node()]) :: true
  def set_connected(test_pid, nodes), do: :ets.insert(@table, {test_pid, nodes})

  @doc "Return the connected-nodes list for `test_pid` (used as the list_nodes MFA)."
  @spec list_connected(pid()) :: [node()]
  def list_connected(test_pid) do
    case :ets.lookup(@table, test_pid) do
      [{^test_pid, nodes}] -> nodes
      [] -> []
    end
  end

  @doc "Capture a connect call. The first argument is the recipient pid."
  @spec connect(pid(), node()) :: true
  def connect(pid, node) do
    send(pid, {:capture_connect, node})
    true
  end

  @doc "Capture a disconnect call."
  @spec disconnect(pid(), node()) :: true
  def disconnect(pid, node) do
    send(pid, {:capture_disconnect, node})
    true
  end
end
