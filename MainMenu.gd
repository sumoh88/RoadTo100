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
	_localize()
	GlobalsUtilities.connect("language_changed", self, "_on_language_changed")

func _localize():
	$ButtonsArea/Play/Label.text = tr("MENU_PLAY")
	$ButtonsArea/Play/Label/LabelSmall.text = tr("MENU_PLAY_SUB")
	$ButtonsArea/Stats/Label.text = tr("MENU_STATS")
	$ButtonsArea/Online/Label.text = tr("MENU_ONLINE")
	$ButtonsArea/Tutorial/Label.text = tr("MENU_HOW_TO_PLAY")
	$ButtonsArea/Shop/Label.text = tr("MENU_SHOP")
	$ButtonsArea/Options/Label.text = tr("MENU_OPTIONS")
	$ExitGame.text = tr("MENU_QUIT")

func _on_language_changed(_locale):
	_localize()



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
