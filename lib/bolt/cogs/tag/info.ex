defmodule Bolt.Cogs.Tag.Info do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Constants
  alias Bolt.Schema.Tag
  alias Bolt.{Helpers, Repo}
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Cache.MemberCache
  alias Nostrum.Struct.{Embed, User}
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["tag info <name:str...>"]

  @impl true
  def description, do: "Shows detailed information about the given tag."

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @doc since: "0.3.0"
  @impl true
  def command(msg, "") do
    response = "ℹ️ usage: `tag info <name:str...>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, name) do
    query =
      from(
        tag in Tag,
        where:
          tag.guild_id == ^msg.guild_id and
            tag.name == ^name,
        select: tag
      )

    case Repo.all(query) do
      [] ->
        response = "🚫 no tag with that name found"
        {:ok, _msg} = Message.create(msg.channel_id, response)

      [tag] ->
        creator_string =
          case MemberCache.get(msg.guild_id, tag.author_id) do
            {:ok, author} -> User.mention(author.user)
            _error -> "unknown user (`#{tag.author_id}`)"
          end

        embed = %Embed{
          title: "Tag information: `#{tag.name}`",
          color: Constants.color_blue(),
          fields: [
            %Embed.Field{
              name: "Creator",
              value: creator_string,
              inline: true
            },
            %Embed.Field{
              name: "Created on",
              value: Helpers.datetime_to_human(tag.inserted_at),
              inline: true
            },
            %Embed.Field{
              name: "Last edit on",
              value:
                if(
                  DateTime.diff(tag.inserted_at, tag.updated_at) <= 0,
                  do: "never",
                  else: Helpers.datetime_to_human(tag.updated_at)
                )
            }
          ]
        }

        {:ok, _msg} = Message.create(msg.channel_id, embed: embed)
    end
  end
end
