extends Control

onready var languageNode = $Language/HBoxContainer/currLanguage
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	languageNode.text = GlobalsUtilities.currLanguage
	$Audio/CheckMusic.pressed = GlobalsUtilities.music_play
	$Audio/CheckSFX.pressed = GlobalsUtilities.sfx_play
	$Utility/CheckFullScreen.pressed = GlobalsUtilities.fullscreen

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func setLangIndex(opSymbol):
	var langIndex = GlobalsUtilities.language.find(GlobalsUtilities.currLanguage)
	langIndex = langIndex+opSymbol
	if langIndex < 0:
		langIndex = GlobalsUtilities.language.size()-1
	elif langIndex > GlobalsUtilities.language.size()-1:
		langIndex = 0
	languageNode.text = GlobalsUtilities.language[langIndex]
	GlobalsUtilities.currLanguage = languageNode.text

func _on_Next_pressed():
	setLangIndex(1)


func _on_Prev_pressed():
	setLangIndex(-1)



func _on_BackMenuButton_pressed():
	get_tree().change_scene("res://MainMenu.tscn")
	GlobalsUtilities.gameStarted = false


func _on_CheckMusic_toggled(button_pressed):
	GlobalsUtilities.music_play = button_pressed
	AudioManager.set_music_enabled(!button_pressed)

func _on_CheckSFX_toggled(button_pressed):
	GlobalsUtilities.sfx_play = button_pressed
	AudioManager.set_sfx_enabled(!button_pressed)


func _on_CheckFullScreen_toggled(button_pressed):
	GlobalsUtilities.fullscreen = button_pressed
	OS.window_fullscreen = button_pressed
