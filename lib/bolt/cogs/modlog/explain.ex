defmodule Bolt.Cogs.ModLog.Explain do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.{Constants, Helpers}
  alias Bolt.Schema.ModLogConfig
  alias Nostrum.Api.Message
  alias Nostrum.Struct.Embed

  @event_map %{
    ## BOT EVENTS
    "AUTOMOD" => """
    Emitted by automatic moderator actions caused by the bot.
    For example, an automatic mute will be logged by this event.
    This also includes self-assignable roles.
    """,
    "BOT_UPDATE" => "Emitted when a noteworthy update is performed in the bot.",
    "CONFIG_UPDATE" => """
    Emitted when the bot's configuration is updated.
    For example, a moderator adding a self-assignable role will cause this to get logged.
    """,
    "INFRACTION_CREATE" => "Emitted when an infraction is created through a command.",
    "INFRACTION_UPDATE" => "Emitted when an infraction is edited through a command.",
    "INFRACTION_EVENTS" => """
    Emitted when an infraction causes the bot to perform an action.
    For example, the `temprole` will log to this event when a temporary role is applied, and when the role is removed again.
    """,

    ## COMMAND EVENTS
    "MESSAGE_CLEAN" => "Emitted when a moderator invokes `clean`. Attaches the deleted messages.",
    "SELF_ASSIGNABLE_ROLES" =>
      "Emitted when bolt assigns or unassigns a role as part of the self-assignable role system.",

    ## GATEWAY EVENTS
    "MESSAGE_EDIT" => """
    Emitted when a message is edited. Includes a link to the message in question.
    """,
    "MESSAGE_DELETE" => """
    Emitted when a message is deleted.
    The gateway does not return a lot of information about messages, so this might not log a lot of information.
    """,
    "GUILD_MEMBER_ADD" => "Emitted when a member joins the guild.",
    "GUILD_MEMBER_UPDATE" => """
    Emitted when a member updates themselves on the guild, for example, by changing their nick.
    """,
    "GUILD_MEMBER_REMOVE" => "Emitted when a member leaves the guild.",
    "GUILD_ROLE_UPDATE" => "Emitted when a role is updated."
  }

  @impl true
  def usage, do: ["modlog explain <event:str>"]

  @impl true
  def description,
    do: """
    Explains the given `event`.
    To find out which events are known by bolt, use `modlog events`.
    """

  @impl true
  def predicates, do: []

  @impl true
  def command(msg, [event_name]) do
    event_name = String.upcase(event_name)

    case Map.get(@event_map, event_name) do
      nil ->
        response =
          if event_name in ModLogConfig.valid_events() do
            "🚫 that event is probably self-explanatory"
          else
            "🚫 unknown event `#{Helpers.clean_content(event_name)}`"
          end

        {:ok, _msg} = Message.create(msg.channel_id, response)

      description ->
        embed = %Embed{
          title: "`#{event_name}`",
          description: description,
          color: Constants.color_blue()
        }

        {:ok, _msg} = Message.create(msg.channel_id, embed: embed)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `modlog explain <event:str>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
