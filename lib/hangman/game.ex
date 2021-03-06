defmodule Hangman.Game do
  @moduledoc """
  Module to create and manage `Hangman` game abstractions. 

  Naturally serves as the symbolic core of the game application.  

  The game embodies the structure of play in this context of letter and word
  guessing.  Therefore it maintains the secret pattern state along with
  the guess state, delineated by correct and incorrect, letter and word.

  Further, a game wouldn't amount to much without a quantifiable outcome
  thus we maintain a score state.  If a game is lost, the score is 
  automatically 25, as deemed by the threshhold of the particular max incorect 
  guesses.  

  The game rules are simply to stay within the max incorrect guesses and choose
  letters consistent with the game.  No timing or other such rules are imposed.

  If the number of incorrect letter guesses exceeds the threshhold,
  the game is lost.  The lower the score and hence the fewer rounds to guess 
  the word, the more desirable aim.

  The `Game` handles a single `Hangman` game or multiple `Hangman` games and 
  runs each game sequentially.  Therefore only one `game` is in play at
  any one time.

  Primary game functions are `load/3`, `guess/2`, `status/1`.
  """

  alias Hangman.{Game, Guess, Pattern}
  require Logger

  # Current game index
  defstruct id: nil,
            current: 0,
            secret: "",
            pattern: "",
            score: 0,
            state: :reset,
            secrets: [],
            patterns: [],
            scores: [],
            max_wrong: 0,
            correct_letters: MapSet.new(),
            incorrect_letters: MapSet.new(),
            incorrect_words: MapSet.new()

  @opaque t :: %__MODULE__{}

  @typedoc "`Game` id is String.t (currently using player's name as unique key)"
  @type id :: String.t()

  @typedoc "`Game` status code values"
  @type code :: :reset | :start | :guessing | :won | :lost | :finished | :abort

  @typedoc "returned `Game` feedback data"

  @type feedback :: %{
          required(:id) => String.t(),
          required(:code) => code,
          optional(:text | :pattern | :result | :previous) => String.t() | atom | map
        }

  @status_codes %{
    start: {:start, 'GAME_START', 0},
    won: {:won, 'GAME_WON', -2},
    lost: {:lost, 'GAME_LOST', 25},
    guessing: {:guessing, 'KEEP_GUESSING', -1},
    reset: {:reset, 'GAME_RESET', 0},
    abort: {:abort, 'GAME_ABORT', 0}
  }

  @mystery_letter "-"

  @min_secret_length Application.get_env(:hangman_game, :min_secret_length)

  @states [:reset, :start, :guessing, :won, :lost, :finished]

  @doc """
  Creates a new `Game` state given new `secret(s)`
  """

  @spec new(id, String.t() | [String.t()], pos_integer) :: t
  def new(id_key, secret, max_wrong)
      when (is_binary(id_key) or is_tuple(id_key)) and is_binary(secret) do
    case @min_secret_length <= String.length(secret) do
      true -> :ok
      false -> raise HangmanError, "Secret submitted is too short"
    end

    secret = String.upcase(secret)
    pattern = String.duplicate(@mystery_letter, String.length(secret))

    %Game{
      id: id_key,
      secret: secret,
      secrets: [secret],
      pattern: pattern,
      max_wrong: max_wrong,
      state: :start
    }
  end

  def new(id_key, secrets, max_wrong)
      when (is_binary(id_key) or is_tuple(id_key)) and is_list(secrets) do
    # Ensure the secrets are atleast the min secret size

    case Enum.all?(secrets, fn x -> @min_secret_length <= String.length(x) end) do
      true -> :ok
      false -> raise HangmanError, "Secret submitted is too short"
    end

    # initialize the list of secrets to be uppercase 
    # initialize the list of patterns to fit the secrets length
    secrets = secrets |> Enum.map(&String.upcase(&1))

    patterns = secrets |> Enum.map(&String.duplicate(@mystery_letter, String.length(&1)))

    %Game{
      id: id_key,
      secret: List.first(secrets),
      pattern: List.first(patterns),
      secrets: secrets,
      patterns: patterns,
      max_wrong: max_wrong,
      state: :start
    }
  end

  @doc """
  Returns boolean whether `Game` states are identical
  """

  @spec equal?(t, t) :: boolean
  def equal?(%Game{} = game1, %Game{} = game2) do
    map1 = Map.from_struct(game1)
    map2 = Map.from_struct(game2)

    Map.equal?(map1, map2)
  end

  @doc """
  Returns boolean whether `Game` is empty
  """

  @spec empty?(t) :: boolean
  def empty?(%Game{} = game) do
    equal?(game, %Game{})
  end

  # Returns length of the current game secret
  @spec secret_length(t) :: integer
  def secret_length(%Game{} = game) do
    true = is_binary(game.secret)
    String.length(game.secret)
  end

  # Change game status to abort
  def abort(%Game{} = game) do
    Kernel.put_in(game.state, :abort)
  end

  @doc """
  Runs `guess` against `Game` `secret`. Updates `Hangman` pattern, status, and
  other `game` recordkeeping structures.

  Guesses follow two types

    * `{:guess_letter, letter}` -   If correct, 
    returns the :correct_letter data tuple along with `game` data
    otherwise, returns the :incorrect_letter data tuple along with `game` data

    * `{:guess_word, word}` -   If correct, returns 
    the :correct_word data tuple along with `game`
    If incorrect, returns the :incorrect_word data tuple with `game` data    
  """

  @spec guess(t, Guess.t()) :: {t, feedback}
  def guess(%Game{} = game, {:guess_letter, letter}) do
    # Assert
    {_, %{code: :guessing}} = status(game)

    letter = letter |> String.upcase()

    {game, result} =
      case String.contains?(game.secret, letter) do
        true ->
          # letter found within secret, update pattern and game
          pattern = Pattern.update(game.pattern, game.secret, letter)
          game = Kernel.put_in(game.correct_letters, MapSet.put(game.correct_letters, letter))
          game = Kernel.put_in(game.pattern, pattern)
          {game, :correct_letter}

        # default: letter not found
        false ->
          game = Kernel.put_in(game.incorrect_letters, MapSet.put(game.incorrect_letters, letter))
          {game, :incorrect_letter}
      end

    # return updated game status
    {game, feedback} = status(game)

    feedback =
      feedback
      |> Map.put(:pattern, game.pattern)
      |> Map.put(:result, result)

    {game, feedback}
  end

  def guess(%Game{} = game, {:guess_word, word}) do
    # Assert
    {_, %{code: :guessing}} = status(game)

    word = String.upcase(word)

    {game, result} =
      case game.secret do
        ^word ->
          game = %{game | pattern: word}
          {game, :correct_word}

        _ ->
          game = Kernel.put_in(game.incorrect_words, MapSet.put(game.incorrect_words, word))
          {game, :incorrect_word}
      end

    {game, feedback} = status(game)

    feedback =
      feedback
      |> Map.put(:pattern, game.pattern)
      |> Map.put(:result, result)

    {game, feedback}
  end

  @doc """
  Returns current `Game` status data and updates status code
  """

  @spec status(t) :: {t, feedback}
  def status(%Game{} = game) do
    new_code =
      cond do
        # RESET, FINISHED -> RESET
        game.state in [:reset, :finished] ->
          :reset

        # GUESSING -> WON
        game.state in [:start, :guessing] and game.secret == game.pattern ->
          :won

        # GUESSING -> LOST
        game.state == :guessing and incorrect(game) > game.max_wrong ->
          :lost

        # START, GUESSING -> GUESSING
        game.state in [:start, :guessing] and game.secret != game.pattern ->
          :guessing

        # WON, LOST, ABORT -> NEXT
        game.state in [:won, :lost, :abort] ->
          :next

        true ->
          raise HangmanError, "unmatched status cond, game is #{inspect(game)}"
      end

    case new_code do
      :next ->
        game |> next

      _ ->
        game = Kernel.put_in(game.state, new_code)
        map = build_feedback(game, new_code)

        {game, map}
    end
  end

  # Returns next game, in the process of doing so checks
  # if all games are over and if all secrets have been played against.
  # If there are indeed games left to play, 
  # updates state and transitions to next game 

  @spec next(t) :: {t, feedback}
  def next(%Game{} = game) do
    # assert that we are only called once a single game is over
    # as opposed to mid-game play
    case game.state in [:won, :lost, :abort] do
      true -> :ok
      _ -> raise HangmanError, "not supported - calling of next when single game is not over"
    end

    games_played = game.current + 1

    {game, feedback} =
      case Kernel.length(game.secrets) > games_played do
        true ->
          # Have games left to play
          # Updates game

          # stash previous result into a key previous in resultant map

          previous =
            case game.state do
              :abort -> %{}
              _ -> build_feedback(game, game.state)
            end

          # New Game Start
          game = archive_and_update(game)

          {_, text, _} = @status_codes[:start]

          {game, %{id: game.id, code: :start, text: text, previous: previous}}

        false ->
          # Otherwise we have no more games left 
          # Store the current score in the game.scores list - insert
          # And update the game

          score = score(game)
          scores = List.insert_at(game.scores, game.current, score)

          game = %{game | state: :finished, scores: scores}

          summary = build_summary(game)

          # Games Over
          {game, %{id: game.id, code: :finished, text: summary}}
      end

    {game, feedback}
  end

  # Saves result from current game, loads next game

  defp archive_and_update(%Game{} = game) do
    ### GAME ARCHIVAL - STEPS ###

    # Store the game finishing pattern into the game.patterns list - replace
    patterns = List.replace_at(game.patterns, game.current, game.pattern)

    # Store the current score in the game.scores list - insert
    scores = List.insert_at(game.scores, game.current, score(game))

    # Increment the current game index    
    # Update game
    game = %{game | patterns: patterns, scores: scores, current: game.current + 1}

    ### REFRESH UPDATE OF CURRENT GAME - STEPS ###

    # Replace the current pattern with new game's pattern
    # Replace the current secret with new game's secret
    # Reset the letter and word set counters

    # Update game
    %{
      game
      | pattern: Enum.at(game.patterns, game.current),
        secret: Enum.at(game.secrets, game.current),
        correct_letters: MapSet.new(),
        incorrect_letters: MapSet.new(),
        incorrect_words: MapSet.new(),
        state: :start
    }
  end

  # Helper function to return current game score

  @spec score(t, code | nil) :: integer | no_return
  defp score(%Game{} = game, state_code \\ nil) do
    code =
      case state_code do
        nil -> game.state
        code when code in @states -> code
        _ -> raise "Invalid state code in function score"
      end

    score =
      case code do
        # compute score if not lost and not reset
        code when code in [:guessing, :won] ->
          MapSet.size(game.incorrect_letters) + MapSet.size(game.incorrect_words) +
            MapSet.size(game.correct_letters)

        code when code in [:lost, :abort] ->
          # return default score if game lost or game_abort
          {_, _, score} = @status_codes[code]
          score

        _ ->
          raise "Shouldn't be asking for score in this state"
      end

    score
  end

  # Helper function to return current number of wrong guesses

  @spec incorrect(t) :: non_neg_integer
  defp incorrect(%Game{} = game) do
    MapSet.size(game.incorrect_letters) + MapSet.size(game.incorrect_words)
  end

  @spec build_feedback(t, code) :: feedback
  defp build_feedback(%Game{} = game, state_code) when state_code in @states do
    {_code, text, score} = @status_codes[state_code]

    score =
      if score < 0 do
        score(game, state_code)
      else
        score
      end

    case state_code do
      :reset ->
        %{id: game.id, code: state_code, text: "GAMES_RESET"}

      _ ->
        str = "#{game.pattern}; score=#{score}; status=#{text}"

        %{id: game.id, code: state_code, text: str}
    end
  end

  # Returns `game` summary as a string.  Includes `number` of games played, `average` 
  # score per game, per game `score`.

  defp build_summary(%Game{} = game) do
    total_score = Enum.reduce(game.scores, 0, &(&1 + &2))

    # count the number of game scores that have 0 e.g. game abort
    # so that we don't count them in the games played total

    {_, _, abort_score} = @status_codes[:abort]

    aborted = Enum.count(game.scores, fn x -> x == abort_score end)

    games = game.current + 1 - aborted

    avg =
      case games do
        games when games <= 0 -> 0
        _ -> total_score / games
      end

    zipped = Enum.zip(game.secrets, game.scores)

    results =
      Enum.reduce(zipped, "", fn {k, v}, acc ->
        acc <> " (#{k}: #{v})"
      end)

    "Game Over! Average Score: #{avg}, Games: #{games}, Scores: #{results}"
  end

  @doc """
  Returns `Game` information
  """

  @spec info(t) :: Keyword.t()
  def info(%Game{} = g) do
    correct_letters = MapSet.to_list(g.correct_letters)
    incorrect_letters = MapSet.to_list(g.incorrect_letters)
    incorrect_words = MapSet.to_list(g.incorrect_words)

    letters = [correct: correct_letters, incorrect: incorrect_letters]
    words = [incorrect: incorrect_words]

    info = [
      id: g.id,
      state: g.state,
      current_game_index: g.current,
      secret: g.secret,
      pattern: g.pattern,
      score: g.score,
      secrets: g.secrets,
      patterns: g.patterns,
      scores: g.scores,
      max_wrong_guesses: g.max_wrong,
      guessed_letters: letters,
      guessed_words: words
    ]

    info
  end

  # Allows users to inspect this module type in a controlled manner
  defimpl Inspect do
    import Inspect.Algebra

    def inspect(t, opts) do
      info = Inspect.List.inspect(Game.info(t), opts)
      concat(["#Game<", info, ">"])
    end
  end
end
