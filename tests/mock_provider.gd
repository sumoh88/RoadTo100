extends "res://engine/GameStateProvider.gd"

# Mock provider for testing GameController.
# Extends the GameStateProvider contract and allows tests to control
# when signals are emitted and what data they carry.

var auto_emit_game_started = true
var auto_emit_action_completed = true
var auto_emit_action_rejected = false
var snapshot_to_emit = null
var result_to_emit = null
var rejection_message = ""

var start_game_called = false
var last_start_game_count = 0
var send_action_called = false
var last_send_action_dict = null


func start_game(player_count):
	start_game_called = true
	last_start_game_count = player_count
	if auto_emit_game_started:
		if snapshot_to_emit == null:
			snapshot_to_emit = _default_snapshot(player_count)
		emit_signal("game_started", snapshot_to_emit)


func send_action(action_dict):
	send_action_called = true
	last_send_action_dict = action_dict
	if auto_emit_action_rejected:
		emit_signal("action_rejected", rejection_message)
	elif auto_emit_action_completed:
		if result_to_emit == null:
			result_to_emit = _default_result()
		emit_signal("action_completed", result_to_emit)


func reset():
	start_game_called = false
	last_start_game_count = 0
	send_action_called = false
	last_send_action_dict = null


func _default_snapshot(player_count):
	var players = []
	for i in range(player_count):
		players.append({
			"id": "player_" + str(i + 1),
			"name": "Player " + str(i + 1),
			"hand_count": 3,
			"hand": [],
		})
	return {
		"players": players,
		"current_player_index": 0,
		"piatto": 0,
		"deck_count": 60 - player_count * 3,
		"discard_top": null,
		"plateau_cards": [],
		"plateau_visual_stack": [{"type": "plate", "value": 0}],
		"advantage_turn": false,
		"advantage_player_id": null,
		"winner": null,
		"turn_number": 0,
		"available_actions": [],
		"phase": "playing",
		"local_player_id": "player_1",
	}


func _default_result():
	return {
		"snapshot": _default_snapshot(2),
		"events": [],
	}
