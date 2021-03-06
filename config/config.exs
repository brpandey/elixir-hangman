# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :hangman, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:hangman, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info

config :hangman_game,
  # Max incorrect hangman guess chances
  max_wrong_guesses: 5,
  port: 3737,
  min_secret_length: 3,
  max_secret_length: 28,
  # 20 secs to choose for letter under human cli
  max_guess_wait: 20000,
  # 5 secs to choose for letter under human cli
  default_guess_wait: 5000,
  min_random_word_length: 5,
  max_random_word_length: 15,
  # Max randoms secrets to play against
  max_random_words: 1000,
  # Number of words to group by when processing dict
  words_container_size: 500,
  # Given words container choose 20 randoms
  random_words_per_container: 20,
  # Maximum amount of events that must be in flow 
  shard_flow_max_demand: 2,
  # 10 reduction workers
  reduction_pool_size: 10,
  # 10 words per shard
  shard_size_words: 10

config :logger, :console,
  level: :info,
  format: "\n$time $metadata[$level] $levelpad$message\n",
  metadata: [:module]

config :ex_doc, :markdown_processor, ExDoc.Markdown.Pandoc

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
