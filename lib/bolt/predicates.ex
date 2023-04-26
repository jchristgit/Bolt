defmodule Bolt.Predicates do
  @moduledoc "Implements various predicates used by commands."

  alias Bolt.BotLog
  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User

  @doc "Checks that the message author is in the superuser list."
  @spec is_superuser?(Message.t()) :: {:ok, Message.t()} | {:error, String.t()}
  def is_superuser?(msg) do
    if msg.author.id in Application.fetch_env!(:bolt, :superusers) do
      BotLog.emit(
        "🔓 #{Humanizer.human_user(msg.author)} passed the root user check" <>
          " and is about to invoke `#{Helpers.clean_content(msg.content)}`" <>
          " in channel `#{msg.channel_id}`"
      )

      {:ok, msg}
    else
      BotLog.emit(
        "🔒#{Humanizer.human_user(msg.author)} attempted using the root-only" <>
          " command `#{Helpers.clean_content(msg.content)}` in channel `#{msg.channel_id}`" <>
          if(
            msg.guild_id != nil,
            do: " on guild ID `#{msg.guild_id}`",
            else: ", which is a direct message channel"
          )
      )

      {
        :noperm,
        "🚫 #{User.full_name(msg.author)} is not in the sudoers file." <>
          " This incident will be reported."
      }
    end
  end
end
