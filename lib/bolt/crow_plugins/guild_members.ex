defmodule Bolt.CrowPlugins.GuildMembers do
  @moduledoc """
  A multigraph plugin that displays the total amount of guild members that
  bolt can see along with per-guild member count graphs.
  """
  # credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart

  alias Nostrum.Cache.GuildCache
  @behaviour Crow.Plugin

  @doc false
  @impl true
  def name do
    'guild_members'
  end

  @doc false
  @impl true
  def config do
    [
      'multigraph guild_members',
      'graph_title total visible guild members across all guilds',
      'graph_vlabel member count',
      'graph_args --base 1000',
      'graph_category discord',
      'graph_info total member count in all guilds bolt can see',
      'members.label total visible members'
      # 'members.min 0'
    ] ++ config_for_guilds()
  end

  @doc false
  @impl true
  def values do
    total_members = Enum.sum(GuildCache.select_all(& &1.member_count))

    [
      'multigraph guild_members',
      'members.value #{total_members}'
    ] ++ values_for_guilds()
  end

  defp config_for_guilds do
    GuildCache.select_all(&{&1.name, &1.id})
    |> Enum.map(fn {name, id} ->
      [
        'multigraph guild_members.gid_#{id}',
        'graph_title member count for #{name}',
        'graph_vlabel member count',
        'graph_args --base 1000',
        'graph_category discord',
        'graph_info total member count for guild #{name} (#{id})',
        'members.label total members'
        # 'members.min 0'
      ]
    end)
    |> :lists.concat()
  end

  defp values_for_guilds do
    GuildCache.select_all(&{&1.id, &1.member_count})
    |> Enum.map(fn {id, member_count} ->
      ['multigraph guild_members.gid_#{id}', 'members.value #{member_count}']
    end)
    |> :lists.concat()
  end
end
