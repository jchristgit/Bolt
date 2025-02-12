defmodule Bolt.Cogs.Infraction.Detail do
  @moduledoc false

  @behaviour Nosedrum.TextCommand

  alias Bolt.Cogs.Infraction.General
  alias Nosedrum.TextCommand.Predicates
  alias Bolt.{Constants, Helpers, Humanizer, Repo}
  alias Bolt.Schema.Infraction
  alias Nostrum.Api.Message
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Embed.{Field, Footer}

  @spec add_specific_fields(Embed.t(), Infraction) :: Embed.t()
  defp add_specific_fields(embed, %Infraction{type: "temprole", data: data}) do
    new_field = %Field{
      name: "Added role",
      value: "<@&#{data["role_id"]}>",
      inline: true
    }

    {_, embed} =
      Map.get_and_update(embed, :fields, fn fields ->
        {fields, fields ++ [new_field]}
      end)

    embed
  end

  defp add_specific_fields(embed, _) do
    embed
  end

  @spec add_field_if(Embed.t(), boolean(), non_neg_integer(), (() -> Field.t())) :: Embed.t()
  defp add_field_if(embed, condition, index, field_func) do
    if condition do
      Map.put(
        embed,
        :fields,
        List.insert_at(embed.fields, index, field_func.())
      )
    else
      embed
    end
  end

  @spec add_reason(Embed.t(), String.t() | nil) :: Embed.t()
  def add_reason(embed, nil) do
    add_reason(embed, "(empty reason)")
  end

  def add_reason(embed, reason) do
    if String.length(reason) > 1024 do
      Map.put(embed, :description, reason)
    else
      Map.put(
        embed,
        :fields,
        List.insert_at(embed.fields, 5, %Field{name: "Reason", value: reason, inline: true})
      )
    end
  end

  @spec format_detail(Infraction) :: Embed.t()
  defp format_detail(infraction) do
    %Embed{
      title: "Infraction ##{infraction.id}",
      color: Constants.color_blue(),
      fields: [
        %Field{
          name: "User",
          value: Humanizer.human_user(infraction.user_id),
          inline: true
        },
        %Field{
          name: "Type",
          value:
            "#{General.emoji_for_type(infraction.type)} #{infraction.type |> String.replace("_", " ") |> String.capitalize()}",
          inline: true
        },
        %Field{
          name: "Creation",
          value: Helpers.datetime_to_human(infraction.inserted_at),
          inline: true
        }
      ],
      footer: %Footer{
        text: "authored by #{Humanizer.human_user(infraction.actor_id)}"
      }
    }
    |> add_specific_fields(infraction)
    |> add_field_if(
      DateTime.diff(infraction.inserted_at, infraction.updated_at, :second) <= 0,
      3,
      fn ->
        %Field{
          name: "Modification",
          value: Helpers.datetime_to_human(infraction.updated_at),
          inline: true
        }
      end
    )
    |> add_field_if(
      infraction.expires_at != nil,
      4,
      fn ->
        %Field{
          name: "Expiry",
          value:
            if(
              Infraction.active?(infraction),
              do: "#{Helpers.datetime_to_human(infraction.expires_at)}",
              else: "#{Helpers.datetime_to_human(infraction.expires_at)} *(inactive)*"
            ),
          inline: true
        }
      end
    )
    |> add_reason(infraction.reason)
  end

  @impl true
  def usage, do: ["infraction detail <id:int>"]

  @impl true
  def description,
    do: """
    View the given infraction ID in detail.
    Requires the `MANAGE_MESSAGES` permission.
    """

  @impl true
  def predicates,
    do: [&Predicates.guild_only/1, Predicates.has_permission(:manage_messages)]

  @impl true
  def command(msg, [maybe_id]) do
    with {id, _} <- Integer.parse(maybe_id),
         infraction when infraction != nil <-
           Repo.get_by(Infraction, id: id, guild_id: msg.guild_id) do
      embed = format_detail(infraction)
      {:ok, _msg} = Message.create(msg.channel_id, embed: embed)
    else
      nil ->
        response = "🚫 no infraction with the given ID found"
        {:ok, _msg} = Message.create(msg.channel_id, response)

      :error ->
        response = "🚫 expected an integer (ID to look up), but that is not a valid integer"
        {:ok, _msg} = Message.create(msg.channel_id, response)
    end
  end

  def command(msg, _args) do
    response = "ℹ️ usage: `infraction detail <id:int>`"
    {:ok, _msg} = Message.create(msg.channel_id, response)
  end
end
