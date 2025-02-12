defmodule Bolt.Cogs.Ban do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Moderation
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["ban <user:snowflake|member> [reason:str]"]

  @impl true
  def description,
    do: """
    Ban the given user with an optional reason.
    An infraction is stored in the infraction database, and can be retrieved later.
    Requires the `BAN_MEMBERS` permission.

    **Examples**:
    ```rs
    // ban Dude without a reason
    ban @Dude#0001

    // the same thing, but with a reason
    ban @Dude#0001 too many cat pictures
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:ban_members)]

  @impl true
  def command(msg, [target | reason_list]) do
    reason = Enum.join(reason_list, " ")

    case Moderation.ban(target, msg.guild_id, msg.author, reason) do
      {:ok, infraction, user_string} ->
        response = "👌 permanently banned #{user_string} (##{infraction.id})"
        {:ok, _msg} = Message.create(msg.channel_id, response)

      {:error, response, _user} ->
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `ban <user:snowflake|member> [reason:str...]`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
