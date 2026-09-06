extends Control




# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
func _ready():
	if GlobalsUtilities.gameStarted: 
		$StartGameButton.emit_signal("pressed")

func _on_BackMenuButton_pressed():
	get_tree().change_scene("res://MainMenu.tscn")
	GlobalsUtilities.gameStarted = false
