defmodule Bolt.Cogs.Note do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["note <user:member> <note:str...>"]

  @impl true
  def description,
    do: """
    Create a note for the given user.
    The note is stored in the infraction database, and can be retrieved later.
    Requires the `MANAGE_MESSAGES` permission.

    **Examples**:
    ```rs
    note @Dude#0001 has an odd affection to ducks
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  def command(msg, [user | note_list]) do
    response =
      with {:ok, member} <- Converters.to_member(user, msg.guild_id),
           note when note != "" <- Enum.join(note_list, " "),
           infraction = %{
             type: "note",
             guild_id: msg.guild_id,
             user_id: member.user.id,
             actor_id: msg.author.id,
             reason: note
           },
           changeset <- Infraction.changeset(%Infraction{}, infraction),
           {:ok, _created_infraction} <- Repo.insert(changeset) do
        ModLog.emit(
          msg.guild_id,
          "INFRACTION_CREATE",
          "#{Humanizer.human_user(msg.author)} added a note to" <>
            " #{Humanizer.human_user(member.user)}, contents: `#{note}`"
        )

        "👌 note created for #{Humanizer.human_user(member.user)}"
      else
        "" ->
          "🚫 note may not be empty"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `note <user:member> <note:str...>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
