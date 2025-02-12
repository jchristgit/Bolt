defmodule Bolt.Cogs.Starboard.Configure do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.ModLog
  alias Bolt.Starboard
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  import Bolt.Humanizer, only: [human_user: 1]

  @impl true
  def usage, do: ["starboard configure <channel:textchannel> [min_stars=5]"]

  @impl true
  def description,
    do: """
    Configure the starboard to send messages having at least `min_stars` star reactions
    to the given text channel.
    Requires the `MANAGE_MESSAGES` permission.

    **Examples**:
    ```rs
    starboard configure #starboard 10
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  def command(msg, [raw_channel]) do
    command(msg, [raw_channel, 5])
  end

  def command(msg, [raw_channel, min_stars]) do
    with {:ok, channel} <- Converters.to_channel(raw_channel, msg.guild_id),
         {:ok, _config} <-
           Starboard.configure(msg.guild_id, channel.id, min_stars) do
      ModLog.emit(
        msg.guild_id,
        "CONFIG_UPDATE",
        "#{human_user(msg.author)} configured the starboard in <##{channel.id}> for a minimum of #{min_stars} star(s)"
      )

      {:ok, _msg} = Message.create(msg.channel_id, "👌 enabled the starboard in <##{channel.id}>")
    else
      error ->
        response = ErrorFormatters.fmt(msg, error)
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _anything) do
    response = "ℹ️ usage: `#{hd(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
