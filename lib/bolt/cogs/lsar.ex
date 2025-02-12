defmodule Bolt.Cogs.Lsar do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Schema.SelfAssignableRoles
  alias Bolt.{Constants, Paginator, Repo}
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Embed.Footer
  alias Nostrum.Struct.Guild.Role
  alias Nostrum.Struct.Message

  @spec format_roles(Message.t(), [Role.t()]) :: [Embed.t()]
  defp format_roles(msg, roles) do
    roles
    |> Stream.map(&Integer.to_string/1)
    |> Stream.map(fn role_id ->
      case Converters.to_role(role_id, msg.guild_id) do
        {:ok, role} -> "• #{role.name} (#{Role.mention(role)})"
        {:error, _reason} -> "• unknown role (`#{role_id}`)"
      end
    end)
    |> Enum.sort()
    |> Stream.chunk_every(10)
    |> Enum.map(&%Embed{description: Enum.join(&1, "\n")})
  end

  @impl true
  def usage, do: ["lsar"]

  @impl true
  def description, do: "Shows all self-assignable roles on this guild."

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  @spec command(Message.t(), [String.t()]) :: {:ok, Message.t()} | reference()
  def command(msg, []) do
    case Repo.get(SelfAssignableRoles, msg.guild_id) do
      nil ->
        response = "🚫 this guild has not configured any self-assignable roles"
        {:ok, _msg} = Api.Message.create(msg.channel_id, response)

      role_row ->
        pages = format_roles(msg, role_row.roles)

        base_embed = %Embed{
          title: "Self-assignable roles",
          color: Constants.color_blue(),
          footer: %Footer{
            text: "Use `assign <role>` to assign or `remove <role>` to remove a role."
          }
        }

        Paginator.paginate_over(msg, base_embed, pages)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `lsar`"
    {:ok, _msg} = Api.Message.create(msg.channel_id, response)
  end
end
