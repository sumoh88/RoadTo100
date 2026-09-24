extends Control

#onready var languageNode = $VBoxContainer/Language/HBoxContainer/currLanguage
#onready var fullscreenNode = $VBoxContainer/Utility/FullscreenLabel/CheckFullScreen
#onready var musicNode = $VBoxContainer/Audio/MusicLabel/CheckMusic
#onready var SFXNode = $VBoxContainer/Audio/SFXLabel/CheckSFX
onready var delete_data_dialog = $DeleteSaveButton/ConfirmationDialog
onready var delete_data_bg = $DeleteSaveButton/DeleteDataBG

func _ready():
	var utilityNode = $VBoxContainer/Utility/
	var audioNode = $VBoxContainer/Audio/
	var SFXNode = $VBoxContainer/Audio/SFXLabel
	LoadFromData()
	if OS.get_name() == "Android":
		utilityNode.visible = false
		audioNode.rect_position.y = 65
		SFXNode.rect_position.y = 65
	delete_btn_init()
		
		
func delete_btn_init():
	var main = load("res://Main.tscn").instance()
	var reset_popup = main.get_node("OverlayLayer/HandResetPopup")
	var reset_popup_btns = $DeleteSaveButton
	
	var style = reset_popup.get_stylebox("panel")
	var styleBtn = reset_popup_btns.get_stylebox("normal")
	var styleBtnHover = reset_popup_btns.get_stylebox("hover")
	var styleBtnPressed = reset_popup_btns.get_stylebox("pressed")
	var btn = delete_data_dialog.get_node("get_ok")
	

	delete_data_dialog.add_stylebox_override("panel", style)
	delete_data_dialog.window_title = ""
	delete_data_dialog.dialog_text = "     Sei sicuro di voler cancellare tutti i dati salvati?     "
	delete_data_dialog.get_ok().text = "     Sicuro     "
	delete_data_dialog.get_cancel().text = "     Annulla     "
	
	delete_data_dialog.get_ok().add_stylebox_override("normal", styleBtn)
	delete_data_dialog.get_cancel().add_stylebox_override("normal", styleBtn)
	delete_data_dialog.get_ok().add_stylebox_override("hover", styleBtnHover)
	delete_data_dialog.get_cancel().add_stylebox_override("hover", styleBtnHover)
	delete_data_dialog.get_ok().add_stylebox_override("pressed", styleBtnPressed)
	delete_data_dialog.get_cancel().add_stylebox_override("pressed", styleBtnPressed)
	var dialog_text = delete_data_dialog.get_label()
	dialog_text.align = Label.ALIGN_CENTER
	dialog_text.valign = Label.ALIGN_CENTER
	styleBtn.set_default_margin(MARGIN_TOP, 15)
	styleBtn.set_default_margin(MARGIN_BOTTOM, 10)
	styleBtnHover.set_default_margin(MARGIN_TOP, 15)
	styleBtnHover.set_default_margin(MARGIN_BOTTOM, 10)
	styleBtnPressed.set_default_margin(MARGIN_TOP, 15)
	styleBtnPressed.set_default_margin(MARGIN_BOTTOM, 10)
	delete_data_dialog.connect("confirmed", self, "_on_delete_data_confirmed")
	delete_data_dialog.get_cancel().connect("pressed", self, "_on_delete_data_cancelled")
	add_child(delete_data_dialog)
	
	


func _on_delete_data_confirmed():
	delete_data_bg.visible = false
	GlobalsUtilities.DeleteSavedData()

func _on_delete_data_cancelled():
	delete_data_bg.visible = false


func _on_DeleteSaveButton_pressed():
	delete_data_bg.visible = true
	delete_data_dialog.popup_centered()





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
		GlobalsUtilities._write_stats_to_config()
	






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


