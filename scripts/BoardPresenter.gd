extends Node
# BoardPresenter — updates board area, plateau stacking, opponent cards, rotations.
# Does NOT contain game rules.

const CARD_FACE = preload("res://scenes/CardFace.tscn")
const PLATE_TEXTURE = preload("res://imgs/plate.png")

# Per-seat data: {layer: Control, rotation_deg: int}
var _resolver = null
var _value_label = null
var _value_layer = null   # static ValueLayer — hidden, replaced by dynamic plate labels
var _draw_pile_count = null
var _discard_top = null
var _permanent_layer = null
var _permanent_back = null
var _plateau_value_card = null  # static Plate.png from scene — hidden, replaced by dynamic plates
var _opp_seats = []  # [{layer, rotation_deg}, ...]

func _ready():
	_resolver = load("res://engine/TextureResolver.gd").new()
	var m = _up("Main"); if m == null: return
	var ga = _ch(m, "GameArea"); if ga == null: return

	# Board area
	var brd = _ch(ga, "BoardArea")
	if brd != null:
		var pl = _ch(brd, "PlateauZone")
		if pl != null:
			_value_label = _rec(pl, "ValueLabel")
			_permanent_layer = _ch(pl, "PermanentCardsLayer")
			if _permanent_layer != null:
				_permanent_back = _ch(_permanent_layer, "PermanentCardBack")
			# Hide the static PlateauValueCard — dynamic plates inside
			# _permanent_layer now handle the visual representation.
			_plateau_value_card = _ch(pl, "PlateauValueCard")
			if _plateau_value_card != null:
				_plateau_value_card.visible = false
			# Hide the static ValueLayer — its Label duplicates the value
			# shown by dynamic plate labels and appears on top of Gold cards.
			_value_layer = _ch(pl, "ValueLayer")
			if _value_layer != null:
				_value_layer.visible = false
		_draw_pile_count = _ch(_ch(brd, "DrawPile"), "CountLabel")
		var dp = _ch(brd, "DiscardPile")
		if dp != null: _discard_top = _ch(dp, "TopCard")

	# Opponent seats: find CardsLayers, store seat data
	# NOTE: Do NOT set rect_pivot_offset or rect_rotation here in _ready,
	# because rect_size may not be finalized yet (can be 0,0) leading to
	# an incorrect pivot and visual misalignment.
	# Pivot and rotation are recalculated in _update_opponents() using the
	# actual runtime rect_size.
	var ol = _ch(ga, "OpponentsLayer")
	if ol != null:
		for pair in [["TopSeat", 180], ["LeftSeat", 90], ["RightSeat", -90]]:
			var s = _ch(ol, pair[0])
			if s != null:
				var cl = _ch(s, "CardsLayer")
				if cl != null:
					_opp_seats.append({"layer": cl, "rotation_deg": pair[1]})
				else:
					_opp_seats.append(null)
			else:
				_opp_seats.append(null)

func _up(name):
	var p = get_parent()
	while p != null and p.name != name: p = p.get_parent()
	return p
func _ch(p, name):
	if p == null: return null
	for c in p.get_children():
		if c.name == name: return c
	return null
func _rec(p, name):
	if p == null: return null
	if p.name == name: return p
	for c in p.get_children():
		var f = _rec(c, name); if f != null: return f
	return null

func apply_snapshot(s):
	if s == null: return
	if _value_label != null: _value_label.text = str(s.get("piatto", 0))
	if _draw_pile_count != null: _draw_pile_count.text = str(s.get("deck_count", 0))
	if _discard_top != null:
		var t = s.get("discard_top", null)
		if t != null: _discard_top.texture = _resolver.texture(t)
		else: _discard_top.texture = null
		_discard_top.visible = t != null
	var vstack = s.get("plateau_visual_stack", [])
	_update_plateau(vstack)
	_update_opponents(s.get("players", []))

