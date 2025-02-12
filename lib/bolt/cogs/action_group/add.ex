defmodule Bolt.Cogs.ActionGroup.Add do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Actions
  alias Bolt.ErrorFormatters
  alias Bolt.ModLog
  alias Bolt.Schema.ActionGroup
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Bolt.Humanizer, only: [human_user: 1]

  @impl true
  def usage,
    do: [
      "ag add <name:str> clear_gatekeeper_actions [accept|join|both]",
      "ag add <name:str> delete_invites",
      "ag add <name:str> delete_vanity_url"
    ]

  @impl true
  def description,
    do: """
    Add an action to an action group.

    - `clear_gatekeeper_actions` deletes all actions for gatekeeper for the selected chain
    - `delete_invites` deletes all invites for the guild, excluding vanity URL
    - `delete_vanity_url` deletes the vanity URL for this guild, if present

    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [name, "clear_gatekeeper_actions" = function, kind]) do
    action = %{module: %{__type__: function, kind: kind}}
    add_action(msg, name, action)
  end

  def command(msg, [name, "delete_invites" = function]) do
    action = %{module: %{__type__: function}}
    add_action(msg, name, action)
  end

  def command(msg, [name, "delete_vanity_url" = function]) do
    action = %{module: %{__type__: function}}
    add_action(msg, name, action)
  end

  def command(msg, _args) do
    response = "ℹ️ see help for usage details"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  defp add_action(msg, name, action) do
    response =
      case Actions.add_guild_group_action(msg.guild_id, name, action) do
        {:ok, %ActionGroup{actions: actions}} ->
          action_description = to_string(List.last(actions).module)

          ModLog.emit(
            msg.guild_id,
            "CONFIG_UPDATE",
            "#{human_user(msg.author)} updated action group `#{name}`, will now #{action_description}"
          )

          "👌 this action group will now #{action_description}"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
