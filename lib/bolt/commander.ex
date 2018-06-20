defmodule Bolt.Commander do
  alias Bolt.Commander.Parsers
  alias Bolt.Commander.Server
  alias Nostrum.Api

  @prefix Application.fetch_env!(:bolt, :prefix)

  @spec find_failing_predicate(
          Nostrum.Struct.Message.t(),
          (Nostrum.Struct.Message.t() ->
             {:ok, Nostrum.Struct.Message.t()} | {:error, Nostrum.Struct.Embed.t()})
        ) :: nil | {:error, Nostrum.Struct.Embed.t()}
  def find_failing_predicate(msg, predicates) do
    predicates
    |> Enum.map(& &1.(msg))
    |> Enum.find(&match?({:error, _embed}, &1))
  end

  @spec invoke(Map.t(), Nostrum.Structs.Message.t(), [String.t()]) :: no_return()
  defp invoke(%{callback: callback} = command, msg, args) do
    parser = Map.get(command, :parser, &Parsers.passthrough/1)

    case Map.get(command, :predicates, []) do
      # no predicates -> invoke command directly
      [] ->
        callback.(msg, parser.(args))

      # non-empty predicate list -> ensure all of them pass
      predicates ->
        failed = find_failing_predicate(msg, predicates)

        case failed do
          nil ->
            # all predicates passed. invoke the command
            callback.(msg, parser.(args))

          {:error, embed} ->
            # a predicate failed. show the response generated by it
            {:ok, _msg} = Api.create_message(msg.channel_id, embed: embed)
        end
    end
  end

  @spec try_split(String.t()) :: [String.t()]
  def try_split(content) do
    try do
      OptionParser.split(content)
    rescue
      _ in RuntimeError -> String.split(content)
    end
  end

  @doc """
  Handle a message sent over the gateway.
  If the message starts with the prefix and
  contains a valid command, the arguments
  are parsed accordingly and passed to
  the command along with the message.
  Otherwise, the message is ignored.
  """
  @spec handle_message(Nostrum.Struct.Message.t()) :: no_return
  def handle_message(msg) do
    with [@prefix <> command_name | args] <- try_split(msg.content),
         command_map when command_map != nil <- Server.lookup(command_name) do
      invoke(command_map, msg, args)
    else
      _err -> :ignored
    end
  end
end
