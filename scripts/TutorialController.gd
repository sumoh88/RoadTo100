extends Node

# TutorialController — drives "Come si gioca" as a fully controlled TUTORIAL MODE.
#
# It owns:
#   - the tutorial CONTENT (the `steps` array below) — separated from game rules;
#   - its popup UI (structure + appearance defined in TutorialController.tscn,
#     styled like the choice_value popup with a representative image on the left).
#     This script only keeps references to those nodes and updates their dynamic
#     content per step; it does NOT build the UI.
#   - input blocking for the whole mode (a full-screen transparent layer that
#     renders on top by tree order and absorbs clicks);
#   - the "Mostra" demo by reusing DebugDemo's short-demo machinery.
#
# Navigation to the Main Menu is intentionally NOT done here: when the tutorial
# ends it emits `tutorial_finished` and the owning scene (Main.gd) navigates.
# This keeps this node fully testable headless.
#
# Extensibility: append an entry to `_build_steps()` for a new block.
# Each step is { id, title, text, image, demo_turns }. `demo_turns` > 0 means
# "Mostra" runs a limited auto-demo for that many turns; 0 just sets up the board.
var _demo_mouse_blocked = false
signal tutorial_finished

var _gc = null        # GameController (parent node)
var _demo = null      # DebugDemo node (sibling under GameController)

# UI nodes
var _overlay_root = null   # full-screen input blocker, always visible in mode
var _dim = null            # semi-transparent backdrop (only when popup shown)
var _panel = null          # styled background box (popupCenter.png)
var _image_rect = null     # representative image on the left
var _title_label = null
var _text_label = null
var _show_btn = null       # "Mostra"
var _proceed_btn = null    # "Prosegui" / "Fine"
var _prev_btn = null   	   # "Precedente"

# Mode state
var active = false
var current_step_index = -1
var steps = []

# Reference to the normal-game "Nuova partita" button (disabled during mode).
var _start_game_button = null


func _ready():
	steps = _build_steps()
	_gc = get_parent()
	_find_demo_node()
	if _demo != null and _demo.has_signal("short_demo_completed"):
		_demo.connect("short_demo_completed", self, "_on_short_demo_completed")
	_init_ui_nodes()
	# Start hidden; only active while in tutorial mode.
	if _overlay_root != null:
		_overlay_root.visible = false

func _input(event):
	if not _demo_mouse_blocked:
		return
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.doubleclick:
				_stop_demo()
				_unblock_demo_mouse()
				_show_popup_content()
				return
				
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_tree().set_input_as_handled()
# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func start_tutorial():
	active = true
	current_step_index = -1
	_block_game_input()
	show_next_step()
	if _gc != null:
		_gc.play_tutorial_initial_deal()
		_gc.start_game(4)


func show_next_step():
	current_step_index += 1
	if current_step_index >= steps.size():
		finish_tutorial()
		return
	var step = steps[current_step_index]
	_populate(step)
	_show_popup_content()

func show_prev_step():
	current_step_index -= 1
	if current_step_index < 0:
		return
	elif current_step_index == 0:
		_prev_btn.disabled = true
	var step = steps[current_step_index]
	_populate(step)
	_show_popup_content()

# "Mostra": run (or restart) the demo for the current step only.
#   - Steps with a "scenario" use the scripted, prepared demo (deterministic).
#   - Other steps fall back to the seeded short auto-demo.
func on_show_pressed():
	if not active or current_step_index < 0 or current_step_index >= steps.size():
		return
	var step = steps[current_step_index]
	if _demo == null:
		return
	if step.has("scenario"):
		# Scripted prepared demo (steps 1-6). One Mostra = only this step.
		_hide_popup_content()   # overlay_root still blocks input during the demo
		_block_demo_mouse()
		_demo.start_scripted_demo(step["scenario"])
		return

	var n = int(step.get("demo_turns", 0))
	var focus = step.get("demo_focus", [])
	if n > 0:
		_hide_popup_content()   # overlay_root still blocks input during the demo
		_block_demo_mouse()
		_demo.start_short_demo(n, focus)
	elif not _game_started():
		# No dedicated turns — just set up the board so pieces are visible.
		_gc.start_game(4)


