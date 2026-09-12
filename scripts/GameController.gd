extends Node

# GameController — central orchestrator for the game UI.
# Manages interface states, coordinates presenters, and drives
# the GameStateProvider.
#
# Signals:
#   action_applied(result) — fired after each completed action (for debug/demo)

onready var main = get_tree().current_scene
onready var valueLabel = main.get_node("GameArea/BoardArea/PlateauZone/ValueLabel")
onready var ResolvedValueLabel = main.get_node("GameArea/BoardArea/DiscardPile/TopCard/ResolvedValueLabel")
signal action_applied(result)
#
# States (in order of progression):
#   WAITING_FOR_STATE  — initial, no game loaded
#   READY_FOR_INPUT    — waiting for player action
#   CARD_SELECTED      — a card is selected, awaiting action type
#   WAITING_FOR_CHOICE — popup open (Jolly/Imbroglio/Gold Reveal)
#   ACTION_PENDING     — action sent to provider, awaiting result
#   ANIMATING          — animations in progress
#   INPUT_LOCKED       — explicit input block
#   GAME_OVER          — game has a winner
enum State {
	WAITING_FOR_STATE,
	READY_FOR_INPUT,
	CARD_SELECTED,
	WAITING_FOR_CHOICE,
	ACTION_PENDING,
	ANIMATING,
	INPUT_LOCKED,
	GAME_OVER,
}

# Provider
var _provider = null
var _LocalGameEngine = load("res://engine/LocalGameEngine.gd")

# Presenter references
var _board = null
var _hand = null
var _turn = null
var _card_animator = null

# Popup references
var _value_choice_popup = null
var _value_choice_label = null
var _value_btn_grid = null
var _value_cancel_btn = null
var _hand_reset_popup = null
var _hand_reset_yes_btn = null
var _hand_reset_no_btn = null

# Full-screen blocker shown while a choice popup is open so that clicking
# outside the popup neither closes it nor reaches the underlying UI.
var _choice_input_blocker = null

# Internal state
var _state = State.WAITING_FOR_STATE
var _last_snapshot = null
var _last_events = []
var _last_error = ""

# Card selection
var _selected_card_id = ""

# Deal animation tracking
var _deal_active = false
var _deal_tween = null
var _deal_clones = []

# Game generation ID — incremented on each start_game() to invalidate
# stale async operations (deal yields, CardAnimator callbacks, timers).
var _game_generation = 0

# True when we're waiting for a CardAnimator to finish. Used to ignore
# stale animation_finished callbacks from cancelled/old animations.
var _expecting_animation_finish = false

# Pending action (for popup-driven actions)
var _pending_action_type = ""
var _pending_card_id = ""
var _pending_valid_values = []
var _pending_blocked_type = false  # F3: true when waiting for Safe Round blocked_type choice

# F3: Safe Round card type choices
const SAFE_ROUND_CHOICES = ["Incremento", "Imbroglio", "Gold"]

# F7: +11 Gold chain (mirrors RoadTo100Rules.GOLD_CHAIN) — used only to
# decide whether a +11 play will activate a Safe Round (23-78) vs the
# Advantage Round (89). Game rules stay in the provider.
const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}


# ---------------------------------------------------------------------------
# Audio Manager reference (sibling of this node under Main)
# ---------------------------------------------------------------------------

func _get_audio_manager():
	return get_node_or_null("/root/AudioManager")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_provider(p):
	_provider = p


func get_game_generation():
	return _game_generation


func start_game(player_count):
	if _provider == null:
		print("[GC] ERROR: No provider set")
		return

	# Increment generation — invalidates all prior async operations.
	_game_generation += 1

	# Cancel any in-progress deal animation from the previous game.
	cancel_deal_animation()

	# Cancel any in-progress CardAnimator from the previous game.
	if _card_animator != null and _card_animator.has_method("cancel"):
		_card_animator.cancel()

	# Reset animation expectation so stale callbacks are ignored.
	_expecting_animation_finish = false

	_state = State.WAITING_FOR_STATE
	_last_snapshot = null
	_last_events = []
	_last_error = ""
	_selected_card_id = ""
	_provider.start_game(player_count)

	var ShuffleDeal = AudioManager.get_node("SFXPlayer/ShuffleDeal")
	AudioManager.play_sfx(ShuffleDeal)
	# Switch to dynamic game music (Piatto starts at 0, no special round)
	var am = _get_audio_manager()
	if am != null and am.has_method("set_game_music"):
		var valueLabelInt = int(valueLabel.text)
		am.set_game_music(valueLabelInt, false)


func get_state():
	return _state


func get_last_snapshot():
	return _last_snapshot


func get_selected_card_id():
	return _selected_card_id


func get_last_events():
	return _last_events


