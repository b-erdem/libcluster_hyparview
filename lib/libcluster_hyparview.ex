defmodule LibclusterHyparview do
  @moduledoc """
  Companion library wiring [HyParView](https://hex.pm/packages/hyparview)
  membership into [libcluster](https://hex.pm/packages/libcluster) for
  partial-mesh Erlang distribution.

  The actual strategy module is `Cluster.Strategy.HyParView`; this module
  is just a namespace anchor.
  """

  @doc "Returns the OTP application name."
  def app, do: :libcluster_hyparview
end
