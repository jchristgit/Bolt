defmodule Bolt.Redact.Deleter do
  @moduledoc "Delete messages as configured"

  @behaviour :gen_statem

  alias Bolt.Repo
  alias Bolt.Schema.RedactConfig
  alias Bolt.Schema.RedactPendingMessage, as: PendingMessage
  alias Nostrum.Api.Message
  import Ecto.Query, only: [from: 2]
  import Nostrum.Constants, only: [discord_epoch: 0]
  require Logger

  @items_to_delete_per_chunk 5
  @naptime_between_full_chunks :timer.seconds(10)
  @naptime_waiting_for_next_chunk :timer.minutes(30)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @spec start_link([:gen_statem.start_opt()]) :: :gen_statem.start_ret()
  def start_link(opts) do
    :gen_statem.start_link(__MODULE__, [], opts)
  end

  def callback_mode, do: :state_functions

  def init([]) do
    {:ok, :deleting, %{}, {:next_event, :internal, :next_chunk}}
  end

  def deleting(:internal, :next_chunk, data) do
    query =
      from(
        m in PendingMessage,
        join: c in RedactConfig,
        on: m.config_id == c.id,
        where:
          fragment("now() AT TIME ZONE 'UTC'") -
            fragment("(? || 'seconds')::interval", c.age_in_seconds) >
            fragment(
              "to_timestamp(((? >> 22) + ?) / 1000) AT TIME ZONE 'UTC'",
              m.message_id,
              ^discord_epoch()
            ),
        select: {m.channel_id, m.message_id},
        limit: @items_to_delete_per_chunk,
        lock: "FOR UPDATE"
      )

    {:ok, num_deleted} =
      Repo.transaction(fn ->
        messages = Repo.all(query)

        for {channel_id, message_id} <- messages do
          :gone = delete_message(channel_id, message_id)
        end

        message_ids = Enum.map(messages, fn {_channel, message} -> message end)
        delete_query = from(m in PendingMessage, where: m.message_id in ^message_ids)
        {deleted, _} = Repo.delete_all(delete_query)
        deleted
      end)

    case num_deleted do
      number when number < @items_to_delete_per_chunk ->
        Logger.debug("No more items to delete in this chunk, napping")
        {:next_state, :napping, data, {:state_timeout, @naptime_waiting_for_next_chunk, :wake}}

      @items_to_delete_per_chunk ->
        {:next_state, :napping, data, {:state_timeout, @naptime_between_full_chunks, :wake}}
    end
  end

  def napping(:state_timeout, :wake, data) do
    {:next_state, :deleting, data, {:next_event, :internal, :next_chunk}}
  end

  defp delete_message(channel_id, message_id) do
    case Message.delete(channel_id, message_id) do
      {:ok} ->
        :gone

      {:error, %{status_code: 404, response: %{message: "Unknown Message"}}} ->
        :gone
    end
  end
end
