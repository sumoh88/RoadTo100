extends Node
# TurnPresenter — manages HUD labels, buttons, popups.
# Does NOT contain game rules.

var _turn_label = null
var _instruction_label = null
var _advantage_label = null
var _play_button = null
var _change_button = null
var _game_over_popup = null

func _ready():
	var m = _node_up("Main")
	if m == null: return
	var ga = _child(m, "GameArea"); if ga == null: return
	var hud = _child(ga, "HUDLayer")
	if hud != null:
		_turn_label = _child(hud, "TurnLabel")
		_instruction_label = _child(hud, "InstructionLabel")
		_advantage_label = _child(hud, "AdvantageLabel")
		var p = _child(hud, "ActionPanel")
		if p != null:
			_play_button = _child(p, "PlayButton"); _change_button = _child(p, "ChangeButton")
	var ol = _child(m, "OverlayLayer")
	if ol != null: _game_over_popup = _child(ol, "GameOverPopup")

func _node_up(name):
	var p = get_parent()
	while p != null and p.name != name: p = p.get_parent()
	return p
func _child(p, name):
	if p == null: return null
	for c in p.get_children():
		if c.name == name: return c
	return null

func apply_snapshot(s):
	if s == null: return
	var t = s.get("turn_number", 0); var w = s.get("winner", null)
	var a = s.get("advantage_turn", false); var lid = s.get("local_player_id", "p1")
	var acts = s.get("available_actions", [])
	if _turn_label != null: _turn_label.visible = t > 0; _turn_label.text = "Turno " + str(t)
	if _advantage_label != null: _advantage_label.visible = a
	if _instruction_label != null:
		if w != null:
			var wn = ""
			var players = s.get("players", [])
			for i in range(players.size()):
				var player = players[i]
				if player.get("id", "") == w:
					wn = player.get("name", "")
					break
			_instruction_label.text = wn + " vince!"
		elif a: _instruction_label.text = "GIRO DI VANTAGGIO"
		else:
			var ci = s.get("current_player_index", 0); var pl = s.get("players", [])
			if ci < pl.size():
				_instruction_label.text = "Turno di " + pl[ci].get("name", "Giocatore")
				if pl[ci].get("id", "") == lid: _instruction_label.text = "Il tuo turno"
	var hp = false; var hc = false
	for a2 in acts:
		var at = a2.get("action_type","")
		if at == "play_card": hp = true
		elif at == "change_card": hc = true
	if _play_button != null: _play_button.disabled = !hp
	if _change_button != null: _change_button.disabled = !hc
	if _game_over_popup != null and w != null and !_game_over_popup.visible: _game_over_popup.popup()

func diagnose():
	print("Turn: turn=" + str(_turn_label != null) + " instr=" + str(_instruction_label != null) + " adv=" + str(_advantage_label != null) + " play=" + str(_play_button != null) + " go=" + str(_game_over_popup != null))
func _diagnose_nodes():
	return " turn=" + (_turn_label.text if _turn_label != null else "?") + " instr=" + (_instruction_label.text if _instruction_label != null else "?")
