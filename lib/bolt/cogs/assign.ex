defmodule Bolt.Cogs.Assign do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Schema.SelfAssignableRoles
  alias Bolt.{ErrorFormatters, Helpers, Humanizer, ModLog, Repo}
  alias Nosedrum.Converters
  alias Nosedrum.TextCommand.Predicates
  alias Nostrum.Api.Guild
  alias Nostrum.Api.Message
  alias Nostrum.Cache.MemberCache
  require Logger

  @impl true
  def usage, do: ["assign <role:role...>"]

  @impl true
  def description,
    do: """
    Assigns the given self-assignable role to yourself.
    To see which roles are self-assignable, use `lsar`.
    Aliased to `iam`.

    **Examples**:
    ```rs
    // Assign the role 'Movie Nighter'
    assign movie nighter
    ```
    """

  @impl true
  def predicates, do: [&Predicates.guild_only/1]

  @impl true
  def command(msg, [role_name]) do
    response =
      with roles_row when roles_row != nil <- Repo.get(SelfAssignableRoles, msg.guild_id),
           {:ok, role} <- Converters.to_role(role_name, msg.guild_id, true),
           true <- role.id in roles_row.roles,
           {:ok} <- Guild.add_member_role(msg.guild_id, msg.author.id, role.id) do
        ModLog.emit(
          msg.guild_id,
          "SELF_ASSIGNABLE_ROLES",
          "gave #{Humanizer.human_user(msg.author)}" <>
            " the self-assignable role #{Humanizer.human_role(msg.guild_id, role.id)}"
        )

        "👌 gave you the `#{Helpers.clean_content(role.name)}` role"
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

  def command(msg, args) when length(args) >= 2 do
    case Repo.get(SelfAssignableRoles, msg.guild_id) do
      nil ->
        response = "🚫 this guild has no self-assignable roles configured"
        {:ok, _msg} = Message.create(msg.channel_id, response)

      roles_row ->
        # Let's check if there's a multi-word role matching the arguments...
        maybe_multi_word_name = Enum.join(args, " ")
        conversion_result = Converters.to_role(maybe_multi_word_name, msg.guild_id, true)

        if match?({:ok, _role}, conversion_result) do
          # If yes, we only have a single role we care about,
          # and the author specified a multi-word role.
          # Pass it along to the single-role command handler, it will perform the rest of the work.
          command(msg, [maybe_multi_word_name])
        else
          # Otherwise, assume we got a list of roles to assign.
          converted_roles = Enum.map(args, &Converters.to_role(&1, msg.guild_id, true))
          response = assign_converted(msg, converted_roles, roles_row.roles)
          {:ok, _msg} = Message.create(msg.channel_id, response)
        end
    end
  end

  def command(msg, []) do
    response = "🚫 expected a single or multiple role name(s) to assign, got nothing"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end

  @spec assign_converted(Message.t(), [Role.t()], [Role.id()]) :: String.t()
  defp assign_converted(msg, converted_roles, self_assignable_roles) do
    valid_roles =
      converted_roles
      |> Stream.filter(&match?({:ok, _role}, &1))
      |> Enum.map(&elem(&1, 1))

    selected_self_assignable_roles =
      valid_roles
      |> Enum.filter(&(&1.id in self_assignable_roles))

    not_selfassignable_errors =
      valid_roles
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(selected_self_assignable_roles))
      |> Enum.map(&"`#{&1.name}` is not self-assignable")

    errors =
      converted_roles
      |> Stream.filter(&match?({:error, _reason}, &1))
      |> Stream.map(&elem(&1, 1))
      |> Enum.map(&format_error/1)
      |> Kernel.++(not_selfassignable_errors)

    if Enum.empty?(selected_self_assignable_roles) do
      "🚫 no valid roles to be given - if you meant to assign a single role, " <>
        "check your spelling. errors:\n#{errors |> Stream.map(&"• #{&1}") |> Enum.join("\n")}"
    else
      with {:ok, member} <- MemberCache.get(msg.guild_id, msg.author.id),
           {:ok, _member} <-
             Guild.modify_member(msg.guild_id, msg.author.id,
               roles: Enum.uniq(member.roles ++ Enum.map(selected_self_assignable_roles, & &1.id))
             ) do
        added_role_list =
          selected_self_assignable_roles
          |> Stream.map(& &1.name)
          |> Stream.map(&Helpers.clean_content/1)
          |> Stream.map(&"`#{&1}`")
          |> Enum.join(", ")

        ModLog.emit(
          msg.guild_id,
          "SELF_ASSIGNABLE_ROLES",
          "gave #{Humanizer.human_user(msg.author)}" <>
            " the self-assignable roles #{added_role_list}"
        )

        if Enum.empty?(errors) do
          "👌 gave you the role(s) #{added_role_list}"
        else
          nice_errors = Enum.map(errors, &format_error/1)

          """
          👌 gave you the role(s) #{added_role_list}, but could not give you the others:
          #{nice_errors |> Stream.map(&"• #{&1}") |> Enum.join("\n")}
          """
        end
      else
        {:ok, nil} ->
          "❌ you are currently not cached for this guild"

        error ->
          ErrorFormatters.fmt(msg, error)
      end
    end
  end

  defp format_error({:not_found, {:by, :name, name, [:case_insensitive]}}) do
    "no role named `#{Helpers.clean_content(name)}` not found (case-insensitive)"
  end

  defp format_error(error), do: error
end
