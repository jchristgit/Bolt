defmodule Bolt.Cogs.USW.Set do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.USWRuleConfig
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["usw set <rule:str> <count:int> [per] <interval:int>"]

  @impl true
  def description,
    do: """
    Sets the given `rule` to allow `count` objects to pass through within `interval` seconds.

    Existing rules:
    • `BURST`: Allows `count` messages by the same author within `interval` seconds.
    • `DUPLICATES`: Allows `count` same messages within `interval` seconds.
    • `LINKS`: Allows `count` links by the same author within `interval` seconds
    • `MENTIONS`: Allows `count` user mentions by the same author within `interval` seconds.
    • `NEWLINES`: Allows `count` newlines by the same author within `interval` seconds.

    For example, to allow 5 messages by the same user within 7 seconds (using the `BURST` rule), one would use `usw set BURST 5 7`.

    For readability, `per` can be given between `count` and `interval`, for example `usw set BURST 5 per 7`.

    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [rule_name, count_str, interval_str]) do
    rule_name = String.upcase(rule_name)

    response =
      with true <- rule_name in USWRuleConfig.existing_rules(),
           {count, _} <- Integer.parse(count_str),
           {interval, _} <- Integer.parse(interval_str),
           params <- %{
             guild_id: msg.guild_id,
             rule: rule_name,
             count: count,
             interval: interval
           },
           changeset <- USWRuleConfig.changeset(%USWRuleConfig{}, params),
           {:ok, _struct} <-
             Repo.insert(
               changeset,
               conflict_target: [:guild_id, :rule],
               on_conflict: [set: [count: count, interval: interval]]
             ) do
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{Humanizer.human_user(msg.author)} updated USW configuration: " <>
            "now allowing max **#{count}** objects per **#{interval}**s in rule `#{rule_name}`"
        )

        "👌 updated configuration, will now allow max **#{count}**" <>
          " objects per **#{interval}**s in rule `#{rule_name}`"
      else
        false ->
          "🚫 `#{Helpers.clean_content(rule_name)}` is not a known rule"

        :error ->
          "🚫 either `count` or `interval` are not integers"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, [filter, count_str, "per", interval_str]) do
    command(msg, [filter, count_str, interval_str])
  end

  def command(msg, _args) do
    response = "🚫 expected 3 arguments (rule, count, interval), got something else"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
