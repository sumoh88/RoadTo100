extends Control




# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
func _ready():
	if GlobalsUtilities.tutorialStarted:
		GlobalsUtilities.tutorialStarted = false
		var tc = _ensure_tutorial_controller()
		if tc != null and tc.has_method("start_tutorial"):
			if tc.has_signal("tutorial_finished"):
				tc.connect("tutorial_finished", self, "_on_tutorial_finished")
			tc.start_tutorial()
	elif GlobalsUtilities.gameStarted:
		GlobalsUtilities.gameStarted = false
		$StartGameButton.emit_signal("pressed")
	elif GlobalsUtilities.demoStarted:
		GlobalsUtilities.gameStarted = false
		$DemoButton.emit_signal("pressed")

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
	get_tree().change_scene("res://MainMenu.tscn")
	GlobalsUtilities.gameStarted = false
