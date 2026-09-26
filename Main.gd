extends Control


const NOTIFICATION_DURATION := 4.0
const FADE_IN_DURATION := 0.35
const FADE_OUT_DURATION := 0.35


# --- Achievement unlock notification (uses ONLY existing nodes:
#     OverlayLayer/UnlockPopup + UnlockName + UnlockDesc). FIFO queue with a
#     fixed display time; a new unlock during the display is queued and does
#     NOT reset the current timer.
var _unlock_popup = null
var _unlock_name = null
var _unlock_desc = null
var _stats_inst = null
var _unlock_queue = []      # achievement ids waiting to be shown
var _notif_time_left = 0.0  # seconds remaining on the current notification

var _unlock_tween = null

func _ready():
	if GlobalsUtilities.tutorialStarted:
		var tc = _ensure_tutorial_controller()
		if tc != null and tc.has_method("start_tutorial"):
			if tc.has_signal("tutorial_finished"):
				tc.connect("tutorial_finished", self, "_on_tutorial_finished")
			tc.start_tutorial()
	elif GlobalsUtilities.gameStarted:
		GlobalsUtilities.gameStarted = true
		GlobalsUtilities.demoStarted = false
		$StartGameButton.emit_signal("pressed")
	elif GlobalsUtilities.demoStarted:
		GlobalsUtilities.gameStarted = false
		GlobalsUtilities.demoStarted = true
		$DemoButton.emit_signal("pressed")

	_connect_unlock_notifications()
	_localize()
	GlobalsUtilities.connect("language_changed", self, "_on_language_changed")


# Wires the existing UnlockPopup (OverlayLayer/UnlockPopup) to achievement
# unlock events.
func _connect_unlock_notifications():
	var popup = get_node_or_null("OverlayLayer/UnlockPopup")
	if popup == null:
		return
	_unlock_popup = popup
	_unlock_name = popup.get_node_or_null("UnlockName")
	_unlock_desc = popup.get_node_or_null("UnlockDesc")
	if _unlock_name == null or _unlock_desc == null:
		return
	# Passive notification: it must never block input to the rest of the UI.
	_unlock_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Name/description come from the same table the Stats scene uses (single source).
	var stats_scene = load("res://Stats.tscn")
	if stats_scene != null:
		_stats_inst = stats_scene.instance()
	GlobalsUtilities.connect("achievement_unlocked", self, "_on_achievement_unlocked")


func _process(delta):
	if _notif_time_left > 0.0:
		_notif_time_left -= delta
		if _notif_time_left <= 0.0:
			_hide_current_unlock()


func _on_achievement_unlocked(achievement_id):
	# Demo and tutorial runs must not generate notifications.
	if GlobalsUtilities.demoStarted or GlobalsUtilities.tutorialStarted:
		return
	_unlock_queue.push_back(str(achievement_id))
	if _notif_time_left <= 0.0 and not _unlock_popup.visible:
		_show_next_unlock()

func _get_achievement_info(id):
	if _stats_inst == null:
		return null
	for a in _stats_inst.achievements:
		if str(a.get("id", "")) == id:
			return a
	return null

func _show_next_unlock():
	if _unlock_queue.size() == 0:
		_unlock_popup.visible = false
		return

	var id = _unlock_queue.pop_front()
	var info = _get_achievement_info(id)

	if info != null:
		_unlock_name.text = str(info.get("name", id))
		_unlock_desc.text = str(info.get("description", ""))
	else:
		_unlock_name.text = str(id)
		_unlock_desc.text = ""

	if _unlock_tween != null:
		_unlock_tween.stop_all()

	_unlock_popup.visible = true
	_unlock_popup.modulate.a = 0.0

	_unlock_tween = Tween.new()
	add_child(_unlock_tween)

	_unlock_tween.interpolate_property(
		_unlock_popup,
		"modulate:a",
		0.0,
		1.0,
		FADE_IN_DURATION,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)
	_unlock_tween.start()

	_notif_time_left = NOTIFICATION_DURATION

func _hide_current_unlock():
	if _unlock_tween != null:
		_unlock_tween.stop_all()

	_unlock_tween = Tween.new()
	add_child(_unlock_tween)

	_unlock_tween.interpolate_property(
		_unlock_popup,
		"modulate:a",
		_unlock_popup.modulate.a,
		0.0,
		FADE_OUT_DURATION,
		Tween.TRANS_QUAD,
		Tween.EASE_IN
	)
	_unlock_tween.start()

	yield(_unlock_tween, "tween_all_completed")

	_unlock_popup.visible = false
	_unlock_popup.modulate.a = 1.0

	_show_next_unlock()

func _localize():
	$OverlayLayer/GameOverPopup/GameOverContainer/GamePlayed.text = tr("STAT_GP")
	$OverlayLayer/GameOverPopup/GameOverContainer/GameWon.text = tr("STAT_GW")
	$OverlayLayer/GameOverPopup/GameOverContainer/GameSeries.text = tr("STAT_WS")
	$OverlayLayer/GameOverPopup/GameOverContainer/GameBestSeries.text = tr("STAT_BS")
	$OverlayLayer/GameOverPopup/GameOverContainer/GameOverLabel.text = tr("GAMEOVER")
	$GameArea/BoardArea/DrawPile/CountLabelName.text = tr("HAND_REMAINED")
	$OverlayLayer/ValueChoicePopup/VBox/MsgLabel.text = tr("CHOOSE_VALUE_STATIC")
	$GameArea/HUDLayer/ActionPanel/BackMenuButton.text = tr("ACTION_BACK")
	$StartGameButton.text = tr("NEW_GAME")
	$DemoButton.text = tr("DEMO_AUTO")
	$OverlayLayer/HandResetPopup/VBox/MsgLabel.text = tr("RESHUFFLE_MSG")
	$OverlayLayer/ValueChoicePopup/VBox/CancelBtn.text = tr("CANCEL_BTN")
	$OverlayLayer/HandResetPopup/VBox/BtnRow/YesBtn.text = tr("YES")
	$OverlayLayer/HandResetPopup/VBox/BtnRow/NoBtn.text = tr("NO")
	$GameArea/HUDLayer/TurnLabel.text = tr("TURN_PREFIX") % 1

func _on_language_changed(_locale):
	_localize()

# Returns the TutorialController node. Uses the scene-instanced one from
# Main.tscn when present; otherwise instantiates it from its .tscn so the
# tutorial UI (structure + appearance defined in the scene) is always available.
func _ensure_tutorial_controller():
	var tc = get_node_or_null("GameController/TutorialController")
	if tc != null:
		return tc
	var packed = load("res://scripts/TutorialController.tscn") as PackedScene
	if packed == null:
		return null
	tc = packed.instance()
	tc.name = "TutorialController"
	get_node("GameController").add_child(tc)
	return tc


func _on_tutorial_finished():
	get_tree().change_scene("res://MainMenu.tscn")
	GlobalsUtilities.gameStarted = false


func _on_BackMenuButton_pressed():
	var ShuffleDeal = AudioManager.get_node("SFXPlayer/ShuffleDeal")
	AudioManager.stop_sfx(ShuffleDeal)
	get_tree().change_scene("res://MainMenu.tscn")
	GlobalsUtilities.gameStarted = false


func _on_bg_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			$TurnPresenter._game_over_popup.hide()
