defmodule Bolt.MixProject do
  use Mix.Project

  def project do
    [
      app: :bolt,
      version: "0.14.0-alpha.1+#{git_version()}",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [coveralls: :test],
      releases: releases(),
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
      {:nostrum, github: "Kraigie/nostrum", override: true},
      {:nosedrum, github: "jchristgit/nosedrum", override: true},

      # PostgreSQL interfacing
      {:ecto_sql, "~> 3.0"},
      {:polymorphic_embed, "~> 3.0"},
      {:jason, "~> 1.0"},
      {:postgrex, "~> 0.14"},

      # Operations
      {:crow, "~> 0.2"},
      {:crow_plugins, github: "jchristgit/crow_plugins"},
      {:castle, "~> 0.3"},
      {:systemd, "~> 0.6"},

      # Linting
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false}
    ]
  end

  defp releases do
    [
      bolt: [
        include_executables_for: [:unix],
        steps: [&Forecastle.pre_assemble/1, :assemble, &Forecastle.post_assemble/1]
      ]
    ]
  end

  defp aliases do
    [
      test: ["ecto.migrate --quiet", "test --no-start"]
    ]
  end

  defp git_version do
    case File.read!(".git/HEAD") do
      "ref: " <> where ->
        commit = File.read!(".git/#{String.trim_trailing(where)}")
        String.slice(commit, 0..5)

      hash ->
        String.slice(String.trim_trailing(hash), 0..5)
    end
  end
end
