defmodule Bolt.Cogs.BanRange do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.Constants
  alias Bolt.Moderation
  alias Bolt.Paginator
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Struct
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Guild
  alias Nostrum.Struct.User

  @impl true
  def usage,
    do: [
      "banrange <lower:snowflake> [to] <upper:snowflake> [reason:str...]",
      "banrange from <lower:snowflake> [reason:str...]"
    ]

  @impl true
  def description,
    do: """
    Ban a range of users by user ID. Infractions will be stored in the database.
    Requires the `BAN_MEMBERS` permission.

    **This command bans all selected members without confirmation**.
    Use the `uidrange` command to see who would be affected.

    **Examples**:
    ```rs
    // Ban all users with ID >= 12345
    banrange from 12345

    // Ban all users with ID >= 12345 and <= 21479
    banrange 12345 to 21479

    // Same as above, but provide a reason for the infraction database
    banrange 12345 to 21479 raid bots
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:ban_members)]

  @impl true
  def command(msg, ["from", lower | reason_list]) do
    reason = Enum.join(reason_list, " ")

    case Integer.parse(lower) do
      {start, ""} ->
        msg.guild_id
        |> :bolt_member_qlc.ids_above(start)
        |> execute(msg.guild_id, msg.author, reason)
        |> display(msg)

      :error ->
        {:ok, _msg} = Message.create(msg.channel_id, "🚫 invalid snowflake, sorry")
    end
  end

  # No infinite recursion is possible here: If `banrange a to to` is run,
  # we just head into this function twice, chopping out the "to" in each call.
  def command(msg, [lower, "to", upper | reason_list]) do
    command(msg, [lower, upper | reason_list])
  end

  def command(msg, [lower, upper | reason_list]) do
    reason = Enum.join(reason_list, " ")

    with {start, ""} <- Integer.parse(lower),
         {stop, ""} <- Integer.parse(upper) do
      msg.guild_id
      |> :bolt_member_qlc.ids_within(start, stop)
      |> execute(msg.guild_id, msg.author, reason)
      |> display(msg)
    else
      :error ->
        {:ok, _msg} = Message.create(msg.channel_id, "🚫 invalid snowflakes, sorry")
    end
  end

  def command(msg, _args) do
    response = "ℹ️  usage:\n```\n#{Enum.join(usage(), "\n")}\n```"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  @spec execute([User.id()], Guild.id(), User.t(), String.t()) :: {:ok, Struct.Message.t()}
  defp execute(targets, guild_id, actor, reason) do
    targets
    |> Stream.map(fn {snowflake, _member} -> snowflake end)
    |> Stream.map(&Moderation.ban("#{&1}", guild_id, actor, reason))
    |> Stream.map(&format_entry/1)
    |> Stream.chunk_every(15)
    |> Enum.map(&%Embed{description: Enum.join(&1, "\n")})
  end

  defp format_entry({:ok, infraction, user}) do
    "- successfully banned #{user} (##{infraction.id})"
  end

  defp format_entry({:error, reason, user}) do
    "- failed to ban #{user} (#{reason})"
  end

  def display(pages, message) do
    base_page = %Embed{
      title: "Ranged ban results",
      color: Constants.color_blue()
    }

    Paginator.paginate_over(message, base_page, pages)
  end
end
