defmodule Bolt.Cogs.ActionGroup.Show do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Actions
  alias Bolt.Constants
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api
  alias Nostrum.Struct.Embed

  @impl true
  def usage, do: ["ag show <name:str>"]

  @impl true
  def description,
    do: """
    Show the given action group.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [name]) do
    case Actions.get_guild_group(msg.guild_id, name) do
      nil ->
        {:ok, _msg} = Api.Message.create(msg.channel_id,
          content: "🚫 no action group named `#{name}` found",
          allowed_mentions: :none
        )

      group ->
        embed = build_action_group_embed(group)
        Api.create_message!(msg.channel_id, embed: embed)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{hd(usage())}`"
    {:ok, _msg} = Api.Message.create(msg.channel_id, response)
  end

  defp build_action_group_embed(group) do
    %Embed{
      title: "action group `#{group.name}`",
      color: Constants.color_blue(),
      description:
        "deduplication #{display_deduplication(group.deduplicate)}\n\n**Actions**:\n" <>
          describe_actions(group.actions)
    }
  end

  defp describe_actions(actions) do
    actions
    |> Stream.map(&"• #{to_string(&1.module)}")
    |> Enum.join("\n")
  end

  defp display_deduplication(true), do: "enabled"
  defp display_deduplication(false), do: "disabled"
end