func perform_action(action_dict):
	"""Send an action directly through the provider (for debug/auto-demo use).
	Bypasses user input flow. Returns after the synchronous action cycle."""
	if _provider == null:
		print("[GC] ERROR: No provider set")
		return
	# If this action has a resolved value (Jolly/Imbroglio), propagate it to
	# GlobalsUtilities so BoardPresenter can display it on the discard pile.
	# This is necessary for CPU plays which don't go through _on_value_chosen().
	if action_dict.has("selected_value"):
		GlobalsUtilities.selected_value = str(action_dict["selected_value"])
	# Close the specific popup if this direct call resolves it (demo/CPU path)
	var at = action_dict.get("action_type", "")
	if at == "play_card" and _value_choice_popup != null and _value_choice_popup.visible:
		_value_choice_popup.hide()
	if at == "reset_hand" and _hand_reset_popup != null and _hand_reset_popup.visible:
		_hand_reset_popup.hide()
	_update_choice_blocker()
	_state = State.ACTION_PENDING
	_provider.send_action(action_dict)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready():
	_find_presenters()
	_find_popups()
	if _provider == null:
		_provider = _LocalGameEngine.new()
	_provider.connect("game_started", self, "_on_game_started")
	_provider.connect("action_completed", self, "_on_action_completed")
	_provider.connect("action_rejected", self, "_on_action_rejected")
	if valueLabel == null:
		valueLabel = Label.new()
		valueLabel.text = ""
	if ResolvedValueLabel == null:
		ResolvedValueLabel = Label.new()
		ResolvedValueLabel.text = ""

func _find_presenters():
	var main = _node_up("Main")
	if main == null:
		return
	for c in main.get_children():
		var name = c.name
		if name == "BoardPresenter":
			_board = c
		elif name == "HandPresenter":
			_hand = c
			if _hand != null and _hand.has_signal("card_selected"):
				_hand.connect("card_selected", self, "_on_card_selected")
		elif name == "TurnPresenter":
			_turn = c
			if _turn != null:
				if _turn.has_signal("play_pressed"):
					_turn.connect("play_pressed", self, "_on_play_pressed")
				if _turn.has_signal("change_pressed"):
					_turn.connect("change_pressed", self, "_on_change_pressed")
				if _turn.has_signal("cancel_pressed"):
					_turn.connect("cancel_pressed", self, "_on_cancel_pressed")
		elif name == "CardAnimator":
			_card_animator = c
			if _card_animator != null and _card_animator.has_signal("animation_finished"):
				_card_animator.connect("animation_finished", self, "_on_animation_finished")


func _find_popups():
	var main = _node_up("Main")
	if main == null:
		return
	var ol = _child(main, "OverlayLayer")
	if ol == null:
		return

	_choice_input_blocker = _child(ol, "InputBlocker")

	_value_choice_popup = _child(ol, "ValueChoicePopup")
	if _value_choice_popup != null:
		var vb = _child(_value_choice_popup, "VBox")
		if vb != null:
			_value_choice_label = _child(vb, "MsgLabel")
			_value_btn_grid = _child(vb, "BtnGrid")
			_value_cancel_btn = _child(vb, "CancelBtn")
			if _value_cancel_btn != null:
				_value_cancel_btn.connect("pressed", self, "_on_value_cancel")
		# Prevent popup from closing on outside click while waiting for choice
		_value_choice_popup.connect("popup_hide", self, "_on_value_choice_popup_hide")

	_hand_reset_popup = _child(ol, "HandResetPopup")
	if _hand_reset_popup != null:
		var vb = _child(_hand_reset_popup, "VBox")
		if vb != null:
			var br = _child(vb, "BtnRow")
			if br != null:
				_hand_reset_yes_btn = _child(br, "YesBtn")
				_hand_reset_no_btn = _child(br, "NoBtn")
				if _hand_reset_yes_btn != null:
					_hand_reset_yes_btn.connect("pressed", self, "_on_hand_reset_yes")
				if _hand_reset_no_btn != null:
					_hand_reset_no_btn.connect("pressed", self, "_on_hand_reset_no")
		# Prevent popup from closing on outside click while waiting for choice
		_hand_reset_popup.connect("popup_hide", self, "_on_hand_reset_popup_hide")


func _child(p, name):
	if p == null: return null
	for c in p.get_children():
		if c.name == name: return c
	return null


func _node_up(name):
	var p = get_parent()
	while p != null and p.name != name:
		p = p.get_parent()
	return p


func _update_choice_blocker():
	"""Show the full-screen InputBlocker while any choice popup is open, so
	clicks outside a popup are absorbed instead of closing it or reaching the
	game UI underneath."""
	if _choice_input_blocker == null:

		return
	var any_visible = false
	for p in [_value_choice_popup, _hand_reset_popup]:
		if p != null and p.visible:
			any_visible = true
			break
	_choice_input_blocker.visible = any_visible


# ---------------------------------------------------------------------------
# Card selection handler
# ---------------------------------------------------------------------------

