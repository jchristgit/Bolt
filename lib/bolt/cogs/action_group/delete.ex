defmodule Bolt.Cogs.ActionGroup.Delete do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Actions
  alias Bolt.ErrorFormatters
  alias Bolt.ModLog
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Bolt.Humanizer, only: [human_user: 1]

  @impl true
  def usage, do: ["ag delete <name:str>"]

  @impl true
  def description,
    do: """
    Delete an action group.
    Any other functionality linked to this action group will no longer reference it.
    If you just want to remake actions of a group, use the `ag clear` command.

    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [name]) do
    response =
      case Actions.delete_guild_group(msg.guild_id, name) do
        {:ok, _action} ->
          ModLog.emit(
            msg.guild_id,
            "CONFIG_UPDATE",
            "#{human_user(msg.author)} deleted action group `#{name}`"
          )

          "👌 action group deleted"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ see help for usage details"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
