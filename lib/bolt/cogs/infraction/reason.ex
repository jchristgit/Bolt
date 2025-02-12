defmodule Bolt.Cogs.Infraction.Reason do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["infraction reason <id:int> <new_reason:str...>"]

  @impl true
  def description,
    do: """
    Updates the reason on the given infraction ID.
    Only the infraction creator can update its reason.
    Requires the `MANAGE_MESSAGES` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  def command(msg, [maybe_id | reason_list]) do
    new_reason = Enum.join(reason_list, " ")

    response =
      with {id, _rest} <- Integer.parse(maybe_id),
           infraction when infraction != nil <-
             Repo.get_by(Infraction, id: id, guild_id: msg.guild_id) do
        if msg.author.id != infraction.actor_id do
          "🚫 you need to be the infraction creator to do that"
        else
          changeset = Infraction.changeset(infraction, %{reason: new_reason})
          {:ok, updated_infraction} = Repo.update(changeset)

          ModLog.emit(
            msg.guild_id,
            "INFRACTION_UPDATE",
            "#{Humanizer.human_user(msg.author)} " <>
              if(
                infraction.reason == nil,
                do:
                  "added the reason `#{Helpers.clean_content(new_reason)}` to ##{infraction.id}",
                else:
                  "updated the reason of infraction ##{infraction.id} to" <>
                    "`#{Helpers.clean_content(new_reason)}`, was" <>
                    "`#{Helpers.clean_content(infraction.reason)}`"
              )
          )

          "👌 updated infraction ##{updated_infraction.id}"
        end
      else
        nil ->
          "🚫 no infraction with the given ID found on this guild"

        :error ->
          "🚫 expected an integer (infraction ID to edit), but that is not a valid integer"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `infraction reason <id:int> <new_reason:str...>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