func _on_card_selected(card_id):
	if _state == State.READY_FOR_INPUT:
		_selected_card_id = card_id
		if _hand != null and _hand.has_method("set_selected"):
			_hand.set_selected(card_id)
		_state = State.CARD_SELECTED

	elif _state == State.CARD_SELECTED:
		if card_id == _selected_card_id:
			_clear_selection()
			_state = State.READY_FOR_INPUT
		else:
			if _hand != null and _hand.has_method("clear_selection"):
				_hand.clear_selection()
			_selected_card_id = card_id
			if _hand != null and _hand.has_method("set_selected"):
				_hand.set_selected(card_id)

	# All other states: ignore click


func _clear_selection():
	_selected_card_id = ""
	if _hand != null and _hand.has_method("clear_selection"):
		_hand.clear_selection()


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_play_pressed():
	if _state == State.CARD_SELECTED and _selected_card_id != "":
		# Safe Round: a blocked card is selectable (for Cambio Carta) but not playable.
		# 89 blocked until Piatto reaches 20 or more.
		if _is_selected_card_89_not_allowed():
			if _turn != null and _turn.has_method("show_tip"):
				_turn.show_tip("Bloccata: Piatto troppo basso.")
			return
		if _is_selected_card_blocked_by_sr():
			if _turn != null and _turn.has_method("show_tip"):
				_turn.show_tip("Bloccata: Giro Sicuro")
			return
		# GdV: non-Incremento cards are not playable during Giro di Vantaggio.
		if _is_selected_card_blocked_by_gdv():
			if _turn != null and _turn.has_method("show_tip"):
				_turn.show_tip("Bloccata: Giro di Vantaggio")
			return
		var ct = _get_selected_card_type()
		if ct == "jolly" or ct == "imbroglio":
			# Show all theoretical values in the popup; only engine-validated
			# choices are enabled. The full range is always displayed so the
			# player can see which values are currently legal.
			var valid_vals = _play_values_for_selected_card()
			var all_vals = _full_value_range(ct)
			_open_value_choice(ct, all_vals, valid_vals)
			return
		elif _play_activates_safe_round():
			# F7: the Safe Round blocked_type is chosen BEFORE the activating
			# play_card is sent; the choice rides on the same single action.
			_open_safe_round_choice()
		else:
			perform_action({"action_type": "play_card", "card_id": _selected_card_id})
	elif _state == State.READY_FOR_INPUT:
		if _turn != null and _turn.has_method("show_tip"):
			_turn.show_tip("Seleziona prima una carta")


func _on_change_pressed():
	if _state == State.CARD_SELECTED and _selected_card_id != "":
		perform_action({"action_type": "change_card", "card_id": _selected_card_id})
	elif _state == State.READY_FOR_INPUT:
		if _turn != null and _turn.has_method("show_tip"):
			_turn.show_tip("Seleziona prima una carta")


func _on_cancel_pressed():
	if _state == State.CARD_SELECTED:
		_clear_selection()
		_state = State.READY_FOR_INPUT


# ---------------------------------------------------------------------------
# Value choice popup (Jolly / Imbroglio)
# ---------------------------------------------------------------------------

func _full_value_range(card_type):
	"""Return all theoretical selectable values for a card type."""
	var vals = []
	if card_type == "jolly":
		for v in range(1, 11): vals.append(v)
	elif card_type == "imbroglio":
		for v in range(-15, 0): vals.append(v)
		for v in range(1, 16): vals.append(v)
	return vals


func _play_values_for_selected_card():
	"""Collect the allowed selected_value choices for the selected card
	from the snapshot's available_actions (provider/rule-filtered)."""
	var vals = []
	if _selected_card_id == "" or _last_snapshot == null:
		return vals
	for a in _last_snapshot.get("available_actions", []):
		if str(a.get("action_type", "")) != "play_card":
			continue
		if str(a.get("card_id", "")) != _selected_card_id:
			continue
		for ch in a.get("choices", []):
			var params = ch.get("parameters", {})
			if params.has("selected_value"):
				vals.append(params["selected_value"])
	return vals


func _open_value_choice(card_name, all_values, valid_values):
	"""Open the value choice popup showing all theoretical values.
	Only values in valid_values (from engine) are enabled.
	If valid_values is empty, all buttons are disabled and a warning is logged."""
	_state = State.WAITING_FOR_CHOICE
	_pending_action_type = "play_card"
	_pending_card_id = _selected_card_id
	_pending_valid_values = valid_values
	_pending_blocked_type = false

	if valid_values.size() == 0:
		print("[GC] WARNING: No choices provided by engine for " + card_name + " — all options disabled")

	if _value_choice_label != null:
		_value_choice_label.text = "Scegli il valore per " + card_name
		GlobalsUtilities.setCustomFont(_value_choice_label, 32)

	# Clear old buttons from grid
	if _value_btn_grid != null:
		for c in _value_btn_grid.get_children():
			_value_btn_grid.remove_child(c)
			c.queue_free()

		# Add value buttons — enabled only if present in valid_values
		for v in all_values:
			var btn = Button.new()
			btn.text = str(v)
			btn.rect_min_size = Vector2(90, 90)
			GlobalsUtilities.setCustomFont(btn, 48, -3)
			GlobalsUtilities.setBtnStyle(btn)
			if not v in valid_values:
				btn.disabled = true
				btn.modulate = Color(1, 1, 1, 0.35)
			else:
				btn.connect("pressed", self, "_on_value_chosen", [v])
			_value_btn_grid.add_child(btn)

	if _value_choice_popup != null:
		_value_choice_popup.popup()
	_update_choice_blocker()


