extends Node
# HandPresenter — manages the local player's hand cards.
# Creates/destroys CardFace instances. Does NOT contain game rules.

const CARD_FACE = preload("res://scenes/CardFace.tscn")
var _cards_layer = null
var _interaction_blocker = null
var _card_faces = []

func _ready():
	var m = _node_up("Main")
	if m == null: return
	var ga = _child(m, "GameArea")
	if ga == null: return
	var la = _child(ga, "LocalPlayerArea")
	if la == null: return
	var h = _child(la, "PlayerHand")
	if h == null: return
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
	_clear()
	var tw = max(1, _cards_layer.rect_size.x)
	var cw = 201; var sp = 15; var n = hd.size()
	var sx = max(0, (tw - (n * cw + max(0, n-1) * sp)) / 2)
	var yp = max(0, (_cards_layer.rect_size.y - 282) / 2)
	for i in range(n):
		var c = CARD_FACE.instance()
		c.name = "HC" + str(i); c.set_card(hd[i], false)
		c.rect_position = Vector2(sx + i * (cw + sp), yp)
		_cards_layer.add_child(c); _card_faces.append(c)

func _clear():
	for c in _card_faces:
		if is_instance_valid(c): c.queue_free()
	_card_faces.clear()

func diagnose():
	print("Hand: layer=" + str(_cards_layer != null) + " children=" + str(_cards_layer.get_child_count() if _cards_layer != null else 0))
func _diagnose_nodes():
	return " cards=" + str(_cards_layer.get_child_count() if _cards_layer != null else 0)
