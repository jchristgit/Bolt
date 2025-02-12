defmodule Bolt.Cogs.ActionGroup.Clear do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Actions
  alias Bolt.ErrorFormatters
  alias Bolt.ModLog
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Bolt.Humanizer, only: [human_user: 1]

  @impl true
  def usage, do: ["ag create <name:str>"]

  @impl true
  def description,
    do: """
    Clear all actions of the given action group.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [name]) do
    response =
      case Actions.set_guild_group_actions(msg.guild_id, name, []) do
        {:ok, _action} ->
          ModLog.emit(
            msg.guild_id,
            "CONFIG_UPDATE",
            "#{human_user(msg.author)} cleared action group `#{name}`"
          )

          "👌 group cleared, use `ag add` to re-add actions"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{hd(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
