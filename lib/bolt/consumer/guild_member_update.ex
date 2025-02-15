defmodule Bolt.Consumer.GuildMemberUpdate do
  @moduledoc "Handles the `GUILD_MEMBER_UPDATE` event."

  alias Bolt.Events.Handler
  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Nostrum.Api.Guild
  alias Nostrum.Struct
  alias Nostrum.Struct.Guild.Member
  import Ecto.Query, only: [from: 2]

  @spec handle(
          guild_id :: Struct.Guild.id(),
          old_member :: Member.t() | nil,
          new_member :: Member.t()
        ) ::
          ModLog.on_emit()
  def handle(guild_id, nil, new_member) do
    # If the original member state could not be fetched from
    # the cache, we can only check for a forcenick violation.
    check_forcenick_violation(guild_id, nil, new_member)
  end

  def handle(guild_id, old_member, new_member) do
    perform_regular_modlog(guild_id, old_member, new_member)
    check_manual_temprole_removal(guild_id, old_member, new_member)
    check_forcenick_violation(guild_id, old_member, new_member)
  end

  @spec perform_regular_modlog(Struct.Guild.id(), Member.t(), Member.t()) :: ModLog.on_emit()
  def perform_regular_modlog(guild_id, old_member, new_member) do
    diff_string =
      []
      |> describe_if_changed(guild_id, old_member, new_member, :nick)
      |> describe_if_changed(guild_id, old_member, new_member, :roles)
      |> Enum.join(", ")

    unless diff_string == "" do
      ModLog.emit(
        guild_id,
        "GUILD_MEMBER_UPDATE",
        "#{Humanizer.human_user(new_member.user_id)} #{diff_string}"
      )
    end
  end

  @spec describe_if_changed([String.t()], Struct.Guild.id(), Member.t(), Member.t(), atom) :: [
          String.t()
        ]
  def describe_if_changed(diff_list, guild_id, old_member, new_member, :roles) do
    # Sort the roles to ensure that newly ordered roles don't
    # don't mess up the Myers difference calculation below.
    old_roles = Enum.sort(old_member.roles)
    new_roles = Enum.sort(new_member.roles)

    role_diff = List.myers_difference(old_roles, new_roles)

    added_roles = role_diff |> Keyword.get_values(:ins) |> List.flatten()
    removed_roles = role_diff |> Keyword.get_values(:del) |> List.flatten()

    diff_list ++
      Enum.map(
        added_roles,
        &"role added #{Humanizer.human_role(guild_id, &1)}"
      ) ++
      Enum.map(
        removed_roles,
        &"role removed #{Humanizer.human_role(guild_id, &1)}"
      )
  end

  def describe_if_changed(diff_list, _guild_id, old_member, new_member, key) do
    old_value = Map.get(old_member, key)
    new_value = Map.get(new_member, key)

    if old_value != new_value do
      cond do
        new_value === true ->
          diff_list ++ ["now #{key}"]

        new_value === false ->
          diff_list ++ ["no longer #{key}"]

        old_value === nil ->
          diff_list ++ ["added #{key} ``#{Helpers.clean_content(new_value)}``"]

        new_value === nil ->
          diff_list ++ ["removed #{key} ``#{Helpers.clean_content(old_value)}``"]

        true ->
          diff_list ++
            [
              "updated #{key} from ``#{Helpers.clean_content(old_value)}`` to ``#{Helpers.clean_content(new_value)}``"
            ]
      end
    else
      diff_list
    end
  end

  @spec check_manual_temprole_removal(Struct.Guild.id(), Member.t(), Member.t()) ::
          ModLog.on_emit() | :ignored
  defp check_manual_temprole_removal(guild_id, old_member, new_member) do
    with role_diff <- List.myers_difference(old_member.roles, new_member.roles),
         removed_roles when removed_roles != [] <- Keyword.get(role_diff, :del, []),
         removed_role_id <- List.first(removed_roles),
         query <-
           from(
             infr in Infraction,
             where:
               infr.guild_id == ^guild_id and infr.user_id == ^new_member.user_id and infr.active and
                 fragment("data->'role_id' = ?", ^removed_role_id) and infr.type == "temprole",
             limit: 1,
             select: infr
           ),
         active_temproles when active_temproles != [] <- Repo.all(query),
         active_temprole <- List.first(active_temproles),
         {:ok, _updated_infraction} <- Handler.update(active_temprole, %{active: false}) do
      ModLog.emit(
        guild_id,
        "INFRACTION_UPDATE",
        "role #{Humanizer.human_role(guild_id, removed_role_id)} was manually removed from " <>
          "#{Humanizer.human_user(new_member.user)}" <>
          "  while a temprole was active (##{active_temprole.id})" <>
          ", the infraction is now inactive and bolt will not attempt to remove the role"
      )
    else
      _err -> :ignored
    end
  end

  @spec check_forcenick_violation(Struct.Guild.id(), Member.t() | nil, Member.t()) ::
          ModLog.on_emit() | :ignored
  defp check_forcenick_violation(guild_id, old_member, new_member)

  defp check_forcenick_violation(_guild_id, %Member{nick: old_nick}, %Member{nick: new_nick})
       when old_nick == new_nick,
       do: :ignored

  defp check_forcenick_violation(guild_id, _old_member, new_member) do
    active_forcenick =
      Repo.get_by(Infraction,
        guild_id: guild_id,
        user_id: new_member.user_id,
        active: true,
        type: "forced_nick"
      )

    nick_description =
      if new_member.nick == nil do
        "removing their nickname"
      else
        "changing nickname to ``#{Helpers.clean_content(new_member.nick)}``"
      end

    with %Infraction{data: %{"nick" => forced_nick}} <- active_forcenick,
         false <- forced_nick == new_member.nick,
         {:ok, _member} <-
           Guild.modify_member(guild_id, new_member.user_id, nick: forced_nick) do
      ModLog.emit(
        guild_id,
        "INFRACTION_EVENTS",
        "#{Humanizer.human_user(new_member.user)} attempted #{nick_description} " <>
          " but has an active forcenick, nickname was reset to `#{forced_nick}`"
      )
    else
      # No active forcenick - all good.
      nil ->
        :ignored

      # New nick *is* the forced nick - all good, it was probably the bot that made this change.
      true ->
        :ignored

      # New nick is not the forced nick, but we couldn't modify it due to an API error.
      {:error, %{status_code: status, message: %{"message" => reason}}} ->
        ModLog.emit(
          guild_id,
          "INFRACTION_EVENTS",
          "failed to reset nick to forced nick on #{Humanizer.human_user(new_member.user)} got an API error: #{reason} (status code #{status})"
        )
    end
  end
end
