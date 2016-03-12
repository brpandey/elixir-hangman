defmodule Player.Events do
  @moduledoc """
  Module implements `GenEvent` manager for use with `player`.

  Handles writing of `event` notification data to a `player` log file or
  displaying them as a `feed` to the user
  """

  require Logger

  @doc """
  Start public interface method
  """
  
  @spec start_link(Keyword.t) :: {:ok, pid}
  def start_link(options \\ [file_output: false, display_output: true]) do
    Logger.info "Starting Hangman Event GenServer, options #{inspect options}"

    {:ok, pid} = reply = GenEvent.start_link()

    # Given file_output is specified, add logger event handler to log events to file
    case Keyword.fetch(options, :file_output) do
      {:ok, true} ->
        GenEvent.add_handler(pid, Player.Logger.Handler, [])
      _ -> ""
    end

    # Given display_output is specified, add a background task process which is setup to 
    # stream the gen events and according to event type display them on screen 
    # using a feed like syntax
    case Keyword.fetch(options, :display_output) do
      
      {:ok, true} ->

        Task.start_link fn ->
          stream = GenEvent.stream(pid)

          # the stream is the generator here in this list comprehension, 
          # as events come in we process them
          for event <- stream do
            case event do
              {:start, name} ->
                IO.puts "##{name}_feed --> Hangman_Game has started"

              {:secret_length, name, game_no, length} ->
                IO.puts "##{name}_feed Game #{game_no}, " <> 
                  "secret length --> #{length}"

              {{:guess_letter, letter}, {name, game_no}} ->
                IO.puts "##{name}_feed Game #{game_no}, " <> 
                  "letter --> #{letter}"

              {{:guess_word, word}, {name, game_no}} ->
                IO.puts "##{name}_feed Game #{game_no}, " <> 
                  "word --> #{word}"

              {:round_status, name, game_no, round_no, status} ->
                IO.puts "##{name}_feed Game #{game_no}, " <> 
                  "Round #{round_no}, status --> #{status}\n"

              {:games_over, name, text} ->
                IO.puts "##{name}_feed Game Over!! --> #{text}"
            end
          end
        end

      _ -> ""
    end

    reply
  end

  @doc """
  Sends `:start` tuple `event` notification to `Player.Events`
  """

  @spec notify_start(pid, name :: String.t) :: :ok
  def notify_start(pid, name) do
    GenEvent.notify(pid, {:start, name})
  end

  @doc """
  Sends `:secret_length` tuple `event` notification to `Player.Events`
  """

  @spec notify_length(pid, data :: tuple) :: :ok
  def notify_length(pid, {name, game_no, length}) do
    GenEvent.notify(pid, {:secret_length, name, game_no, length})
  end

  @doc """
  Sends either a `{:guess_letter, letter}` or 
  `{:guess_word, word}` tuple  `event` notification to `Player.Events`, 
  depending on guess.
  """

  @spec notify_guess(pid, guess :: Guess.t, info :: tuple) :: :ok

  def notify_guess(pid, {:guess_letter, letter} = _guess, 
                   {name, game_no}) when is_binary(letter) do
    guess = {:guess_letter, letter}
    info = {name, game_no}

    GenEvent.notify(pid, {guess, info})
  end


  def notify_guess(pid, {:guess_word, word} = _guess, 
                   {name, game_no}) when is_binary(word) do
    guess = {:guess_word, word}
    info = {name, game_no}

    GenEvent.notify(pid, {guess, info})
  end


  @doc """
  Sends `:round_status` tuple `event` notification to `Player.Events`
  """

  @spec notify_status(pid, data :: tuple) :: :ok
  def notify_status(pid, {name, game_no, round_no, status}) do
    GenEvent.notify(pid, {:round_status, name, game_no, round_no, status})
  end

  @doc """
  Sends `:games_over` tuple `event` notification to `Player.Events`
  """

  @spec notify_games_over(pid, name :: String.t, text :: String.t) :: :ok
  def notify_games_over(pid, name, text) do
    GenEvent.notify(pid, {:games_over, name, text})
  end

  @doc """
  Issues request to stop `GenEvent` manager
  """
  
  @spec stop(pid) :: :ok
  def stop(pid) do
    GenEvent.stop(pid)
  end


  @docp """
  Callback function for termination
  """
  
  #@callback terminate(term, term) :: :ok
  def terminate(_reason, _state) do
    :ok
  end

end
