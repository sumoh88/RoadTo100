extends Control



onready var _msg_label = $InstructionLabel
onready var top = $inputBlockerContainer/inputBlockerMaskTop
onready var bottom = $inputBlockerContainer/inputBlockerMaskBottom
onready var right = $inputBlockerContainer/inputBlockerMaskRight
onready var left = $inputBlockerContainer/inputBlockerMaskLeft

var initTopPos
var initBottomPos
var initRightPos
var initLeftPos

var initTopSize
var initBottomSize
var initRightSize
var initLeftSize


var _main = null
var _gc = null
var _mg = null
var _hand = null
var _cards_layer = null
var active = false
var _waiting_action_applied = false
var _target_card_id = ""
var _target_card_face = null
var _phase = 0          # 0 = select, 1 = play
var _screen_size = Vector2(1920, 1080)
var steps = 10
var secondPhase = false
var shuffleAnimationTime = 2.5
var turnAnimationTime = 4.5
var waitTime = 0.5






func _ready():
	start()
	waitAnimations(shuffleAnimationTime)
	_find_nodes()
	_mg.step_delay_ms = 100
	_update_instruction(0)
	yield(get_tree(), "idle_frame")

	initTopPos = top.rect_position
	initBottomPos = bottom.rect_position
	initRightPos = right.rect_position
	initLeftPos = left.rect_position

	initTopSize = top.rect_size
	initBottomSize = bottom.rect_size
	initRightSize = right.rect_size
	initLeftSize = left.rect_size

func start():
	if  GlobalsUtilities.interactive_tutorial_done:
		return
	if active:
		return
	active = true
	visible = true
	

func waitAnimations(time = waitTime):
	mouse_filter = Control.MOUSE_FILTER_STOP
	yield(get_tree().create_timer(time), "timeout")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _node(root, path):
	if root == null:
		return null
	return root.get_node_or_null(path)


func _find_nodes():
	_main = get_parent()
	print("TUT MAIN: ",_main.name)
	_gc = _node(_main, "GameController")
	_mg = _node(_gc, "ManualGame")
	_hand = _node(_main, "HandPresenter")
	_cards_layer = _node(_main, "GameArea/LocalPlayerArea/PlayerHand/CardsLayer")
	if _gc != null and _gc.has_signal("action_applied"):
		_gc.connect("action_applied", self, "_on_action_applied")
	if _hand != null and _hand.has_signal("card_selected"):
		_hand.connect("card_selected", self, "_on_card_selected")

func _screen_size():
	var s = get_viewport().get_size()
	if (s.x <= 1.0 or s.y <= 1.0) and _main != null:
		s = _main.rect_size
	if s.x <= 1.0 or s.y <= 1.0:
		s = Vector2(1920, 1080)
	return s




func _on_card_selected(card_id):
	if not active:
		return
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_on_action_click("card_selected", card_id)



func _on_action_applied(result):
	if not active:
		return
	var is_player_1 = false
	var currentAction
	for event in result.get("events", []):
		if event.get("player_id", "") == "player_1":
			is_player_1 = true
			currentAction = event.get("type", "")
			break
	if not is_player_1:
		return
		
	print("_phase: ", _phase)
	print("currentAction: ", currentAction)
	if currentAction == "card_played":
		print("CARD PLAYED")
		_on_action_click("card_played", result)
	elif currentAction == "card_changed":
		_on_action_click("card_changed", result)
		
		
	elif currentAction == "turn_changed":
		if _phase == steps:
			print("FINISH")
			yield(get_tree().create_timer(2.0), "timeout")
			_finish()
			return
		print("turn_changed")
		return
	else:
		_on_action_click("action_applied", result)
	
#	print("=== ACTION APPLIED ===")
#	for event in result.get("events", []):
#		print("EVENT TYPE: ", event.get("type", ""))
#		print("EVENT DATA: ", event)



func _on_action_click(event_type, data = null):
	if not active:
		return
	if secondPhase:
		return

	if event_type == "card_selected":
		print("SELECTED")
#		if _waiting_action_applied:
#			print("WAIT")
#			return
		_phase = _phase + 1
		call_deferred("_rebuild_mask")
		_waiting_action_applied = true
	elif event_type == "card_changed":
		print("CHANGED")
		_phase = _phase + 1
		call_deferred("_rebuild_mask")
	elif event_type == "card_played":
		print("PLAYED")
		if _waiting_action_applied and _phase != 6:
			print("WAIT")
			return
		_phase = _phase + 1
		call_deferred("_rebuild_mask")
	elif event_type == "action_applied":
		print("ACTION")
		if not _waiting_action_applied:
			_phase = _phase + 1
			call_deferred("_rebuild_mask")
			return
		_waiting_action_applied = false


func _set_initial_mask():
	top.rect_position = initTopPos
	top.rect_size = initTopSize

	bottom.rect_position = initBottomPos
	bottom.rect_size = initBottomSize

	right.rect_position = initRightPos
	right.rect_size = initRightSize

	left.rect_position = initLeftPos
	left.rect_size = initLeftSize


func _update_instruction(phase):
	if _msg_label == null:
		return
	_msg_label.text = tr("INIT_TUT_PHASE"+str(phase))

func _rebuild_mask():
	if not active:
		return
	if _phase == 0:
		var offset = 0
		waitAnimations()
	elif _phase == 1:
#		print("### PHASE 1")
		var offset = 35
		top.rect_size.y = initTopSize.y - offset
		bottom.rect_size.y = initBottomSize.y + offset
		bottom.rect_position.y = initBottomPos.y - offset
		right.rect_position.y = initRightPos.y - offset
		left.rect_position.y = initLeftPos.y - offset
		_update_instruction(_phase)
		waitAnimations()
	elif _phase == 2:
#		print("### PHASE 2")
		_set_initial_mask()
		_update_instruction(_phase)
		waitAnimations(turnAnimationTime)
		print("wait turn")
	elif _phase == 3:
		if secondPhase:
#			print("### PHASE 3B")
			_set_initial_mask()
			var offset = 35
			var h_offset = 93
			var w_offset = 816
			var w_size = 105
			top.rect_size.y = initTopSize.y + h_offset
			right.rect_position.y = initRightPos.y + h_offset
			left.rect_position.y = initLeftPos.y + h_offset
			right.rect_size.y = initRightSize.y - h_offset - offset
			left.rect_size.y = initLeftSize.y - h_offset - offset
			bottom.rect_position.y = initBottomPos.y - offset
			bottom.rect_size.y = initBottomSize.y + offset
			right.rect_position.x = initRightPos.x + w_offset
			right.rect_size.x = initRightSize.x - w_offset
			left.rect_size.x = initLeftSize.x + w_offset - w_size
			_update_instruction(_phase)
			waitAnimations()
			secondPhase = false
		else:
#			print("### PHASE 3")
			var offset = 35
			top.rect_size.y = initTopSize.y - offset
			bottom.rect_size.y = initBottomSize.y + offset
			bottom.rect_position.y = initBottomPos.y - offset
			right.rect_position.y = initRightPos.y - offset
			left.rect_position.y = initLeftPos.y - offset
			secondPhase = true
			waitAnimations()
			call_deferred("_rebuild_mask")
	elif _phase == 4:
		print("### PHASE 4")
		_set_initial_mask()
		var offset = 184
		right.rect_position.x = initRightPos.x + offset
		left.rect_size.x = initLeftSize.x + offset
		_update_instruction(_phase)
		waitAnimations(turnAnimationTime)
		print("wait turn")
	elif _phase == 5:
		print("### PHASE 5")
		if secondPhase:
			_update_instruction(_phase)
			waitAnimations()
			secondPhase = false
		else:
			var offset = 35
			top.rect_size.y = initTopSize.y - offset
			bottom.rect_size.y = initBottomSize.y + offset
			bottom.rect_position.y = initBottomPos.y - offset
			right.rect_position.y = initRightPos.y - offset
			left.rect_position.y = initLeftPos.y - offset
			secondPhase = true
			_update_instruction(_phase)
			waitAnimations()
			call_deferred("_rebuild_mask")
	elif _phase == 6:
		print("### PHASE 6")
#		if secondPhase:
#			print("### PHASE 6b")
#			_update_instruction(_phase+1)
#			waitAnimations()
#			secondPhase = false
#		else:
#			print("### PHASE 6a")
		var offset = 0
		top.rect_size.y = initTopSize.y - offset
		bottom.rect_size.y = initBottomSize.y + offset
		bottom.rect_position.y = initBottomPos.y - offset
		right.rect_position.y = initRightPos.y - offset
		left.rect_position.y = initLeftPos.y - offset
		$InstructionLabel.rect_position.y = -100
		right.rect_size.x = 0
		left.rect_size.x = 1920
		_update_instruction(_phase)
		waitAnimations()
#			secondPhase = true
#			call_deferred("_rebuild_mask")
	elif _phase == 7:
		print("### PHASE 7")
		_set_initial_mask()
		var offset = 184
		right.rect_position.x = initRightPos.x + offset
		left.rect_size.x = initLeftSize.x + offset
		$InstructionLabel.rect_position.y = 250
		_update_instruction(_phase)
		waitAnimations(turnAnimationTime)
		print("wait turn")
	
	elif _phase == 8:
		print("### PHASE 8")
		var offset = 35
		top.rect_size.y = initTopSize.y - offset
		bottom.rect_size.y = initBottomSize.y + offset
		bottom.rect_position.y = initBottomPos.y - offset
		right.rect_position.y = initRightPos.y - offset
		left.rect_position.y = initLeftPos.y - offset
		_update_instruction(_phase)
		waitAnimations()
	elif _phase == 9:
		print("### PHASE 9")
		right.rect_size.x = 0
		left.rect_size.x = 1920
		_update_instruction(_phase)
		waitAnimations(turnAnimationTime)
		print("wait turn")
		_phase = _phase + 1



func _finish():
	if not active:
		return
	active = false
	if _msg_label != null:
		_msg_label.queue_free()
		_msg_label = null
	GlobalsUtilities.interactive_tutorial_done = true
	GlobalsUtilities.tutorialStarted = false
	GlobalsUtilities.gameStarted = false
	GlobalsUtilities.demoStarted = false
	GlobalsUtilities.SaveData()
	emit_signal("finished")
	visible = false



func _on_BackMenuButton_pressed():
	var ShuffleDeal = AudioManager.get_node("SFXPlayer/ShuffleDeal")
	AudioManager.stop_sfx(ShuffleDeal)
	get_tree().change_scene("res://MainMenu.tscn")
	GlobalsUtilities.gameStarted = false
