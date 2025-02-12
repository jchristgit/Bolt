defmodule Bolt.Redact.Ingestor do
  @moduledoc "Ingests messages on a per-channel basis"

  @behaviour :gen_statem

  alias Bolt.Repo
  alias Bolt.Schema.RedactChannelIngestionState, as: IngestionState
  alias Bolt.Schema.RedactConfig
  alias Bolt.Schema.RedactPendingMessage, as: PendingMessage
  alias Ecto.Changeset
  alias Nostrum.Api.Channel
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Message
  require Logger

  # States:
  # - ingesting: backfilling old messages
  # - streaming: got within very recent messages (PENDING)

  @catchup_until :timer.hours(2)
  @max_jitter :timer.seconds(30)

  def child_spec(state, channel_id, config, opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [state, channel_id, config, opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def flush(pid) do
    :gen_statem.call(pid, :flush)
  end

  @doc """
  Set up the ingestor.

  ## Parameters

  - `ingestion_state`: Last saved state of the ingestor, or `nil` if first run.
  - `channel_id`: Channel to be ingested.
  - `configs`: Redaction configs relevant for this channel. That is, all user configurations for which
    the configured channel is this channel
  """
  @spec start_link(IngestionState.t() | nil, Channel.id(), [RedactConfig.t()], [
          :gen_statem.start_opt()
        ]) ::
          :gen_statem.start_ret()
  def start_link(ingestion_state, channel_id, configs, opts) do
    :gen_statem.start_link(__MODULE__, [ingestion_state, channel_id, configs], opts)
  end

  def init([
        %{last_processed_message_id: last_id} = ingestion_state,
        channel_id,
        configs
      ]) do
    configs_by_author = for config <- configs, into: %{}, do: {config.author_id, config.id}
    load_more_in = max(-age(last_id) + @catchup_until, 0) + :rand.uniform(@max_jitter)

    Logger.debug(
      "Starting up, next load in channel #{channel_id} in #{load_more_in / 1000} seconds"
    )

    actions = {:timeout, load_more_in, {:load_more, last_id}}

    {:ok, :ingesting,
     %{channel_id: channel_id, ingestion: ingestion_state, author_configs: configs_by_author},
     actions}
  end

  def init([nil, channel_id, configs]) do
    configs_by_author = for config <- configs, into: %{}, do: {config.author_id, config.id}
    actions = {:timeout, 0, {:load_more, 0}}

    {:ok, :ingesting,
     %{author_configs: configs_by_author, channel_id: channel_id, ingestion: nil}, actions}
  end

  def callback_mode, do: :state_functions

  def ingesting({:call, from}, :flush, %{ingestion: state}) do
    reply_action = {:reply, from, Repo.delete(state)}
    {:stop_and_reply, :normal, reply_action}
  end

  def ingesting(
        :timeout,
        {:load_more, after_id},
        %{
          author_configs: author_configs,
          channel_id: channel,
          ingestion: ingestion
        } = data
      ) do
    case Channel.messages(channel, 100, {:after, after_id}) do
      {:ok, descending_messages} ->
        case descending_messages do
          [] ->
            actions = {:timeout, @catchup_until, {:load_more, after_id}}
            Logger.debug("Reached end of channel #{channel}, napping")
            {:keep_state_and_data, actions}

          [latest | _] = messages ->
            relevant_messages =
              messages
              |> Enum.filter(&Map.has_key?(author_configs, &1.author.id))
              |> Enum.map(
                &%{
                  message_id: &1.id,
                  channel_id: channel,
                  config_id: Map.get(author_configs, &1.author.id)
                }
              )
              |> Enum.sort_by(& &1.message_id, :desc)

            {:ok, updated_ingestion} =
              update_ingestion(relevant_messages, ingestion, channel, latest.id)

            actions = {:timeout, 0, {:load_more, updated_ingestion.last_processed_message_id}}

            {:keep_state, %{data | ingestion: updated_ingestion}, actions}
        end

      other ->
        Logger.error("Disabling ingestor for channel #{channel}: #{inspect(other)}")
        :ok = disable_ingestion(ingestion, channel)
        {:stop, :normal}
    end
  end

  defp age(%Message{id: id}) do
    age(id)
  end

  defp age(id) do
    creation = DateTime.to_unix(Snowflake.creation_time(id))
    now = DateTime.to_unix(DateTime.utc_now())
    :timer.seconds(now - creation)
  end

  defp update_ingestion(relevant_messages, ingestion, channel, latest_id) do
    Repo.transaction(fn ->
      {_inserted, _} = Repo.insert_all(PendingMessage, relevant_messages)
      insert_or_update_ingestion!(ingestion, channel, latest_id)
    end)
  end

  defp insert_or_update_ingestion!(nil, channel_id, latest_id) do
    ingestion = %IngestionState{}

    changeset =
      IngestionState.changeset(ingestion, %{
        channel_id: channel_id,
        last_processed_message_id: latest_id
      })

    Repo.insert!(changeset)
  end

  defp insert_or_update_ingestion!(ingestion, _channel_id, latest_id) do
    changeset = Changeset.change(ingestion, last_processed_message_id: latest_id)
    Repo.update!(changeset)
  end

  defp disable_ingestion(nil, channel_id) do
    patch = %{channel_id: channel_id, last_processed_message_id: 0, enabled: false}
    ingestion = %IngestionState{}
    changeset = IngestionState.changeset(ingestion, patch)
    Repo.insert(changeset)
  end

  defp disable_ingestion(ingestion, _channel_id) do
    patch = %{enabled: false}
    changeset = IngestionState.changeset(ingestion, patch)
    Repo.update(changeset)
  end
end
