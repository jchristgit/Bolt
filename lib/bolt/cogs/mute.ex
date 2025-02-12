defmodule Bolt.Cogs.Mute do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.Cogs.Tempmute
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["mute <user:member> [reason:str...]"]

  @impl true
  def description,
    do: """
    Times out the given `user` for a day.
    The user can be unmuted by using `.unmute`.
    To apply a temporary timeout, use `.tempmute`.
    Requires the `MODERATE_MEMBERS` permission.

    ```rs
    // Mute @Dude#0007.
    .mute @Dude#0007

    // Mute @Dude#0007 with a reason provided for the infraction.
    .mute @Dude#0007 spamming in #general
    ```
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1, Predicates.has_permission(:moderate_members)]

  @impl true
  def command(msg, [user_str | reason_list]) do
    Tempmute.command(msg, [user_str, "1d" | reason_list])
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{List.first(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
