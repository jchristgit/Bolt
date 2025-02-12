defmodule Bolt.Cogs.ActionGroup.List do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Actions
  alias Bolt.Schema.ActionGroup
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["ag list"]

  @impl true
  def description,
    do: """
    List action groups configured for this guild.
    To inspect the actions configured in a group, use `ag show [group]`.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, []) do
    groups = Actions.get_guild_groups(msg.guild_id)
    response = "__**Configured action groups**__\n#{format_groups(groups)}"
    {:ok, _msg} = Message.create(msg.channel_id, content: response, allowed_mentions: :none)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{hd(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  defp format_groups([]) do
    "ℹ️  no action groups configured on this guild"
  end

  defp format_groups(groups) do
    groups
    |> Stream.map(&"• #{format_group(&1)}")
    |> Enum.join("\n")
  end

  defp format_group(%ActionGroup{name: name, deduplicate: deduplicate}) do
    "`#{name}` (deduplication #{bool_to_switch_human(deduplicate)})"
  end

  defp bool_to_switch_human(true), do: "enabled"
  defp bool_to_switch_human(false), do: "disabled"
end
