defmodule Bolt.Cogs.USW.Escalate do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Repo
  alias Bolt.Schema.USWPunishmentConfig
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["usw escalate [on|off]"]

  @impl true
  def description,
    do: """
    Toggles automatic punishment escalation.
    Use the command without any argument to show whether automatic punishment is currently enabled.
    Enable it using `on`, disable it again using `off`.

    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, []) do
    response =
      case Repo.get(USWPunishmentConfig, msg.guild_id) do
        nil ->
          "🚫 USW punishment is not configured"

        %USWPunishmentConfig{escalate: escalate} ->
          "ℹ automatic punishment escalation is " <> if escalate, do: "enabled", else: "disabled"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, ["on"]) do
    response =
      case Repo.get(USWPunishmentConfig, msg.guild_id) do
        nil ->
          "🚫 USW punishment is not configured"

        config ->
          changeset = USWPunishmentConfig.changeset(config, %{escalate: true})
          {:ok, _updated_config} = Repo.update(changeset)
          "👌 automatic punishment escalation is now enabled"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, ["off"]) do
    response =
      case Repo.get(USWPunishmentConfig, msg.guild_id) do
        nil ->
          "🚫 USW punishment is not configured"

        config ->
          changeset = USWPunishmentConfig.changeset(config, %{escalate: false})
          {:ok, _updated_config} = Repo.update(changeset)
          "👌 automatic punishment escalation is now disabled"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `usw escalate [on|off]`"
    {:ok, _msg} = Message.create(msg.channeL_id, response)
  end
end
