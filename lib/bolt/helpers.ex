defmodule Bolt.Helpers do
  @moduledoc "Various helpers used throughout the bot."

  alias Nosedrum.Converters
  alias Nostrum.Api.Guild
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Cache.MemberCache
  alias Nostrum.Struct
  alias Nostrum.Struct.Guild.{Member, Role}
  alias Nostrum.Struct.User
  require Logger

  @doc """
  Convert a boolean value to the
  "human" string equivalent.

  ## Examples

    iex> Helpers.bool_to_human(true)
    "yes"
    iex> Helpers.bool_to_human(false)
    "no"
  """
  @spec bool_to_human(boolean) :: String.t()
  def bool_to_human(true), do: "yes"
  def bool_to_human(false), do: "no"

  @doc """
  Converts a valid datetime to a
  human-readable string in the form
  "dd.mm.yy hh:mm (n [seconds/minutes/hours/days/weeks/months/years] ago)"
  """
  @spec datetime_to_human(DateTime.t()) :: String.t()
  def datetime_to_human(dt) do
    "<t:#{DateTime.to_unix(dt)}:R>"
  end

  @doc "Try to return a member of the given guild ID with the given author ID."
  @spec get_member(
          Struct.Guild.id(),
          User.id()
        ) :: {:ok, Member.t()} | {:error, String.t()}
  def get_member(guild_id, author_id) do
    case MemberCache.get(guild_id, author_id) do
      {:ok, _member} = result ->
        result

      {:error, _reason} ->
        case Guild.member(guild_id, author_id) do
          {:ok, _member} = result -> result
          {:error, _why} -> {:error, "member not be found in cache nor via the API"}
        end
    end
  end

  @spec find_role(
          [Role.t()],
          [Snowflake.id()]
        ) :: {:ok, Role.t()} | {:error, String.t()}
  defp find_role(guild_roles, member_roles) do
    role_match =
      guild_roles
      |> Map.values()
      |> Stream.filter(&(&1.id in member_roles))
      |> Enum.max_by(& &1.position, fn -> {:error, "no roles on member"} end)

    case role_match do
      {:error, _reason} = error -> error
      role -> {:ok, role}
    end
  end

  @doc "Returns the top role for the given member ID on the given guild, representative for permissions on the given guild ID."
  @spec top_role_for(
          Struct.Guild.id(),
          User.id()
        ) :: {:ok, Role.t()} | {:error, String.t()}
  def top_role_for(guild_id, member_id) do
    case get_member(guild_id, member_id) do
      {:ok, member} ->
        case GuildCache.get(guild_id) do
          {:ok, guild} ->
            find_role(guild.roles, member.roles)

          {:error, _reason} ->
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case Guild.roles(guild_id) do
              {:ok, roles} ->
                find_role(roles, member.roles)

              {:error, _} ->
                {:error, "guild was not in the cache, nor could it be fetched from the API"}
            end
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Replace `@everyone` and `@here` mentions with their harmless variants
  """
  @spec clean_content(boolean() | String.t()) :: String.t()
  def clean_content(true), do: "true"
  def clean_content(false), do: "false"

  def clean_content(content) when is_binary(content) do
    content
    |> String.replace("@everyone", "@\u200Beveryone")
    |> String.replace("@here", "@\u200Bhere")
    |> String.replace("`", "\\`")
  end

  @doc "Convert text into either a raw snowflake or a snowflake + member."
  @spec into_id(Struct.Guild.id(), String.t()) ::
          {:ok, User.id(), User.t() | nil}
          | {:error, String.t()}
  def into_id(guild_id, text) do
    case Integer.parse(text) do
      {value, ""} ->
        {:ok, value, nil}

      :error ->
        case Converters.to_member(text, guild_id) do
          {:ok, member} -> {:ok, member.user_id, nil}
          {:error, _} = error -> error
        end
    end
  end

  @doc "Checks that `actor_id`'s top role is above `target_id`s top role on `guild_id`."
  @spec above?(Struct.Guild.id(), User.id(), User.id()) :: {:ok, true | false} | {:error, String.t()}
  def above?(guild_id, actor_id, target_id) do
    case top_role_for(guild_id, actor_id) do
      {:ok, actor_top_role} ->
        case top_role_for(guild_id, target_id) do
          {:ok, target_top_role} ->
            {:ok, actor_top_role.position > target_top_role.position}

          # If the author passed all checks and got around to invoke the command,
          # happens to have a single role, and the target member does not have any
          # roles, then the author is always above the member in the hierarchy.
          # This does not take guild ownership into account.
          {:error, "no roles on member"} ->
            {:ok, true}

          # If the target user is no longer on the guild, then the actor is surely above them
          # in the role hierarchy. This is usually the case with bans.
          {:error, "there is no member with ID " <> _remainder} ->
            {:ok, true}

          {:error, _reason} = error ->
            error
        end

      _err ->
        {:error,
         "you need to be above the target user in the role " <>
           "hierarchy to run that, but you don't have any roles"}
    end
  end

  @doc """
  Return `plural` when the given integer is not one, otherwise, return `singular`.

  ## Examples

      iex> pluralize(1, "sheep", "sheep")
      "sheep"
      iex> pluralize(5, "sheep", "sheep")
      "sheep"
  """
  @spec pluralize(Integer.t(), String.t(), String.t()) :: String.t()
  def pluralize(1, singular, _plural), do: singular
  def pluralize(_n, _singular, plural), do: plural
end
