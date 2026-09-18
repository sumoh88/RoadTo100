extends Control

#onready var languageNode = $VBoxContainer/Language/HBoxContainer/currLanguage
#onready var fullscreenNode = $VBoxContainer/Utility/FullscreenLabel/CheckFullScreen
#onready var musicNode = $VBoxContainer/Audio/MusicLabel/CheckMusic
#onready var SFXNode = $VBoxContainer/Audio/SFXLabel/CheckSFX



func _ready():
	LoadFromData()

func LoadFromData():
	var languageNode = $VBoxContainer/Language/HBoxContainer/currLanguage
	var fullscreenNode = $VBoxContainer/Utility/FullscreenLabel/CheckFullScreen
	var musicNode = $VBoxContainer/Audio/MusicLabel/CheckMusic
	var SFXNode = $VBoxContainer/Audio/SFXLabel/CheckSFX
	var data = GlobalsUtilities.config.load(GlobalsUtilities.config_path)
	if data == OK:
		print("LOAD IF")
		var language = GlobalsUtilities.config.get_value("LANGUAGE", "language", "Italiano")
		var fullscreen = GlobalsUtilities.config.get_value("SCREEN", "fullscreen", true)
		var music_volume = GlobalsUtilities.config.get_value("AUDIO", "music_volume", 0.6)
		var sfx_volume = GlobalsUtilities.config.get_value("AUDIO", "sfx_volume", 0.4)
		languageNode.text = language
		fullscreenNode.pressed = fullscreen
		musicNode.value = music_volume * 10
		SFXNode.value = sfx_volume * 10
		_on_set_language(0, language)
		_on_CheckFullScreen_toggled(fullscreen)
		_on_CheckMusic_value_changed(music_volume * 10)
		_on_CheckSFX_value_changed(sfx_volume * 10)
	else:
		print("LOAD ELSE")
		var language = GlobalsUtilities.config.get_value("LANGUAGE", "language", "Italiano")
		var fullscreen = GlobalsUtilities.config.get_value("SCREEN", "fullscreen", true)
		var music_volume = GlobalsUtilities.config.get_value("AUDIO", "music_volume", 0.6)
		var sfx_volume = GlobalsUtilities.config.get_value("AUDIO", "sfx_volume", 0.4)
		languageNode.text = language
		fullscreenNode.pressed = fullscreen
		musicNode.value = music_volume *10
		SFXNode.value = sfx_volume *10
	




func _on_set_language(opSymbol, lang):
	if GlobalsUtilities.config != null:
		GlobalsUtilities.config.set_value("LANGUAGE", "language", lang)
	var langIndex = GlobalsUtilities.language.find(GlobalsUtilities.currLanguage)
	langIndex = langIndex+opSymbol
	if langIndex < 0:
		langIndex = GlobalsUtilities.language.size()-1
	elif langIndex > GlobalsUtilities.language.size()-1:
		langIndex = 0
	GlobalsUtilities.languageNode.text = GlobalsUtilities.language[langIndex]
	GlobalsUtilities.currLanguage = GlobalsUtilities.languageNode.text

func _on_Next_pressed():
	_on_set_language(1, GlobalsUtilities.currLanguage)


func _on_Prev_pressed():
	_on_set_language(-1, GlobalsUtilities.currLanguage)



func _on_BackMenuButton_pressed():
	GlobalsUtilities.SaveData()
	get_tree().change_scene("res://MainMenu.tscn")
	GlobalsUtilities.gameStarted = false


func _on_CheckFullScreen_toggled(button_pressed):
	if GlobalsUtilities.config != null:
		GlobalsUtilities.config.set_value("SCREEN", "fullscreen", button_pressed)
	GlobalsUtilities.fullscreen = button_pressed
	OS.window_fullscreen = button_pressed


func _on_CheckMusic_value_changed(value):
	var bus = AudioServer.get_bus_index("Music")
	print("mValue: ", value)
	GlobalsUtilities.config.set_value("AUDIO", "music_volume", value/10)
	AudioServer.set_bus_volume_db(bus, linear2db(value/10))


func _on_CheckSFX_value_changed(value):
	var bus = AudioServer.get_bus_index("SFX")
	print("sValue: ", value)
	GlobalsUtilities.config.set_value("AUDIO", "sfx_volume", value/10)
	AudioServer.set_bus_volume_db(bus, linear2db(value/10))
