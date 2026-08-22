extends Node

# CardAnimator — processes event queues and plays tween-based animations.
# Events are played in FIFO order. Each animated event type gets its own
# method; unknown/skipped events advance with a minimal delay.
#
# card_played: clones the card from the correct player's hand (found by
#   player_id in the event), hides the original, animates the clone to the
#   destination (plateau or discard). The clone is in global coords on a
#   common overlay layer.
#
# card_drawn: animates a cardback from the draw pile to the drawn card's
#   position in the correct player's hand. For the local player, the target
#   CardFace is hidden and revealed on completion. For opponents, animates
#   to the hand area.
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

# Opponent seat mapping: player_id -> seat name
const OPPONENT_SEATS = {
	"player_2": "TopSeat",
	"player_3": "LeftSeat",
	"player_4": "RightSeat",
}

# Standard card dimensions (used as fallback)
const CARD_W = 80
const CARD_H = 112

# Animation timing
const PLAY_ANIM_DURATION = 0.35
const DRAW_ANIM_DURATION = 0.3
const FADE_DURATION = 0.75


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

func hide_drawn_cards(events):
	"""Pre-hide cards that will be drawn, so the snapshot doesn't show them
	before the draw animation plays. Called by GameController after apply."""
	for e in events:
		if e.get("type", "") == "card_drawn":
			var player_id = e.get("player_id", "")
			var card_id = e.get("card_id", "")
			var card = _find_card_node(player_id, card_id)
			if card != null:
				card.visible = false

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
	elif type == "card_drawn":
		_animate_card_drawn(event)
	else:
		# Unknown/unimplemented event types: skip with minimal delay
		yield(get_tree().create_timer(0.03), "timeout")
		_process_next()


# ---------------------------------------------------------------------------
# Card played animation
# ---------------------------------------------------------------------------

