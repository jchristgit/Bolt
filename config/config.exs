# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :bolt,
  botlog_channel: System.get_env("BOTLOG_CHANNEL"),
  ecto_repos: [Bolt.Repo],
  prefix: System.get_env("BOT_PREFIX") || ".",
  rrd_executable: System.get_env("RRD_EXECUTABLE") || nil,
  rrd_directory: if(System.get_env("RRD_EXECUTABLE"), do: "/tmp", else: nil),
  superusers:
    (System.get_env("SUPERUSERS") || "")
    |> String.split(":", trim: true)
    |> Enum.map(fn user_id ->
      {value, _} = Integer.parse(user_id)
      value
    end),
  web_domain: System.get_env("WEB_DOMAIN"),
  token: System.get_env("BOT_TOKEN")

config :crow,
  ip: {127, 0, 0, 1},
  port: 4950,
  plugins: [
    # Application-specific
    # General runtime information
    CrowPlugins.BEAM.Atoms,
    CrowPlugins.BEAM.ContextSwitches,
    {CrowPlugins.BEAM.ETS,
     name: ~c"nostrum_caches",
     mode: :memory,
     tables: [
       :nostrum_users,
       :nostrum_guild_members,
       :nostrum_guilds
     ]},
    {CrowPlugins.BEAM.ETS,
     name: ~c"nostrum_caches",
     mode: :items,
     tables: [
       :nostrum_users,
       :nostrum_guild_members,
       :nostrum_guilds
     ]},
    CrowPlugins.BEAM.GarbageCollections,
    CrowPlugins.BEAM.IO,
    CrowPlugins.BEAM.Memory,
    CrowPlugins.BEAM.Reductions,
    CrowPlugins.BEAM.SystemInfo
  ]

config :logger,
  truncate: 16_384,
  backends: [:console, Bolt.BotLogLoggerBackend],
  level: :debug

config :logger, :console, format: "[$level] $message\n"

config :nosedrum,
  prefix: System.get_env("BOT_PREFIX") || "."

config :bolt, Bolt.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("PGSQL_URL")

config :nostrum,
  request_guild_members: true,
  youtubedl: false,
  ffmpeg: false,
  caches: %{
    presences: Nostrum.Cache.PresenceCache.NoOp
  }

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :bolt, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:bolt, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env()}.exs"
