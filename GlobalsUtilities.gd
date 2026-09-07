extends Node

onready var sr_active = false
onready var selected_value = ""
onready var gameStarted = false
onready var plateValue = 0

var splash_shown = false

const THRESHOLD_PIANO: int = 30
const THRESHOLD_CELLO: int = 60
const THRESHOLD_VIOLIN: int = 89

var font_data = load("res://fonts/Dyuthi.ttf")


func setCustomFont(currNode, size, spacing = 0):
	if font_data != null:
		var dyn_font = DynamicFont.new()
		dyn_font.font_data = font_data
		dyn_font.size = size
		dyn_font.extra_spacing_top = 12
		dyn_font.use_filter = true
		dyn_font.use_mipmaps = true
		dyn_font.extra_spacing_char = spacing
		currNode.add_font_override("font", dyn_font)



func setCustomStyle(currNode):
	var styleN = StyleBoxTexture.new()
	var styleD = StyleBoxTexture.new()
	var styleP = StyleBoxTexture.new()
	var styleH = StyleBoxTexture.new()
	
	styleN.texture = load("res://imgs/btnChoice.png")
	currNode.add_stylebox_override("normal", styleN)
	
	styleD.texture = load("res://imgs/btnChoice.png")
	currNode.add_stylebox_override("disabled", styleD)
	
	styleP.texture = load("res://imgs/btnChoicePressed.png")
	currNode.add_stylebox_override("pressed", styleP)
	
	styleH.texture = load("res://imgs/btnChoiceHover.png")
	currNode.add_stylebox_override("hover", styleH)
