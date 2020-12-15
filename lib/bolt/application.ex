defmodule Bolt.Application do
  @moduledoc """
  The entry point for bolt.

  Starts the required processes, including the gateway consumer supervisor.
  """

  require Logger
  use Application

  @impl true
  @spec start(
          Application.start_type(),
          term()
        ) :: {:ok, pid()} | {:ok, pid(), Application.state()} | {:error, term()}
  def start(_type, _args) do
    children = [
      # Manages the PostgreSQL connection.
      Bolt.Repo,

      # Handles timed events of infractions.
      {Bolt.Events.Handler, name: Bolt.Events.Handler},
      Nosedrum.Storage.ETS,

      # Allows for embed pagination.
      {Bolt.Paginator, name: Bolt.Paginator},

      # Caches messages for mod log purposes.
      {Nosedrum.MessageCache.Agent, name: Bolt.MessageCache},

      # Supervises the Uncomplicated Spam Wall processes.
      Bolt.USWSupervisor,

      # Supervises Discord Gateway event consumers.
      Bolt.ConsumerSupervisor
    ]

    case :prometheus_httpd.start() do
      {:ok, _pid} ->
        Logger.debug("Started Prometheus scraping HTTP endpoint.")

      other ->
        Logger.info("Cannot start `:prometheus_httpd`: #{inspect(other)}")
    end

    bootstrap_instrumentation()
    options = [strategy: :rest_for_one, name: Bolt.Supervisor]
    Supervisor.start_link(children, options)
  end

  def bootstrap_instrumentation do
    true =
      :prometheus_gauge.declare(
        name: :bolt_guild_members,
        help: "Amount of guild members by guild ID.",
        labels: [:guild_id]
      )

    true =
      :prometheus_counter.declare(
        name: :bolt_guild_messages_total,
        help: "Total amount of messages by guild ID and channel ID, bot messages excluded.",
        labels: [:guild_id, :channel_id]
      )
  end
end
