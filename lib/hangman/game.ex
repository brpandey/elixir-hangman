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
  
  require Logger

  alias Hangman.{Round, Game, Guess, Pattern}
  
  defstruct id: nil, client_pid: nil,
  current: 0, #Current game index
  secret: "", pattern: "", score: 0, state: :games_reset
  secrets: [],  patterns: [], scores: [],
  max_wrong: 0, correct_letters: MapSet.new, 
  incorrect_letters: MapSet.new, incorrect_words: MapSet.new
  
  @opaque t :: %__MODULE__{}

  @typedoc "`Game` id is String.t (currently using player's name as unique key)"
  @type id :: String.t
  
  @typedoc "`Game` status code values"
  @type code :: :games_reset | :game_start | :game_keep_guessing | 
  :game_won | :game_lost | :games_over

  @typedoc """
  `Game` summary values, either [] if we are still playing or [...] if game finished
  """
  @type summary :: [] | [status: :games_over, average_score: integer, 
     games: pos_integer, results: [tuple]]

  @typedoc "returned `Game` feedback data"

  @type feedback :: %{id: String.t, code: code, summary: summary, 
                      optional(:text :: :atom) => String.t, 
                      optional(:pattern :: :atom) => String.t,
                      optional(:result :: :atom) => :atom}

  @typedoc "Game result tuple returned to `Game.Server`"
  @type result :: {t, feedback}

  @status_codes  %{
    game_won: {:game_won, 'GAME_WON', -2}, 
    game_lost: {:game_lost, 'GAME_LOST', 25}, 
    game_keep_guessing: {:game_keep_guessing, 'GAME_KEEP_GUESSING', -1},
    games_reset: {:games_reset, 'GAME_RESET', 0}
  }
  
  @mystery_letter "-"

  @states [:games_reset, :game_start, :game_keep_guessing, 
           :game_won, :game_lost, :games_over]
  
  # Returns module attribute constant
  @spec mystery_letter :: String.t
  def mystery_letter, do: @mystery_letter
  
  
  @doc """
  Loads a new `Game` state given new `secret(s)`
  """
  
  @spec load(id, String.t | [String.t], pos_integer) :: t
  def load(id_key, secret, max_wrong)
  when is_binary(id_key) and is_binary(secret) do
    pattern = String.duplicate(@mystery_letter, String.length(secret))
    
    %Game{id: id_key, secret: String.upcase(secret), 
          pattern: pattern, max_wrong: max_wrong}
  end
  
  def load(id_key, secrets, max_wrong) when is_list(secrets) do
    #initialize the list of secrets to be uppercase 
    #initialize the list of patterns to fit the secrets length
    secrets = Enum.map(secrets, &String.upcase(&1))    
    patterns = Enum.map(secrets, &String.duplicate(@mystery_letter, 
                                                   String.length(&1)))
    
    %Game{id: id_key, secret: List.first(secrets), 
          pattern: List.first(patterns), secrets: secrets, 
          patterns: patterns, max_wrong: max_wrong}
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

  @spec guess(t, guess :: Guess.t) :: result
  def guess(%Game{} = game, {:guess_letter, letter}) do
    
    # assert we can guess :)
    {_, %{code: :game_keep_guessing}} = status(game) # Assert
    
    letter = letter |> String.upcase

    result = 
      case String.contains?(game.secret, letter) do 
          true -> 
          
          # letter found within secret, update pattern and game
            pattern = Pattern.update(game.pattern, game.secret, letter)
            game = Kernel.put_in(game.correct_letters,
                               MapSet.put(game.correct_letters, letter))
            game = Kernel.put_in(game.pattern, pattern)
            :correct_letter
        
          false -> #default: letter not found
            game = Kernel.put_in(game.incorrect_letters, 
                                 MapSet.put(game.incorrect_letters, letter))        
          :incorrect_letter
      end
    
    #return updated game status
    {game, feedback} = status(game)
    
    feedback = feedback 
    |> Map.put(:pattern, game.pattern) 
    |> Map.put(:result, result)
    
    {game, feedback}
  end
  
  
  def guess(%Game{} = game, {:guess_word, word}) do
    {_, %{code: :game_keep_guessing}} = status(game) # Assert
    
    word = String.upcase(word)
    
    result = 
      case game.secret do
        word -> 
          game = %{ game | pattern: word }        
          :correct_word
        _ -> 
          game = Kernel.put_in(game.incorrect_words, 
                               MapSet.put(game.incorrect_words, word))
          :incorrect_word
      end
    
    {game, feedback} = status(game)

    feedback = feedback 
    |> Map.put(:pattern, game.pattern) 
    |> Map.put(:result, result)

    {game, feedback}
  end
  

  defp status_helper(%Game{} = game, state) when state in @states do
    {code, text, score} = @status_codes[state]        

    if score < 0, do: score = score(game)

    augmented_text = "#{game.pattern}; score=#{score}; status=#{text}"
    feedback = %{id: game.id, code: game.state, text: augmented_text, summary: []}

    {game, feedback}
  end

  @doc """
  Returns current `Game` status data and updates status code
  """
  
  @spec status(t) :: {id, code, String.t}
  def status(%Game{} = game) do

    new_code = cond do
      # GAMES_RESET, GAMES_OVER -> GAMES_RESET
      game.state in [:games_reset, :games_over] -> :games_reset
      
      # GAME_KEEP_GUESSING -> GAME_WON
      game.state == :game_keep_guessing and 
      game.secret == game.pattern -> :game_won

      # GAME_KEEP_GUESSING -> GAME_LOST
      game.state == :game_keep_guessing and 
      incorrect_guesses(game) > game.max_wrong -> :game_lost

      # GAME_START, GAME_KEEP_GUESSING -> GAME_KEEP_GUESSING
      game.state in [:game_start, :game_keep_guessing] and 
      game.secret != game.pattern -> :game_keep_guessing

      # GAME_WON, GAME_LOST -> GAME_START, GAMES_OVER (check if games left)
      game.state in [:game_won, :game_lost] -> :next_game
    end

    case new_code do
      :next_game ->
        # This returns a tuple with a map 
        # containing either GAME START or GAMES OVER
        {game, map} = next(game) 

      _ ->
        game = Kernel.put_in(game.state, new_code)
        {game, map} = status_helper(game, new_code)
    end


    {game, map}
  end
  


  # Helper function to return current number of wrong guesses
  
  @spec incorrect_guesses(t) :: non_neg_integer
  defp incorrect_guesses(%Game{} = game) do
    Set.size(game.incorrect_letters) + 
    Set.size(game.incorrect_words)
  end
  
  # Helper function to return current game score
  
  @spec score(code) :: integer
  defp score(code) do
    
    case code do
      # compute score if not lost and not reset
      code when code in [:game_keep_guessing, :game_won] ->
        Set.size(game.incorrect_letters) + 
        Set.size(game.incorrect_words) +
        Set.size(game.correct_letters)
      :game_lost ->
        # return default lost score if game lost
        {_, _, score} = @status_codes[:game_lost]
        score
    end    
  end
  

  @docp """
  Returns next game, in the process of doing so checks
  if all games are over and if all secrets have been played against.
  If there are indeed games left to play, 
  updates state and transitions to next game 
  """
  @spec next(t) :: {t, term}  
  defp next(%Game{} = game) do

    games_played = game.current + 1
    
    feedback = 
      case Kernel.length(game.secrets) > games_played do
        true ->   
          # Have games left to play
          # Updates game
          
          # New Game Start
          game = save_and_load(game)
          
          %{id: game.id, code: :game_start, summary: []}
        false ->
          # Otherwise we have no more games left 
          # Store the current score in the game.scores list - insert
          # And update the game
          scores = List.insert_at(game.scores, game.current, score(game))
          game = %{ game | state: :games_over, scores: score }
          summary = final_summary(game)
          
          # Games Over
          %{id: game.id, code: :games_over, summary: summary}
      end

    {game, feedback}
  end

  
  # Saves result from current game, loads next game
  
  @spec save_and_load(t) :: t
  defp save_and_load(%Game{} = game) do
    '''
    First, do game archival steps
    '''
    
    #Store the game finishing pattern into the game.patterns list - replace
    patterns = List.replace_at(game.patterns, 
                               game.current, game.pattern)
    
    #Store the current score in the game.scores list - insert
    scores = List.insert_at(game.scores, game.current, score(game))
    
    #Increment the current game index
    
    #Update game
    game = %{ game | patterns: patterns, 
              scores: scores, current: game.current + 1 }
    
    '''
    Second, do refresh of current game
    '''
    
    #Replace the current pattern with new game's pattern
    #Replace the current secret with new game's secret
    #Reset the letter and word set counters
    
    #Update game
    %{ game | pattern: Enum.at(game.patterns, game.current),
       secret: Enum.at(game.secrets, game.current),
       correct_letters: MapSet.new, 
       incorrect_letters: MapSet.new, 
       incorrect_words: MapSet.new,
       state: :game_start}
  end
  
  
  # Returns games summary status for when all games are over
  
  @spec final_summary(t) :: summary
  defp final_summary(%Game{} = game) do
    total_score = Enum.reduce(game.scores, 0, &(&1 + &2))
    games_played = game.current + 1
    average_score = total_score / games_played
    
    results = Enum.zip(game.secrets, game.scores)
    
    [status: :games_over, average_score: average_score, 
     games: games_played, results: results]
  end


  @doc """
  Returns `Game` information
  """

  @spec info(t) :: Keyword.t
  def info(%Game{} = g) do

    correct_letters = MapSet.to_list(g.correct_letters)
    incorrect_letters = MapSet.to_list(g.incorrect_letters)
    incorrect_words = MapSet.to_list(g.incorrect_words)
    
    letters = [correct: correct_letters, incorrect: incorrect_letters]
    words = [incorrect: incorrect_words]
    
    info = [
      id: g.id,
      client_pid: g.client_pid,
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
      concat ["#Game<", info, ">"]
    end
  end

end
