defmodule Bolt.Cogs.Infraction.Expiry do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.ErrorFormatters
  alias Bolt.Events.Handler
  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Parsers
  alias Bolt.Repo
  alias Bolt.Schema.Infraction
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Api.Guild
  require Logger

  @impl true
  def usage, do: ["infraction expiry <id:int> <expiry:duration>"]

  @impl true
  def description,
    do: """
    Update the expiration date of the given infraction ID, relative to now.
    This is only applicable to timed (temporary) infractions that have not expired yet.
    Requires the `MANAGE_GUILD` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, [maybe_id, new_expiry]) do
    response =
      with {id, _rest} <- Integer.parse(maybe_id),
           infraction when infraction != nil <-
             Repo.get_by(Infraction, id: id, guild_id: msg.guild_id),
           {:ok, offset_seconds} <- Parsers.duration_string_to_seconds(new_expiry),
           updated_expiry <- DateTime.add(DateTime.utc_now(), offset_seconds),
           {:ok, updated_infraction} <- update_expiry(infraction, updated_expiry) do
        emit_log(msg, infraction, updated_infraction, offset_seconds)

        expiry_string =
          if offset_seconds == 0,
            do: "expires now",
            else: "now expires at #{Helpers.datetime_to_human(updated_infraction.expires_at)}"

        "👌 infraction ##{infraction.id} #{expiry_string}"
      else
        nil ->
          "🚫 no infraction with ID `#{Helpers.clean_content(maybe_id)}` found"

        :error ->
          "🚫 expected an integer for the infraction ID, got something else"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `infraction expiry <id:int> <expiry:duration>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  @spec emit_log(Message.t(), Infraction, Infraction, non_neg_integer()) :: ModLog.on_emit()
  defp emit_log(msg, old_infraction, new_infraction, 0),
    do:
      ModLog.emit(
        msg.guild_id,
        "INFRACTION_UPDATE",
        "#{Humanizer.human_user(msg.author)} set ##{new_infraction.id} to expire now, " <>
          "was #{Helpers.datetime_to_human(old_infraction.expires_at)}"
      )

  defp emit_log(msg, old_infraction, new_infraction, _offset_seconds),
    do:
      ModLog.emit(
        msg.guild_id,
        "INFRACTION_UPDATE",
        "#{Humanizer.human_user(msg.author)} changed expiry for " <>
          "##{new_infraction.id} " <>
          "to #{Helpers.datetime_to_human(new_infraction.expires_at)}, " <>
          "was #{Helpers.datetime_to_human(old_infraction.expires_at)}"
      )

  # Requires a special branch as Discord expires this automatically
  defp update_expiry(
         %Infraction{
           guild_id: guild_id,
           user_id: user_id,
           type: "timeout",
           expires_at: old_expiry
         } = infraction,
         new_expiry
       ) do
    with now <- DateTime.utc_now(),
         {:expired?, false} <- {:expired?, DateTime.compare(old_expiry, now) == :lt},
         {:api, {:ok, _member}} <-
           {:api,
            Guild.modify_member(guild_id, user_id, communication_disabled_until: new_expiry)} do
      changeset = Infraction.changeset(infraction, %{expires_at: new_expiry})
      Repo.update(changeset)
    else
      {:expired?, true} ->
        {:error, "infraction already expired"}

      {:api, errtuple} ->
        errtuple
    end
  end

  defp update_expiry(infraction, new_expiry) do
    Handler.update(infraction, %{expires_at: new_expiry})
  end
end
