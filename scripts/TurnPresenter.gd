extends Node
# TurnPresenter — manages HUD labels, buttons, popups.
# Does NOT contain game rules.

signal play_pressed
signal change_pressed
signal cancel_pressed

var _turn_label = null
var _instruction_label = null
var _warning_label = null
var _advantage_label = null
var _play_button = null
var _change_button = null
var _cancel_button = null
var _game_over_popup = null


func _ready():
	var m = _node_up("Main")
	if m == null: return
	var ga = _child(m, "GameArea"); if ga == null: return
	var hud = _child(ga, "HUDLayer")
	_warning_label = _child(hud, "InstructionLabel")
	var ovrl = _child(m, "OverlayLayer")
	var gop = _child(ovrl, "GameOverPopup")
	var goc = _child(gop, "GameOverContainer")

	if hud != null:
		_turn_label = _child(hud, "TurnLabel")
		_instruction_label = _child(goc, "InstructionLabel")
		
		_advantage_label = _child(hud, "AdvantageLabel")
		var p = _child(hud, "ActionPanel")
		if p != null:
			_play_button = _child(p, "PlayButton")
			_change_button = _child(p, "ChangeButton")
			_cancel_button = _child(p, "CancelButton")
			if _play_button != null:
				_play_button.connect("pressed", self, "_on_play")
			if _change_button != null:
				_change_button.connect("pressed", self, "_on_change")
			if _cancel_button != null:
				_cancel_button.connect("pressed", self, "_on_cancel")
	var ol = _child(m, "OverlayLayer")
	if not GlobalsUtilities.tutorialStarted:
		if ol != null: _game_over_popup = _child(ol, "GameOverPopup")
	_localize()
	GlobalsUtilities.connect("language_changed", self, "_on_language_changed")

func _localize():
	if _play_button != null: _play_button.text = tr("ACTION_PLAY")
	if _change_button != null: _change_button.text = tr("ACTION_CHANGE")
	if _cancel_button != null: _cancel_button.text = tr("CANCEL")

func _on_language_changed(_locale):
	_localize()


func _node_up(name):
	var p = get_parent()
	while p != null and p.name != name: p = p.get_parent()
	return p


func _child(p, name):
	if p == null: return null
	for c in p.get_children():
		if c.name == name: return c
	return null


func _on_play():
	emit_signal("play_pressed")


func _on_change():
	emit_signal("change_pressed")


func _on_cancel():
	emit_signal("cancel_pressed")


func show_tip(msg):
	if _warning_label != null:
		_warning_label.text = msg


func apply_snapshot(s):
	GlobalsUtilities.selected_value = ""
	if s == null: return
	var t = s.get("turn_number", 0); var w = s.get("winner", null)
	var sr = s.get("special_round_active", false); var lid = s.get("local_player_id", "p1")
	var acts = s.get("available_actions", [])
	var sr_type = s.get("special_round_type", "")
	if _turn_label != null: _turn_label.visible = t > 0; _turn_label.text = tr("TURN_PREFIX") % t
	# F7: top indicator distinguishes the active Special Round type.
	if _advantage_label != null:
		_advantage_label.visible = sr
		# _warning_label.visible = sr
		if sr:
			if sr_type == "safe":
				_advantage_label.text = tr("SR_SAFE")
			else:
				_advantage_label.text = tr("SR_ADVANTAGE")
	if _instruction_label != null:
		if w != null:
			var wn = ""
			var players = s.get("players", [])
			for i in range(players.size()):
				var player = players[i]
				if player.get("id", "") == w:
					wn = player.get("name", "")
					break
			_instruction_label.text = tr("WINNER_FMT") % wn
		else:
			# F7: the turn info is never replaced by the Special Round —
			# the Special Round type lives in _advantage_label.
			var ci = s.get("current_player_index", 0); var pl = s.get("players", [])
			if ci < pl.size():
				_warning_label.text = tr("TURN_OF") % pl[ci].get("name", "Giocatore")
				if pl[ci].get("id", "") == lid: _warning_label.text = tr("YOUR_TURN")
	var hp = false; var hc = false
	for a2 in acts:
		var at = a2.get("action_type","")
		if at == "play_card": hp = true
		elif at == "change_card": hc = true
	if _play_button != null: _play_button.disabled = !hp
	if _change_button != null: _change_button.disabled = !hc
	if _game_over_popup != null and w != null:
		if !_game_over_popup.visible:
			_game_over_popup.popup()
		var main = _node_up("Main")
		main.get_node("StartGameButton").disabled = false
		var goc = _child(_game_over_popup, "GameOverContainer")
		var gamePlayed = goc.get_node("GamePlayed")
		var gameWon = goc.get_node("GameWon")
		var gameSeries = goc.get_node("GameSeries")
		var gameBestSeries = goc.get_node("GameBestSeries")
		gamePlayed.get_node("Value").text = str(GlobalsUtilities.stats["games_played"])
		gameWon.get_node("Value").text = str(GlobalsUtilities.stats["games_won"])
		gameSeries.get_node("Value").text = str(GlobalsUtilities.stats["current_streak"])
		gameBestSeries.get_node("Value").text = str(GlobalsUtilities.stats["best_streak"])

	

func diagnose():
	print("Turn: turn=" + str(_turn_label != null) + " instr=" + str(_warning_label != null) + " adv=" + str(_advantage_label != null) + " play=" + str(_play_button != null) + " go=" + str(_game_over_popup != null))
func _diagnose_nodes():
	return " turn=" + (_turn_label.text if _turn_label != null else "?") + " instr=" + (_warning_label.text if _warning_label != null else "?")
