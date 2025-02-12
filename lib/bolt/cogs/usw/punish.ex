defmodule Bolt.Cogs.USW.Punish do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Bolt.{Helpers, Parsers, Repo}
  alias Bolt.Schema.USWPunishmentConfig
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["usw punish <punishment...>"]

  @impl true
  def description,
    do: """
    Sets the punishment to be applied when a filter triggers.

    Existing punishments:
    • `temprole <role:role> <duration:duration>`: Temporarily `role` for `duration`. This can be useful to mute members temporarily.
    • `timeout <duration:duration>`: Time out the target user for `duration`. Uses Discord's native timeout functionality.

    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, ["temprole", role, duration]) do
    response =
      with {:ok, role} <- Converters.to_role(role, msg.guild_id),
           {:ok, total_seconds} <- Parsers.duration_string_to_seconds(duration),
           new_config <- %{
             guild_id: msg.guild_id,
             duration: total_seconds,
             punishment: "TEMPROLE",
             data: %{
               "role_id" => role.id
             }
           },
           changeset <- USWPunishmentConfig.changeset(%USWPunishmentConfig{}, new_config),
           {:ok, _config} <-
             Repo.insert(
               changeset,
               conflict_target: [:guild_id],
               on_conflict: :replace_all
             ) do
        "👌 punishment is now applying temporary role `#{role.name}` for" <>
          " #{total_seconds} seconds"
      else
        {:error, reason} ->
          "🚫 error: #{Helpers.clean_content(reason)}"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, ["timeout", duration]) do
    response =
      with {:ok, total_seconds} <- Parsers.duration_string_to_seconds(duration),
           new_config <- %{
             guild_id: msg.guild_id,
             duration: total_seconds,
             punishment: "TIMEOUT",
             data: %{}
           },
           changeset <- USWPunishmentConfig.changeset(%USWPunishmentConfig{}, new_config),
           {:ok, _config} <-
             Repo.insert(
               changeset,
               conflict_target: [:guild_id],
               on_conflict: :replace_all
             ) do
        "👌 punishment is now timing out users for" <>
          " #{total_seconds} seconds"
      else
        {:error, reason} ->
          "🚫 error: #{Helpers.clean_content(reason)}"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, [_unknown_type | _args]) do
    response = "🚫 unknown punishment type"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
