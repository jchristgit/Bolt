defmodule Bolt.Cogs.ActionGroup.Trigger do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Actions
  alias Bolt.ModLog
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Bolt.Humanizer, only: [human_user: 1]

  @impl true
  def usage, do: ["ag trigger <name:str>"]

  @impl true
  def description,
    do: """
    Trigger execution of an action group.

    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [name]) do
    case Actions.get_guild_group(msg.guild_id, name) do
      nil ->
        {:ok, _msg} = Message.create(msg.channel_id,
          content: "🚫 no action group named `#{name}` found",
          allowed_mentions: :none
        )

      group ->
        context = Actions.build_context(msg)

        ModLog.emit(
          msg.guild_id,
          "AUTOMOD",
          "#{human_user(msg.author)} manually triggered action group `#{name}`",
          allowed_mentions: :none
        )

        group
        |> Actions.run_group(context)
        |> report_run_result(msg.channel_id)

        Actions.run_group(group, context)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{hd(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  defp report_run_result(:aborted, channel_id) do
    {:ok, _msg} = Message.create(channel_id, content: "⚠️ run aborted due to deduplication")
  end

  defp report_run_result(_result, channel_id) do
    {:ok, _msg} = Message.create(channel_id, content: "👌 action group run done")
  end
end
