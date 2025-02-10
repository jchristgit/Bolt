defmodule Bolt.Cogs.Clean do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Parsers
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api
  alias Nostrum.Cache.ChannelGuildMapping
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User

  @impl true
  def usage, do: ["clean <amount:int>", "clean <options...>"]

  @impl true
  def description,
    do: """
    Cleanup messages. The execution of this command can be customized with the following options:
    `--bots`: Only clean messages authored by bots
    `--no-bots`: Do not clean any messages authored by bots
    `--limit <amount:int>`: Specify the limit of messages to delete, capped at 1000
    `--channel <channel:textchannel>`: The channel to delete messages in
    `--user <user:snowflake|user>`: Only delete messages by this user, can be specified multiple times
    `--content <content:str>`: Only delete messages containing `content`

    **Examples**:
    ```rs
    // delete 60 messages in the current channel
    clean 60

    // delete up to 10 messages by
    // bots in the current channel
    clean --bots --limit 10

    // delete up to 30 messages sent
    // by 197177484792299522 in the #fsharp channel
    clean --user 197177484792299522 --channel #fsharp

    // delete up to 50 messages containing
    // "lol no generics" in the #golang channel
    clean --content "lol no generics" --channel #golang --limit 50
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  def parse_args(args) do
    OptionParser.parse(
      args,
      strict: [
        # --bots | --no-bots
        #   clean only bot messages, or exclude bot messages from cleaning
        bots: :boolean,
        # --channel <channel:textchannel>
        #   clean in the given channel instead of the current one
        channel: :string,
        # --limit <limit:int>
        #   clean at most `limit` messages
        limit: :integer,
        # --user <user:snowflake|user>
        #   clean only messages by `user`, can be specified multiple times
        user: [:string, :keep],
        # --content <str>
        #   clean only messages containing `content` (case-insensitive)
        content: :string
      ]
    )
  end

  @impl true
  def command(msg, {options, [], []}) when options != [] do
    with {:ok, target_channel_id} <-
           parse_channel(msg.guild_id, options[:channel], msg.channel_id),
         limit <- min(Keyword.get(options, :limit, 100), 1000),
         {:ok, messages} when messages != [] <-
           Api.Channel.messages(target_channel_id, limit, {:before, msg.id}),
         {:ok, message_stream} <- apply_filter(messages, :bots, options[:bots], msg.guild_id),
         {:ok, message_stream} <-
           apply_filter(message_stream, :user, options[:user], msg.guild_id),
         {:ok, message_stream} <-
           apply_filter(message_stream, :content, options[:content], msg.guild_id),
         false <- Enum.empty?(message_stream),
         messages_to_delete <- Enum.to_list(message_stream),
         message_ids <- Enum.map(messages_to_delete, & &1.id),
         {:ok} <- Api.Channel.bulk_delete_messages(msg.channel_id, message_ids) do
      Api.Message.react(msg.channel_id, msg.id, "👌")

      log_content =
        messages_to_delete
        |> Stream.map(
          &"#{String.pad_leading(&1.author.username, 20)}##{&1.author.discriminator}: #{&1.content}"
        )
        |> Enum.reverse()
        |> Enum.join("\n")

      ModLog.emit(
        msg.guild_id,
        "MESSAGE_CLEAN",
        "#{Humanizer.human_user(msg.author)} deleted" <>
          " #{length(messages_to_delete)} messages in <##{target_channel_id}>",
        file: %{
          name: "deleted_messages.log",
          body: log_content
        }
      )
    else
      {:ok, []} ->
        # No messages returned from the API call
        response = "🚫 no messages found, does the bot have `READ_MESSAGE_HISTORY` "
        {:ok, _msg} = Api.Message.create(msg.channel_id, response)

      # `message_stream` is empty
      true ->
        # No messages found after filter application
        response = "🚫 no messages found matching the given options"
        {:ok, _msg} = Api.Message.create(msg.channel_id, response)

      error ->
        response = ErrorFormatters.fmt(msg, error)
        {:ok, _msg} = Api.Message.create(msg.channel_id, response)
    end
  end

  def command(msg, {[], [], []}) do
    response =
      "ℹ️ usage: `#{List.first(usage())}` or `#{List.last(usage())}`, " <>
        "see `help clean` for options"

    {:ok, _msg} = Api.Message.create(msg.channel_id, response)
  end

  def command(msg, {[], [maybe_amount | []], []}) do
    case Integer.parse(maybe_amount) do
      {amount, ""} ->
        command(msg, {[limit: amount], [], []})

      :error ->
        response =
          "🚫 expected options or limit to prune as sole argument, " <> "see `help clean` for help"

        {:ok, _msg} = Api.Message.create(msg.channel_id, response)
    end
  end

  def command(msg, {[], [_maybe_amount | _unrecognized_args], []}) do
    {:ok, _msg} =
      Api.Message.create(
        msg.channel_id,
        "🚫 expected the message limit as the sole argument, but got some other unrecognized args"
      )
  end

  def command(msg, {options, args, []}) when options != [] and args != [] do
    {:ok, _msg} =
      Api.Message.create(
        msg.channel_id,
        "🚫 expected either a sole argument (amount to delete) or exact options, got both"
      )
  end

  def command(msg, {_parsed, _args, invalid}) when invalid != [] do
    invalid_args = Parsers.describe_invalid_args(invalid)

    {:ok, _msg} =
      Api.Message.create(
        msg.channel_id,
        "🚫 unrecognized argument(s) or invalid value: #{invalid_args}"
      )
  end

  @spec parse_channel(
          invocation_guild_id :: Guild.id(),
          passed_channel :: String.t() | nil,
          default_channel_id :: Channel.id()
        ) :: {:ok, Channel.id()} | {:error, String.t()}
  defp parse_channel(_guild_id, nil, default_id), do: {:ok, default_id}

  defp parse_channel(guild_id, passed_channel, _default_id) do
    case Converters.to_channel(passed_channel, guild_id) do
      {:ok, channel} -> {:ok, channel.id}
      {:error, reason} -> {:error, "could not parse `channel` argument: #{reason}"}
    end
  end

  @spec apply_filter([Message.t()], atom(), String.t(), Guild.id()) ::
          {:ok, [Message.t()]} | {:error, String.t()}
  defp apply_filter(messages, option_name, option_val, guild_id)

  defp apply_filter(messages, :bots, nil, _guild_id), do: {:ok, messages}
  # `--bots` given: exclude non-bots
  defp apply_filter(messages, :bots, true, _guild_id),
    do: {:ok, Stream.filter(messages, & &1.author.bot)}

  # `--no-bots` given: exclude bots
  defp apply_filter(messages, :bots, false, _guild_id),
    do: {:ok, Stream.reject(messages, & &1.author.bot)}

  defp apply_filter(messages, :user, nil, _guild_id), do: {:ok, messages}
  # single `--user` flag given, `OptionParser` passes it as a string
  defp apply_filter(messages, :user, user, _guild_id) when is_bitstring(user) do
    [%Message{channel_id: channel_id}] = Enum.take(messages, 1)

    with guild_id when guild_id != nil <- ChannelGuildMapping.get(channel_id),
         {:ok, snowflake} <- parse_snowflake(guild_id, user) do
      filtered = Stream.filter(messages, &(&1.author.id == snowflake))
      {:ok, filtered}
    else
      error ->
        error
    end
  end

  # multiple `--user` flags given
  defp apply_filter(messages, :user, users, guild_id) do
    parsed_snowflakes = Enum.map(users, &parse_snowflake(guild_id, &1))

    # Did any given flag not parse correctly?
    if Enum.any?(parsed_snowflakes, &match?({:error, _reason}, &1)) do
      # If yes, build a string of errors and return it.
      error_description =
        parsed_snowflakes
        |> Stream.filter(&match?({:error, _reason}, &1))
        |> Stream.map(&elem(&1, 1))
        |> Stream.map(&"• #{&1}")
        |> Enum.join("\n")

      {:error, "🚫 failed to parse `--user` flag:\n#{error_description}"}
    else
      # If not, return only messages that were sent by the given snowflakes.
      filtered_messages = Stream.filter(messages, &(&1.author.id in parsed_snowflakes))
      {:ok, filtered_messages}
    end
  end

  defp apply_filter(messages, :content, nil, _guild_id), do: {:ok, messages}

  defp apply_filter(messages, :content, content, _guild_id) do
    {:ok, Stream.filter(messages, &(content in &1.content))}
  end

  @spec parse_snowflake(Guild.id(), String.t()) :: {:ok, User.id()} | {:error, String.t()}
  defp parse_snowflake(guild_id, user_string) do
    case Integer.parse(user_string) do
      # If the given flag is a valid integer, we're going to
      # assume that the command invocator passed a raw snowflake
      # to the `--user` flag.
      # Although the member converter accounts for this, it only
      # searches members on the guild. If a user left the server,
      # we have no way of converting a regular user string properly.
      {snowflake, ""} ->
        {:ok, snowflake}

      _error ->
        # Otherwise, assume it's a string describing a guild member,
        # so let's ask the converter to find us the matching member.
        case Converters.to_member(user_string, guild_id) do
          {:ok, member} ->
            {:ok, member.user_id}

          error ->
            error
        end
    end
  end
end
