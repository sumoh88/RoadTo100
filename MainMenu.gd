extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
func _ready():
	if not GlobalsUtilities.splash_shown:
		print("WEFIOWRMIFIMEMFOWEPC")
		GlobalsUtilities.splash_shown = true
		get_tree().change_scene("res://SplashScreen.tscn")
		return
	AudioManager.set_menu_music()
	
func _on_Play_pressed():
	GlobalsUtilities.demoStarted = false
	GlobalsUtilities.gameStarted = true
	get_tree().change_scene("res://Main.tscn")
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_ExitGame_pressed():
	get_tree().quit()


func _on_Tutorial_pressed():
	GlobalsUtilities.gameStarted = false
	GlobalsUtilities.demoStarted = true
	get_tree().change_scene("res://Main.tscn")
