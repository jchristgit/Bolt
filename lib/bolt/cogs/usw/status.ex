defmodule Bolt.Cogs.USW.Status do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Nosedrum.TextCommand.Predicates
  alias Bolt.{Constants, Humanizer, Paginator, Repo}
  alias Bolt.Schema.{USWPunishmentConfig, USWRuleConfig}
  alias Nostrum.Api.Message
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Embed.Field
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["usw status"]

  @impl true
  def description,
    do: """
    Shows the current status of USW.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, []) do
    query = from(config in USWRuleConfig, where: config.guild_id == ^msg.guild_id, select: config)

    pages =
      query
      |> Repo.all()
      |> Enum.sort_by(& &1.rule)
      |> Stream.map(
        &%Field{
          name: "`#{&1.rule}`",
          value: """
          max: #{&1.count}
          per: #{&1.interval}s
          """,
          inline: true
        }
      )
      |> Stream.chunk_every(6)
      |> Enum.map(&%Embed{fields: &1})

    case pages do
      [] ->
        response = "🚫 no rules configured on this guild"
        {:ok, _msg} = Message.create(msg.channel_id, response)

      _ ->
        base_embed = %Embed{
          title: "uncomplicated spam wall: status",
          description: format_punishment_config(msg.guild_id),
          color: Constants.color_blue()
        }

        Paginator.paginate_over(msg, base_embed, pages)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `usw status`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  # ...
  @spec divmod(non_neg_integer(), non_neg_integer()) :: {non_neg_integer(), non_neg_integer()}
  defp divmod(a, b) do
    {div(a, b), rem(a, b)}
  end

  @spec maybe_tail(non_neg_integer(), String.t()) :: String.t()
  defp maybe_tail(0, _tail), do: ""
  defp maybe_tail(_n, tail), do: tail

  @spec format_duration(non_neg_integer()) :: String.t()
  defp format_duration(seconds) do
    {days, day_rem} = divmod(seconds, 60 * 60 * 24)
    {hours, hour_rem} = divmod(day_rem, 60 * 60)
    {minutes, _minute_rem} = divmod(hour_rem, 60)

    if days > 0 do
      "#{days} days" <> maybe_tail(hours, " and #{hours} hours")
    else
      "#{hours} hours" <> maybe_tail(minutes, " and #{minutes} minutes")
    end
  end

  defp format_punishment_config(guild_id) do
    case Repo.get(USWPunishmentConfig, guild_id) do
      nil ->
        "no punishment is configured"

      %USWPunishmentConfig{
        duration: duration,
        escalate: escalate,
        punishment: "TEMPROLE",
        data: %{"role_id" => role_id}
      } ->
        duration_string = format_duration(duration)

        human_role = Humanizer.human_role(guild_id, role_id)

        "configured punishment: `TEMPROLE` of role #{human_role} for #{duration_string}" <>
          ", automatic punishment escalation is " <> if escalate, do: "enabled", else: "disabled"

      %USWPunishmentConfig{
        duration: duration,
        escalate: escalate,
        punishment: "TIMEOUT"
      } ->
        duration_string = format_duration(duration)

        "configured punishment: `TIMEOUT` for #{duration_string}" <>
          ", automatic punishment escalation is " <> if escalate, do: "enabled", else: "disabled"
    end
  end
end
