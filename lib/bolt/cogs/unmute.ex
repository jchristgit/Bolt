defmodule Bolt.Cogs.Unmute do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Ecto.Changeset
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Guild
  alias Nostrum.Api.Message
  alias Nostrum.Struct.User
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["unmute <user:member...>"]

  @impl true
  def description,
    do: """
    Unmutes the given `user`. Requires that the user is currently muted.
    Requires the `MANAGE_MESSAGES` permission.
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  def command(msg, user_list) when user_list != [] do
    response =
      with {:ok, member} <- Converters.to_member(Enum.join(user_list, " "), msg.guild_id),
           mute_query <-
             from(
               infr in Infraction,
               where:
                 infr.guild_id == ^msg.guild_id and infr.user_id == ^member.user.id and
                   infr.type == "timeout" and infr.expires_at > ^DateTime.utc_now()
             ),
           mute_infraction when mute_infraction != nil <- Repo.one(mute_query),
           {:ok, _modified_member} <-
             Guild.modify_member(
               mute_infraction.guild_id,
               mute_infraction.user_id,
               communication_disabled_until: nil
             ),
           {:ok, updated_infraction} <- expire_mute(mute_infraction) do
        ModLog.emit(
          msg.guild_id,
          "INFRACTION_UPDATE",
          "#{User.full_name(msg.author)} unmuted " <>
            "#{User.full_name(member.user)} (##{updated_infraction.id})"
        )

        "👌 #{User.full_name(member.user)} is now unmuted"
      else
        nil ->
          "🚫 there is no active mute or tempmute for the given user"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{List.first(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  @spec expire_mute(Infraction) :: {:ok, Infraction} | {:error, String.t() | Changeset.t()}
  defp expire_mute(infraction) do
    infraction
    |> Infraction.changeset(%{active: false})
    |> Repo.update()
  end
end
