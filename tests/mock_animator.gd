extends Node

# Mock CardAnimator for testing GameController animation flow.
# Controllable: play_events only stores events; finish_animation emits signal.
# No yield, no auto-emit — test controls when animation_finished fires.

signal animation_finished

var events_received = []
var animating = false


func play_events(events, snapshot):
	events_received = events.duplicate()
	animating = true


func finish_animation():
	animating = false
	emit_signal("animation_finished")


func is_animating():
	return animating
