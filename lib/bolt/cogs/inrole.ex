defmodule Bolt.Cogs.InRole do
  @moduledoc "Shows members in the given role."
  @maximum_fetched 500

  @behaviour Nosedrum.TextCommand

  alias Bolt.{Constants, ErrorFormatters, Paginator}
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Struct.{Embed, User}

  @impl true
  def usage, do: ["inrole <role:role>"]

  @impl true
  def description,
    do: """
    Show members in the given role. The converter is case-insensitive.

    The command is capped to show at most #{@maximum_fetched} members.

    **Example**:
    ```rs
    // Show members in the 'Muted' role
    .inrole muted
    ```
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def command(msg, "") do
    response = "ℹ️ usage: `inrole <role:role...>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, role_string) do
    case Converters.to_role(role_string, msg.guild_id, true) do
      {:ok, role} ->
        members = :bolt_member_qlc.role_members(msg.guild_id, role.id)

        base_embed = %Embed{
          title: "Members with role `#{role.name}` (`#{length(members)}` total)",
          color: Constants.color_blue()
        }

        pages =
          members
          |> Enum.take(@maximum_fetched)
          |> Enum.sort_by(fn {_member, user} -> String.downcase(user.username) end)
          |> Stream.map(fn {_member, user} ->
            "#{User.full_name(user)} (#{User.mention(user)})"
          end)
          |> Stream.chunk_every(25)
          |> Enum.map(fn mention_chunk ->
            %Embed{
              description: Enum.join(mention_chunk, ", ")
            }
          end)

        Paginator.paginate_over(msg, base_embed, pages)

      error ->
        response = ErrorFormatters.fmt(msg, error)
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end
end
