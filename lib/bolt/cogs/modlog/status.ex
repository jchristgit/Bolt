defmodule Bolt.Cogs.ModLog.Status do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Nosedrum.TextCommand.Predicates
  alias Bolt.{Constants, Paginator, Repo}
  alias Bolt.Schema.ModLogConfig
  alias Nostrum.Api.Message
  alias Nostrum.Struct.Embed
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["modlog status", "modlog status unlogged"]

  @impl true
  def description,
    do: """
    View the current configuration of the mod log.
    Shows which events are logged in which channel(s).
    If invoked as `modlog status unlogged`, shows which events are currently not logged.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, []) do
    query = from(config in ModLogConfig, where: config.guild_id == ^msg.guild_id, select: config)

    case Repo.all(query) do
      [] ->
        response = "❌ modlog is not configured"
        {:ok, _msg} = Message.create(msg.channel_id, response)

      config_rows ->
        pages =
          config_rows
          |> Enum.group_by(
            fn row -> row.event end,
            fn row -> row.channel_id end
          )
          |> Map.to_list()
          |> Stream.map(fn {event, channels} ->
            {event, Stream.map(channels, &"<##{&1}>")}
          end)
          |> Stream.map(fn {event, channels} ->
            "• `#{event}` is logged in #{Enum.join(channels, ", ")}"
          end)
          |> Stream.chunk_every(6)
          |> Enum.map(fn entry_chunk ->
            %Embed{
              description: Enum.join(entry_chunk, "\n")
            }
          end)

        base_embed = %Embed{
          title: "Mod log configuration",
          color: Constants.color_blue()
        }

        Paginator.paginate_over(msg, base_embed, pages)
    end
  end

  def command(msg, ["unlogged"]) do
    query =
      from(config in ModLogConfig, where: config.guild_id == ^msg.guild_id, select: config.event)

    logged_events =
      query
      |> Repo.all()
      |> MapSet.new()

    all_events = MapSet.new(ModLogConfig.valid_events())
    unlogged_events = MapSet.difference(all_events, logged_events)

    response =
      if Enum.empty?(unlogged_events) do
        "ℹ️  all known events are logged already"
      else
        "ℹ️  unlogged events: #{Enum.join(unlogged_events, ", ")}"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `modlog status`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
