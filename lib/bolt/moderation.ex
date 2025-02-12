defmodule Bolt.Moderation do
  @moduledoc "Server moderation functions."

  alias Bolt.ErrorFormatters
  alias Bolt.Events.Handler
  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Nostrum.Api
  alias Nostrum.Struct.Guild
  alias Nostrum.Struct.User
  import Ecto.Query, only: [from: 2]

  @doc """
  Timeout the given user on the given guild.

  Takes care of:

  - creating the timeout on Discord
  - inserting an infraction database entry
  - reporting the timeout to the mod log
  - returning a user-presentable string

  ## Parameters

  - `target`: The user to ban, as a user-supplied string. See `Bolt.Helpers.into_id/2`.
  - `guild_id`: The guild on which to perform the ban.
  - `actor`: The user which is executing the ban action.
  - `reason`: The reason for the infraction database & audit log.
  - `expiry`: `t:DateTime.t/0` until which to mute the user, or `nil` for infinite.

  ## Return

  On success, a triple in the form `{:ok, created_infraction, target_user_humanized}`.
  On error, a pair in the for `{:error, description}`.
  """
  @spec timeout(String.t(), Guild.id(), User.t(), String.t() | nil, DateTime.t()) ::
          {:ok, Infraction.t(), String.t()} | {:error, String.t()}
  def timeout(target, guild_id, actor, reason, expiry) do
    with {:ok, target_id, converted_user} <- Helpers.into_id(guild_id, target),
         infraction = %{
           type: "timeout",
           guild_id: guild_id,
           user_id: target_id,
           actor_id: actor.id,
           expires_at: expiry,
           reason: if(reason != "", do: reason, else: nil)
         },
         {:ok, true} <- Helpers.above?(guild_id, actor.id, target_id),
         # Okay, technically it isn't permanent, but by that time humanity
         # will either be eradicated or has found better problems anyways, so
         {:ok, _member} <-
           Api.Guild.modify_member(guild_id, target_id, communication_disabled_until: expiry),
         changeset <- Infraction.changeset(%Infraction{}, infraction),
         {:ok, created_infraction} <- Repo.insert(changeset) do
      user_string = Humanizer.human_user(converted_user || target_id)

      ModLog.emit(
        guild_id,
        "INFRACTION_CREATE",
        "#{Humanizer.human_user(actor)} timed out #{user_string}" <>
          if(reason != "", do: " with reason `#{reason}`", else: "") <>
          if(expiry != nil, do: " until #{Helpers.datetime_to_human(expiry)}", else: "forever")
      )

      {:ok, created_infraction, user_string}
    else
      {:ok, false} ->
        {:error, "🚫 you need to be above the target user in the role hierarchy", "`#{target}`"}

      error ->
        # user_string always defined here, since failure
        # of the defining line is caught above.
        {:error, ErrorFormatters.fmt(nil, error), "`#{target}`"}
    end
  end

  @doc """
  Ban the given user on the given guild.

  Takes care of:

  - creating the ban on Discord
  - inserting an infraction database entry
  - reporting the ban to the mod log
  - returning a user-presentable string

  ## Parameters

  - `guild_id`: The guild on which to perform the ban.
  - `target`: The user to ban. See `Bolt.Helpers.into_id/2`.
  - `actor_id`: The user which is executing the ban action.
  - `reason`: The reason for the infraction database & audit log.

  ## Returns

  Returns the created infraction with a string describing the banned user on
  success, or a user-facing error message on failure.
  """
  @spec ban(String.t(), Guild.id(), User.t(), String.t()) ::
          {:ok, Infraction.t(), String.t()} | {:error, String.t()}
  def ban(target, guild_id, actor, reason) do
    with {:ok, target_id, converted_user} <- Helpers.into_id(guild_id, target),
         infraction = %{
           type: "ban",
           guild_id: guild_id,
           user_id: target_id,
           actor_id: actor.id,
           reason: if(reason != "", do: reason, else: nil)
         },
         {:ok, true} <- Helpers.above?(guild_id, actor.id, target_id),
         {:ok} <- Api.Guild.ban_member(guild_id, target_id, 7),
         changeset <- Infraction.changeset(%Infraction{}, infraction),
         {:ok, created_infraction} <- Repo.insert(changeset) do
      user_string = Humanizer.human_user(converted_user || target_id)

      ModLog.emit(
        guild_id,
        "INFRACTION_CREATE",
        "#{Humanizer.human_user(actor)} banned #{user_string}" <>
          if(reason != "", do: " with reason `#{reason}`", else: "")
      )

      expire_tempbans(guild_id, target_id, actor, created_infraction.id)
      {:ok, created_infraction, user_string}
    else
      {:ok, false} ->
        {:error, "🚫 you need to be above the target user in the role hierarchy", "`#{target}`"}

      error ->
        {:error, ErrorFormatters.fmt(nil, error), "`#{target}`"}
    end
  end

  # Helper functions
  @spec expire_tempbans(Guild.id(), User.id(), User.t(), pos_integer()) :: ModLog.on_emit()
  defp expire_tempbans(guild_id, target_id, actor, ban_infraction_id) do
    tempban_query =
      from(
        infr in Infraction,
        where:
          infr.active and infr.user_id == ^target_id and infr.guild_id == ^guild_id and
            infr.type == "tempban",
        limit: 1,
        select: infr
      )

    case Repo.all(tempban_query) do
      [infr] ->
        # Kill the existing tempban from the timed event handler.
        {:ok, _updated_infraction} = Handler.update(infr, %{active: false})

        ModLog.emit(
          guild_id,
          "INFRACTION_UPDATE",
          "tempban ##{infr.id} was obsoleted by ban from #{User.full_name(actor)} (##{ban_infraction_id})"
        )

      [] ->
        :noop
    end
  end
end