# "Prosegui" advances; on the last step it acts as "Fine".
func on_proceed_pressed():
	if not active:
		return
	if _is_last_step():
		finish_tutorial()
	else:
		_stop_demo()
		show_next_step()
		_prev_btn.disabled = false

func on_prev_pressed():
	print("__________ current_step_index: ", current_step_index)
	if _is_first_step():
		return
	else:
		_stop_demo()
		show_prev_step()

# Called when the tutorial ends (via "Fine"); the scene navigates to the menu.
func finish_tutorial():
	GlobalsUtilities.tutorialStarted = false
	active = false
	_stop_demo()
	_close_overlay()
	_unblock_game_input()
	emit_signal("tutorial_finished")


# ---------------------------------------------------------------------------
# Mode / input control
# ---------------------------------------------------------------------------

func _block_game_input():
	if _overlay_root != null:
		_overlay_root.visible = true
	_start_game_button = _find_start_game_button()
	if _start_game_button != null:
		_start_game_button.set_disabled(true)
	var main = get_parent()
	if main != null:
		var overlay_layer = main.get_node_or_null("OverlayLayer")
		if overlay_layer != null:
			var input_blocker = overlay_layer.get_node_or_null("InputBlocker")
			if input_blocker != null:
				overlay_layer.move_child(input_blocker, overlay_layer.get_child_count() - 1)
				input_blocker.visible = true


func _unblock_game_input():
	if _overlay_root != null:
		_overlay_root.visible = false
	if _start_game_button != null and is_instance_valid(_start_game_button):
		_start_game_button.set_disabled(false)
	_start_game_button = null

func _block_demo_mouse():
	_demo_mouse_blocked = true

func _unblock_demo_mouse():
	_demo_mouse_blocked = false

func _find_start_game_button():
	var p = get_parent()
	while p != null:
		if p.name == "Main":
			return p.get_node_or_null("StartGameButton")
		p = p.get_parent()
	return null


func _close_overlay():
	if _overlay_root != null:
		_overlay_root.visible = false


# ---------------------------------------------------------------------------
# Demo hooks
# ---------------------------------------------------------------------------

func _find_demo_node():
	if _gc == null:
		return
	for c in _gc.get_children():
		if c != self and c.has_method("start_short_demo"):
			_demo = c
			break


func _on_short_demo_completed():
	# Always return to the popup of the same step.
	if not active:
		return
	if current_step_index < 0 or current_step_index >= steps.size():
		return
	_unblock_demo_mouse()
	_show_popup_content()


func _stop_demo():
	if _demo != null and _demo.has_method("stop_demo"):
		_demo.stop_demo()
	_unblock_demo_mouse()


func _game_started():
	return _gc != null and _gc.get_last_snapshot() != null


func _is_first_step():
	print("__________ current_step_index: ", current_step_index)
	return current_step_index == 0

func _is_last_step():
	return current_step_index == steps.size() - 1


# ---------------------------------------------------------------------------
# Popup content / visibility
# ---------------------------------------------------------------------------

func _populate(step):
	if _image_rect != null:
		var path = step.get("image", "")
		if path != "":
			_image_rect.texture = load(path)
	if _title_label != null:
		_title_label.text = step["title"]
	if _text_label != null:
		_text_label.text = step["text"]
	if _proceed_btn != null:
		_proceed_btn.text = "Fine" if _is_last_step() else "Prosegui"


func _show_popup_content():
	if _dim != null:
		_dim.visible = true
	if _panel != null:
		_panel.visible = true


func _hide_popup_content():
	if _dim != null:
		_dim.visible = false
	if _panel != null:
		_panel.visible = false


# ---------------------------------------------------------------------------
# Tutorial CONTENT (separated from game logic)
# ---------------------------------------------------------------------------

