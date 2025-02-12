defmodule Bolt.Cogs.GateKeeper.OnJoin do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.Cogs.GateKeeper.Actions
  alias Bolt.Gatekeeper
  alias Bolt.Schema.JoinAction
  alias Bolt.{ErrorFormatters, ModLog, Repo}
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Struct.{Channel, User}
  require Logger

  @impl true
  def usage, do: ["keeper onjoin <action...>"]

  @impl true
  def description,
    do: """
    Sets actions to be ran when a member joins the server.

    **Actions**:
    • `ignore`: Delete any configured actions.
    • `send <template:str> to user`: Attempts to send the given `template` to the user who joined.
      If the user has direct messages disabled, this will fail.
    • `send <template:str> to <channel:textchannel>`: Sends the given `template` to the given `channel`.
    • `add role <role:role...>`: Adds the given `role` to the member who joined.

    Templates are regular text that have special values interpolated when they are about to be sent out.
    You can use `{mention}` to mention the user who joined in the resulting text.

    **Examples**:
    ```rs
    // On join, (attempt to) send "Welcome to our server!" to the user who joined
    .keeper onjoin send "Welcome to our server!" to user

    // On join, send "Welcome to our server, {mention}!" to the #welcome channel
    .keeper onjoin send "Welcome to our server, {mention}!" to #welcome

    // On join, add the role 'Guest' to the user who joined
    .keeper onjoin add role Guest
    ```
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, []) do
    Actions.command(msg, ["join"])
  end

  def command(msg, ["add", "role" | role_str]) do
    response =
      with {:ok, role} <- Converters.to_role(Enum.join(role_str, " "), msg.guild_id),
           action_map <- %{
             guild_id: msg.guild_id,
             action: "add_role",
             data: %{
               "role_id" => role.id
             }
           },
           changeset <- JoinAction.changeset(%JoinAction{}, action_map),
           {:ok, _action} <- Repo.insert(changeset) do
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{User.full_name(msg.author)} set gatekeeper to add role `#{role.name}` on join"
        )

        "👌 will now add role `#{role.name}` on join"
      else
        error -> ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, ["ignore"]) do
    {total_deleted, _} = Gatekeeper.clear_actions(msg.guild_id, :join)

    response =
      if total_deleted == 0 do
        "🚫 no actions to delete"
      else
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{User.full_name(msg.author)} deleted **#{total_deleted}** join action(s)"
        )

        "👌 deleted **#{total_deleted}** join actions"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, ["send", template, "to", "user"]) do
    action_map = %{
      guild_id: msg.guild_id,
      action: "send_dm",
      data: %{
        "template" => template
      }
    }

    changeset = JoinAction.changeset(%JoinAction{}, action_map)

    response =
      case Repo.insert(changeset) do
        {:ok, _action} ->
          ModLog.emit(
            msg.guild_id,
            "CONFIG_UPDATE",
            "#{User.full_name(msg.author)} set gatekeeper to DM users with " <>
              "```md\n#{template}``` on join"
          )

          "👌 will now attempt to DM users with the given template on join"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, ["send", template, "to", channel_str]) do
    response =
      with {:ok, channel} <- Converters.to_channel(channel_str, msg.guild_id),
           action_map <- %{
             guild_id: msg.guild_id,
             action: "send_guild",
             data: %{
               "channel_id" => channel.id,
               "template" => template
             }
           },
           changeset <- JoinAction.changeset(%JoinAction{}, action_map),
           {:ok, _action} <- Repo.insert(changeset) do
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{User.full_name(msg.author)} set gatekeeper to send " <>
            "```md\n#{template}``` to #{Channel.mention(channel)} on join"
        )

        "👌 will now send the given template to #{Channel.mention(channel)} on join"
      else
        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _) do
    response = "ℹ️ usage: `#{usage()}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
