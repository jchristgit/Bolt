defmodule Bolt.Cogs.Role.Mute do
  @moduledoc false
  @behaviour Nosedrum.TextCommand

  alias Bolt.Schema.MuteRole
  alias Bolt.{ErrorFormatters, ModLog, Repo}
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Struct.User

  @impl true
  def usage, do: ["role mute [muterole:role...]"]

  @impl true
  def description,
    do: """
    Set the role to be applied when the `.mute` or `.tempmute` commands are used.
    When invoked without a role, show the currently configured mute role.
    Note that the `.mute` and `.tempmute` commands can be used by users with the guild-wide `MANAGE_MESSAGES` permission.
    Requires the `MANAGE_GUILD` permission.

    **Example**:
    ```rs
    // See the currently configured mute role.
    .role mute

    // Set the mute role to a role called 'Muted'
    .role mute Muted
    ```
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_guild)]

  @impl true
  def command(msg, []) do
    response =
      with %MuteRole{role_id: role_id} <- Repo.get(MuteRole, msg.guild_id),
           {:ok, guild} <- GuildCache.get(msg.guild_id),
           {:ok, role} <- Map.get(guild.roles, role_id) do
        if role == nil do
          "ℹ️ mute role is currently set to an unknown role, does it exist?"
        else
          "ℹ️ mute role is currently set to `#{role.name}`"
        end
      else
        nil ->
          "ℹ️ no mute role configured, pass a role to set it up"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, ["delete"]) do
    response =
      with row when row != nil <- Repo.get(MuteRole, msg.guild_id),
           {:ok, struct} <- Repo.delete(row) do
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{User.full_name(msg.author)} deleted configured mute role, was `#{struct.role_id}`"
        )

        "👌 deleted configured mute role"
      else
        nil -> "🚫 no mute role is set up"
        error -> ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, role_str_list) do
    role_str = Enum.join(role_str_list, " ")

    response =
      with {:ok, role} <- Converters.to_role(role_str, msg.guild_id),
           mute_role_map <- %{
             guild_id: msg.guild_id,
             role_id: role.id
           },
           changeset <- MuteRole.changeset(%MuteRole{}, mute_role_map),
           {:ok, _struct} <-
             Repo.insert(changeset,
               on_conflict: [set: [role_id: role.id]],
               conflict_target: :guild_id
             ) do
        ModLog.emit(
          msg.guild_id,
          "CONFIG_UPDATE",
          "#{User.full_name(msg.author)} set the mute role to `#{role.name}`"
        )

        "👌 will now use role `#{role.name}` for mutes"
      else
        error -> ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
