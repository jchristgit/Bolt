defmodule Bolt.Cogs.Tag.Delete do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.{Helpers, Repo}
  alias Bolt.Schema.Tag
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Struct
  alias Nostrum.Struct.User

  @impl true
  def usage, do: ["tag delete <tag_name:str...>"]

  @impl true
  def description,
    do: """
    Deletes the tag with the given `tag_name`.
    Only the tag author may delete their tag.
    """

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def command(%Struct.Message{author: %User{id: author_id}} = msg, tag_name) do
    case Repo.get_by(Tag, name: tag_name, guild_id: msg.guild_id) do
      nil ->
        response = "🚫 no tag named `#{Helpers.clean_content(tag_name)}` found on this guild"
        {:ok, _msg} = Message.create(msg.channel_id, response)

      %Tag{author_id: creator_id} = tag when creator_id == author_id ->
        response =
          case Repo.delete(tag) do
            {:ok, _deleted_tag} -> "👌 successfully deleted #{Helpers.clean_content(tag_name)}"
            {:error, _reason} -> "❌ couldn't delete the tag because of some weird error"
          end

        {:ok, _} = Message.create(msg.channel_id, response)

      tag ->
        response = "🚫 only the tag author, <@#{tag.author_id}>, can delete the tag"

        {:ok, _msg} =
          Message.create(msg.channel_id, content: response, allowed_mentions: :none)
    end
  end
end
