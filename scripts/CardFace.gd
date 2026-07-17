extends TextureRect

# CardFace — purely visual card representation.
# Loads textures from the centralized TextureResolver.
# Does NOT know game rules, hand logic, or networking.
#
# Usage:
#   var card = preload("res://scenes/CardFace.tscn").instance()
#   card.set_card(card_dict, false)  # show face
#   card.set_card(card_dict, true)   # show back

signal clicked(card_id)

var card_id = ""
var _resolver = null
var _texture_loaded = false

func _ready():
	if _resolver == null:
		_resolver = load("res://engine/TextureResolver.gd").new()
	if !_texture_loaded:
		texture = _resolver.texture(null)

func set_card(card_dict, show_back = false):
	"""Set the card face from a card dict (serialized card data).
	If show_back is true, always shows cardback regardless of card data.
	"""
	if _resolver == null:
		_resolver = load("res://engine/TextureResolver.gd").new()

	card_id = card_dict.get("card_id", "") if card_dict != null else ""
	_texture_loaded = true

	if show_back:
		texture = load("res://imgs/cardback.png")
	else:
		texture = _resolver.texture(card_dict)

func set_card_back():
	"""Shortcut to display the card back."""
	card_id = ""
	_texture_loaded = true
	texture = load("res://imgs/cardback.png")

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		emit_signal("clicked", card_id)
