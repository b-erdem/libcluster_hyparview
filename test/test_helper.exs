ExUnit.start()

{:ok, _} = HyParView.Transport.Test.start_link()
{:ok, _} = LibclusterHyparview.Test.Capture.start_link()

# libcluster's `Cluster.Strategy.ensure_exported!` uses
# `function_exported?/3`, which only returns true for already-loaded
# modules. Force-load test support modules so the strategy can call them.
Code.ensure_loaded(LibclusterHyparview.Test.Capture)
