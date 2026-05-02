defmodule Cluster.Strategy.HyParViewTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Cluster.Strategy.HyParView, as: Strategy
  alias HyParView.Peer
  alias LibclusterHyparview.Test.Capture

  setup do
    # The strategy is started via `start_link` and we want to assert what
    # happens when it dies — trap exits so the test process survives the
    # propagated signal.
    Process.flag(:trap_exit, true)
    :ok
  end

  defp unique_node(prefix) do
    suffix = System.unique_integer([:positive])
    String.to_atom("#{prefix}_#{suffix}@127.0.0.1")
  end

  defp unique_address, do: make_ref()

  defp build_state(local_peer, contacts \\ [], opts \\ []) do
    test_pid = Keyword.get(opts, :test_pid, self())

    %Cluster.Strategy.State{
      topology: :test_topology,
      connect: {Capture, :connect, [test_pid]},
      disconnect: {Capture, :disconnect, [test_pid]},
      list_nodes: {Capture, :list_connected, [test_pid]},
      config: [
        local_peer: local_peer,
        contacts: contacts,
        transport: HyParView.Transport.Test,
        hyparview_config: [
          active_view_size: 5,
          passive_view_size: 10,
          shuffle_interval: 1_000_000
        ]
      ]
    }
  end

  defp start_strategy(state) do
    {:ok, pid} = Strategy.start_link([state])

    on_exit(fn ->
      if Process.alive?(pid) do
        try do
          GenServer.stop(pid, :normal, 100)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    pid
  end

  describe "lifecycle" do
    test "starts a HyParView.Server and is alive" do
      pid = start_strategy(build_state(Peer.new(unique_node("local"), unique_address())))

      %{hp_pid: hp_pid} = :sys.get_state(pid)
      assert is_pid(hp_pid)
      assert Process.alive?(hp_pid)
      assert HyParView.active_view(hp_pid) == []
    end

    test "stops cleanly" do
      pid = start_strategy(build_state(Peer.new(unique_node("clean"), unique_address())))

      ref = Process.monitor(pid)
      GenServer.stop(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 500
    end

    test "stops if HyParView.Server dies" do
      capture_log(fn ->
        pid = start_strategy(build_state(Peer.new(unique_node("hp-dies"), unique_address())))
        %{hp_pid: hp_pid} = :sys.get_state(pid)

        ref = Process.monitor(pid)
        GenServer.stop(hp_pid, :shutdown)

        assert_receive {:DOWN, ^ref, :process, ^pid, _}, 500
      end)
    end
  end

  describe "peer_up handling" do
    test "connects when peer.id is a node atom" do
      pid = start_strategy(build_state(Peer.new(unique_node("conn"), unique_address())))

      remote_node = unique_node("remote")
      remote_peer = Peer.new(remote_node, unique_address())

      send(pid, {:hyparview, {:peer_up, remote_peer}})

      assert_receive {:capture_connect, ^remote_node}, 200
    end

    test "ignores non-atom peer.id" do
      pid = start_strategy(build_state(Peer.new(unique_node("ignore"), unique_address())))

      bogus = Peer.new("not-an-atom", unique_address())
      send(pid, {:hyparview, {:peer_up, bogus}})

      refute_receive {:capture_connect, _}, 50
    end
  end

  describe "peer_down handling" do
    test "disconnects when peer.id is a node atom and is currently connected" do
      remote_node = unique_node("remote")

      # `disconnect_nodes` only fires for nodes in the "currently connected"
      # list, so we mock that.
      Capture.set_connected(self(), [remote_node])

      pid = start_strategy(build_state(Peer.new(unique_node("disc"), unique_address())))

      remote_peer = Peer.new(remote_node, unique_address())
      send(pid, {:hyparview, {:peer_down, remote_peer}})

      assert_receive {:capture_disconnect, ^remote_node}, 200
    end

    test "ignores non-atom peer.id" do
      pid = start_strategy(build_state(Peer.new(unique_node("ignore-d"), unique_address())))

      bogus = Peer.new("not-an-atom", unique_address())
      send(pid, {:hyparview, {:peer_down, bogus}})

      refute_receive {:capture_disconnect, _}, 50
    end
  end

  describe "real two-node integration via Test transport" do
    test "joining contact triggers connect; killing it triggers disconnect" do
      contact_node = unique_node("contact")
      contact_peer = Peer.new(contact_node, unique_address())

      joiner_node = unique_node("joiner")
      joiner_peer = Peer.new(joiner_node, unique_address())

      {:ok, contact_pid} =
        HyParView.start_link(
          peer: contact_peer,
          transport: HyParView.Transport.Test,
          config: [active_view_size: 5, shuffle_interval: 1_000_000]
        )

      on_exit(fn ->
        if Process.alive?(contact_pid) do
          try do
            GenServer.stop(contact_pid, :normal, 100)
          catch
            :exit, _ -> :ok
          end
        end
      end)

      strategy_pid = start_strategy(build_state(joiner_peer, [contact_peer]))

      assert_receive {:capture_connect, ^contact_node}, 1_000

      # After the connect was reported, mock contact as currently connected
      # so the disconnect filter passes.
      Capture.set_connected(self(), [contact_node])

      %{hp_pid: joiner_hp} = :sys.get_state(strategy_pid)
      GenServer.stop(contact_pid)
      :ok = HyParView.connection_lost(joiner_hp, contact_peer)

      assert_receive {:capture_disconnect, ^contact_node}, 1_000
    end
  end
end
