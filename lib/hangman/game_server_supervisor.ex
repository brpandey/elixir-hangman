defmodule Hangman.Game.Server.Supervisor do
	use Supervisor

  require Logger

	#Hangman.Server.Supervisor is a first line supervisor
	#which will dynamically start its children

	def start_link do
		Logger.info "Starting Hangman Game Server Supervisor"

		Supervisor.start_link(__MODULE__, nil, name: :hangman_game_server_supervisor)
	end

	def start_child(player, secret) do	
		Supervisor.start_child(:hangman_game_server_supervisor, [player, secret])
	end

	def init(_) do

		children = [
			worker(Hangman.Game.Server, []) 
		]

		#:simple_one_for_one to indicate that 
		#we're starting children dynamically 
		supervise( children, strategy: :simple_one_for_one )
	end
end