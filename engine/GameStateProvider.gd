extends Node

# Abstract base class for game state providers.
# Defines the contract between GameController and any source of authoritative
# game state — local (LocalGameEngine) or remote (future RemoteGameAdapter).
#
# Signals:
#   game_started(snapshot)     — emitted after start_game()
#   action_completed(result)   — emitted after send_action() succeeds
#   action_rejected(error_msg) — emitted when send_action() fails validation
#   state_updated(snapshot)    — reserved for future networking (remote updates)
#   connection_lost()          — reserved for future networking
#
# Methods (override in subclass):
#   start_game(player_count)   — initialize a new game
#   send_action(action_dict)   — process a player action

signal game_started(snapshot)
signal action_completed(result)
signal action_rejected(error_message)
signal state_updated(snapshot)
signal connection_lost()

func start_game(player_count):
	"""Initialize a new game. Override in subclass."""
	pass

func send_action(action_dict):
	"""Process a player action. Override in subclass."""
	pass
