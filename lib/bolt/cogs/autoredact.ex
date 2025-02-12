defmodule Bolt.Cogs.Autoredact do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Parsers
  alias Bolt.Predicates
  alias Bolt.Redact
  alias Nostrum.Api.Message
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Snowflake
  import Bolt.Helpers, only: [clean_content: 1]

  @impl true
  def usage,
    do: [
      "autoredact <guild:guild> <age:duration> [excluded_channel:textchannel...]",
      "autoredact <guild:guild> off",
      "autoredact <guild:guild> status"
    ]

  @impl true
  def description,
    do: """
    Automatically redact (delete) messages in all text channels on the given
    guild ID authored by you older than the given `age`. `age` must be at least
    one hour. One or more channels to be excluded can be specified.

    **Example**
    ```rs
    // Automatically redact all your messages on guild 1234 older than 2 days
    .autoredact 1234 2d

    // Same as above, but ignore the #announcements and #staff channels
    .autoredact 1234 2d #announcements #staff

    // Switch off auto redaction for the given guild
    .autoredact 1234 off

    // Query status for the given guild
    .autoredact 1234 status
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.dm_only/1]

  @impl true
  def command(msg, [raw_guild, "off"]) do
    response =
      case Snowflake.cast(raw_guild) do
        {:ok, guild_id} ->
          case Redact.unconfigure(guild_id, msg.author.id) do
            0 -> "🚫 no configurations were found for you on there"
            1 -> "👌 fly safe"
          end

        :error ->
          "🚫 bad guild ID"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, [raw_guild, "status"]) do
    response =
      case Snowflake.cast(raw_guild) do
        {:ok, guild_id} ->
          case Redact.info(guild_id, msg.author.id) do
            nil ->
              "ℹ️  no configuration set up"

            info ->
              pretty_exclusions = format_exclusions(info.config.excluded_channels)

              """
              ℹ️  **auto redact config** for `#{guild_id}`
              \\- minimum age: #{info.config.age_in_seconds}s
              \\- messages pending removal: `#{info.pending_messages}`
              \\- excluded channels:
              #{pretty_exclusions}
              """
          end

        :error ->
          "🚫 bad guild ID"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, [raw_guild, raw_age | raw_excluded_channels]) do
    response =
      with {:ok, guild_id} <- Snowflake.cast(raw_guild),
           {:ok, guild} <- GuildCache.get(guild_id),
           {:ok, age_in_seconds} <- Parsers.duration_string_to_seconds(raw_age),
           {:ok, excluded_channels} <- parse_excluded_channels(raw_excluded_channels),
           {:invalid_channels, []} <- find_invalid_channels(excluded_channels, guild),
           {:ok, _config} <-
             Redact.configure(guild_id, msg.author.id, age_in_seconds, excluded_channels) do
        "👌 fly safe"
      else
        {:invalid_channels, _channels} ->
          "🚫 one or more given channels are unknown to me"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage:\n```rs\n#{Enum.join(usage(), "\n")}\n```"
    {:ok, _msg} = Message.create(msg, response)
  end

  defp parse_excluded_channels(channels) do
    case do_parse_excluded_channels(channels) do
      {:error, _why} = result -> result
      channels -> {:ok, channels}
    end
  end

  defp do_parse_excluded_channels([channel | channels]) do
    case Snowflake.cast(channel) do
      :error ->
        {:error, "bad channel id #{clean_content(to_string(channel))}"}

      {:ok, channel_id} ->
        [channel_id | do_parse_excluded_channels(channels)]
    end
  end

  defp do_parse_excluded_channels([]) do
    []
  end

  def format_exclusions(exclusions) do
    exclusions
    |> Stream.map(&"  \\- <##{&1}>")
    |> Enum.join("\n")
    |> then(&if(&1 == "", do: "    \\- (none)", else: &1))
  end

  def find_invalid_channels(channel_ids, guild) do
    {:invalid_channels, Enum.reject(channel_ids, &Map.has_key?(guild.channels, &1))}
  end
end
