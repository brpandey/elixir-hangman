defmodule Hangman.Web.Handler do

  @moduledoc """
  Module drives `Player.Controller`, while
  setting up the proper `Game` server and `Event` consumer states.

  Simply stated it politely nudges the player to proceed to the next 
  course of action or make the next guess.  The handler also collects 
  input from the user as necessary and displays data back to the 
  user.

  When the game is finished it politely ends the game playing.

  This module is the goto destination after all the arguments
  have been collected in `Hangman.Web`
  """

  alias Hangman.{Game.Pid.Cache, Player, Player.Controller}

  require Logger

  @doc """
  Sets up the `game` server and per player `event` server.
  Used primarly by the `Web.Collator`
  """
  
  @spec setup(tuple()) :: tuple
  def setup({name, secrets}) when 
  (is_binary(name) or is_tuple(name)) and is_list(secrets) do

    # Grab game pid first from game pid cache
    game_pid = Cache.get_server_pid(name, secrets)

    # Start Worker in Controller
    Controller.start_worker(name, :robot, false, game_pid)

    name
  end

  @doc """
  Play handles client play loop
  """

  @spec play(Player.id) :: tuple
  def play(player_handler_key) do
    # atom tag on end for pipe ease

    # Loop until we have received an :exit value from the Player Controller
    list = Enum.reduce_while(Stream.cycle([player_handler_key]), [], fn key, acc ->
      
      feedback = key |> Controller.proceed

      case feedback do
        {code, _status} when code in [:begin, :transit] ->
          {:cont, acc}

        {:retry, _status} ->
          Process.sleep(2000) # Stop gap for now for no proc error by gproc
          {:cont, acc}

        {:action, status} -> # collect guess result status as given from action state
          acc = [status | acc] # prepend to list then later reverse -- O(1)
          {:cont, acc}

        {:exit, status} -> 
          acc = [status | acc] # prepend to list then later reverse -- O(1)
          Controller.stop_worker(key)

          {:halt, acc}

        _ -> raise "Unknown Player state"
      end
    end)

    # we reverse the prepended list of round statuses
    list = list |> Enum.reverse

    {player_handler_key, list}
  end


end
