defmodule Bolt.Cogs.MemberInfo do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Helpers
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Cache.MemberCache
  alias Nostrum.Cache.UserCache
  alias Nostrum.Snowflake
  alias Nostrum.Struct.{Embed, Guild, User}

  @spec format_member_info(Guild.t(), Guild.Member.t()) :: Nostrum.Embed.t()
  defp format_member_info(guild_id, member) do
    join_datetime = DateTime.from_unix!(member.joined_at)
    creation_datetime = Snowflake.creation_time(member.user_id)
    user = UserCache.get!(member.user_id)

    embed = %Embed{
      title: "#{user.username}##{user.discriminator}",
      fields: [
        %Embed.Field{name: "ID", value: "`#{user.id}`", inline: true},
        %Embed.Field{name: "Total roles", value: "#{length(member.roles)}", inline: true},
        %Embed.Field{
          name: "Joined this Guild",
          value: Helpers.datetime_to_human(join_datetime),
          inline: true
        },
        %Embed.Field{
          name: "Joined Discord",
          value: Helpers.datetime_to_human(creation_datetime),
          inline: true
        }
      ],
      thumbnail: %Embed.Thumbnail{url: User.avatar_url(user)}
    }

    case Helpers.top_role_for(guild_id, member.user_id) do
      {:error, reason} ->
        Embed.put_field(embed, "Roles", "*#{reason}*")

      {:ok, role} ->
        embed
        |> Embed.put_field(
          "Roles",
          member.roles
          |> Stream.map(&"<@&#{&1}>")
          |> Enum.join(", ")
        )
        |> Embed.put_color(role.color)
    end
  end

  @impl true
  def usage, do: ["memberinfo [member:member]"]

  @impl true
  def description,
    do: """
    Look up information about the given `member`.
    When no argument is given, shows information about yourself.
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def command(msg, "") do
    case MemberCache.get(msg.guild_id, msg.author.id) do
      {:ok, member} ->
        embed = format_member_info(msg.guild_id, member)
        {:ok, _msg} = Message.create(msg.channel_id, embed: embed)

      {:error, _reason} ->
        response = "❌ failed to find you in this guild's members - that's a bit weird"
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, maybe_member) do
    case Converters.to_member(maybe_member, msg.guild_id) do
      {:ok, fetched_member} ->
        embed = format_member_info(msg.guild_id, fetched_member)
        {:ok, _msg} = Message.create(msg.channel_id, embed: embed)

      {:error, reason} ->
        response = "❌ couldn't fetch member information: #{reason}"
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end
end
