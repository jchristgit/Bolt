defmodule Bolt.Cogs.Sudo.Log do
  @moduledoc false

  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.ModLogConfig
  alias Nostrum.Api.Message
  import Ecto.Query, only: [from: 2]

  @spec command(Nostrum.Struct.Message.t(), [String.t()]) :: {:ok, Nostrum.Struct.Message.t()}
  def command(msg, content_list) when content_list != [] do
    content = Enum.join(content_list, " ")
    startup_note = "⏲ distributing event, please wait"
    {:ok, startup_msg} = Message.create(msg.channel_id, startup_note)

    query =
      from(
        conf in ModLogConfig,
        where: conf.event == "BOT_UPDATE",
        distinct: conf.guild_id,
        select: conf.guild_id
      )

    query
    |> Repo.all()
    |> Enum.each(fn guild_id ->
      ModLog.emit(
        guild_id,
        "BOT_UPDATE",
        content
      )

      :timer.sleep(200)
    end)

    response = "👌 event broadcasted to subscribed guilds"
    {:ok, _msg} = Message.create(msg.channel_id, response)
    Message.delete(startup_msg)
  end

  def command(msg, []) do
    response = "🚫 content to log must not be empty"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
