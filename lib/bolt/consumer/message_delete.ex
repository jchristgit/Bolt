defmodule Bolt.Consumer.MessageDelete do
  @moduledoc "Handles the `MESSAGE_DELETE` event."

  alias Bolt.{Constants, Helpers, ModLog}
  alias Nosedrum.MessageCache.Agent, as: MessageCache
  alias Nostrum.Cache.UserCache
  alias Nostrum.Snowflake
  alias Nostrum.Struct.{Channel, Embed, Guild, Message, User}
  import Nostrum.Struct.Embed

  @spec handle(Channel.id(), Guild.id(), Message.id()) :: {:ok, Message.t()}
  def handle(channel_id, guild_id, msg_id) do
    cached_message = MessageCache.get(guild_id, msg_id, Bolt.MessageCache)
    log(cached_message, channel_id, guild_id, msg_id)
  end

  @spec log(Message.t()) :: {:ok, Message.t()}
  def log(message) when message != nil do
    log(message, message.channel_id, message.guild_id, message.id)
  end

  @spec log(Message.t(), Channel.id(), Guild.id(), Message.id()) :: {:ok, Message.t()}
  def log(message, channel_id, guild_id, msg_id) do
    embed =
      %Embed{
        color: Constants.color_red(),
        fields: [
          %Embed.Field{
            name: "Metadata",
            value: """
            Channel: <##{channel_id}>
            Creation: #{msg_id |> Snowflake.creation_time() |> Helpers.datetime_to_human()}
            Message ID: #{msg_id}
            """,
            inline: true
          }
        ]
      }
      |> add_content(message)
      |> add_author(message)

    ModLog.emit_embed(guild_id, "MESSAGE_DELETE", embed)
  end

  @spec add_content(Embed.t(), Message.t() | nil) :: Embed.t()
  defp add_content(embed, nil) do
    put_description(embed, "*unknown, message not in cache*")
  end

  defp add_content(embed, cached_msg) do
    put_description(embed, cached_msg.content)
  end

  @spec add_author(Embed.t(), Message.t() | nil) :: Embed.t()
  defp add_author(embed, nil) do
    embed
  end

  defp add_author(embed, cached_msg) do
    case UserCache.get(cached_msg.author.id) do
      {:ok, user} -> put_author(embed, User.full_name(user), nil, User.avatar_url(user))
      _error -> embed
    end
  end
end
