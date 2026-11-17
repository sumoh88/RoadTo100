extends Node
# Isolate: does add_child(main) complete?

func _ready():
	var main = load("res://Main.tscn").instance()
	add_child(main)
	var f = File.new()
	f.open("res://tests/_dbg.txt", FILE_WRITE)
	f.write("MAIN LOADED OK\n")
	f.close()
	get_tree().quit(0)
