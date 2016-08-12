
alias Experimental.GenStage

defmodule Hangman.Player.Alert.Handler do
  use GenStage

  require Logger

  @moduledoc """
  Module implements event logger handler for `Hangman.Events.Manager`.
  Each `event` is logged to a file named after the player `id`.
  """

  def start_link(options) do
    GenStage.start_link(__MODULE__, options)
  end

  def stop(pid) when is_pid(pid) do
    GenStage.call(pid, :stop)
  end

  # Callbacks

  def init(options) do
    # Starts a permanent subscription to the broadcaster
    # which will automatically start requesting items.

    with {:ok, key} <- Keyword.fetch(options, :id), 
    {:ok, write_pid} <- Keyword.fetch(options, :pid) do
      {:consumer, {key, write_pid}, subscribe_to: [Hangman.Game.Event.Manager]}
    else 
      ## ABORT if display output not true
      _ -> {:stop, :normal}
    end
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  @doc """
  The handle_events callback handles various events
  which ultimately write to `player` logger file

  """

  def handle_events(events, _from, {key, write_pid}) do

    for event <- events, key == Kernel.elem(event, 1) do
      process_event(event, write_pid)
    end

    {:noreply, [], {key, write_pid}}    
  end

  defp process_event(event, _write_pid) do

    msg = 
      case event do
        {:start, name, game_no} ->
          "##{name}_feed --> Game #{game_no} has started"
        {:register, name, {game_no, length}} ->
          "##{name}_feed Game #{game_no}, " <> 
            "secret length --> #{length}"
        {:guess, name, {{:guess_letter, letter}, game_no}} ->
          "##{name}_feed Game #{game_no}, " <> 
            "letter --> #{letter}"
        {:guess, name, {{:guess_word, word}, game_no}} ->
          "##{name}_feed Game #{game_no}, " <> 
            "word --> #{word}"
        {:status, name, {game_no, round_no, text}} ->
          "##{name}_feed Game #{game_no}, " <> 
            "Round #{round_no}, status --> #{text}\n"
        {:games_over, name, text} ->
          "##{name}_feed Game Over!! --> #{text}"
      end


    IO.puts(msg)


  end


  @doc """
  Terminate callback. Closes player `logger` file
  """
  
  @callback terminate(term, term) :: :ok | tuple
  def terminate(_reason, _state) do
    Logger.info "Terminating Player Alert"
    :ok
  end
end