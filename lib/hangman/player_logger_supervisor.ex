defmodule Hangman.Player.Logger.Supervisor do
  use Supervisor

  alias Hangman.{Player}

  @moduledoc false

  '''
  Module implements supervisor functionality overseeing 
  dynamically started player events servers

  Player events server processes are started with 
  both log and display options off
  '''

  require Logger

  @name __MODULE__

  @doc """
  Supervisor start and link wrapper function
  """

  @spec start_link :: Supervisor.on_start
  def start_link do
    Logger.info "Starting Hangman Player Logger Supervisor"
    Supervisor.start_link(@name, {}, name: :player_logger_supervisor)
  end

  @doc """
  Starts a player events worker dynamically
  """

  @spec start_child(String.t) :: Supervisor.on_start_child
  def start_child(id) when is_binary(id) do
    options = [id: id]
    Supervisor.start_child(:player_logger_supervisor, [options])
  end
  
  @doc """
  For each worker instantiated through start_child, 
  defines the worker specification to be supervised.

  Supervises each player events server
  """
  
  @callback init(term) :: {:ok, tuple}
  def init(_) do
    # define single child specification 
    # since we are starting children dynamically

    children = [
      worker(Player.Logger.Handler, [], restart: :transient)
    ]

    # :one_for_one to indicate that 
    # we're starting children dynamically but children not of same type

    supervise( children, strategy: :simple_one_for_one )
  end
  
end