defmodule Bolt.Cogs.Temprole do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Events.Handler
  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Parsers
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Guild
  alias Nostrum.Api.Message
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["temprole <user:member> <role:role> <duration:duration> [reason:str...]"]

  @impl true
  def description,
    do: """
    Temporarily apply the given role to the given user.
    An infraction is stored in the infraction database, and can be retrieved later.
    Requires the `MANAGE_ROLES` permission.

    **Examples**:
    ```rs
    // apply the role "Shitposter" to Dude for 24 hours
    temprole @Dude#0001 Shitposter 24h

    // the same thing, but with a specified reason
    temprole @Dude#0001 Shitposter 24h spamming pictures
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_roles)]

  @impl true
  def command(msg, [user, role, duration | reason_list]) do
    response =
      with reason <- Enum.join(reason_list, " "),
           {:ok, member} <- Converters.to_member(user, msg.guild_id),
           {:ok, role} <- Converters.to_role(role, msg.guild_id),
           query <-
             from(
               infr in Infraction,
               where:
                 infr.active and infr.user_id == ^member.user.id and
                   infr.guild_id == ^msg.guild_id and infr.type == "temprole" and
                   fragment("data->'role_id' = ?", ^role.id),
               limit: 1,
               select: {infr.id, infr.expires_at}
             ),
           [] <- Repo.all(query),
           {:ok, expiry} <- Parsers.human_future_date(duration),
           {:ok} <-
             Guild.add_member_role(
               msg.guild_id,
               member.user.id,
               role.id
             ),
           infraction_map <- %{
             type: "temprole",
             guild_id: msg.guild_id,
             user_id: member.user.id,
             actor_id: msg.author.id,
             reason: if(reason != "", do: reason, else: nil),
             expires_at: expiry,
             data: %{
               "role_id" => role.id
             }
           },
           {:ok, _created_infraction} <- Handler.create(infraction_map) do
        ModLog.emit(
          msg.guild_id,
          "INFRACTION_CREATE",
          "#{Humanizer.human_user(msg.author)} applied temporary role" <>
            " #{Humanizer.human_role(msg.guild_id, role)} to #{Humanizer.human_user(member.user)}" <>
            " until #{Helpers.datetime_to_human(expiry)}" <>
            if(reason != "", do: " with reason `#{reason}`", else: "")
        )

        response =
          "👌 temporary role #{Humanizer.human_role(msg.guild_id, role)} applied to " <>
            "#{Humanizer.human_user(member.user)} until #{Helpers.datetime_to_human(expiry)}"

        if reason != "" do
          response <> " with reason `#{Helpers.clean_content(reason)}`"
        else
          response
        end
      else
        {:ok, false} ->
          "🚫 you need to be above the target user in the role hierarchy"

        [{existing_id, existing_expiry}] ->
          "❌ there already is an infraction applying that role under ID ##{existing_id}" <>
            " which will expire on #{Helpers.datetime_to_human(existing_expiry)}"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _incorrect_args) do
    response = "ℹ️ usage: `temprole <user:member> <role:role> <duration:duration> [reason:str...]`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
