defmodule Bolt.Cogs.ModLog.Set do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.ModLogConfig
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["modlog set <event:str> <channel:textchannel>"]

  @impl true
  def description,
    do: """
    Set the given `event` to be logged in `channel`.
    `ALL` can be given in place of `event` in order to delete any existing configuration(s) and log all events to `channel`.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, ["all", channel]) do
    response =
      with {:ok, channel} <- Converters.to_channel(channel, msg.guild_id),
           query <- from(config in ModLogConfig, where: config.guild_id == ^msg.guild_id),
           {total_deleted, _maybe_deleted_rows} <- Repo.delete_all(query),
           new_configs <-
             ModLogConfig.valid_events()
             |> Enum.map(
               &%{
                 guild_id: msg.guild_id,
                 channel_id: channel.id,
                 event: &1
               }
             ),
           {_total_inserted, _maybe_inserted_rows} <- Repo.insert_all(ModLogConfig, new_configs) do
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{Humanizer.human_user(msg.author)} set the log channel" <>
            " for ALL events to <##{channel.id}>"
        )

        if total_deleted > 0 do
          "👌 deleted #{total_deleted} existing configs," <>
            " will now log all events to <##{channel.id}>"
        else
          "👌 will now log all events to <##{channel.id}>"
        end
      else
        {:error, reason} ->
          "🚫 invalid channel: #{Helpers.clean_content(reason)}"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, [event, channel]) do
    event = String.upcase(event)

    response =
      with {:ok, channel} <- Converters.to_channel(channel, msg.guild_id),
           config_map <- %{
             guild_id: msg.guild_id,
             channel_id: channel.id,
             event: event
           },
           changeset <- ModLogConfig.changeset(%ModLogConfig{}, config_map),
           {:ok, _created_config} <-
             Repo.insert(changeset,
               on_conflict: {:replace, [:channel_id]},
               conflict_target: [:guild_id, :event]
             ) do
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{Humanizer.human_user(msg.author)} set the log channel" <>
            " for event `#{event}` to <##{channel.id}>"
        )

        "👌 will now log `#{event}` events in <##{channel.id}>"
      else
        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `modlog set <event:str> <channel:textchannel>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