func _on_value_chosen(value):
	if _state != State.WAITING_FOR_CHOICE:
		return
	if _pending_valid_values.size() > 0 and not value in _pending_valid_values:
		return  # Invalid value — stay in WAITING_FOR_CHOICE, popup stays open
	if _value_choice_popup != null:
		_value_choice_popup.hide()
	_update_choice_blocker()
	var action = {"action_type": _pending_action_type, "card_id": _pending_card_id}
	action["selected_value"] = value
	GlobalsUtilities.selected_value = str(value)
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	perform_action(action)


func _on_value_cancel():
	if _value_choice_popup != null:
		_value_choice_popup.hide()
	_update_choice_blocker()
	if _state != State.WAITING_FOR_CHOICE:
		return
	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	_pending_blocked_type = false
	_state = State.CARD_SELECTED


func _on_value_choice_popup_hide():
	"""Prevent ValueChoicePopup from closing on outside click while waiting for choice.
	
	If the state is still WAITING_FOR_CHOICE, immediately re-show the popup to
	prevent a hardlock where the game waits for a choice but no popup is visible.
	"""
	if _state == State.WAITING_FOR_CHOICE and _value_choice_popup != null:
		call_deferred("re_popup_value_choice")


func re_popup_value_choice():
	if _state == State.WAITING_FOR_CHOICE and _value_choice_popup != null:
		_value_choice_popup.popup()
	_update_choice_blocker()


# ---------------------------------------------------------------------------
# Hand Reset popup (GdV: non-advantage player has no playable Orange cards)
# ---------------------------------------------------------------------------

func _check_reset_hand(snapshot):
	"""Open HandResetPopup ONLY during GdV for the local non-advantage player
	who has no playable Incremento cards."""
	if snapshot == null:
		return
	if _state == State.WAITING_FOR_CHOICE or _state == State.ACTION_PENDING or _state == State.GAME_OVER:
		return
	# Only during Giro di Vantaggio (never during Safe Round)
	var sr_type = str(snapshot.get("special_round_type", ""))
	if sr_type != "advantage":
		return
	# Only if it's the local player's turn
	var cur_idx = snapshot.get("current_player_index", -1)
	var players = snapshot.get("players", [])
	if cur_idx < 0 or cur_idx >= players.size():
		return
	var cur_pid = players[cur_idx].get("id", "")
	if cur_pid != snapshot.get("local_player_id", "player_1"):
		return
	# Only for non-advantage player
	var adv_pid = snapshot.get("special_round_player_id", null)
	if cur_pid == adv_pid:
		return
	# Check available_actions: reset_hand present, no play_card
	var acts = snapshot.get("available_actions", [])
	var has_reset = false
	var has_play = false
	for a in acts:
		var at = str(a.get("action_type", ""))
		if at == "reset_hand":
			has_reset = true
		elif at == "play_card":
			has_play = true
	if has_reset and not has_play:
		_state = State.WAITING_FOR_CHOICE
		if _hand_reset_popup != null:
			_hand_reset_popup.popup()
	_update_choice_blocker()


func _on_hand_reset_yes():
	if _hand_reset_popup != null:
		_hand_reset_popup.hide()
	_update_choice_blocker()
	if _state != State.WAITING_FOR_CHOICE:
		return
	perform_action({"action_type": "reset_hand"})


func _on_hand_reset_no():
	if _hand_reset_popup != null:
		_hand_reset_popup.hide()
	_update_choice_blocker()
	if _state != State.WAITING_FOR_CHOICE:
		return

	# Player can now choose change_card instead (it's already in available_actions)
	_state = State.READY_FOR_INPUT


func _on_hand_reset_popup_hide():
	"""Prevent HandResetPopup from closing on outside click while waiting for choice.
	
	If the state is still WAITING_FOR_CHOICE, immediately re-show the popup to
	prevent a hardlock where the game waits for a choice but no popup is visible.
	"""
	if _state == State.WAITING_FOR_CHOICE and _hand_reset_popup != null:
		call_deferred("re_popup_hand_reset")


func re_popup_hand_reset():
	if _state == State.WAITING_FOR_CHOICE and _hand_reset_popup != null:
		_hand_reset_popup.popup()
	_update_choice_blocker()


# ---------------------------------------------------------------------------
# Provider signal handlers
# ---------------------------------------------------------------------------

