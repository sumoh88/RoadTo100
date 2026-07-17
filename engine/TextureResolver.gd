extends Reference

# Centralized card texture resolution.
# Convention: res://imgs/{prefix}{value}.png
#   inc  → inc{value}.png  (e.g. inc9.png, incJolly.png)
#   gold → gold{value}.png (e.g. gold23.png)
#   spe  → spe{value}.png  (e.g. spe89.png, spe+11.png)
#   imb  → imb.png
# Special assets (not cards):
#   cardback.png, cardbackplate.png, table.png, plate.png

const BASE = "res://imgs/"

var _fallback = null

func _init():
	_fallback = load(BASE + "cardback.png")

func path(card_dict):
	"""Return the texture path for a card dict, or null."""
	if card_dict == null:
		return null
	var t = str(card_dict.get("card_type", ""))
	var n = str(card_dict.get("name", ""))
	var v = card_dict.get("value", null)

	# Fixed filenames
	if t == "imbroglio":
		return BASE + "imb.png"

	# Named lookup
	if n == "Jolly" or t == "jolly":
		return BASE + "incJolly.png"
	if n == "89":
		return BASE + "spe89.png"
	if n == "+11":
		return BASE + "spe+11.png"

	# Prefix + value
	var prefix = ""
	if t == "increment" or t == "jolly": prefix = "inc"
	elif t == "gold": prefix = "gold"
	elif t == "special": prefix = "spe"
	else: return null

	if v != null:
		return BASE + prefix + str(v) + ".png"

	return null

func texture(card_dict):
	"""Return a loaded Texture for the given card dict, or fallback."""
	var p = path(card_dict)
	if p != null and ResourceLoader.exists(p):
		return load(p)
	return _fallback
