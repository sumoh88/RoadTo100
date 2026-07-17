extends Reference
class_name GameState

# Mirrors simulator/domain/game.py
# Mutable game state containing players, deck, discard, turn info, etc.

var players = []      # Array of PlayerData
var deck = null
var discard_pile = [] # Array of CardData
var current_player_index = null  # int or null
var turn_number = 0
# Use literal 0 for GamePhase.SETUP to avoid class_name parse-time dep
var phase = 0  # GameConstants.GamePhase.SETUP
var winner = null     # PlayerData or null
var metadata = {}

func _init(p_players = [], p_deck = null, p_discard = [],
		   p_current_player_index = null, p_turn_number = 0,
		   p_phase = 0, p_winner = null, p_metadata = {}):
	players = p_players.duplicate()
	if p_deck != null:
		deck = p_deck
	else:
		deck = (load("res://engine/Deck.gd") as Script).new()
	discard_pile = p_discard.duplicate()
	current_player_index = p_current_player_index
	turn_number = p_turn_number
	phase = p_phase
	winner = p_winner
	metadata = p_metadata.duplicate()

func add_player(player):
	players.append(player)

func add_players(new_players):
	for p in new_players:
		players.append(p)

func current_player():
	if current_player_index == null:
		return null
	if current_player_index < 0 or current_player_index >= players.size():
		return null
	return players[current_player_index]

func set_current_player(player):
	if player == null:
		current_player_index = null
		return
	for i in range(players.size()):
		if players[i].player_id == player.player_id:
			current_player_index = i
			return

func set_winner(player):
	winner = player

func set_phase(new_phase):
	phase = new_phase