func _on_game_started(snapshot):
	# Cancel any in-progress deal animation from a previous game.
	cancel_deal_animation()

	_last_snapshot = snapshot
	_clear_selection()
	if snapshot.get("winner", null) != null:
		_apply_snapshot(snapshot)
		_state = State.GAME_OVER
		GlobalsUtilities.gameStarted = false
	else:
		_animate_initial_deal(snapshot)


func cancel_deal_animation():
	"""Abort an in-progress deal and clean up all temporary nodes."""
	if not _deal_active:
		return
	_deal_active = false

	# Remove the tween (queue_free is sufficient in Godot 3.4).
	if _deal_tween != null and is_instance_valid(_deal_tween):
		_deal_tween.queue_free()
	_deal_tween = null

	# Remove all clones from the animation layer.
	for c in _deal_clones:
		if is_instance_valid(c):
			c.queue_free()
	_deal_clones.clear()


# ---------------------------------------------------------------------------
# Initial dealing animation — progressive card reveal per player, starting
# from the current player. Hands begin empty and grow to 3 cards each.
# ---------------------------------------------------------------------------

const _DEAL_ANIM_DURATION = 0.15
const _OPPONENT_SEATS = {
	"player_2": "LeftSeat",
	"player_3": "TopSeat",
	"player_4": "RightSeat",
}

func _animate_initial_deal(snapshot):
	var anim_layer = _find_animation_layer()
	var players = snapshot.get("players", [])

	if anim_layer == null:
		# Headless fallback: apply immediately.
		_apply_snapshot(snapshot)
		_state = State.READY_FOR_INPUT
		_check_reset_hand(snapshot)
		_update_choice_blocker()
		return

	# Capture generation at deal start — used to detect if a new game
	# invalidated this deal mid-animation (after yields).
	var my_gen = _game_generation

	# Re-randomize draw pile jitter for the new game.
	if _board != null and _board.has_method("randomize_draw_pile"):
		_board.randomize_draw_pile()

	# Apply snapshot so all card nodes exist in their final positions.
	_apply_snapshot(snapshot)

	# Show plate back during deal animation.
	if _board != null and _board.has_method("show_plate_back"):
		_board.show_plate_back()

	# Immediately hide all hand cards — they'll be revealed progressively.
	_hide_all_hand_cards()

	_state = State.ANIMATING

	var deal_order = _build_deal_order_from_current(snapshot, players)
	var draw_pos = _get_deal_draw_pile_pos()
	var cardback_tex = load("res://imgs/cardback.png")
	var tween = Tween.new()
	add_child(tween)

	# Track deal state for cancellation.
	_deal_active = true
	_deal_tween = tween
	_deal_clones = []

	for ev in deal_order:
		# Abort if a new game started and cancelled this deal.
		if not _deal_active or _game_generation != my_gen:
			return

		var pid = ev["player_id"]
		var card_idx = ev["card_index"]
		var target_pos = _get_hand_card_global_pos(pid, card_idx)

		var clone = TextureRect.new()
		clone.texture = cardback_tex
		clone.expand = true
		clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		clone.rect_min_size = Vector2(80, 112)
		clone.rect_size = Vector2(80, 112)
		clone.rect_position = draw_pos
		clone.mouse_filter = 2
		anim_layer.add_child(clone)
		_deal_clones.append(clone)

		tween.interpolate_property(clone, "rect_position",
			draw_pos, target_pos, _DEAL_ANIM_DURATION,
			Tween.TRANS_QUAD, Tween.EASE_OUT)
		tween.start()
		yield(tween, "tween_all_completed")
		clone.queue_free()

		# Abort check after yield — a new game may have started.
		if not _deal_active or _game_generation != my_gen:
			return

		# Reveal the actual card in the player's hand.
		_reveal_hand_card(pid, card_idx)

	tween.queue_free()
	_deal_tween = null
	_deal_clones.clear()

	# Only set READY_FOR_INPUT if this deal wasn't superseded.
	if _game_generation != my_gen:
		return

	# Hide plate back — game is ready to start.
	if _board != null and _board.has_method("hide_plate_back"):
		_board.hide_plate_back()

	_state = State.READY_FOR_INPUT
	_check_reset_hand(snapshot)
	_update_choice_blocker()


func _build_deal_order_from_current(snapshot, players):
	"""Build deal sequence: current player gets 3 cards, then next player, etc."""
	var cur_idx = snapshot.get("current_player_index", 0)
	var n = players.size()
	var events = []
	for i in range(n):
		var pidx = (cur_idx + i) % n
		var pid = players[pidx].get("id", "")
		var hand_size = players[pidx].get("hand", []).size()
		for ci in range(hand_size):
			events.append({"player_id": pid, "card_index": ci})
	return events


