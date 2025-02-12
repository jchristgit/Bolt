defmodule Bolt.Cogs.Role.Deny do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Helpers
  alias Bolt.Humanizer
  alias Bolt.ModLog
  alias Bolt.Repo
  alias Bolt.Schema.SelfAssignableRoles
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Message

  @impl true
  def usage, do: ["role deny <role:role...>"]

  @impl true
  def description,
    do: """
    Remove the given role from the self-assignable roles.
    Self-assignable roles are special roles that can be assigned my members through bot commands.
    Requires the `MANAGE_ROLES` permission.

    **Examples**:
    ```rs
    // no longer allow self-assignment of the 'Movie Nighter' role
    role deny movie nighter
    ```
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_roles)]

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def command(msg, "") do
    response = "ℹ️ usage: `role deny <role:role...>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  def command(msg, role_name) do
    response =
      case Converters.to_role(role_name, msg.guild_id, true) do
        {:ok, role} ->
          existing_row = Repo.get(SelfAssignableRoles, msg.guild_id)

          cond do
            existing_row == nil ->
              "🚫 this guild has no self-assignable roles"

            role.id not in existing_row.roles ->
              "🚫 role `#{Helpers.clean_content(role.name)}` is not self-assignable"

            true ->
              updated_row = %{
                roles: Enum.reject(existing_row.roles, &(&1 == role.id))
              }

              changeset = SelfAssignableRoles.changeset(existing_row, updated_row)
              {:ok, _updated_row} = Repo.update(changeset)

              ModLog.emit(
                msg.guild_id,
                "CONFIG_UPDATE",
                "#{Humanizer.human_user(msg.author)} removed" <>
                  " #{Humanizer.human_role(msg.guild_id, role)} from self-assignable roles"
              )

              "👌 role #{Humanizer.human_role(msg.guild_id, role)} is no longer self-assignable"
          end

        {:error, reason} ->
          "🚫 cannot convert `#{Helpers.clean_content(role_name)}` to `role`: #{reason}"
      end

    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
