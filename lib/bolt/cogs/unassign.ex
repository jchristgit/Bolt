defmodule Bolt.Cogs.Unassign do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Bolt.{ErrorFormatters, Helpers, ModLog, Repo}
  alias Bolt.Schema.SelfAssignableRoles
  alias Nostrum.Api.Guild
  alias Nostrum.Api.Message
  alias Nostrum.Struct.User

  @impl true
  def usage, do: ["unassign <role:role...>"]

  @impl true
  def description,
    do: """
    Unassign the given self-assignable role from yourself.
    To see which roles are self-assignable, use `lsar`.
    Aliased to `iamn`.

    **Examples**:
    ```rs
    // unassign the role 'Movie Nighter'
    unassign movie nighter
    ```
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def command(msg, "") do
    response = "🚫 expected the role name to unassign, got nothing"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, role_name) do
    response =
      with roles_row when roles_row != nil <- Repo.get(SelfAssignableRoles, msg.guild_id),
           {:ok, role} <- Converters.to_role(role_name, msg.guild_id, true),
           true <- role.id in roles_row.roles,
           {:ok} <- Guild.remove_member_role(msg.guild_id, msg.author.id, role.id) do
        ModLog.emit(
          msg.guild_id,
          "SELF_ASSIGNABLE_ROLES",
          "removed the self-assignable role `#{role.name}` from" <>
            " #{User.full_name(msg.author)} (`#{msg.author.id}`)"
        )

        "👌 removed the `#{Helpers.clean_content(role.name)}` role from you"
      else
        nil ->
          "🚫 this guild has no self-assignable roles configured"

        false ->
          "🚫 that role is not self-assignable"

        error ->
          ErrorFormatters.fmt(msg, error)
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
