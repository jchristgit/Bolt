defmodule Bolt.Cogs.ModLog.Unset do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.ModLogConfig
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["modlog unset <event:str>"]

  @impl true
  def description,
    do: """
    Disables logging of the given `event`.
    `all` can be given in place of `event` in order to stop logging all events.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, ["all"]) do
    import Ecto.Query, only: [from: 2]

    # log before the log channel is deleted to ensure this log still appears there
    ModLog.emit(
      msg.guild_id,
      "CONFIG_UPDATE",
      "#{Humanizer.human_user(msg.author)} unset the log channel" <>
        " for ALL events"
    )

    query = from(config in ModLogConfig, where: config.guild_id == ^msg.guild_id)
    {deleted, nil} = Repo.delete_all(query)

    response = "👌 deleted #{deleted} existing mod log configuration(s)"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, [event]) do
    event = String.upcase(event)

    response =
      if event in ModLogConfig.valid_events() do
        case Repo.get_by(ModLogConfig, guild_id: msg.guild_id, event: event) do
          nil ->
            "🚫 event `#{event}` has no log channel configured"

          config ->
            {:ok, _struct} = Repo.delete(config)

            ModLog.emit(
              msg.guild_id,
              "CONFIG_UPDATE",
              "#{Humanizer.human_user(msg.author)} unset the log channel" <>
                " for event `#{event}` (was <##{config.channel_id}>)"
            )

            "👌 unset the log channel for `#{event}` (was <##{config.channel_id}>)"
        end
      else
        "🚫 `#{Helpers.clean_content(event)}` is not a known event"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `modlog unset <event:str>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
