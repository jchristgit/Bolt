defmodule Bolt.Cogs.GuildInfo do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.{Constants, Helpers}
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Snowflake
  alias Nostrum.Struct.{Embed, Guild}

  @spec format_guild_info(Guild.t()) :: Embed.t()
  defp format_guild_info(guild) do
    info_embed = %Embed{
      title: guild.name,
      color: Constants.color_blue(),
      fields: [
        %Embed.Field{
          name: "Statistics",
          value: """
          Channels: #{if guild.channels != nil,
            do: map_size(guild.channels),
            else: "*unknown, guild not in cache*"}
          Emojis: #{length(guild.emojis)}
          Roles: #{map_size(guild.roles)}
          Members: #{Map.get(guild, :member_count, "*guild not in cache*")}
          """,
          inline: true
        },
        %Embed.Field{
          name: "Owner",
          value: "<@#{guild.owner_id}> (`#{guild.owner_id}`)",
          inline: true
        },
        %Embed.Field{
          name: "ID",
          value: "#{guild.id}",
          inline: true
        },
        %Embed.Field{
          name: "Creation date",
          value:
            guild.id
            |> Snowflake.creation_time()
            |> Helpers.datetime_to_human(),
          inline: true
        },
        %Embed.Field{
          name: "Features",
          value:
            (fn ->
               features =
                 guild.features
                 |> Stream.map(&"`#{&1}`")
                 |> Enum.join(", ")

               case features do
                 "" -> "none"
                 value -> value
               end
             end).(),
          inline: true
        }
      ]
    }

    if guild.icon != nil do
      info_embed
      |> Embed.put_thumbnail(Guild.icon_url(guild, "png"))
    end
  end

  @spec fetch_and_build(Nostrum.Struct.Snowflake.t(), String.t()) :: String.t()
  defp fetch_and_build(guild_id, on_not_found) do
    case GuildCache.get(guild_id) do
      {:ok, guild} ->
        format_guild_info(guild)

      {:error, _reason} ->
        %Embed{
          title: "Failed to fetch guild information",
          description: "#{on_not_found} was not found in the cache. sorry! :-(",
          color: Constants.color_red()
        }
    end
  end

  @impl true
  def usage, do: ["guildinfo [guild:snowflake]"]

  @impl true
  def description,
    do: """
    Show information about the current guild, or a given guild ID.
    Aliased to `ginfo` and `guild`.
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def command(msg, []) do
    embed = fetch_and_build(msg.guild_id, "This guild")
    {:ok, _msg} = Message.create(msg.channel_id, embed: embed)
  end

  def command(msg, [guild_id]) do
    case Snowflake.cast(guild_id) do
      {:ok, snowflake} when snowflake != nil ->
        embed = fetch_and_build(snowflake, "A guild with ID `#{snowflake}`")
        {:ok, _msg} = Message.create(msg.channel_id, embed: embed)

      _ ->
        response = "🚫 `#{Helpers.clean_content(guild_id)}` is not a valid guild ID"
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `guildinfo [guild:snowflake]`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
