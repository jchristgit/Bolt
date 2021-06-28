defmodule Bolt.Consumer.Ready do
  @moduledoc "Handles the `READY` event."

  alias Nosedrum.Storage.ETS, as: CommandStorage
  alias Bolt.{BotLog, Cogs}
  alias Nostrum.Api

  @infraction_group %{
    "detail" => Cogs.Infraction.Detail,
    "reason" => Cogs.Infraction.Reason,
    "list" => Cogs.Infraction.List,
    "user" => Cogs.Infraction.User,
    "expiry" => Cogs.Infraction.Expiry
  }

  @commands %{
    ## Bot meta commands
    "help" => Cogs.Help,
    "guide" => Cogs.Guide,
    "stats" => Cogs.Stats,

    ## Meta Commands
    "guildinfo" => Cogs.GuildInfo,
    "inrole" => Cogs.InRole,
    "memberinfo" => Cogs.MemberInfo,
    "roleinfo" => Cogs.RoleInfo,
    "roles" => Cogs.Roles,
    "uidrange" => Cogs.UidRange,

    ## Self-assignable roles
    "lsar" => Cogs.Lsar,
    "assign" => Cogs.Assign,
    "unassign" => Cogs.Unassign,

    ## Role configuration
    "role" => %{
      ## Add / remove self-assignable roles
      "allow" => Cogs.Role.Allow,
      "deny" => Cogs.Role.Deny,

      ## Roles for specific tasks
      "mute" => Cogs.Role.Mute
    },

    ## Moderation Commands
    "clean" => Cogs.Clean,
    "warn" => Cogs.Warn,
    "forcenick" => Cogs.ForceNick,
    "mute" => Cogs.Mute,
    "tempmute" => Cogs.Tempmute,
    "unmute" => Cogs.Unmute,
    "temprole" => Cogs.Temprole,
    "kick" => Cogs.Kick,
    "tempban" => Cogs.Tempban,
    "ban" => Cogs.Ban,
    "multiban" => Cogs.MultiBan,
    "lastjoins" => Cogs.LastJoins,

    ## Infraction database operations
    "note" => Cogs.Note,
    "infraction" => @infraction_group,
    # Alias
    "infr" => @infraction_group,

    ## Mod Log management
    "modlog" => %{
      "status" => Cogs.ModLog.Status,
      "set" => Cogs.ModLog.Set,
      "unset" => Cogs.ModLog.Unset,
      "events" => Cogs.ModLog.Events,
      "explain" => Cogs.ModLog.Explain,
      "mute" => Cogs.ModLog.Mute,
      "unmute" => Cogs.ModLog.Unmute
    },

    ## Spam wall management
    "usw" => %{
      "status" => Cogs.USW.Status,
      "set" => Cogs.USW.Set,
      "unset" => Cogs.USW.Unset,
      "punish" => Cogs.USW.Punish,
      "escalate" => Cogs.USW.Escalate
    },

    ## Tag database CR[U]D
    "tag" => %{
      "create" => Cogs.Tag.Create,
      "delete" => Cogs.Tag.Delete,
      "info" => Cogs.Tag.Info,
      "list" => Cogs.Tag.List,
      "raw" => Cogs.Tag.Raw,
      default: Cogs.Tag
    },

    ## Member join configuration management
    "keeper" => %{
      "actions" => Cogs.GateKeeper.Actions,
      "onaccept" => Cogs.GateKeeper.OnAccept,
      "onjoin" => Cogs.GateKeeper.OnJoin
    },

    ## Server filter management
    # "filter" => %{
    # "add" => Cogs.Filter.Add,
    # "show" => Cogs.Filter.Show,
    # "remove" => Cogs.Filter.Remove
    # },

    ## Rule verification
    "accept" => Cogs.Accept,

    ## Bot Management commands
    "sudo" => Cogs.Sudo,

    ## Easter eggs
    "ed" => Cogs.Ed
  }

  @aliases %{
    "gatekeeper" => Map.fetch!(@commands, "keeper"),
    "ginfo" => Map.fetch!(@commands, "guildinfo"),
    "gk" => Map.fetch!(@commands, "keeper"),
    "guild" => Map.fetch!(@commands, "guildinfo"),
    "iam" => Map.fetch!(@commands, "assign"),
    "iamn" => Map.fetch!(@commands, "unassign"),
    "infr" => Map.fetch!(@commands, "infraction"),
    "man" => Map.fetch!(@commands, "help"),
    "member" => Map.fetch!(@commands, "memberinfo"),
    "minfo" => Map.fetch!(@commands, "memberinfo"),
    "rinfo" => Map.fetch!(@commands, "roleinfo")
  }

  @spec handle(map()) :: :ok
  def handle(data) do
    :ok = load_commands()
    BotLog.emit("⚡ Logged in and ready, seeing `#{length(data.guilds)}` guilds.")
    :ok = Api.update_status(:online, "you | .help", 3)
  end

  defp load_commands do
    [@commands, @aliases]
    |> Stream.concat()
    |> Enum.each(fn {name, cog} -> CommandStorage.add_command([name], cog) end)
  end
end
