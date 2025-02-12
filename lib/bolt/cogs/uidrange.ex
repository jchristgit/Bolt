defmodule Bolt.Cogs.UidRange do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.Constants
  alias Bolt.ErrorFormatters
  alias Bolt.Paginator
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Cache.UserCache
  alias Nostrum.Struct.Embed

  @impl true
  def usage,
    do: ["uidrange <from:snowflake> [to] <upper:snowflake>", "uidrange from <lower:snowflake>"]

  @impl true
  def description,
    do: """
    Display all users in the given inclusive range of snowflakes.
    Useful for finding accounts on the server that were created
    in a certain period, or for usage in combination with `banrange`.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1]

  @impl true
  def command(msg, ["from", lower]) do
    case Integer.parse(lower) do
      {start, ""} ->
        msg.guild_id
        |> find_matches(start)
        |> Enum.sort()
        |> display_matches(msg.channel_id)

      :error ->
        Message.create(msg.channel_id, "🚫 invalid snowflake, sorry")
    end
  end

  def command(msg, [from, "to", to]) do
    command(msg, [from, to])
  end

  def command(msg, [from, to]) do
    with {start, ""} <- Integer.parse(from),
         {stop, ""} <- Integer.parse(to) do
      msg.guild_id
      |> find_matches(start, stop)
      |> Enum.sort()
      |> display_matches(msg.channel_id)
    else
      :error ->
        Message.create(msg.channel_id, "🚫 invalid snowflakes, sorry")
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{usage()}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  defp find_matches(guild_id, from) do
    :bolt_member_qlc.ids_above(guild_id, from)
  end

  defp find_matches(guild_id, from, to) do
    :bolt_member_qlc.ids_within(guild_id, from, to)
  end

  defp display_matches({:error, why}, where) do
    response = ErrorFormatters.fmt(nil, why)
    {:ok, _msg} = Message.create(where, response)
  end

  defp display_matches(matches, where) do
    matches
    |> Stream.chunk_every(10)
    |> Enum.map(&format_chunk/1)
    |> paginate(where)
  end

  defp format_entry({snowflake, _member}) do
    user = UserCache.get!(snowflake)
    "- `#{snowflake}` (#{user.username}##{user.discriminator})"
  end

  defp format_chunk(chunk) do
    formatted = Stream.map(chunk, &format_entry/1)
    %Embed{description: Enum.join(formatted, "\n")}
  end

  defp paginate(pages, channel_id) do
    base_page = %Embed{
      title: "ID range results",
      color: Constants.color_blue()
    }

    fake_msg = %{channel_id: channel_id}
    Paginator.paginate_over(fake_msg, base_page, pages)
  end
end
