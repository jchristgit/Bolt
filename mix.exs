defmodule Bolt.MixProject do
  use Mix.Project

  def project do
    [
      app: :bolt,
      version: "0.11.2",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [coveralls: :test],
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Bolt.Application, []},
      applications: [:ecto_sql, :postgrex, :nostrum]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Discord interfacing
      {:nosedrum, "~> 0.2"},
      {:nostrum, "~> 0.3", override: true},

      # PostgreSQL interfacing
      {:ecto_sql, "~> 3.0"},
      {:jason, "~> 1.0"},
      {:postgrex, "~> 0.14"},

      # Miscellaneous
      {:timex, "~> 3.1"},
      {:aho_corasick, git: "https://github.com/wudeng/aho-corasick.git"},

      # Linting
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: :dev, runtime: false},
      {:distillery, "~> 2.0", runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ecto.migrate --quiet", "test --no-start"]
    ]
  end
end
