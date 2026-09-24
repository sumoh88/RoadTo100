extends Control

func _ready():
	GlobalsUtilities.tutorialStarted = false
	if not GlobalsUtilities.splash_shown:
		GlobalsUtilities.splash_shown = true
		get_tree().change_scene("res://SplashScreen.tscn")
		return
	AudioManager.set_menu_music()
	var optionMenu = load("res://OptionMenu.tscn").instance()
	var langNode = optionMenu.get_node("VBoxContainer/Language/HBoxContainer/currLanguage")
	langNode.text = GlobalsUtilities.currLanguage
	print("__________________ LANG: ", langNode.text)



func _on_Play_pressed():
	GlobalsUtilities.demoStarted = false
	GlobalsUtilities.gameStarted = true
	GlobalsUtilities.SaveData()
	get_tree().change_scene("res://Main.tscn")
	
func _on_Stats_pressed():
	get_tree().change_scene("res://Stats.tscn")

func _on_Online_pressed():
	pass # disabled

func _on_Tutorial_pressed():
	GlobalsUtilities.gameStarted = false
	GlobalsUtilities.demoStarted = false
	GlobalsUtilities.tutorialStarted = true
	get_tree().change_scene("res://Main.tscn")

func _on_Shop_pressed():
	pass # disabled

func _on_Options_pressed():
	get_tree().change_scene("res://OptionMenu.tscn")

func _on_ExitGame_pressed():
	get_tree().quit()
