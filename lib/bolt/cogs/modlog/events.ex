defmodule Bolt.Cogs.ModLog.Events do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.{Constants, Paginator}
  alias Bolt.Schema.ModLogConfig
  alias Nostrum.Api.Message
  alias Nostrum.Struct.Embed

  @impl true
  def usage, do: ["modlog events"]

  @impl true
  def description,
    do: """
    Show all known modlog events.
    This can be useful to find out which event you want to log where.
    To get further details on a single event, use `modlog explain <event:str>`.
    """

  @impl true
  def predicates, do: []

  @impl true
  def command(msg, []) do
    pages =
      ModLogConfig.valid_events()
      |> Stream.map(&"• #{&1}")
      |> Stream.chunk_every(6)
      |> Enum.map(
        &%Embed{
          description: Enum.join(&1, "\n")
        }
      )

    base_embed = %Embed{
      title: "Known events",
      color: Constants.color_blue()
    }

    Paginator.paginate_over(msg, base_embed, pages)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `modlog events`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
