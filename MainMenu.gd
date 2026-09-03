extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
func _ready():
	AudioManager.set_menu_music()
	
func _on_Play_pressed():
	get_tree().change_scene("res://Main.tscn")
	GlobalsUtilities.gameStarted = true
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