# Build a standard tutorial scenario setup: P1 with the given cards, the other
# players with filler, and `draw_last` as the card P1 will draw next (LAST of
# the draw pile is drawn first). Optional `meta` overrides game metadata.
func _sc_setup(p1_cards, draw_last, meta=null):
	var spec = {
		"player_count": 4,
		"current_player_index": 0,
		"hands": {
			"player_1": p1_cards,
			"player_2": ["+2", "Gold78", "+10"],
			"player_3": ["+3", "+10", "Imbroglio"],
			"player_4": ["+6", "+5", "+10"],
		},
		"draw_pile": ["+1", "+2", draw_last],
	}
	if meta != null:
		spec["meta"] = meta
	return spec


func _build_steps():
	return [
		# STEP base — Regole base (seeded short demo, unchanged).
		{
			"id": "turn_basics",
			"title": "Il turno e il tavolo",
			"text": "Nel tuo turno puoi scegliere se giocare una carta o rimetterne una nel Mazzo, poi peschi una nuova carta.\nIn basso trovi la tua mano, mentre al centro invece trovi, in ordine:\n◌ il Piatto (il punteggio).\n◌ il Mazzo (dal quale si pesca).\n◌ la pila degli Scarti (per le carte giocate).\n\nIl Mazzo è composto da 30 Incremento,\n10 Jolly, 7 Imbroglio, 7 Gold, 3 Gold 89 e 3 carte +11. Per un totale di 60 carte.",
			"image": "res://icon.png",
			"demo_turns": 1,
			"scenario": {
				"segments": [
					{"setup": _sc_setup(["+7", "Imbroglio", "+7"], "Jolly", {"piatto": 0}),
					"script": [
						{"action": "play", "card": "+7"},
						{"action": "play", "card": "0"}
					]},
					{"setup": _sc_setup(["+7", "Imbroglio", "+7"], "Jolly", {"piatto": 0}),
					"script": [
						{"action": "change_card", "card_id": "increment_7_0"}
					]}
				]
			},
		},
		# STEP 0 — Incrementi (scripted: +7 demo, rewind, Jolly demo).
		{
			"id": "increment_cards",
			"title": "Carte Incremento",
			"text": "Le carte Incremento aggiungono il loro valore al Piatto.\n\nEsistono Incrementi da +1 a +10.\n\nIl Jolly, quando viene giocato, ti fa scegliere il valore dell'incremento.",
			"image": "res://imgs/inc7.png",
			"scenario": {
				"segments": [
					{"setup": _sc_setup(["Imbroglio", "+7", "Jolly"], "Imbroglio", {"piatto": 7}),
					"script": [
						{"action": "play", "card": "+7"},
						{"action": "play", "card": "0"}
					]},
					{"setup": _sc_setup(["Imbroglio", "+7", "Jolly"], "Imbroglio", {"piatto": 7}),
					"script": [
						{"action": "play", "card": "Jolly", "value": 7}
					]},
				]
			},
		},
		# STEP 2 — Imbroglio (scripted: play Imbroglio, choose -7).
		{
			"id": "imbroglio",
			"title": "Carta Imbroglio",
			"text": "L'Imbroglio ti fa scegliere un valore da -15 a +15 (escluso 0).\nPuoi usarlo per aumentare o ridurre il Piatto.\n\nAttenzione:\nL'imbroglio non può essere usato per ottenere una vittoria.\nL'imbroglio non può mai raggiungere o superare 100 o portare il piatto sotto lo 0.",
			"image": "res://imgs/imb.png",
			"scenario": {
				"segments": [
					{"setup": _sc_setup(["Imbroglio", "+7", "Imbroglio"], "Gold67", {"piatto": 14}),
					"script": [
						{"action": "play", "card": "Imbroglio", "value": -10}
					]},
				]
			},
		},
		# STEP 3 — Gold (scripted: play Gold, Safe Round activation + choice).
		{
			"id": "gold",
			"title": "Carte Gold",
			"text": "Le carte Gold impostano il Piatto al loro valore e attivano un Giro Sicuro:\n\nL'attivatore del Giro Sicuro (rappresentato da una stella) sceglie quale tipo di carta bloccare per un intero turno!\n\nSfruttalo a tuo vantaggio per velocizzare o rallentare la partita.\n\nEsiste solo una copia per ogni Gold, e sono:\n12, 23, 34, 45, 56, 67, 78",
			"image": "res://imgs/gold23.png",
			"scenario": {
				"segments": [
					{"setup": _sc_setup(["+7", "Imbroglio", "Gold67"], "89", {"piatto": 4}),
					"script": [
						{"action": "play", "card": "Gold67", "blocked_type": "Imbroglio"},
						{"action": "play", "card": "Gold78"},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "+10"}
					]},
				]
			},
		},
		# STEP 4 — Regola del Rimbalzo (scripted: gdv bounce demo).
		{
			"id": "bounce_rules",
			"title": "Regola del rimbalzo",
			"text": "Se una Carta Incremento porta il Piatto oltre 100, viene applicata la Regola del Rimbalzo:\n\nSei il Piatto supera 100 il valore in eccesso rimbalza indietro!\n\nTieni sempre sott'occhio il valore del Piatto, potresti anche sfruttarlo a tuo vantaggio.",
			"image": "res://imgs/plate.png",
			"demo_turns": 7,
			"scenario": {
				"segments": [
					{"setup": _sc_setup(["+7", "Imbroglio", "Gold89"], "Jolly", {"piatto": 98, 
					"special_round_active": true, "special_round_type": "advantage",
					"special_round_player_id": "player_2", "_activator_has_played_next": true}),
					"script": [
						{"action": "play", "card": "+7"},
						{"action": "play", "card": "+2"},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "+6"},
						{"action": "play", "card": "Imbroglio", "value": -15}
					]},
				]
			},
		},
		# STEP 5 — 89 / GdV (scripted: P1 plays 89, GdV starts, a CPU shows the
		# restriction: only increments/+11 are playable for the others).
		{
			"id": "gdv",
			"title": "Carta 89 e Giro di Vantaggio",
			"text": "La carta 89 imposta il Piatto a 89 e avvia il Giro di Vantaggio.\nL'attivatore diventa il Giocatore in Vantaggio fino alla fine del suo prossimo turno:\n\nDurante il Giro di Vantaggio solo il Giocatore in Vantaggio può fare 100 e vincere, inoltre il Giocare in Vantaggio ignora il rimbalzo!\n\nDurante il Giro di Vantaggio si possono giocare solo carte di tipo Incremento.",
			"image": "res://imgs/spe89.png",
			"demo_turns": 5,
			"scenario": {
				"segments": [
					{"setup": _sc_setup(["89", "+4", "Jolly"], "+11", {"piatto": 84, "allow89": true}),
					"script": [
						{"action": "play", "card": "89"},   # P1: 89 -> GdV (piatto 89)
						{"action": "play", "card": "+2"},    # P2: only an increment is playable
						{"action": "play", "card": "+3"},
						{"action": "play", "card": "+6"},
						{"action": "play", "card": "Jolly", "value": 7}
					]},
				]
			},
		},
		# STEP 6 — +11 (three cases, each a prepared segment = rewind between).
		{
			"id": "plus11",
			"title": "Carta +11",
			"text": "La carta +11 è un Incremento Speciale e aggiunge 11 al Piatto.\n\nQuesta carta ignora la regola del rimbalzo e il Giro di Vantaggio, se il piatto è vicino a 100 puoi usarla per vincere subito!\n\nInoltre, se usi la carta +11 subito dopo una carta Gold si trasforma nella Gold successiva attivando così il giro speciale!\n\nNon sprecarla!",
			"image": "res://imgs/spe+11.png",
			"scenario": {
				"segments": [
					# Case 1: +11 in GdV (P1 advantage) -> victory.
					{"setup": _sc_setup(["+11", "+4", "Jolly"], "+4", {
					"piatto": 89, "special_round_active": true, "special_round_type": "advantage",
					"special_round_player_id": "player_1"}), "script": [
						{"action": "play", "card": "+11"},
						{"action": "play", "card": "0"},
						{"action": "play", "card": "0"}
					]},
					# Case 2: +11 on a normal Piatto.
					{"setup": _sc_setup(["+11", "+3", "+5"], "+4", {"piatto": 30}),
					"script": [
						{"action": "play", "card": "+11"},
						{"action": "play", "card": "0"},
						{"action": "play", "card": "0"}
					]},
					# Case 3: +11 after a Gold -> transforms into the next Gold.
					{"setup": _sc_setup(["+11", "+3", "+5"], "+4", {"piatto": 12, "plateau": ["Gold12"]}),
					"script": [
						{"action": "play", "card": "+11", "blocked_type": "Imbroglio"}
					]},
				]
			},
		},
		# STEP 7 — Consigli / combo (my designed pedagogical sequence).
		{
			"id": "consigli",
			"title": "Consigli e combo",
			"text": "Combina le carte per avvantaggiarti o per svantaggiare gli avversari in modo che sia tu a portare il Piatto a 100.\n\nPer esempio puoi combinare due +11 al momento giusto per vincere.\nOppure prova a usare il Rimbalzo o le Imbroglio per togliere la vittoria a un avversario.",
			"image": "res://imgs/incJolly.png",
			"scenario": {
				"segments": [
					# Show increments raising the Piatto.
					{"setup": _sc_setup(["+11", "+11", "Jolly"], "+5", {"piatto": 78, "plateau": ["Gold78"]}),
					"script": [
						{"action": "play", "card": "+11"},
						{"action": "play", "card": "+2"},    # P2: only an increment is playable
						{"action": "play", "card": "+3"},
						{"action": "play", "card": "+6"},
						{"action": "play", "card": "+11"},
						{"action": "play", "card": "0"},
						{"action": "play", "card": "0"}
					]},
					# Show using a Jolly as the exact value to reach 100 and win.
					{"setup": _sc_setup(["+10", "+3", "+1"], "+3", {"piatto": 98}),
					"script": [
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "+2"},
						{"action": "play", "card": "+3"},
						{"action": "play", "card": "+6"},
						{"action": "play", "card": "0"},
						{"action": "play", "card": "0"}
					]},
					{"setup": _sc_setup(["Imbroglio", "Gold67", "Jolly"], "+4", {"piatto": 82}),
					"script": [
						{"action": "play", "card": "Imbroglio", "value": -15},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "Jolly", "value": +3},
						{"action": "play", "card": "0"},
						{"action": "play", "card": "0"}
					]},
					{"setup": _sc_setup(["Imbroglio", "Gold67", "Jolly"], "+4", {"piatto": 82}),
					"script": [
						{"action": "play", "card": "Gold67", "blocked_type": "Imbroglio"},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "+10"},
						{"action": "play", "card": "Jolly", "value": +3}
					]},
				]
			},
		},
	]


