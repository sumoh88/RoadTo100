extends Node

# CardAnimator — skeleton for card movement tween animations.
# Full queue implementation in Passaggio E.

signal animation_finished()

var _animation_layer = null
var _tween = null
var _busy = false


func _ready():
	_animation_layer = _find_node_by_name(get_parent(), "CardAnimationLayer")
	if _animation_layer == null:
		_animation_layer = _find_node_by_name(get_parent().get_parent(), "CardAnimationLayer")
	_tween = Tween.new()
	add_child(_tween)


func _find_node_by_name(parent, name):
	if parent == null: return null
	for c in parent.get_children():
		if c.name == name: return c
	return null


func is_animating():
	return _busy
