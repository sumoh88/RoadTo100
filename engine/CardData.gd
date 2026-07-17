extends Reference
class_name CardData

# Mirrors simulator/domain/card.py
# - card_id: unique identifier
# - name: human-readable name
# - value: optional numeric value (int or null)
# - color: category/color
# - metadata: additional arbitrary dictionary

var card_id = ""
var name = ""
var value = null   # int or null
var color = ""
var metadata = {}

func _init(p_card_id = "", p_name = "", p_value = null, p_color = "", p_metadata = {}):
	card_id = p_card_id
	name = p_name
	value = p_value
	color = p_color
	metadata = p_metadata.duplicate()
