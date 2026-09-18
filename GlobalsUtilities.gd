extends Node

onready var sr_active = false
onready var music_play = true
onready var sfx_play = true
onready var fullscreen = true
onready var selected_value = ""
onready var gameStarted = false
onready var demoStarted = false
onready var tutorialStarted = false
onready var plateValue = 0
onready var language = ["Italiano", "English"]
onready var currLanguage = "Italiano"

var splash_shown = false

const THRESHOLD_PIANO: int = 30
const THRESHOLD_CELLO: int = 60
const THRESHOLD_VIOLIN: int = 89

var font_data = load("res://fonts/Dyuthi.ttf")

onready var options = load("res://OptionMenu.tscn").instance()
onready var languageNode = options.get_node("VBoxContainer/Language/HBoxContainer/currLanguage")
onready var fullscreenNode = options.get_node("VBoxContainer/Utility/FullscreenLabel/CheckFullScreen")
onready var musicNode = options.get_node("VBoxContainer/Audio/MusicLabel/CheckMusic")
onready var SFXNode = options.get_node("VBoxContainer/Audio/SFXLabel/CheckSFX")
onready var config = ConfigFile.new()
var exe_dir = OS.get_executable_path().get_base_dir()

var config_path



func setCustomFont(currNode, size, spacing = 0, spacingTop = 12):
	if font_data != null:
		var dyn_font = DynamicFont.new()
		dyn_font.font_data = font_data
		dyn_font.size = size
		dyn_font.outline_size = 2
		dyn_font.outline_color = Color(0, 0, 0, 1)
		dyn_font.extra_spacing_top = spacingTop
		dyn_font.use_filter = true
		dyn_font.use_mipmaps = true
		dyn_font.extra_spacing_char = spacing
		currNode.add_font_override("font", dyn_font)



func setCustomStyle(currNode, type, image):
	var styleN = StyleBoxTexture.new()
	var styleD = StyleBoxTexture.new()
	var styleP = StyleBoxTexture.new()
	var styleH = StyleBoxTexture.new()
	var styleF = StyleBoxEmpty.new()
	var imgPath = "res://imgs/"+image+".png"
	
	styleN.texture = load(imgPath)
	currNode.add_stylebox_override(type, styleN)

	styleD.texture = load("res://imgs/btnDisabled.png")
	currNode.add_stylebox_override("disabled", styleD)

	styleP.texture = load("res://imgs/btnPressed.png")
	currNode.add_stylebox_override("pressed", styleP)

	styleH.texture = load("res://imgs/btnChange.png")
	currNode.add_stylebox_override("hover", styleD)
	
	currNode.add_stylebox_override("focus", styleF)
	
func setBtnStyle(currNode):
	var styleN = StyleBoxTexture.new()
	var styleD = StyleBoxTexture.new()
	var styleP = StyleBoxTexture.new()
	var styleH = StyleBoxTexture.new()
	var styleF = StyleBoxEmpty.new()
	
	styleN.texture = load("res://imgs/btnChoice.png")
	currNode.add_stylebox_override("normal", styleN)
	
	styleD.texture = load("res://imgs/btnChoice.png")
	currNode.add_stylebox_override("disabled", styleD)

	styleP.texture = load("res://imgs/btnChoicePressed.png")
	currNode.add_stylebox_override("pressed", styleP)

	styleH.texture = load("res://imgs/btnChoiceHover.png")
	currNode.add_stylebox_override("hover", styleH)
	
	currNode.add_stylebox_override("focus", styleF)
	
	
	


func SaveData():
	print("SAVE")
	config.save(GlobalsUtilities.config_path)

func LoadSavedData():
	print("G LOAD IF ", OS.get_name())
	
	if OS.get_name() == "Android":
		config_path = "user://RT100.cfg"
	else:
		config_path = OS.get_executable_path().get_base_dir().plus_file("RT100.cfg")
	var data = config.load(config_path)
	if data == OK:
		var lang = config.get_value("LANGUAGE", "language", currLanguage)
		var fs_value = config.get_value("SCREEN", "fullscreen", fullscreen)
		var music_volume = config.get_value("AUDIO", "music_volume", 0.6)
		var sfx_volume = config.get_value("AUDIO", "sfx_volume", 0.4)
		OS.window_fullscreen = fs_value
		options._on_set_language(0, lang)
		options._on_CheckFullScreen_toggled(fs_value)
		options._on_CheckMusic_value_changed(music_volume * 10)
		options._on_CheckSFX_value_changed(sfx_volume * 10)
	else:
		print("G LOAD ELSE")
		options._on_set_language(0, currLanguage)
		options._on_CheckFullScreen_toggled(fullscreen)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(0.6))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(0.4))