func _hide_all_hand_cards():
	var main = _node_up("Main")
	if main == null: return
	var ga = _child(main, "GameArea")
	if ga == null: return

	# Local player
	var la = _child(ga, "LocalPlayerArea")
	if la != null:
		var ph = _child(la, "PlayerHand")
		if ph != null:
			var cl = _child(ph, "CardsLayer")
			if cl != null:
				for c in cl.get_children():
					c.visible = false

	# Opponents — hide both cards AND their shadows (OPS nodes)
	var ol = _child(ga, "OpponentsLayer")
	if ol != null:
		for seat_name in _OPPONENT_SEATS.values():
			var seat = _child(ol, seat_name)
			if seat != null:
				var cl = _child(seat, "CardsLayer")
				if cl != null:
					for c in cl.get_children():
						c.visible = false


func _reveal_hand_card(player_id, card_idx):
	var main = _node_up("Main")
	if main == null: return
	var ga = _child(main, "GameArea")
	if ga == null: return

	if player_id == "player_1":
		var la = _child(ga, "LocalPlayerArea")
		if la != null:
			var ph = _child(la, "PlayerHand")
			if ph != null:
				var cl = _child(ph, "CardsLayer")
				if cl != null:
					var children = cl.get_children()
					if card_idx < children.size():
						children[card_idx].visible = true
	else:
		var seat_name = _OPPONENT_SEATS.get(player_id, "")
		if seat_name == "": return
		var ol = _child(ga, "OpponentsLayer")
		if ol == null: return
		var seat = _child(ol, seat_name)
		if seat == null: return
		var cl = _child(seat, "CardsLayer")
		if cl == null: return

		# Find the card index among non-OPS nodes and reveal it + its shadow.
		var card_nodes = []
		for c in cl.get_children():
			if not c.name.begins_with("OPS"):
				card_nodes.append(c)
		if card_idx < card_nodes.size():
			card_nodes[card_idx].visible = true
			# Reveal the corresponding shadow (OPS<idx>_<seat_idx>)
			var shadow_name_prefix = "OPS" + str(card_idx) + "_"
			for c in cl.get_children():
				if c.name.begins_with(shadow_name_prefix):
					c.visible = true
					break


func _get_hand_card_global_pos(player_id, card_idx):
	var main = _node_up("Main")
	if main == null: return Vector2(960, 400)
	var ga = _child(main, "GameArea")
	if ga == null: return Vector2(960, 400)

	if player_id == "player_1":
		var la = _child(ga, "LocalPlayerArea")
		if la != null:
			var ph = _child(la, "PlayerHand")
			if ph != null:
				var cl = _child(ph, "CardsLayer")
				if cl != null:
					var children = cl.get_children()
					if card_idx < children.size():
						return children[card_idx].rect_global_position
	else:
		var seat_name = _OPPONENT_SEATS.get(player_id, "")
		if seat_name == "": return Vector2(960, 400)
		var ol = _child(ga, "OpponentsLayer")
		if ol == null: return Vector2(960, 400)
		var seat = _child(ol, seat_name)
		if seat == null: return Vector2(960, 400)
		var cl = _child(seat, "CardsLayer")
		if cl == null: return Vector2(960, 400)
		var card_nodes = []
		for c in cl.get_children():
			if not c.name.begins_with("OPS"):
				card_nodes.append(c)
		if card_idx < card_nodes.size():
			return card_nodes[card_idx].rect_global_position

	return Vector2(960, 400)


func _find_animation_layer():
	var main = _node_up("Main")
	if main == null: return null
	for c in main.get_children():
		if c.name == "CardAnimationLayer":
			return c
	return null


func _get_deal_draw_pile_pos():
	var main = _node_up("Main")
	if main == null: return Vector2(340, 130)
	var ga = _child(main, "GameArea")
	if ga == null: return Vector2(340, 130)
	var ba = _child(ga, "BoardArea")
	if ba == null: return Vector2(340, 130)
	var dp = _child(ba, "DrawPile")
	if dp == null: return Vector2(340, 130)
	return dp.rect_global_position + dp.rect_size / 2


func _get_player_hand_pos(player_id):
	var main = _node_up("Main")
	if main == null: return Vector2(960, 400)
	var ga = _child(main, "GameArea")
	if ga == null: return Vector2(960, 400)

	if player_id == "player_1":
		var la = _child(ga, "LocalPlayerArea")
		if la != null:
			var ph = _child(la, "PlayerHand")
			if ph != null:
				return ph.rect_global_position + ph.rect_size / 2
	else:
		var seat_name = _OPPONENT_SEATS.get(player_id, "")
		if seat_name != "":
			var ol = _child(ga, "OpponentsLayer")
			if ol != null:
				var seat = _child(ol, seat_name)
				if seat != null:
					return seat.rect_global_position + seat.rect_size / 2

	return Vector2(960, 400)


