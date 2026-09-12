extends Node

# Mock CardAnimator for testing cancellation behavior.

var _busy = false
var cancel_called = false


func is_animating():
	return _busy


func cancel():
	"""Simulate cancel() — sets busy to false and records the call."""
	cancel_called = true
	_busy = false


func play_events(events, snapshot):
	pass
