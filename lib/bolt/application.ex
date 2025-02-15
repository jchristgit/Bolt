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
    bot_options = %{
      consumer: Bolt.Consumer,
      wrapped_token: fn -> Application.fetch_env!(:bolt, :token) end
    }
    children = [
      # Manages the PostgreSQL connection.
      Bolt.Repo,

      # Handles timed events of infractions.
      {Bolt.Events.Handler, name: Bolt.Events.Handler},

      # Stores our commands.
      Nosedrum.TextCommand.Storage.ETS,

      # Allows for embed pagination.
      {Bolt.Paginator, name: Bolt.Paginator},

      # Caches messages for mod log purposes.
      {Nosedrum.MessageCache.Agent, name: Bolt.MessageCache},

      # Supervises the Uncomplicated Spam Wall processes.
      Bolt.USWSupervisor,

      # Manages the bolt <-> rrdtool connection.
      Bolt.RRD,

      # Handles the Discord connection.
      {Nostrum.Bot, {bot_options, []}},

      # Supervises bolt's auto-redact worker processes.
      Bolt.Redact.Supervisor,
    ]

    options = [strategy: :rest_for_one, name: Bolt.Supervisor]
    Supervisor.start_link(children, options)
  end
end