func _on_action_completed(result):
	_last_snapshot = result.get("snapshot", null)
	_last_events = result.get("events", [])
	emit_signal("action_applied", result)

	# Start animation BEFORE applying snapshot so CardAnimator can clone
	# the card texture from the pre-action hand state (before the card is removed).
	var should_animate = _card_animator != null and _card_animator.has_method("play_events") and _last_events.size() > 0
	if should_animate:
		_state = State.ANIMATING
		_expecting_animation_finish = true
		_card_animator.play_events(_last_events, _last_snapshot)

		# During animation, update board and hand but NOT the turn indicator.
		# The turn indicator will be updated when animation completes, so the
		# text remains "Il tuo turno" / "Turno di Player X" during the card movement.
		if _board != null and _board.has_method("apply_snapshot"):
			_board.apply_snapshot(_last_snapshot)
		if _hand != null and _hand.has_method("apply_snapshot"):
			_hand.apply_snapshot(_last_snapshot)

		# Pre-hide any cards that will be drawn, so they don't flicker into
		# existence before the draw animation reveals them.
		if _card_animator != null and _card_animator.has_method("hide_drawn_cards"):
			_card_animator.hide_drawn_cards(_last_events)
	else:
		_apply_snapshot(_last_snapshot)
		_finish_post_action()


# ---------------------------------------------------------------------------
# F7: Safe Round choice popup — opened BEFORE the activating play_card is
# sent, so the blocked_type rides on the same single play_card action.
# ---------------------------------------------------------------------------

func _selected_card_dict():
	if _selected_card_id == "" or _last_snapshot == null:
		return null
	var lid = _last_snapshot.get("local_player_id", "player_1")
	for p in _last_snapshot.get("players", []):
		if p.get("id", "") == lid:
			for c in p.get("hand", []):
				if c.get("card_id", "") == _selected_card_id:
					return c
	return null


func _play_activates_safe_round():
	"""F7: true when the selected card will activate a Safe Round — a normal
	Gold, or a +11 played immediately after a normal Gold whose next chain
	value is 23-78 (a chain to 89 activates the Advantage Round instead)."""
	var c = _selected_card_dict()
	if c == null:
		return false
	var ct = str(c.get("card_type", ""))
	if ct == "gold":
		return true
	if ct == "special" and str(c.get("name", "")) == "+11":
		var plateau_cards = _last_snapshot.get("plateau_cards", [])
		if plateau_cards.size() > 0:
			var last = plateau_cards[plateau_cards.size() - 1]
			if str(last.get("card_type", "")) == "gold":
				var chain_val = GOLD_CHAIN.get(int(last.get("value", 0)), null)
				return chain_val != null and chain_val != 89
	return false


func _is_selected_card_blocked_by_sr():
	"""True when the selected card is of the type currently blocked by an
	active Safe Round (Giro Sicuro). Such cards are selectable (for Cambio
	Carta) but must be rejected by Play. Mirrors the SR blocking rules."""
	if _selected_card_id == "" or _last_snapshot == null:
		return false
	if not _last_snapshot.get("special_round_active", false):
		return false
	var sr_type = str(_last_snapshot.get("special_round_type", ""))
	if sr_type != "safe":
		return false
	var blocked_type = str(_last_snapshot.get("blocked_type", "")).to_lower()
	if blocked_type == "":
		return false
	var card = _selected_card_dict()
	if card == null:
		return false
	var ct = str(card.get("card_type", "")).to_lower()
	var name = str(card.get("name", ""))
	if blocked_type == "incremento":
		return ct == "increment" or ct == "jolly" or name == "+11"
	elif blocked_type == "gold":
		return ct == "gold" or name == "89"
	elif blocked_type == "imbroglio":
		return ct == "imbroglio"
	return false

func _is_selected_card_89_not_allowed():
	"""True when the selected card is 89 but allow89 is still false (Piatto < 20)."""
	if _selected_card_id == "" or _last_snapshot == null:
		return false
	if _last_snapshot.get("allow89", false):
		return false
	var card = _selected_card_dict()
	if card == null:
		return false
	return str(card.get("name", "")) == "89"

func _is_selected_card_blocked_by_gdv():
	"""True when the selected card is not playable during Giro di Vantaggio.
	
	During GdV, only Incremento cards (increment/jolly/+11) can be played.
	All other cards should be rejected by Play.
	"""
	if _selected_card_id == "" or _last_snapshot == null:
		return false
	if not _last_snapshot.get("special_round_active", false):
		return false
	var sr_type = str(_last_snapshot.get("special_round_type", ""))
	if sr_type != "advantage":
		return false
	var card = _selected_card_dict()
	if card == null:
		return false
	var ct = str(card.get("card_type", "")).to_lower()
	var name = str(card.get("name", ""))
	return not (ct == "increment" or ct == "jolly" or name == "+11")

