defmodule Bolt.MixProject do
  use Mix.Project

  def project do
    [
      app: :bolt,
      version: "0.12.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [coveralls: :test],
      aliases: aliases(),
      test_coverage: [summary: [threshold: 0]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Bolt.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Discord interfacing
      {:nosedrum, github: "jchristgit/nosedrum"},
      {:nostrum, github: "Kraigie/nostrum", override: true},

      # PostgreSQL interfacing
      {:ecto_sql, "~> 3.0"},
      {:polymorphic_embed, "~> 3.0"},
      {:jason, "~> 1.0"},
      {:postgrex, "~> 0.14"},

      # Monitoring (CAW CAW CAW)
      {:crow, "~> 0.1"},
      {:crow_plugins, "~> 0.1"},

      # Linting
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ecto.migrate --quiet", "test --no-start"]
    ]
  end
end
