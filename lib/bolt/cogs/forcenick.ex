defmodule Bolt.Cogs.ForceNick do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Events.Handler
  alias Bolt.Schema.Infraction
  alias Bolt.{Helpers, ModLog, Parsers, Repo}
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Guild
  alias Nostrum.Api.Message
  alias Nostrum.Struct.User
  require Logger

  @impl true
  def usage, do: ["forcenick <user:member> <duration:duration> <nick:str...>"]

  @impl true
  def description,
    do: """
    Apply the given nickname on the given member.
    If the member attempts to change the nickname to anything else while the forced nick is active, Bolt will revert it.

    **Example**:
    ```rs
    // Apply the nick "Billy Bob" to Dude#0007 for 2 days.
    .forcenick @Dude#0007 2d Billy Bob
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_nicknames)]

  @impl true
  def command(msg, [user, duration | nick]) when nick != [] do
    nickname = Enum.join(nick, " ")

    response =
      with {:ok, expiry} <- Parsers.human_future_date(duration),
           {:ok, member} <- Converters.to_member(user, msg.guild_id),
           nil <-
             Repo.get_by(Infraction,
               type: "forced_nick",
               guild_id: msg.guild_id,
               user_id: member.user.id,
               active: true
             ),
           {:ok, _member} <- Guild.modify_member(msg.guild_id, member.user.id, nick: nickname) do
        infraction_map = %{
          type: "forced_nick",
          guild_id: msg.guild_id,
          user_id: member.user.id,
          actor_id: msg.author.id,
          expires_at: expiry,
          data: %{
            "nick" => nickname
          }
        }

        case Handler.create(infraction_map) do
          {:ok, _infraction} ->
            ModLog.emit(
              msg.guild_id,
              "INFRACTION_CREATE",
              "#{User.full_name(msg.author)} has forced the nickname `#{nickname}` on " <>
                "#{User.full_name(member.user)} (`#{member.user.id}`) until #{Helpers.datetime_to_human(expiry)}"
            )

            "👌 user #{User.full_name(member.user)} will have nickname `#{nickname}` for #{duration}"

          error ->
            Logger.error(fn ->
              "Error trying to create `forced_nick` infraction: #{inspect(error)}"
            end)

            "❌ unknown error encountered trying to create infraction, maybe retry"
        end
      else
        %Infraction{expires_at: expiry} ->
          "🚫 there is already an active `forced_nick` infraction for that member expiring at #{Helpers.datetime_to_human(expiry)}"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{List.first(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
