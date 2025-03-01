defmodule Bolt.Redact.Starter do
  @moduledoc "Starts up the redact subsystem worker processes"

  alias Bolt.Redact
  alias Bolt.Repo
  alias Bolt.Schema.RedactConfig
  alias Nostrum.ConsumerGroup
  alias Nostrum.Token
  import Ecto.Query, only: [from: 2]
  import Nostrum.Bot, only: [with_bot: 2]
  require Logger
  use GenServer, restart: :transient

  def start_link(options) do
    GenServer.start_link(__MODULE__, :ok, options)
  end

  def init(args) do
    {:ok, nil, {:continue, args}}
  end

  def handle_continue(:ok, state) do
    :bolt
    |> Application.fetch_env(:token)
    |> then(fn {:ok, token} -> token end)
    |> Token.decode_token!()
    |> with_bot(fn ->
      :ok = ConsumerGroup.join()

      receive do
        {:event, {:READY, _, _}} -> :ok
      after
        10_000 -> :ok
      end

      :ok = ConsumerGroup.leave()
      # Make sure cache is actually full.... jesus christ, this is hacky
      :timer.sleep(5_000)

      guild_ids_query =
        from config in RedactConfig,
          distinct: true,
          select: config.guild_id

      started =
        guild_ids_query
        |> Repo.all()
        |> Stream.map(&fetch_and_start_guild_workers/1)
        |> Enum.sum()

      Logger.debug("Started #{started} redact workers")

      {:stop, :normal, state}
    end)
  end

  defp fetch_and_start_guild_workers(guild_id) do
    configs_query =
      from config in RedactConfig,
        where: config.guild_id == ^guild_id

    channel_ids = Redact.relevant_channels(guild_id, [])

    configs_query
    |> Repo.all()
    |> Redact.configure_guild_workers(channel_ids)
    |> Enum.count()
  end
end
