defmodule Bolt.Cogs.Sudo.LeaveGuild do
  @moduledoc false

  alias Bolt.Helpers
  alias Nostrum.Api.Guild
  alias Nostrum.Api.Message

  @spec command(Nostrum.Struct.Message.t(), [String.t()]) :: {:ok, Nostrum.Struct.Message.t()}
  def command(msg, [guild_id]) do
    response =
      case Integer.parse(guild_id) do
        {value, _rest} ->
          {:ok} = Guild.leave(value)
          "👌 left guild `#{value}`"

        :error ->
          "🚫 `#{Helpers.clean_content(guild_id)}` is not a valid guild ID"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "🚫 this command only takes one argument, the guild ID to leave"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
