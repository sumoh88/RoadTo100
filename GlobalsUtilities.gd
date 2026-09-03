extends Node

onready var sr_active = false
onready var selected_value = ""
onready var gameStarted = false
onready var plateValue = 0


const THRESHOLD_PIANO: int = 30
const THRESHOLD_CELLO: int = 60
const THRESHOLD_VIOLIN: int = 89
