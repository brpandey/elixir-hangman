defmodule Hangman.Player.Worker.Supervisor do
  @moduledoc false

  '''
  Module implements supervisor functionality, overseeing
  dynamically started player workers.

  Player workers are dynamically started with player_id,
  player_type, display, and game_pid parameters

  Restart strategy is transient.  So unless the shutdown
  is abnormal (E.g. word not in dictionary) the player is not restarted.

  Hangman.Player.Worker.Supervisor is a first line supervisor
  which will dynamically start its children
  '''

  use Supervisor
  alias Hangman.Player
  require Logger

  @doc """
  Supervisor start and link wrapper function
  """

  @spec start_link :: Supervisor.on_start()
  def start_link() do
    _ = Logger.debug("Starting Hangman Player Worker Supervisor")

    Supervisor.start_link(__MODULE__, {}, name: :hangman_player_worker_supervisor)
  end

  @doc """
  Starts a player worker dynamically
  """

  @spec start_child(Player.id(), atom, boolean, pid) :: Supervisor.on_start_child()
  def start_child(player_id, player_type, display, game_pid) do
    Supervisor.start_child(:hangman_player_worker_supervisor, [
      {player_id, player_type, display, game_pid}
    ])
  end

  @doc """
  For each worker instantiated through start_child, 
  defines the worker specification to be supervised.

  Supervises each player worker server
  """

  @callback init(term) :: {:ok, tuple}
  def init(_) do
    children = [
      worker(Player.Worker, [], restart: :transient)
    ]

    # :simple_one_for_one to indicate that 
    # we're starting children dynamically 
    supervise(children, strategy: :simple_one_for_one)
  end
end
