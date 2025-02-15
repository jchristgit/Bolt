defmodule Bolt.Events.Deserializer do
  @moduledoc "Deserializes JSONB data from rows from the `events` into Elixir functions."

  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Nostrum.Api.Guild
  require Logger

  @spec deserialize(Infraction) :: (-> any())
  def deserialize(%Infraction{
        id: infraction_id,
        type: "temprole",
        guild_id: guild_id,
        user_id: user_id,
        data: %{"role_id" => role_id}
      }) do
    func = fn ->
      human_role = Humanizer.human_role(guild_id, role_id)
      human_user = Humanizer.human_user(user_id)

      case Guild.remove_member_role(guild_id, user_id, role_id) do
        {:ok} ->
          ModLog.emit(
            guild_id,
            "INFRACTION_EVENTS",
            "removed temporary role #{human_role} from #{human_user} (##{infraction_id})"
          )

        {:error, %{message: %{"message" => reason}}} ->
          ModLog.emit(
            guild_id,
            "INFRACTION_EVENTS",
            "could NOT remove temporary role #{human_role} from #{human_user} (#{reason}, infraction ##{infraction_id})"
          )

        _error ->
          ModLog.emit(
            guild_id,
            "INFRACTION_EVENTS",
            "could NOT remove temporary role #{human_role} from #{human_user} (unexpected error, infraction ##{infraction_id})"
          )
      end
    end

    {:ok, func}
  end

  def deserialize(%Infraction{
        id: infraction_id,
        type: "tempban",
        guild_id: guild_id,
        user_id: user_id
      }) do
    func = fn ->
      human_user = Humanizer.human_user(user_id)

      case Guild.unban_member(guild_id, user_id) do
        {:ok} ->
          ModLog.emit(
            guild_id,
            "INFRACTION_EVENTS",
            "removed temporary ban for #{human_user} (##{infraction_id})"
          )

        {:error, %{message: %{"message" => reason}}} ->
          ModLog.emit(
            guild_id,
            "ERROR",
            "could NOT remove temporary ban for #{human_user} (#{reason}, infraction ##{infraction_id})"
          )

        err ->
          Logger.error("Failed to remove tempban (infr #{infraction_id}): #{inspect(err)}")

          ModLog.emit(
            guild_id,
            "ERROR",
            "failed to remove temporary ban for #{human_user} (unexpected error, infraction ##{infraction_id})"
          )
      end
    end

    {:ok, func}
  end

  def deserialize(%Infraction{type: "forced_nick"} = infraction) do
    func = fn ->
      changeset = Infraction.changeset(infraction, %{active: false})
      Repo.update(changeset)
    end

    {:ok, func}
  end

  def deserialize(%Infraction{
        type: type,
        id: infraction_id,
        guild_id: guild_id,
        user_id: user_id,
        data: %{
          "role_id" => mute_role_id
        }
      })
      when type in ["tempmute", "mute"] do
    func = fn ->
      human_user = Humanizer.human_user(user_id)

      modlog_message =
        case Guild.remove_member_role(guild_id, user_id, mute_role_id) do
          {:ok} ->
            "user #{human_user} was unmuted (##{infraction_id})"

          {:error, %{message: %{"message" => reason}}} ->
            "failed to unmute #{human_user}, got API error: #{reason} (infraction ##{infraction_id})"
        end

      ModLog.emit(
        guild_id,
        "INFRACTION_EVENTS",
        modlog_message
      )
    end

    {:ok, func}
  end
end
