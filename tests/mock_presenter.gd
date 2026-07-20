extends Node

# Mock presenter for testing GameController.
# Tracks the last snapshot received via apply_snapshot().
# Includes signals and methods for Steps 2 + 3.

signal card_selected(card_id)
signal play_pressed
signal change_pressed
signal cancel_pressed

var last_snapshot = null
var last_selected = null
var cleared_count = 0
var last_tip = ""


func apply_snapshot(s):
	last_snapshot = s


func set_selected(card_id):
	last_selected = card_id


func clear_selection():
	cleared_count += 1
	last_selected = null


func get_selected_card_id():
	return last_selected


func show_tip(msg):
	last_tip = msg
