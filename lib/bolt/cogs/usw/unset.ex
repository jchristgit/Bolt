defmodule Bolt.Cogs.USW.Unset do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.USWRuleConfig
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["usw unset <rule:str>"]

  @impl true
  def description,
    do: """
    Unsets configuration for the given rule, effectively disabling it.

    All rules can be disabled at once by running `usw unset all`.

    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, ["all"]) do
    query =
      from(entry in USWRuleConfig,
        where: entry.guild_id == ^msg.guild_id,
        select: {entry.rule, entry.count, entry.interval}
      )

    case Repo.delete_all(query) do
      {0, _deleted} ->
        {:ok, _msg} = Message.create(msg.channel_id, "🚫 no rules to delete")

      {count, deleted} ->
        postmortem =
          deleted
          |> Stream.map(fn {name, count, interval} -> "• `#{name}`: #{count} per #{interval}s" end)
          |> Enum.join("\n")

        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{Humanizer.human_user(msg.author)} deleted the following USW rule(s):\n#{postmortem}"
        )

        response = "👌 deleted the following #{count} rule(s):\n#{postmortem}"
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, [rule]) do
    rule = String.upcase(rule)

    response =
      if rule in USWRuleConfig.existing_rules() do
        case Repo.get_by(USWRuleConfig, guild_id: msg.guild_id, rule: rule) do
          nil ->
            "🚫 there is no configuration set up for rule `#{rule}`"

          object ->
            {:ok, _struct} = Repo.delete(object)

            ModLog.emit(
              msg.guild_id,
              "CONFIG_UPDATE",
              "#{Humanizer.human_user(msg.author)} deleted USW " <>
                "configuration for rule `#{rule}`"
            )

            "👌 deleted configuration for rule `#{rule}`"
        end
      else
        "🚫 unknown rule: `#{Helpers.clean_content(rule)}`"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
