defmodule Player.Game do
  @moduledoc """
  Module handles game playing for synchronous `human` and `robot`
  player types. Handles relationship between 
  `Player.FSM`, `Game.Server` and `Player.Events`

  Loads up the `player` specific `game` components: 
  a dynamic `game` server, and a dynamic `event` server

  Manages specific `player` fsm behaviour (`human` or `robot`).
  Wraps fsm game play into an enumerable for easy running.
  """


  @human Player.human
  @robot Player.robot

  @doc """
  Function run connects all the `player` specific components together 
  and runs the player `game`
  """

  @spec run0(String.t, Player.kind, [String.t], boolean, boolean) :: :ok
  def run0(name, type, secrets, log, display) when is_binary(name)
  and is_atom(type) and is_list(secrets) and is_binary(hd(secrets)) 
  and is_boolean(log) and is_boolean(display) do

    fn_display = fn
      _, true -> 
        # if display arg is true then don't print out round status again
        "" 
      text, false -> 
        IO.puts("\n#{text}")
    end
    
    name 
    |> setup(secrets, log, display)
		|> rounds_handler(type)
		|> Stream.each(&fn_display.(&1, display))
		|> Stream.run
    
  end

  # for Web playing
  @spec run(String.t, Player.kind, [String.t], boolean, boolean) :: :ok
  def run(name, type, secrets, log, _display) when is_binary(name)
  and is_atom(type) and is_list(secrets) and is_binary(hd(secrets)) 
  and is_boolean(log) do
    
    l = List.new

    name 
    |> setup(secrets, log, false)
		|> rounds_handler(type)
		|> Stream.into(l)
		|> Stream.run
    
    IO.puts "web run list is: #{inspect l}"
  end

  
  @doc "Start dynamic `player` child `worker`"
  
  @spec start_player(String.t, Player.kind, pid, pid) :: Supervisor.on_start_child
  def start_player(name, type, game_pid, notify_pid) do
    Player.Supervisor.start_child(name, type, game_pid, notify_pid)
  end
  
  @doc """
  Function setup loads the `player` specific `game` components.
  Setups the `game` server and per player `event` server.
  """
  
  @spec setup(String.t, [String.t], boolean, boolean) :: tuple
  def setup(name, secrets, log, display) when is_binary(name) and
  is_list(secrets) and is_binary(hd(secrets)) and 
  is_boolean(log) and is_boolean(display) do
    
    # Grab game pid first from game pid cache
	  game_pid = Game.Pid.Cache.get_server_pid(name, secrets)
    
    # Get event server pid next
    {:ok, notify_pid} = 
      Player.Events.Supervisor.start_child(log, display)

    {name, game_pid, notify_pid}
  end


  @doc """
  Permits `robot` or `human` round playing!
  Wraps the `robot` or `human` player game playing in a stream.
  Stream resource returns an enumerable.

  Terminates player `events` server and `fsm` upon finish
  """

  @spec rounds_handler(tuple, Player.kind) :: Enumerable.t

  # Robot round playing!

	def rounds_handler({name, game_pid, notify_pid}, 
                       @robot) do

		Stream.resource(
			fn -> 
        # Dynamically start hangman player
        {:ok, ppid} = start_player(name, @robot, game_pid, notify_pid)
        ppid
				end,

			fn ppid ->
				case Player.FSM.wall_e_guess(ppid) do
					{:game_reset, reply} -> 
            IO.puts "\n#{reply}"
            {:halt, ppid}
          
					# All other game states :game_keep_guessing ... :games_over
					{_, reply} -> {[reply], ppid}							
				end
        
			end,
			
			fn ppid -> 
        # Be a good functional citizen and cleanup server resources
        Player.Events.stop(notify_pid)
        Player.FSM.stop(ppid) 
      end
		)
	end

  # Human round playing!

	def rounds_handler({name, game_pid, notify_pid}, @human) do

    # Wrap the player fsm game play in a stream
    # Stream resource returns an enumerable

		Stream.resource(
			fn -> 
        # Dynamically start hangman player
        {:ok, ppid} = start_player(name, @human, game_pid, notify_pid)
        {ppid, []}
				end,

			fn {ppid, code} ->

        case code do
          [] -> 
            {code, reply} = Player.FSM.socrates_proceed(ppid)
            {[reply], {ppid, code}}

          :game_choose_letter ->
            choice = IO.gets("[Please input letter choice] ")
            letter = String.strip(choice)
            {code, reply} = Player.FSM.socrates_guess(ppid, letter)

				    case {code, reply} do
					    {:game_reset, reply} -> 
                IO.puts "\n#{reply}"
                {:halt, ppid}
              _ -> {[reply], {ppid, code}}
            end
          
          :game_last_word ->
            {code, reply} = Player.FSM.socrates_win(ppid)

				    case {code, reply} do
					    {:game_reset, reply} -> 
                IO.puts "\n#{reply}"
                {:halt, ppid}
              _ -> {[reply], {ppid, code}}
            end

          :game_won -> 
            {code, reply} = Player.FSM.socrates_proceed(ppid)
            {[reply], {ppid, code}}

          :game_lost -> 
            {code, reply} = Player.FSM.socrates_proceed(ppid)
            {[reply], {ppid, code}}          

          :games_over -> 
            {:halt, ppid}

            #:games_over

				end
			end,
			
                    
			fn ppid -> 
        # Be a good functional citizen and cleanup server resources
        Player.Events.stop(notify_pid)
        Player.FSM.stop(ppid) 
      end
		)
	end

end
