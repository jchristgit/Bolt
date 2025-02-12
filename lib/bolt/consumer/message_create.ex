defmodule Bolt.Consumer.MessageCreate do
  @moduledoc "Handles the `MESSAGE_CREATE` gateway event."

  @nosedrum_storage_implementation Nosedrum.TextCommand.Storage.ETS

  alias Bolt.RRD
  alias Bolt.USW
  alias Nosedrum.MessageCache.Agent, as: MessageCache
  alias Nosedrum.TextCommand.Invoker.Split, as: CommandInvoker
  alias Nostrum.Api.Message
  alias Nostrum.Struct

  @spec handle(Message.t()) :: :ok | nil
  def handle(msg) do
    unless msg.author.bot do
      case CommandInvoker.handle_message(msg, @nosedrum_storage_implementation) do
        {:error, {:unknown_subcommand, _name, :known, known}} ->
          Message.create(
            msg.channel_id,
            "🚫 unknown subcommand, known subcommands: `#{Enum.join(known, "`, `")}`"
          )

        {:error, :predicate, {:error, reason}} ->
          Message.create(msg.channel_id, "❌ cannot evaluate permissions: #{reason}")

        {:error, :predicate, {:noperm, reason}} ->
          Message.create(msg.channel_id, reason)

        _ ->
          :ok
      end

      postprocess(msg)
    end
  end

  defp postprocess(%Struct.Message{guild_id: nil}), do: :ok

  defp postprocess(msg) do
    MessageCache.consume(msg, Bolt.MessageCache)
    USW.apply(msg)

    if RRD.enabled?() do
      {:ok, _response} = RRD.count_channel_message(msg.guild_id, msg.channel_id)
    end
  end
end
