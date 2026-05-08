defmodule LibclusterHyparview.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/b-erdem/libcluster_hyparview"
  @description """
  libcluster strategy that uses HyParView for membership: nodes are connected
  via Erlang distribution only when present in the local active view, giving
  Elixir clusters partial-mesh BEAM distribution.
  """

  def project do
    [
      app: :libcluster_hyparview,
      version: @version,
      # Transitively bound by `:hyparview` which requires 1.19+
      # (set-theoretic types via @spec).
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      description: @description,
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,
      dialyzer: dialyzer(),
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        "ci.lint": :test,
        "ci.test": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # `hyparview` v0.2.0 (with the breaking-change Transport
      # callback signature) isn't published to hex yet. Track `main`
      # via git until then; switch to `{:hyparview, "~> 0.2"}` after
      # the v0.2.0 release.
      {:hyparview, github: "b-erdem/hyparview", branch: "main"},
      {:libcluster, "~> 3.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Baris Erdem"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      flags: [:error_handling, :missing_return, :extra_return, :underspecs],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp aliases do
    [
      check: ["format --check-formatted", "credo --strict", "dialyzer", "test"],
      "ci.lint": ["format --check-formatted", "credo --strict"],
      "ci.test": ["test --warnings-as-errors"]
    ]
  end
end
