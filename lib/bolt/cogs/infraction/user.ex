defmodule Bolt.Cogs.Infraction.User do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Cogs.Infraction.General
  alias Nosedrum.TextCommand.Predicates
  alias Bolt.{Constants, Helpers, Humanizer, Paginator, Repo}
  alias Bolt.Schema.Infraction
  alias Nostrum.Api.Message
  alias Nostrum.Struct.Embed
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["infraction user <user:snowflake|member...>"]

  @impl true
  def description,
    do: """
    View all infractions for the given user.
    The user can be given as a snowflake if they are now longer present on this guild.
    Requires the `MANAGE_MESSAGES` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  def command(msg, args) when args != [] do
    user_text = Enum.join(args, " ")

    case Helpers.into_id(msg.guild_id, user_text) do
      {:ok, user_id, _maybe_user} ->
        query =
          from(
            infr in Infraction,
            where: [guild_id: ^msg.guild_id, user_id: ^user_id],
            order_by: [desc: infr.inserted_at]
          )

        queryset = Repo.all(query)

        user_string = Humanizer.human_user(user_id)

        base_embed = %Embed{
          title: "Infractions for #{user_string}",
          color: Constants.color_blue()
        }

        formatted_entries =
          queryset
          |> Stream.map(&format_entry/1)
          |> Stream.chunk_every(6)
          |> Enum.map(fn entry_chunk ->
            %Embed{
              description: Enum.join(entry_chunk, "\n")
            }
          end)

        Paginator.paginate_over(msg, base_embed, formatted_entries)

      {:error, reason} ->
        response = "🚫 #{Helpers.clean_content(reason)}"
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `infraction user <user:snowflake|member...>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  @spec format_relative_datetime(DateTime.t()) :: String.t()
  defp format_relative_datetime(dt) do
    unix_stamp = DateTime.to_unix(dt)
    "<t:#{unix_stamp}:R>"
  end

  @spec format_expiry(DateTime) :: String.t()
  @spec format_expiry(nil) :: String.t()
  defp format_expiry(nil) do
    ""
  end

  defp format_expiry(dt) do
    now = DateTime.utc_now()

    if DateTime.compare(now, dt) == :gt do
      "(expired #{format_relative_datetime(dt)}) "
    else
      "(expires #{format_relative_datetime(dt)}) "
    end
  end

  @spec format_entry(Infraction) :: String.t()
  def format_entry(infr) do
    "[`#{infr.id}`] " <>
      "#{General.emoji_for_type(infr.type)} " <>
      format_surrounding_markup_for_active_infractions(infr) <>
      format_relative_datetime(infr.inserted_at) <>
      " " <>
      format_expiry(infr.expires_at) <>
      format_surrounding_markup_for_active_infractions(infr) <>
      if(infr.reason != nil, do: ": #{infr.reason}", else: "")
  end

  defp format_surrounding_markup_for_active_infractions(infr) do
    if Infraction.active?(infr) do
      "**"
    else
      ""
    end
  end
end
