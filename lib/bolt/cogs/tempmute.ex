defmodule Bolt.Cogs.Tempmute do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.Moderation
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Bolt.Parsers, only: [human_future_date: 1]
  import Bolt.Helpers, only: [datetime_to_human: 1]

  @impl true
  def usage, do: ["tempmute <user:member> <duration:duration> [reason:str...]"]

  @impl true
  def description,
    do: """
    Temporarily mutes the given `user` by applying the configured mute role.
    Requires the `MODERATE_MEMBERS` permission.

    ```rs
    // Mute @Dude#0007 for 2 days and 12 hours.
    .tempmute @Dude#0007 2d12h

    // Mute @Dude#0007 for 5 hours with a reason provided for the infraction.
    .tempmute @Dude#0007 5h spamming in #general
    ```
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1, Predicates.has_permission(:moderate_members)]

  @impl true
  def command(msg, [user_str, duration | reason_list]) do
    raw_reason = Enum.join(reason_list, " ")
    reason = if raw_reason != "", do: raw_reason, else: nil

    with {:ok, expiry} <- human_future_date(duration),
         {:ok, infraction, user_string} <-
           Moderation.timeout(user_str, msg.guild_id, msg.author, reason, expiry) do
      response =
        "👌 timed out #{user_string} until #{datetime_to_human(expiry)} (##{infraction.id})"

      {:ok, _msg} = Message.create(msg.channel_id, response)
    else
      {:error, response, _user} ->
        {:ok, _msg} = Message.create(msg.channel_id, response)

      {:error, response} ->
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _args) do
    response = "ℹ️  usage: `#{List.first(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
