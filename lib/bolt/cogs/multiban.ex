defmodule Bolt.Cogs.MultiBan do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.Cogs.Ban
  alias Bolt.Helpers
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage,
    do: [
      "multiban <user:snowflake|member...>",
      "multiban <reason:str> <user:snowflake|member...>"
    ]

  @impl true
  def description,
    do: """
    Ban the given users with an optional reason.
    Infractions are stored in the infraction database, and can be retrieved later.
    Requires the `BAN_MEMBERS` permission.

    **Examples**:
    ```rs
    // Ban two bots
    multiban @Dude#0001 @Meep#0142

    // Same as above, but provide a reason
    multiban "bot accounts" @Dude#0001 @Meep#0142
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:ban_members)]

  @impl true
  def command(msg, [reason_or_target | targets] = args) when args != [] do
    case Helpers.into_id(msg.guild_id, reason_or_target) do
      {:ok, _snowflake, _user} ->
        multiban(args, msg)

      {:error, _reason} ->
        # reason cannot be interpreted as a user,
        # it's probably a reason instead
        multiban(targets, msg, reason_or_target)
    end
  end

  def command(msg, []) do
    response = "ℹ️ usage: `multiban [reason:str] <user:snowflake|member...>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  defp multiban(user_ids, msg, reason \\ "") do
    Enum.map(user_ids, &Ban.command(msg, [&1, reason]))
  end
end
