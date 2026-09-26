extends Control

onready var languageNode = $VBoxContainer/Language/HBoxContainer/currLanguage
onready var languageTitle = $VBoxContainer/Language/title
onready var delete_data_dialog = $DeleteSaveButton/DeleteConfirmPopup
onready var delete_data_bg = $DeleteSaveButton/DeleteDataBG
#onready var fullscreenNode = $VBoxContainer/Utility/FullscreenLabel/CheckFullScreen
#onready var musicNode = $VBoxContainer/Audio/MusicLabel/CheckMusic
#onready var SFXNode = $VBoxContainer/Audio/SFXLabel/CheckSFX

onready var origSpacingTop = languageTitle.get("custom_fonts/font").extra_spacing_top
onready var origSpacingChar = languageTitle.get("custom_fonts/font").extra_spacing_char
onready var origSize = languageTitle.get("custom_fonts/font").size



func _ready():
	var utilityNode = $VBoxContainer/Utility/
	var audioNode = $VBoxContainer/Audio/
	var SFXNode = $VBoxContainer/Audio/SFXLabel
	LoadFromData()
	if OS.get_name() == "Android":
		utilityNode.visible = false
		audioNode.rect_position.y = 65
		SFXNode.rect_position.y = 65
	_localize()
	GlobalsUtilities.connect("language_changed", self, "_on_language_changed")



func _localize():
	$VBoxContainer/Language/title.text = tr("OPT_LANGUAGE_LABEL")
	$VBoxContainer/Utility/FullscreenLabel.text = tr("OPT_FULLSCREEN")
	$VBoxContainer/Audio/MusicLabel.text = tr("OPT_MUSIC")
	$VBoxContainer/Audio/SFXLabel.text = tr("OPT_SFX")
	$BackMenuButton.text = tr("OPT_BACK")
	$DeleteSaveButton/btnLabel.text = tr("OPT_DELETE_BTN")
	_localize_popup()

func _localize_popup():
	delete_data_dialog.get_node("VBox/Label").text = tr("OPT_DELETE_DIALOG")
	delete_data_dialog.get_node("VBox/BtnRow/ConfirmYesBtn").text = tr("YES")
	delete_data_dialog.get_node("VBox/BtnRow/ConfirmNoBtn").text = tr("NO")

func _on_language_changed(_locale):
	_localize()
	_localize_popup()
	
	


func _on_delete_data_confirmed():
	delete_data_bg.visible = false
	delete_data_dialog.visible = false
#	delete_data_dialog.popup()
	GlobalsUtilities.DeleteSavedData()

func _on_delete_data_cancelled():
	delete_data_bg.visible = false
	delete_data_dialog.visible = false
#	delete_data_dialog.popup()


func _on_DeleteSaveButton_pressed():
	delete_data_bg.visible = true
	delete_data_dialog.popup_centered()





func LoadFromData():
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
		GlobalsUtilities._write_stats_to_config()
	






func _on_set_language(operSymbol, lang):
	var idx = GlobalsUtilities.language.find(str(lang))
	if idx < 0:
		idx = 0
	idx = idx + operSymbol
	if idx < 0:
		idx = GlobalsUtilities.language.size() - 1
	elif idx >= GlobalsUtilities.language.size():
		idx = 0
	var new_name = GlobalsUtilities.language[idx]
	GlobalsUtilities.set_language(new_name)
	if GlobalsUtilities.config != null:
		GlobalsUtilities.config.set_value("LANGUAGE", "language", new_name)
	GlobalsUtilities.SaveData()

func _on_Next_pressed():
	_on_set_language(1, GlobalsUtilities.currLanguage)
	languageNode.text = GlobalsUtilities.currLanguage


func _on_Prev_pressed():
	_on_set_language(-1, GlobalsUtilities.currLanguage)
	languageNode.text = GlobalsUtilities.currLanguage


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




func _on_ConfirmYesBtn_pressed():
	_on_delete_data_confirmed()


func _on_ConfirmNoBtn_pressed():
	_on_delete_data_cancelled()