func _update_plateau(stack):
	"""Rebuild the plateau visual stack from the provider's visual stack data.

	Each item is either:
	  {"type": "plate", "value": N}   — carta Piatto (value card)
	  {"type": "card", "card": {...}} — Gold/89 card face
	"""
	if _permanent_layer == null:
		return

	# Clear existing children (both card faces and plate cards)
	for c in _permanent_layer.get_children():
		if c.name.begins_with("SV") or c.name.begins_with("PL"):
			c.free()

	# Show/hide the permanent card back (cardbackplate.png)
	var has_card = false
	for item in stack:
		if item["type"] == "card":
			has_card = true
			break
	if _permanent_back != null:
		_permanent_back.visible = has_card

	# Rebuild the visual stack bottom to top
	for i in range(stack.size()):
		var item = stack[i]
		if item["type"] == "card":
			# Card face (Gold/89)
			var c = CARD_FACE.instance()
			c.name = "SV" + str(i)
			c.set_card(item["card"], false)
			c.rect_position = Vector2(0, 0)
			c.mouse_filter = 2
			_permanent_layer.add_child(c)
		elif item["type"] == "plate":
			# Carta Piatto (value card)
			var p = TextureRect.new()
			p.name = "PL" + str(i)
			p.texture = PLATE_TEXTURE
			p.expand = true
			p.mouse_filter = 2
			# Match PlateauValueCard dimensions from Main.tscn
			p.rect_min_size = Vector2(203, 292)
			p.rect_size = Vector2(203, 292)
			p.rect_position = Vector2(0, 0)

			# Value label overlay
			var lbl = Label.new()
			lbl.text = str(item["value"])
			lbl.align = Label.ALIGN_CENTER
			lbl.valign = Label.VALIGN_CENTER
			lbl.anchor_right = 1.0
			lbl.anchor_bottom = 1.0
			# Match the style from Main.tscn's PlateauValueCard ValueLabel
			lbl.margin_left = -10.0
			lbl.margin_top = 50.0
			lbl.add_color_override("font_color", Color(0, 0, 0, 1))
			# Try to load the Dyuthi font at size 105
			var font_data = load("res://fonts/Dyuthi.ttf")
			if font_data != null:
				var dyn_font = DynamicFont.new()
				dyn_font.font_data = font_data
				dyn_font.size = 105
				dyn_font.extra_spacing_char = -10
				lbl.add_font_override("font", dyn_font)

			p.add_child(lbl)
			_permanent_layer.add_child(p)

func _update_opponents(players):
	for idx in range(min(_opp_seats.size(), players.size() - 1)):
		var seat = _opp_seats[idx]
		if seat == null: continue
		var layer = seat["layer"]
		var rotation = seat["rotation_deg"]
		var pdata = players[idx + 1]
		if pdata == null: continue
		var count = pdata.get("hand_count", 0)
		for c in layer.get_children():
			if c.name.begins_with("OP"): c.free()
		if count == 0: continue

		# Recalculate pivot and rotation using the actual runtime rect_size.
		# (In _ready(), rect_size may be (0,0) before layout is finalized.)
		var pivot = layer.rect_size / 2
		layer.rect_pivot_offset = pivot
		layer.rect_rotation = rotation

		# Place cards at (0,0) in local unrotated space, properly spaced
		var cw = 60; var sp = 6
		for i in range(count):
			var c = CARD_FACE.instance()
			c.name = "OP" + str(i) + "_" + str(idx)
			c.set_card_back()
			c.rect_min_size = Vector2(cw, 84)
			c.rect_size = Vector2(cw, 84)
			c.rect_position = Vector2(i * (cw + sp), 0)
			c.mouse_filter = 2
			layer.add_child(c)

		# Compute the bounding box of the placed cards (only OP-named children)
		var min_x = 9999; var max_x = -9999
		var min_y = 9999; var max_y = -9999

		for c in layer.get_children():
			if not c.name.begins_with("OP"): continue
			var p = c.rect_position
			var s = c.rect_size
			if p.x < min_x: min_x = p.x
			if p.x + s.x > max_x: max_x = p.x + s.x
			if p.y < min_y: min_y = p.y
			if p.y + s.y > max_y: max_y = p.y + s.y

		# Bounding box center in unrotated local space
		var bb_cx = (min_x + max_x) / 2.0
		var bb_cy = (min_y + max_y) / 2.0

		# The layer's center in its own space is rect_size/2
		var layer_cx = layer.rect_size.x / 2.0
		var layer_cy = layer.rect_size.y / 2.0

		# Calculate offset to center the bounding box within the layer.
		# Since rotation is around the layer's center, centering in unrotated
		# space also centers in rotated space.
		var dx = layer_cx - bb_cx
		var dy = layer_cy - bb_cy

		# Apply the centering offset to each card's position
		for c in layer.get_children():
			if not c.name.begins_with("OP"): continue
			c.rect_position = Vector2(c.rect_position.x + dx, c.rect_position.y + dy)

func diagnose():
	print("Board: resolver=" + str(_resolver != null) + " val=" + str(_value_label != null) +
		" deck=" + str(_draw_pile_count != null) + " disc=" + str(_discard_top != null) +
		" perml=" + str(_permanent_layer != null) + " permb=" + str(_permanent_back != null) +
		" seats=" + str(_opp_seats.size()))
func _diagnose_nodes():
	var pc = _permanent_layer.get_child_count() if _permanent_layer != null else -1
	return " board(perm=" + str(pc) + ")"
