defmodule Bolt.Cogs.Tag.Read do
  @moduledoc false

  alias Bolt.Constants
  alias Bolt.Helpers
  alias Bolt.Repo
  alias Bolt.Schema.Tag
  alias Nostrum.Api.Message
  alias Nostrum.Struct
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Embed.Footer
  alias Nostrum.Struct.User
  import Ecto.Query, only: [from: 2]

  @spec command(Struct.Message.t(), [String.t()]) :: {:ok, Message.t()}
  def command(msg, args) when args != [] do
    # We downcase it here since although the database type is the
    # case-insensitive `citext`, `levenshtein` function does not
    # take this into account when comparing the strings. Whether
    # bug or feature is unknown, but we need to work around it regardless.
    name = String.downcase(Enum.join(args, " "))

    query =
      from(tag in Tag,
        where:
          tag.guild_id == ^msg.guild_id and
            fragment("levenshtein(lower(?), ?)", tag.name, ^name) < 5,
        order_by: [desc: fragment("distance")],
        limit: 5,
        select: {tag, fragment("levenshtein(lower(?), ?) AS distance", tag.name, ^name)}
      )

    case Repo.all(query) do
      # No matches at all.
      [] ->
        response =
          "❌ no tag named exactly as or similarly to " <>
            "`#{Helpers.clean_content(name)}` found"

        {:ok, _msg} = Message.create(msg.channel_id, response)

      # Direct match.
      [{matching_tag, 0 = _distance} | _] ->
        response = %Embed{
          title: matching_tag.name,
          description: matching_tag.content,
          timestamp: DateTime.to_iso8601(matching_tag.inserted_at),
          color: Constants.color_blue(),
          footer: build_footer(msg.guild_id, matching_tag.author_id)
        }

        {:ok, _msg} = Message.create(msg.channel_id, embed: response)

      # Collection of close matches, bt no direct match.
      close_matches ->
        joined_names =
          close_matches
          |> Stream.map(&elem(&1, 0))
          |> Stream.map(&Helpers.clean_content(&1.name))
          |> Enum.join(", ")

        response = """
        ❌ no direct match found, but found the following close matches:
        #{joined_names}
        """

        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _args) do
    response =
      "ℹ usage: `tag <name:str>` or `tag <subcommand>" <>
        " [args...]`, see `help tag` for details"

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  @spec build_footer(Guild.id(), User.id()) :: Footer.t()
  defp build_footer(guild_id, author_id) do
    case Helpers.get_member(guild_id, author_id) do
      {:ok, member} ->
        %Footer{
          text: "Created by #{User.full_name(member.user)}",
          icon_url: User.avatar_url(member.user)
        }

      {:error, _reason} ->
        %Footer{
          text: "Created by unknown user #{author_id}"
        }
    end
  end
end
