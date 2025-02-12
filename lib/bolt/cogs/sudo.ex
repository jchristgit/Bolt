defmodule Bolt.Cogs.Sudo do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["sudo ?"]

  @impl true
  def description,
    do: """
    We trust you have received the usual lecture from the local System Administrator. It usually boils down to these three things:
    #1) Respect the privacy of others.
    #2) Think before you type.
    #3) With great power comes great responsibility.
    """

  @impl true
  def predicates, do: [&Predicates.superuser?/1]

  @impl true
  def command(msg, ["guilds" | args]) do
    alias Bolt.Cogs.Sudo.Guilds

    Guilds.command(msg, args)
  end

  def command(msg, ["leaveguild" | args]) do
    alias Bolt.Cogs.Sudo.LeaveGuild

    LeaveGuild.command(msg, args)
  end

  def command(msg, ["send" | args]) do
    alias Bolt.Cogs.Sudo.Send

    Send.command(msg, args)
  end

  def command(msg, ["log" | args]) do
    alias Bolt.Cogs.Sudo.Log

    Log.command(msg, args)
  end

  def command(msg, ["load" | args]) do
    alias Bolt.Cogs.Sudo.Load

    Load.command(msg, args)
  end

  def command(msg, ["unload" | args]) do
    alias Bolt.Cogs.Sudo.Unload

    Unload.command(msg, args)
  end

  def command(msg, ["rrdstats" | args]) do
    alias Bolt.Cogs.Sudo.RRDStats

    RRDStats.command(msg, args)
  end

  def command(msg, ["autoredact" | args]) do
    alias Bolt.Cogs.Autoredact

    # beta phase
    Autoredact.command(msg, args)
  end

  def command(msg, _args) do
    response = "🚫 unknown subcommand"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
