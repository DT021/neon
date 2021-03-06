defmodule Neon.MixProject do
  use Mix.Project

  def project do
    [
      app: :neon,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext, :rustler] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      rustler_crates: crates(),
      aliases: aliases(),
      preferred_cli_env: preferred_cli_env(),
      deps: deps(),
      dialyzer: [
        plt_add_deps: :transitive,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      extra_applications: [:cachex, :logger, :runtime_tools],
      mod: {Neon.Application, []}
    ]
  end

  # Specifies the Rust nifs to build
  def crates do
    [
      neon_predict: [
        mode: if(Mix.env() == :prod, do: :release, else: :debug),
        path: __DIR__
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:absinthe, "~> 1.5"},
      {:absinthe_plug, "~> 1.5.0"},
      {:absinthe_phoenix, "~> 2.0.0"},
      {:argon2_elixir, "~> 2.0"},
      {:cachex, "~> 3.3"},
      {:dataloader, "~> 1.0.0"},
      {:ecto_enum, "~> 1.4"},
      {:ecto_sql, "~> 3.4"},
      {:gen_registry, "~> 1.0"},
      {:gettext, "~> 0.11"},
      {:hackney, "~> 1.16.0"},
      {:jason, "~> 1.0"},
      {:phoenix_ecto, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.2.6"},
      {:phoenix_live_view, "~> 0.14.2"},
      {:phoenix, "~> 1.5.1"},
      {:plug_cowboy, "~> 2.0"},
      {:postgrex, "~> 0.15.5"},
      {:rustler, "~> 0.22.0-rc.0"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:tesla, "~> 1.3.0"},
      {:websockex, "~> 0.4.2"},
      {:credo, "~> 1.4", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:reverse_proxy_plug, "~> 1.3.0", only: :dev},
      {:bypass, "~> 1.0", only: :test},
      {:ex_machina, "~> 2.4", only: :test},
      {:wallaby, "~> 0.26.0", runtime: false, only: :test}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "ecto.seed"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.seed": ["run priv/repo/seeds.exs"],
      "test.unit": ["ecto.create --quiet", "ecto.migrate", "test test/neon test/neon_server"],
      "test.browser": ["ecto.create --quiet", "ecto.migrate", "test test/neon_client"]
    ]
  end

  defp preferred_cli_env do
    [
      "test.unit": :test,
      "test.browser": :test
    ]
  end
end
