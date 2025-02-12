defmodule Bolt.BotLog do
  @moduledoc "A bot log, used for logging bot events to the bot administrator."

  alias Nostrum.Api
  alias Nostrum.Struct.Message

  @spec emit(String.t()) :: {:ok, Message.t()} | :noop
  def emit(content) do
    case Application.fetch_env(:bolt, :botlog_channel) do
      {:ok, channel_id} when channel_id != nil ->
        {actual_id, _} = Integer.parse(channel_id)
        {:ok, _msg} = Api.Message.create(actual_id, content)

      _ ->
        :noop
    end
  end
end
