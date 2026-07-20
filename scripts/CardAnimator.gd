extends Node

# CardAnimator — processes event queues and plays tween-based animations.
# Events are played in FIFO order. Each animated event type gets its own
# method; unknown/skipped events advance with a minimal delay.
#
# Signals:
#   animation_started  — queue processing begins
#   animation_finished — all events processed
#
# Headless fallback: when _animation_layer is null (no GUI), fires
# animation_finished immediately after one idle frame.

signal animation_started
signal animation_finished

var _animation_layer = null
var _tween = null
var _busy = false
var _queue = []


func _ready():
	_animation_layer = _find_node_by_name(get_parent(), "CardAnimationLayer")
	if _animation_layer == null:
		var main = _find_node_by_name(get_parent(), "Main")
		if main != null:
			_animation_layer = _find_node_by_name(main, "CardAnimationLayer")
	_tween = Tween.new()
	add_child(_tween)


func _find_node_by_name(parent, name):
	if parent == null: return null
	for c in parent.get_children():
		if c.name == name: return c
	return null


func is_animating():
	return _busy


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func play_events(events, snapshot):
	if _busy:
		return
	_busy = true
	_queue = events.duplicate()
	emit_signal("animation_started")

	# Headless fallback: no GUI nodes available
	if _animation_layer == null:
		yield(get_tree(), "idle_frame")
		_finish()
		return

	_process_next()


# ---------------------------------------------------------------------------
# Queue processor
# ---------------------------------------------------------------------------

func _process_next():
	if _queue.empty():
		_finish()
		return

	var event = _queue.pop_front()
	var type = event.get("type", "")

	if type == "card_played":
		_animate_card_played(event)
	else:
		# Unknown/unimplemented event types: skip with minimal delay
		yield(get_tree().create_timer(0.03), "timeout")
		_process_next()


# ---------------------------------------------------------------------------
# Animation methods
# ---------------------------------------------------------------------------

func _animate_card_played(event):
	var card_id = event.get("card_id", "")
	var destination = event.get("destination", "discard")

	var card_node = _create_card_clone(card_id)
	if card_node == null:
		# Card not found on screen — skip this event
		yield(get_tree().create_timer(0.03), "timeout")
		_process_next()
		return

	# Determine target position
	var target_pos = _get_destination_pos(destination)

	# Animate from current position to target
	var anim_time = 0.25
	_tween.interpolate_property(card_node, "rect_position",
		card_node.rect_position, target_pos, anim_time,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.interpolate_property(card_node, "modulate",
		Color(1, 1, 1, 1), Color(1, 1, 1, 0), anim_time,
		Tween.TRANS_LINEAR, Tween.EASE_IN)
	_tween.start()
	yield(_tween, "tween_all_completed")

	card_node.queue_free()
	yield(get_tree().create_timer(0.02), "timeout")
	_process_next()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _create_card_clone(card_id):
	"""Find a CardFace in the hand by card_id and clone its texture for animation."""
	# Walk up to find the HandPresenter
	var main = _find_node_by_name(get_parent(), "Main")
	if main == null:
		main = get_node("/root/Main")
		if main == null:
			return null

	var ga = _find_node_by_name(main, "GameArea")
	if ga == null:
		return null
	var la = _find_node_by_name(ga, "LocalPlayerArea")
	if la == null:
		return null
	var ph = _find_node_by_name(la, "PlayerHand")
	if ph == null:
		return null
	var cards_layer = _find_node_by_name(ph, "CardsLayer")
	if cards_layer == null:
		return null

	for c in cards_layer.get_children():
		# CardFace has card_id property set by set_card()
		if c.has_method("get_card_id") and c.card_id == card_id:
			var clone = TextureRect.new()
			clone.texture = c.texture
			clone.rect_position = c.rect_global_position
			clone.rect_size = c.rect_size
			_animation_layer.add_child(clone)
			return clone

	return null


func _get_destination_pos(destination):
	"""Calculate the on-screen target for the animation."""
	var main = _find_node_by_name(get_parent(), "Main")
	if main == null:
		main = get_node("/root/Main")
		if main == null:
			return Vector2(960, 400)

	var ga = _find_node_by_name(main, "GameArea")
	if ga == null:
		return Vector2(960, 400)
	var board = _find_node_by_name(ga, "BoardArea")
	if board == null:
		return Vector2(960, 400)

	if destination == "plateau":
		var plateau = _find_node_by_name(board, "PlateauZone")
		if plateau != null:
			return plateau.rect_global_position + Vector2(plateau.rect_size.x / 2, plateau.rect_size.y / 2)

	# Discard pile (default)
	var discard = _find_node_by_name(board, "DiscardPile")
	if discard != null:
		return discard.rect_global_position + Vector2(discard.rect_size.x / 2, discard.rect_size.y / 2)

	return Vector2(960, 400)


func _finish():
	_busy = false
	_queue.clear()
	emit_signal("animation_finished")