func _open_safe_round_choice():
	"""Open ValueChoicePopup for Safe Round blocked_type selection."""
	_state = State.WAITING_FOR_CHOICE
	_pending_action_type = "play_card"
	_pending_card_id = _selected_card_id
	_pending_valid_values = SAFE_ROUND_CHOICES.duplicate()
	_pending_blocked_type = true

	if _value_choice_label != null:
		_value_choice_label.text = "Scegli la tipologia da bloccare"

	# Clear old buttons and create Safe Round type buttons
	if _value_btn_grid != null:
		for c in _value_btn_grid.get_children():
			_value_btn_grid.remove_child(c)
			c.queue_free()

		var vList = VBoxContainer.new()
		vList.rect_min_size = Vector2(465, 650)
		vList.add_constant_override("separation", 10)
		vList.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_value_btn_grid.add_child(vList)
		for choice in SAFE_ROUND_CHOICES:
			var btn = Button.new()
			btn.text = choice
			btn.rect_min_size = Vector2(180, 70)
			btn.margin_bottom = 20
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			GlobalsUtilities.setCustomFont(btn, 32, 0, 6)
			if choice == "Incremento":
				GlobalsUtilities.setCustomStyle(btn,"normal", "btnHover")
			elif choice == "Gold":
				GlobalsUtilities.setCustomStyle(btn,"normal", "btnFocus")
			elif choice == "Imbroglio":
				GlobalsUtilities.setCustomStyle(btn,"normal", "btnPlay")
			btn.connect("pressed", self, "_on_safe_round_choice_chosen", [choice])
			vList.add_child(btn)

	if _value_choice_popup != null:
		_value_choice_popup.popup()
	_update_choice_blocker()


func _on_safe_round_choice_chosen(choice):
	"""Handle Safe Round blocked_type choice: send the single activating
	play_card with the chosen blocked_type."""
	if _state != State.WAITING_FOR_CHOICE:
		return
	if _pending_blocked_type != true:
		return

	if _value_choice_popup != null:
		_value_choice_popup.hide()
	_update_choice_blocker()

	var action = {"action_type": "play_card", "card_id": _pending_card_id}
	action["blocked_type"] = choice

	_pending_action_type = ""
	_pending_card_id = ""
	_pending_valid_values = []
	_pending_blocked_type = false

	perform_action(action)


func _on_animation_finished():
	# Track whether we're currently expecting an animation to complete.
	# If not (e.g., new game started and cancelled the animator), ignore
	# stale callbacks from the old game.
	if not _expecting_animation_finish:
		return

	_expecting_animation_finish = false

	# Now that animation is complete, update the turn indicator to show the next player.
	if _turn != null and _turn.has_method("apply_snapshot"):
		_turn.apply_snapshot(_last_snapshot)
	_finish_post_action()


func _finish_post_action():
	# GAME_OVER is set here, after the winning card animation has completed.
	if _last_snapshot != null and _last_snapshot.get("winner", null) != null:
		_clear_selection()
		_state = State.GAME_OVER
		# Return to menu music when game ends
		var am = _get_audio_manager()
		if am != null and am.has_method("set_menu_music"):
			am.set_menu_music()
		return

	_validate_selection(_last_snapshot)
	if _selected_card_id == "":
		_state = State.READY_FOR_INPUT
	else:
		_state = State.CARD_SELECTED
	_check_reset_hand(_last_snapshot)
	_update_choice_blocker()


func _on_action_rejected(error_message):
	_last_error = error_message
	_clear_selection()
	_state = State.READY_FOR_INPUT


# ---------------------------------------------------------------------------
# Selection validation
# ---------------------------------------------------------------------------

func _validate_selection(snapshot):
	if _selected_card_id == "" or snapshot == null:
		return
	var lid = snapshot.get("local_player_id", "player_1")
	var found = false
	for p in snapshot.get("players", []):
		if p.get("id", "") == lid:
			for c in p.get("hand", []):
				if c.get("card_id", "") == _selected_card_id:
					found = true
					break
			break
	if found:
		if _hand != null and _hand.has_method("set_selected"):
			_hand.set_selected(_selected_card_id)
	else:
		_clear_selection()


# ---------------------------------------------------------------------------
# Card type lookup
# ---------------------------------------------------------------------------

func _get_selected_card_type():
	if _selected_card_id == "" or _last_snapshot == null:
		return ""
	var lid = _last_snapshot.get("local_player_id", "player_1")
	for p in _last_snapshot.get("players", []):
		if p.get("id", "") == lid:
			for c in p.get("hand", []):
				if c.get("card_id", "") == _selected_card_id:
					return c.get("card_type", "")
	return ""


# ---------------------------------------------------------------------------
# Presenter update
# ---------------------------------------------------------------------------

func _apply_snapshot(snapshot):
	if snapshot == null:
		return
	if _board != null and _board.has_method("apply_snapshot"):
		_board.apply_snapshot(snapshot)
	if _hand != null and _hand.has_method("apply_snapshot"):
		_hand.apply_snapshot(snapshot)
	if _turn != null and _turn.has_method("apply_snapshot"):
		_turn.apply_snapshot(snapshot)
