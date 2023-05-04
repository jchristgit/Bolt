defmodule Bolt.USW.Rules.Links do
  @moduledoc "Checks for repeated links sent by a single user."
  @behaviour Bolt.USW.Rule

  alias Bolt.USW
  alias Nosedrum.MessageCache.Agent, as: MessageCache
  alias Nostrum.Struct.{Message, Snowflake}

  # Taken from Matthew O'Riordan on StackOverflow: https://stackoverflow.com/a/8234912/1955716
  # credo:disable-for-next-line Credo.Check.Readability.MaxLineLength
  @link_re ~r</((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)/>

  @impl true
  @spec apply(Message.t(), non_neg_integer(), non_neg_integer(), Snowflake.t()) ::
          :action | :passthrough
  def apply(msg, limit, interval, interval_seconds_ago_snowflake) do
    recent_links =
      msg.guild_id
      |> MessageCache.recent_in_guild(:infinity, Bolt.MessageCache)
      |> Stream.filter(&(&1.id >= interval_seconds_ago_snowflake))
      |> Stream.filter(&(&1.author.id == msg.author.id))
      |> Stream.map(& &1.content)
      |> Stream.map(&Regex.scan(@link_re, &1))
      |> Stream.map(&Enum.count(&1))
      |> Enum.sum()

    if recent_links >= limit do
      USW.punish(
        msg.guild_id,
        msg.author.id,
        "sending #{recent_links} links in #{interval}s"
      )

      :action
    else
      :passthrough
    end
  end
end
