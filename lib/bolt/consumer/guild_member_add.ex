defmodule Bolt.Consumer.GuildMemberAdd do
  @moduledoc "Handles the `GUILD_MEMBER_ADD` event."

  alias Bolt.{Helpers, Humanizer, ModLog, Repo}
  alias Bolt.Schema.{Infraction, JoinAction}
  alias Nostrum.Api.Guild
  alias Nostrum.Api.Message
  alias Nostrum.Api.User
  alias Nostrum.Snowflake
  alias Nostrum.Struct
  alias Nostrum.Struct.Guild.Member
  import Ecto.Query, only: [from: 2]

  @spec handle(Struct.Guild.id(), Struct.Guild.Member.t()) :: {:ok, Struct.Message.t()}
  def handle(guild_id, member) do
    creation_datetime = Snowflake.creation_time(member.user_id)

    ModLog.emit(
      guild_id,
      "GUILD_MEMBER_ADD",
      "#{Humanizer.human_user(member.user_id)} has joined " <>
        "- account created #{Helpers.datetime_to_human(creation_datetime)}"
    )

    check_active_temprole(guild_id, member)
    execute_join_actions(guild_id, member)
  end

  @spec check_active_temprole(Struct.Guild.id(), Struct.Guild.Member.t()) ::
          :ignored | ModLog.on_emit()
  defp check_active_temprole(guild_id, member) do
    query =
      from(
        infr in Infraction,
        where:
          infr.guild_id == ^guild_id and infr.user_id == ^member.user_id and
            infr.type == "temprole" and infr.expires_at > ^DateTime.utc_now(),
        select: infr
      )

    case Repo.all(query) do
      [] ->
        :ignored

      infractions ->
        Enum.each(infractions, fn temprole_infraction ->
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          case Guild.add_member_role(
                 guild_id,
                 member.user.id,
                 temprole_infraction.data["role_id"]
               ) do
            {:ok} ->
              ModLog.emit(
                guild_id,
                "INFRACTION_EVENTS",
                "member #{Humanizer.human_user(member.user)} with active temprole" <>
                  " (#{Humanizer.human_role(guild_id, temprole_infraction.data["role_id"])}) rejoined, temporary role was reapplied"
              )

            {:error, %{message: %{"message" => reason}}} ->
              ModLog.emit(
                guild_id,
                "INFRACTION_EVENTS",
                "member #{Humanizer.human_user(member.user)} with active temprole" <>
                  " rejoined, but failed to reapply role: `#{reason}`"
              )
          end
        end)
    end
  end

  @spec execute_join_actions(Struct.Guild.id(), Struct.Guild.Member.t()) :: :ok
  defp execute_join_actions(guild_id, member) do
    query = from(action in JoinAction, where: action.guild_id == ^guild_id)

    query
    |> Repo.all()
    |> Enum.each(&execute_single_action(&1, guild_id, member))
  end

  @spec execute_single_action(JoinAction, Struct.Guild.id(), Struct.Guild.Member.t()) ::
          {:ok, Message.t()} | :ignored | :ok
  defp execute_single_action(action, guild_id, member)

  defp execute_single_action(
         %JoinAction{action: "add_role", data: %{"role_id" => role_id}},
         guild_id,
         member
       ) do
    case Guild.add_member_role(guild_id, member.user.id, role_id) do
      {:ok} ->
        :ok

      {:error, %{status_code: status, message: %{"message" => reason}}} ->
        ModLog.emit(
          guild_id,
          "ERROR",
          "tried adding role #{Humanizer.human_role(guild_id, role_id)} to #{Humanizer.human_user(member.user)} " <>
            "but got an API error: #{reason} (status code #{status})"
        )
    end
  end

  defp execute_single_action(
         %JoinAction{
           action: "send_guild",
           data: %{"channel_id" => target_channel, "template" => template}
         },
         _guild_id,
         member
       ) do
    text = String.replace(template, "{mention}", Member.mention(member))

    Message.create(target_channel, text)
  end

  defp execute_single_action(
         %JoinAction{action: "send_dm", data: %{"template" => template}},
         _guild_id,
         member
       ) do
    text = String.replace(template, "{mention}", Member.mention(member))

    case User.create_dm(member.user.id) do
      {:ok, dm_channel} ->
        Message.create(dm_channel.id, text)

      _error ->
        :ignored
    end
  end
end
