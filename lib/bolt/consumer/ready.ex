defmodule Bolt.Consumer.Ready do
  @moduledoc "Handles the `READY` event."

  alias Bolt.BotLog
  alias Bolt.Cogs
  alias Nosedrum.TextCommand.Storage.ETS, as: CommandStorage
  alias Nostrum.Api.Self
  require Logger

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
    "banrange" => Cogs.BanRange,
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
      "explain" => Cogs.ModLog.Explain
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
    "ag" => %{
      "list" => Cogs.ActionGroup.List,
      "create" => Cogs.ActionGroup.Create,
      "add" => Cogs.ActionGroup.Add,
      "show" => Cogs.ActionGroup.Show,
      "clear" => Cogs.ActionGroup.Clear,
      "trigger" => Cogs.ActionGroup.Trigger,
      "delete" => Cogs.ActionGroup.Delete
    },

    ## Starboard management
    "starboard" => %{
      "configure" => Cogs.Starboard.Configure
    },

    ## Rule verification
    "accept" => Cogs.Accept,

    ## Bot Management commands
    "sudo" => Cogs.Sudo,

    ## Easter eggs
    "ed" => Cogs.Ed

    ## bolt ARS (automatic redact subsystem)
    # "autoredact" => Cogs.Autoredact
  }

  @aliases %{
    "actiongroup" => Map.fetch!(@commands, "ag"),
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
    # "unpermanent" => Map.fetch!(@commands, "autoredact"),
  }

  @spec handle(map()) :: :ok
  def handle(data) do
    :ok = load_commands()
    BotLog.emit("⚡ Logged in and ready, seeing `#{length(data.guilds)}` guilds.")
    prefix = Application.fetch_env!(:bolt, :prefix)
    :ok = Self.update_status(:online, {:watching, "you | #{prefix}help"})
    :systemd.notify(:ready)
  end

  defp load_commands do
    [@commands, @aliases]
    |> Stream.concat()
    |> Enum.each(&load_command/1)
  end

  defp load_command({name, cog}) do
    case is_map(cog) do
      # It's a command with subcommands
      true ->
        Enum.each(cog, fn {subname, module} ->
          CommandStorage.add_command([name, subname], module)
        end)

      # It's a plain command
      false ->
        CommandStorage.add_command([name], cog)
    end
  end
end
