defmodule Bolt.Cogs.RoleInfo do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Helpers
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Guild.Role
  alias Nostrum.Struct.{Embed, Guild}

  @impl true
  def usage, do: ["roleinfo <role:role>"]

  @impl true
  def description,
    do: """
    Show information about the given role.
    The role can be given as either by ID, its name, or a role mention.
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def command(msg, "") do
    response = "🚫 expected role to lookup as sole argument"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, role) do
    case Converters.to_role(role, msg.guild_id, true) do
      {:ok, matching_role} ->
        embed = format_role_info(matching_role, msg.guild_id)
        {:ok, _msg} = Message.create(msg.channel_id, embed: embed)

      {:error, reason} ->
        response = "🚫 conversion error: #{Helpers.clean_content(reason)}"
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  @spec format_role_info(Role.t(), Guild.id()) :: Embed.t()
  defp format_role_info(role, guild_id) do
    %Embed{
      title: role.name,
      color: role.color,
      footer: %Embed.Footer{
        text: "Permission bitset: #{Integer.to_string(role.permissions, 2)}"
      },
      fields: [
        %Embed.Field{
          name: "ID",
          value: "#{role.id}",
          inline: true
        },
        %Embed.Field{
          name: "Creation",
          value:
            role.id
            |> Snowflake.creation_time()
            |> Helpers.datetime_to_human(),
          inline: true
        },
        %Embed.Field{
          name: "Color hex",
          value: Integer.to_string(role.color, 16),
          inline: true
        },
        %Embed.Field{
          name: "Mentionable",
          value: Helpers.bool_to_human(role.mentionable),
          inline: true
        },
        %Embed.Field{
          name: "Position",
          value: "#{role.position}",
          inline: true
        },
        %Embed.Field{
          name: "Member count",
          value: count_role_members(role.id, guild_id),
          inline: true
        }
      ]
    }
  end

  @spec count_role_members(Role.id(), Guild.id()) :: String.t()
  defp count_role_members(role_id, guild_id) do
    guild_id
    |> :bolt_member_qlc.total_role_members(role_id)
    |> Integer.to_string()
  end
end