func _animate_card_played(event):
	var card_id = event.get("card_id", "")
	var player_id = event.get("player_id", "")
	var destination = event.get("destination", "discard")

	# Find the card in the correct player's hand
	var card_node = _find_card_node(player_id, card_id)
	if card_node == null:
		# Card not found on screen — skip this event
		yield(get_tree().create_timer(0.03), "timeout")
		_process_next()
		return

	# Create clone with the card's visual appearance in animation layer coords
	var clone = TextureRect.new()
	clone.texture = card_node.texture
	clone.expand = true
	clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clone.rect_min_size = card_node.rect_size
	clone.rect_size = card_node.rect_size
	clone.rect_position = _global_to_layer(card_node.rect_global_position)
	clone.mouse_filter = 2

	# Hide the original card BEFORE the snapshot removes it
	card_node.visible = false

	_animation_layer.add_child(clone)

	# Determine target position in animation layer coords
	var target_pos = _get_dest_pos(destination)

	# Animate from current position to target with fade-out only at the end
	var fade_delay = PLAY_ANIM_DURATION - FADE_DURATION
	_tween.interpolate_property(clone, "rect_position",
		clone.rect_position, target_pos, PLAY_ANIM_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.interpolate_property(clone, "modulate",
		Color(1, 1, 1, 1), Color(1, 1, 1, 0), FADE_DURATION,
		Tween.TRANS_LINEAR, Tween.EASE_IN, fade_delay)
	_tween.start()
	yield(_tween, "tween_all_completed")

	clone.queue_free()
	yield(get_tree().create_timer(0.02), "timeout")
	_process_next()


# ---------------------------------------------------------------------------
# Card drawn animation
# ---------------------------------------------------------------------------

func _animate_card_drawn(event):
	var player_id = event.get("player_id", "")
	var card_id = event.get("card_id", "")

	# Safety: if headless, skip with minimal delay
	if _animation_layer == null:
		yield(get_tree().create_timer(0.03), "timeout")
		_process_next()
		return

	# Start position: draw pile center in animation layer coords
	var start_pos = _get_draw_pile_pos()

	# End position: the drawn card's position in the player's hand.
	# The snapshot has already been applied, so we search the post-snapshot UI.
	var end_card = _find_card_node(player_id, card_id)
	var end_pos = start_pos  # fallback

	if end_card != null:
		end_pos = _global_to_layer(end_card.rect_global_position)
		# Hide the target card so it's revealed by the animation
		end_card.visible = false
	elif card_id == "":
		# For opponent cards with no card_id, use the hand layer center
		var hand_center = _get_hand_center(player_id)
		if hand_center != null:
			end_pos = hand_center

	# Create a cardback clone — independent from any previous animation state.
	var clone = TextureRect.new()
	clone.texture = load("res://imgs/cardback.png")
	clone.expand = true
	clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clone.rect_min_size = Vector2(CARD_W, CARD_H)
	clone.rect_size = Vector2(CARD_W, CARD_H)
	# Start position: draw pile center. Set BEFORE adding to layer so the
	# tween's initial value is captured correctly.
	clone.rect_position = start_pos
	clone.mouse_filter = 2
	_animation_layer.add_child(clone)

	# Animate from pile to hand
	_tween.interpolate_property(clone, "rect_position",
		start_pos, end_pos, DRAW_ANIM_DURATION,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.interpolate_property(clone, "modulate",
		Color(1, 1, 1, 1), Color(1, 1, 1, 1), DRAW_ANIM_DURATION,
		Tween.TRANS_LINEAR, Tween.EASE_IN)
	_tween.start()
	yield(_tween, "tween_all_completed")

	clone.queue_free()

	# Reveal the hidden card (if any)
	if end_card != null:
		if is_instance_valid(end_card):
			end_card.visible = true

	yield(get_tree().create_timer(0.02), "timeout")
	_process_next()


# ---------------------------------------------------------------------------
# Card node finding by player_id
# ---------------------------------------------------------------------------

func _find_card_node(player_id, card_id):
	var main = _get_main_node()
	if main == null:
		return null

	if player_id == "player_1":
		return _find_local_card(main, card_id)
	else:
		return _find_opponent_card(main, player_id, card_id)


func _find_local_card(main, card_id):
	var ga = _find_node_by_name(main, "GameArea")
	if ga == null: return null
	var la = _find_node_by_name(ga, "LocalPlayerArea")
	if la == null: return null
	var ph = _find_node_by_name(la, "PlayerHand")
	if ph == null: return null
	var cards_layer = _find_node_by_name(ph, "CardsLayer")
	if cards_layer == null: return null

	# Match by card_id (local cards have card_id set by set_card)
	if card_id != "":
		for c in cards_layer.get_children():
			if c.card_id == card_id:
				return c

	# Fallback: return any CardFace from the hand (for card_drawn when card_id
	# matches  but the node was recreated by the snapshot with the same card_id)
	for c in cards_layer.get_children():
		if c.card_id == card_id:
			return c
		# Also return any CardFace node
		if c.has_method("set_card"):
			return c

	return null


func _find_opponent_card(main, player_id, card_id):
	var seat_name = OPPONENT_SEATS.get(player_id, "")
	if seat_name == "":
		return null
	var ga = _find_node_by_name(main, "GameArea")
	if ga == null: return null
	var ol = _find_node_by_name(ga, "OpponentsLayer")
	if ol == null: return null
	var seat = _find_node_by_name(ol, seat_name)
	if seat == null: return null
	var cards_layer = _find_node_by_name(seat, "CardsLayer")
	if cards_layer == null: return null

	# Opponent cards all have card_id="" (set_card_back), so matching by
	# card_id is not possible. Return the rightmost card (newest position)
	# as a reasonable approximation.
	var rightmost = null
	var max_x = -99999.0
	for c in cards_layer.get_children():
		if c.rect_position.x > max_x:
			max_x = c.rect_position.x
			rightmost = c
	# Also check if any card happens to have a matching non-empty card_id
	if card_id != "":
		for c in cards_layer.get_children():
			if c.card_id == card_id:
				return c
	return rightmost


# ---------------------------------------------------------------------------
# Position helpers
# ---------------------------------------------------------------------------

func _global_to_layer(global_pos):
	"""Convert a global screen position to animation-layer local coordinates.

	CardAnimationLayer is a fullscreen Control at Main origin (0, 0).
	In Godot 3, Control has no to_local() / to_global() (Node2D only).
	Since the layer spans the full screen at the root, global = local."""
	return global_pos


func _get_dest_pos(destination):
	"""Return the animation-layer position for a destination zone."""
	var main = _get_main_node()
	if main == null:
		return Vector2(960, 400)

	var ga = _find_node_by_name(main, "GameArea")
	if ga == null: return Vector2(960, 400)
	var ba = _find_node_by_name(ga, "BoardArea")
	if ba == null: return Vector2(960, 400)

	if destination == "plateau":
		var pz = _find_node_by_name(ba, "PlateauZone")
		if pz != null:
			var center = pz.rect_global_position + pz.rect_size / 2
			return _global_to_layer(center)

	# Discard pile (default)
	var dp = _find_node_by_name(ba, "DiscardPile")
	if dp != null:
		var center = dp.rect_global_position + dp.rect_size / 2
		return _global_to_layer(center)

	return Vector2(960, 400)


func _get_draw_pile_pos():
	"""Return the draw pile center in animation-layer coordinates."""
	var main = _get_main_node()
	if main == null:
		return Vector2(960, 400)

	var ga = _find_node_by_name(main, "GameArea")
	if ga == null: return Vector2(960, 400)
	var ba = _find_node_by_name(ga, "BoardArea")
	if ba == null: return Vector2(960, 400)
	var dp = _find_node_by_name(ba, "DrawPile")
	# Belt-and-suspenders: verify the node is "DrawPile" by checking its name,
	# not just the search string. Prevents confusion if BoardArea children
	# were somehow reordered or renamed.
	if dp == null or dp.name != "DrawPile":
		return Vector2(960, 400)

	var center = dp.rect_global_position + dp.rect_size / 2
	return _global_to_layer(center)


func _get_hand_center(player_id):
	"""Return the approximate hand/seat center for a player, in layer coords."""
	var main = _get_main_node()
	if main == null:
		return null
	var ga = _find_node_by_name(main, "GameArea")
	if ga == null: return null

	if player_id == "player_1":
		var la = _find_node_by_name(ga, "LocalPlayerArea")
		if la == null: return null
		var ph = _find_node_by_name(la, "PlayerHand")
		if ph == null: return null
		var center = ph.rect_global_position + ph.rect_size / 2
		return _global_to_layer(center)
	else:
		var seat_name = OPPONENT_SEATS.get(player_id, "")
		if seat_name == "": return null
		var ol = _find_node_by_name(ga, "OpponentsLayer")
		if ol == null: return null
		var seat = _find_node_by_name(ol, seat_name)
		if seat == null: return null
		var center = seat.rect_global_position + seat.rect_size / 2
		return _global_to_layer(center)


func _get_main_node():
	var p = get_parent()
	if p != null and p.name == "Main":
		return p
	var main = _find_node_by_name(p, "Main")
	if main == null:
		main = get_node("/root/Main")
	return main


# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------

func _finish():
	_busy = false
	_queue.clear()
	emit_signal("animation_finished")
