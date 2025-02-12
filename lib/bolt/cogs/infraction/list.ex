defmodule Bolt.Cogs.Infraction.List do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Cogs.Infraction.General
  alias Bolt.Schema.Infraction
  alias Bolt.{Constants, Humanizer, Paginator, Repo}
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api
  alias Nostrum.Cache.Me
  alias Nostrum.Struct.Embed
  import Ecto.Query, only: [from: 2]

  @impl true
  def usage, do: ["infraction list"]

  @impl true
  def description,
    do: """
    List all infractions on this guild.
    Requires the `MANAGE_MESSAGES` permission.

    When `--no-automod` is given (e.g. `infr list --no-automod`), does not show any infractions created by the automod.
    When `--automod` is given, only shows infractions created by the automod.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  @spec parse_args([String.t()]) ::
          {OptionParser.parsed(), OptionParser.argv(), OptionParser.errors()}
  def parse_args(args) do
    OptionParser.parse(
      args,
      strict: [
        automod: :boolean
      ]
    )
  end

  @impl true
  def command(msg, {[], [], []}) do
    query =
      from(
        infr in Infraction,
        where: infr.guild_id == ^msg.guild_id,
        order_by: [desc: infr.inserted_at],
        select: infr
      )

    respond(query, msg)
  end

  @impl true
  def command(msg, {[automod: true], [], []}) do
    query =
      from(
        infr in Infraction,
        where: infr.guild_id == ^msg.guild_id and infr.actor_id == ^Me.get().id,
        order_by: [desc: infr.inserted_at],
        select: infr
      )

    respond(query, msg, "Infractions on this guild created by automod")
  end

  @impl true
  def command(msg, {[automod: false], [], []}) do
    query =
      from(
        infr in Infraction,
        where: infr.guild_id == ^msg.guild_id and infr.actor_id != ^Me.get().id,
        order_by: [desc: infr.inserted_at],
        select: infr
      )

    respond(query, msg, "Infractions on this guild excluding automod")
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `infr list [--automod|--no-automod]`"
    {:ok, _msg} = Api.Message.create(msg.channel_id, response)
  end

  @spec respond(Ecto.Query.t(), Message.t(), String.t()) :: {:ok, Message.t()}
  defp respond(query, msg, title \\ "All infractions on this guild") do
    queryset = Repo.all(query)

    base_embed = %Embed{
      title: title,
      color: Constants.color_blue()
    }

    pages =
      queryset
      |> Stream.map(fn infr ->
        %Embed.Field{
          name:
            "##{infr.id} #{General.emoji_for_type(infr.type)} #{if Infraction.active?(infr), do: "(active)", else: ""}",
          value:
            """
            **User**: #{Humanizer.human_user(infr.user_id)}
            **Actor**: #{Humanizer.human_user(infr.actor_id)}
            **Creation**: <t:#{DateTime.to_unix(infr.inserted_at)}:R>
            """ <>
              if(
                infr.expires_at != nil,
                do: "**Expiration**: <t:#{DateTime.to_unix(infr.expires_at)}:R>",
                else: ""
              ),
          inline: true
        }
      end)
      |> Stream.chunk_every(6)
      |> Enum.map(fn field_chunk ->
        %Embed{
          fields: field_chunk
        }
      end)

    Paginator.paginate_over(msg, base_embed, pages)
  end
end
