import Config

if config_env() != :test do
  config :bolt,
    botlog_channel: System.get_env("BOTLOG_CHANNEL"),
    ecto_repos: [Bolt.Repo],
    prefix: System.get_env("BOT_PREFIX") || ".",
    # rrd_directory: is set below
    superusers:
      (System.get_env("SUPERUSERS") || "")
      |> String.split(":", trim: true)
      |> Enum.map(fn user_id ->
        {value, _} = Integer.parse(user_id)
        value
      end),
    web_domain: System.get_env("WEB_DOMAIN"),
    token: System.get_env("BOT_TOKEN")

  # STATE_DIRECTORY is exported by systemd when we set the `StateDirectory` option.
  case System.get_env("STATE_DIRECTORY") do
    nil ->
      nil

    directory ->
      config :bolt, :rrd_directory, List.last(String.split(directory, ":"))
  end

  config :nosedrum,
    prefix: System.get_env("BOT_PREFIX") || "."

  config :bolt, Bolt.Repo,
    adapter: Ecto.Adapters.Postgres,
    url: System.get_env("PGSQL_URL")
end
