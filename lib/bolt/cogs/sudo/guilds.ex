defmodule Bolt.Cogs.Sudo.Guilds do
  @moduledoc false

  alias Bolt.Constants
  alias Bolt.Helpers
  alias Bolt.Paginator
  alias Nostrum.Api.Message
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Embed.Field

  @spec command(Nostrum.Struct.Message.t(), [String.t()]) :: {:ok, Nostrum.Struct.Message.t()}
  def command(msg, []) do
    pages =
      []
      |> GuildCache.fold(fn guild, acc -> [guild | acc] end)
      |> Stream.map(
        &%Field{
          name: &1.name,
          value: """
          ID: `#{&1.id}`
          member count: `#{&1.member_count}`
          joined at: #{Helpers.datetime_to_human(&1.joined_at)}
          """,
          inline: true
        }
      )
      |> Stream.chunk_every(6)
      |> Enum.map(
        &%Embed{
          fields: &1
        }
      )

    base_page = %Embed{
      title: "Guilds in cache",
      color: Constants.color_blue()
    }

    Paginator.paginate_over(msg, base_page, pages)
  end

  def command(msg, _args) do
    response = "🚫 this subcommand accepts no arguments"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
