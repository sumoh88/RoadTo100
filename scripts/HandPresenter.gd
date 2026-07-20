extends Node
# HandPresenter — manages the local player's hand cards.
# Creates/destroys CardFace instances. Does NOT contain game rules.

signal card_selected(card_id)

const CARD_FACE = preload("res://scenes/CardFace.tscn")
const SELECT_RISE = -40

var _cards_layer = null
var _interaction_blocker = null
var _card_faces = []
var _selected_card_id = ""
var _card_original_positions = {}  # card_id -> Vector2


func _ready():
	var m = _node_up("Main")
	if m == null: return
	var ga = _child(m, "GameArea"); if ga == null: return
	var la = _child(ga, "LocalPlayerArea"); if la == null: return
	var h = _child(la, "PlayerHand"); if h == null: return
	_cards_layer = _child(h, "CardsLayer")
	_interaction_blocker = _child(h, "InteractionBlocker")


func _node_up(name):
	var p = get_parent()
	while p != null and p.name != name: p = p.get_parent()
	return p


func _child(p, name):
	if p == null: return null
	for c in p.get_children():
		if c.name == name: return c
	return null


func apply_snapshot(s):
	if s == null or _cards_layer == null: return
	var lid = s.get("local_player_id", "player_1")
	var hd = []
	for p in s.get("players", []):
		if p.get("id", "") == lid: hd = p.get("hand", []); break
	var prev_selected = _selected_card_id
	_clear()
	_selected_card_id = ""
	_card_original_positions = {}
	var tw = max(1, _cards_layer.rect_size.x)
	var cw = 201; var sp = 15; var n = hd.size()
	var sx = max(0, (tw - (n * cw + max(0, n-1) * sp)) / 2)
	var yp = max(0, (_cards_layer.rect_size.y - 282) / 2)
	for i in range(n):
		var c = CARD_FACE.instance()
		c.name = "HC" + str(i)
		c.set_card(hd[i], false)
		var pos = Vector2(sx + i * (cw + sp), yp)
		c.rect_position = pos
		_card_original_positions[c.card_id] = pos
		c.connect("clicked", self, "_on_card_face_clicked")
		_cards_layer.add_child(c)
		_card_faces.append(c)
	# Preserve selection if the card still exists in the new hand
	if prev_selected != "" and _card_original_positions.has(prev_selected):
		_selected_card_id = prev_selected
		_update_highlight()


func _clear():
	for c in _card_faces:
		if is_instance_valid(c): c.queue_free()
	_card_faces.clear()


# ---------------------------------------------------------------------------
# CardFace click relay
# ---------------------------------------------------------------------------

func _on_card_face_clicked(card_id):
	emit_signal("card_selected", card_id)


# ---------------------------------------------------------------------------
# Selection visual management
# ---------------------------------------------------------------------------

func set_selected(card_id):
	_selected_card_id = card_id
	_update_highlight()


func clear_selection():
	_selected_card_id = ""
	_update_highlight()


func get_selected_card_id():
	return _selected_card_id


func _update_highlight():
	# Restore all cards to original positions
	for c in _card_faces:
		if is_instance_valid(c) and _card_original_positions.has(c.card_id):
			c.rect_position = _card_original_positions[c.card_id]
	# Raise the selected card
	if _selected_card_id != "":
		for c in _card_faces:
			if is_instance_valid(c) and c.card_id == _selected_card_id:
				var orig = _card_original_positions.get(c.card_id, c.rect_position)
				c.rect_position = Vector2(orig.x, orig.y + SELECT_RISE)
				break


func diagnose():
	print("Hand: layer=" + str(_cards_layer != null) + " children=" + str(_cards_layer.get_child_count() if _cards_layer != null else 0))
func _diagnose_nodes():
	return " cards=" + str(_cards_layer.get_child_count() if _cards_layer != null else 0)
