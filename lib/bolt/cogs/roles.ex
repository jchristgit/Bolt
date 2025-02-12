defmodule Bolt.Cogs.Roles do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.{Constants, Helpers, Paginator}
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Guild.Role

  @spec get_role_list(Nostrum.Struct.Snowflake.t()) :: {:ok, [Role.t()]} | {:error, String.t()}
  defp get_role_list(guild_id) do
    with {:ok, guild} <- GuildCache.get(guild_id),
         {:ok, _roles} = result <- Map.fetch(guild, :roles) do
      result
    else
      _error ->
        {:error, "Couldn't look up guild from the cache"}
    end
  end

  @impl true
  def usage,
    do: [
      "roles [--compact] [--no-mention] " <>
        "[--sort-by members|name|position] [--reverse|--no-reverse]"
    ]

  @impl true
  def description,
    do: """
    Show all roles on the guild the command is invoked on.

    The following options can be given:
    • `--compact`: Show roles comma-separated and without the ID instead of the default format
    • `--no-mention`: Don't display the roles as mentions, but display their names instead
    • `--sort-by members|name|position`: \
    Specify the sorting order of the roles, defaults to `name`
    • `--reverse|--no-reverse`: Reverse the sorting order - when `sort-by` \
    is given as either *members*, *name* or *position*, \
    `--reverse` is implied for sanity reasons, \
    use `--no-reverse` to sort regularly
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def parse_args(args),
    do:
      OptionParser.parse(
        args,
        strict: [
          compact: :boolean,
          mention: :boolean,
          reverse: :boolean,
          sort_by: :string
        ]
      )

  @impl true
  def command(msg, {parsed, [], []}) do
    compact = Keyword.get(parsed, :compact, false)
    mention_roles = Keyword.get(parsed, :mention, true)
    sort_by = Keyword.get(parsed, :sort_by, "name")
    reverse = Keyword.get(parsed, :reverse)

    if sort_by in ["members", "name", "position"] do
      chunker = make_chunker(sort_by, msg.guild_id, reverse, compact, mention_roles)

      title =
        if parsed in [[], [compact: true]],
          do: "All roles on this guild",
          else: "Roles matching query"

      case get_role_list(msg.guild_id) do
        {:ok, roles} ->
          base_embed = %Embed{
            title: title,
            color: Constants.color_blue()
          }

          {:ok, _msg} = Paginator.paginate_over(msg, base_embed, chunker.(roles))

        {:error, reason} ->
          response = "❌ could not fetch guild roles: #{Helpers.clean_content(reason)}"
          {:ok, _msg} = Message.create(msg.channel_id, response)
      end
    else
      "🚫 unknown sort order, use `members`, `name`, or `position`"
    end
  end

  def command(msg, {_parsed, _args, invalid}) when invalid != [] do
    description =
      invalid
      |> Stream.map(fn {option_name, value} ->
        case value do
          nil -> "`#{option_name}`"
          val -> "`#{option_name}` (set to `#{val}`)"
        end
      end)
      |> Enum.join(", ")
      |> Helpers.clean_content()

    {:ok, _msg} =
      Message.create(
        msg.channel_id,
        "🚫 unrecognized argument(s) or invalid value: #{description}"
      )
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `#{List.first(usage())}`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  @spec sort_key(sort_by :: String.t(), role :: Role.t(), guild_id :: Guild.id()) ::
          non_neg_integer() | String.t()
  defp sort_key("members", role, guild_id) do
    :bolt_member_qlc.total_role_members(guild_id, role.id)
  end

  defp sort_key("name", role, _guild_id), do: role.name
  defp sort_key("position", role, _guild_id), do: role.position

  @spec get_sorter(sort_by :: String.t(), reverse :: boolean() | nil) ::
          (term(), term() -> boolean())
  defp get_sorter(sort_by, nil) when sort_by in ["members", "position"], do: &>=/2
  defp get_sorter(_sort_by, nil), do: &<=/2
  defp get_sorter(_sort_by, true), do: &>=/2
  defp get_sorter(_sort_by, false), do: &<=/2

  @spec display_role(compact :: boolean(), mention :: boolean(), role :: Role.t()) :: String.t()
  defp display_role(true, true, role), do: Role.mention(role)
  defp display_role(true, false, role), do: role.name
  defp display_role(false, true, role), do: "`#{role.id}` - #{Role.mention(role)}"
  defp display_role(false, false, role), do: "`#{role.id}` - #{role.name}"

  defp make_chunker(sort_by, guild_id, reverse, compact, mention_roles) do
    fn all_roles ->
      all_roles
      |> Stream.map(fn {_id, role} -> role end)
      |> Enum.sort_by(&sort_key(sort_by, &1, guild_id), get_sorter(sort_by, reverse))
      |> Stream.map(&display_role(compact, mention_roles, &1))
      |> Stream.chunk_every(if(compact, do: 50, else: 15))
      |> Stream.map(&Enum.join(&1, if(compact, do: ", ", else: "\n")))
      |> Enum.map(&%Embed{description: &1})
    end
  end
end
