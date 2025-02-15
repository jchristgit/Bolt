defmodule Bolt.Cogs.ActionGroup.Create do
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
    Create a new action group with the given name.
    To add actions to a group, use the `ag add` command.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [name]) do
    case Actions.create_guild_group(msg.guild_id, name) do
      {:ok, _group} ->
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{human_user(msg.author)} created action group `#{name}`"
        )

        {:ok, _msg} =
          Message.create(msg.channel_id, "👌 group created, use `ag add` to add actions")

      error ->
        response = ErrorFormatters.fmt(msg, error)
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{hd(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
