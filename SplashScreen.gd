extends Control

const FADE_IN_TIME = 0.7
const DISPLAY_TIME = 1.5
const FADE_OUT_TIME = 0.7

onready var logo = $LogoCont/Logo
onready var bg = $LogoCont/bg

var skip = false
var playing = false


func _ready():
	logo.modulate.a = 0
	fade_in()


func _process(_delta):
	if is_any_key_pressed():
		skip = true

		if playing:
			finish_splash()


func is_any_key_pressed():
	for action in InputMap.get_actions():
		if Input.is_action_just_pressed(action):
			return true

	return false


func fade_in():
	playing = true

	if skip:
		finish_splash()
		return

	var tween = Tween.new()
	add_child(tween)

	tween.interpolate_property(
		logo,
		"modulate:a",
		0,
		1,
		FADE_IN_TIME,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN
	)

	tween.connect("tween_all_completed", self, "_on_fade_in_complete")
	tween.start()


func _on_fade_in_complete():
	if skip:
		finish_splash()
		return

	yield(get_tree().create_timer(DISPLAY_TIME), "timeout")

	if skip:
		finish_splash()
		return

	fade_out()


func fade_out():
	var tween = Tween.new()
	add_child(tween)

	tween.interpolate_property(
		logo,
		"modulate:a",
		1,
		0,
		FADE_OUT_TIME,
		Tween.TRANS_LINEAR,
		Tween.EASE_OUT
	)

	tween.connect("tween_all_completed", self, "finish_splash")
	tween.start()


func finish_splash():
	set_process(false)
	logo.visible = false
	bg.visible = false

	get_tree().call_deferred("change_scene", "res://MainMenu.tscn")
