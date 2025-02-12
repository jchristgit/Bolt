defmodule Bolt.Cogs.Sudo.Load do
  @moduledoc "Load a command."

  alias Nosedrum.TextCommand.Storage.ETS, as: CommandStorage
  alias Nostrum.Api.Message
  alias Nostrum.Struct.User
  require Logger

  defp to_command_module(name) do
    String.to_existing_atom("Elixir.Bolt.Cogs." <> name)
  rescue
    _ -> nil
  end

  def command(msg, [name, module_name]) do
    reply =
      case to_command_module(module_name) do
        nil ->
          "🚫 unknown command module `#{module_name}`"

        module ->
          case CommandStorage.lookup_command(name) do
            subcommands when is_map(subcommands) ->
              "🚫 `#{name}` is already loaded as a command group"

            nil ->
              CommandStorage.add_command({name}, module)

              Logger.info(
                "`#{User.full_name(msg.author)}` loaded command `#{name}` as `#{module}`."
              )

              "👌 `#{module_name}` is now loaded as `#{name}`"

            module ->
              short_modname = String.replace_leading("#{module}", "Elixir.", "")
              "🚫 `#{name}` is already loaded as `#{short_modname}`"
          end
      end

    {:ok, _msg} = Message.create(msg.channel_id, reply)
  end

  def command(msg, _args) do
    reply = """
    ℹ usage:
    - `sudo load <command_name:str> <module:str>`
    """

    {:ok, _msg} = Message.create(msg.channel_id, reply)
  end
end