# ---------------------------------------------------------------------------
# Popup UI references
#
# The nodes (structure + appearance) live in TutorialController.tscn. This only
# grabs references to them and wires up signals.
# ---------------------------------------------------------------------------

func _init_ui_nodes():
	_overlay_root = get_node_or_null("TutorialOverlay")
	_dim = get_node_or_null("TutorialOverlay/Dim")
	_panel = get_node_or_null("TutorialOverlay/Panel")
	_image_rect = get_node_or_null("TutorialOverlay/Panel/Image")
	_title_label = get_node_or_null("TutorialOverlay/Panel/Title")
	_text_label = get_node_or_null("TutorialOverlay/Panel/Text")
	_show_btn = get_node_or_null("TutorialOverlay/Panel/ShowButton")
	_proceed_btn = get_node_or_null("TutorialOverlay/Panel/ProceedButton")
	_prev_btn = get_node_or_null("TutorialOverlay/Panel/PrevButton")
	if _show_btn != null:
		_show_btn.connect("pressed", self, "on_show_pressed")
	if _proceed_btn != null:
		_proceed_btn.connect("pressed", self, "on_proceed_pressed")
	if _prev_btn != null:
		_prev_btn.connect("pressed", self, "on_prev_pressed")


func _on_BackMenuButton_pressed():
	var ShuffleDeal = AudioManager.get_node("SFXPlayer/ShuffleDeal")
	AudioManager.stop_sfx(ShuffleDeal)
	finish_tutorial()
