extends Node
# BoardPresenter — updates board area, plateau stacking, opponent cards, rotations.
# Does NOT contain game rules.

onready var main = get_tree().current_scene
onready var ResolvedValueLabel = main.get_node("GameArea/BoardArea/DiscardPile/TopCard/ResolvedValueLabel")
onready var valueLabel = main.get_node("GameArea/BoardArea/PlateauZone/ValueLabel")

const CARD_FACE = preload("res://scenes/CardFace.tscn")
const PLATE_TEXTURE = preload("res://imgs/plate.png")


# Per-seat data: {layer: Control, rotation_deg: int}
var _resolver = null
var _shadow_factory = null
var _value_label = null
var _value_layer = null   # static ValueLayer — hidden, replaced by dynamic plate labels
var _draw_pile_count = null
var _draw_pile_cardback = null
var _discard_top = null
var _discard_pile = null

# Riferimento all'unica ombra della pila degli Scarti.
# Viene creata nascosta e mostrata solo quando esiste almeno uno scarto.
var _discard_shadow = null

var _permanent_layer = null
var _permanent_back = null
var _plateau_value_card = null  # static Plate.png from scene — hidden, replaced by dynamic plates
var _opp_seats = []  # [{layer, rotation_deg}, ...]
var _sr_badges = {}  # player_id -> Label (special round indicator)
var _ga = null       # GameArea reference for creating local player badge


func _ready():
	_resolver = load("res://engine/TextureResolver.gd").new()
	_shadow_factory = load("res://scripts/ShadowFactory.gd").new()

	var m = _up("Main")
	if m == null:
		return

	var ga = _ch(m, "GameArea")
	if ga == null:
		return

	_ga = ga

	# Board area
	var brd = _ch(ga, "BoardArea")

	if brd != null:
		var pl = _ch(brd, "PlateauZone")

		if pl != null:
			_value_label = _rec(pl, "ValueLabel")
			_permanent_layer = _ch(pl, "PermanentCardsLayer")

			if _permanent_layer != null:
				_permanent_back = _ch(
					_permanent_layer,
					"PermanentCardBack"
				)

			# Hide the static PlateauValueCard — dynamic plates inside
			# _permanent_layer now handle the visual representation.
			_plateau_value_card = _ch(
				pl,
				"PlateauValueCard"
			)

			if _plateau_value_card != null:
				_plateau_value_card.visible = false

			# Hide the static ValueLayer — its Label duplicates the value
			# shown by dynamic plate labels and appears on top of Gold cards.
			if _value_label != null:
				_value_label.visible = false

		var draw_pile = _ch(brd, "DrawPile")

		if draw_pile != null:
			_draw_pile_count = _ch(
				draw_pile,
				"CountLabel"
			)

			# Draw pile: store reference and apply initial jitter.
			var cb = _ch(draw_pile, "CardBack")

			if cb != null:
				_draw_pile_cardback = cb
				randomize_draw_pile()

		var dp = _ch(brd, "DiscardPile")
		_discard_pile = dp

		if dp != null:
			_discard_top = _ch(
				dp,
				"TopCard"
			)

		# Soft shadows under the table piles
		# (one unified shadow each).
		_setup_pile_shadows(brd)


	# Opponent seats: find CardsLayers, store seat data
	# NOTE: Do NOT set rect_pivot_offset or rect_rotation here in _ready,
	# because rect_size may not be finalized yet (can be 0,0) leading to
	# an incorrect pivot and visual misalignment.
	# Pivot and rotation are recalculated in _update_opponents() using the
	# actual runtime rect_size.
	var ol = _ch(ga, "OpponentsLayer")

	if ol != null:
		for pair in [
			["TopSeat", 180],
			["LeftSeat", 90],
			["RightSeat", -90]
		]:
			var s = _ch(
				ol,
				pair[0]
			)

			if s != null:
				var cl = _ch(
					s,
					"CardsLayer"
				)

				if cl != null:
					_opp_seats.append({
						"layer": cl,
						"rotation_deg": pair[1]
					})
				else:
					_opp_seats.append(null)
			else:
				_opp_seats.append(null)


	# Create SR badges (special round indicators) for each seat + local player
	# if GlobalsUtilities.gameStarted:
	_sr_badges = _create_sr_badges(
		ga,
		ol
	)

	if ResolvedValueLabel == null:
		ResolvedValueLabel = Label.new()
		ResolvedValueLabel.text = ""


func _up(name):
	var p = get_parent()

	while p != null and p.name != name:
		p = p.get_parent()

	return p


func _ch(p, name):
	if p == null:
		return null

	for c in p.get_children():
		if c.name == name:
			return c

	return null


func _rec(p, name):
	if p == null:
		return null

	if p.name == name:
		return p

	for c in p.get_children():
		var f = _rec(c, name)

		if f != null:
			return f

	return null


# ---------------------------------------------------------------------------
# Soft shadows under the table piles (Draw / Plateau / Discard)
# ---------------------------------------------------------------------------

func _setup_pile_shadows(brd):
	if brd == null:
		return

	var pile_size = Vector2(
		203,
		292
	)

	# Mazzo: ombra sempre visibile.
	var draw_pile = _ch(
		brd,
		"DrawPile"
	)

	if draw_pile != null:
		_shadow_factory.add_pile_shadow(
			draw_pile,
			Vector2(0, 0),
			pile_size
		)

	# Scarti: ombra inizialmente NASCOSTA.
	# Verrà mostrata da _update_discard() quando compare
	# la prima carta nella pila.
	var discard_pile = _ch(
		brd,
		"DiscardPile"
	)

	if discard_pile != null:
		_discard_shadow = _shadow_factory.add_pile_shadow(
			discard_pile,
			Vector2(0, 0),
			pile_size,
			Vector2(5, 9),
			false
		)

	# Piatto: ombra sempre presente come prima.
	var plateau_zone = _ch(
		brd,
		"PlateauZone"
	)

	if plateau_zone != null:
		var pcl = _ch(
			plateau_zone,
			"PermanentCardsLayer"
		)

		if pcl != null:
			_shadow_factory.add_pile_shadow(
				pcl,
				Vector2(0, 0),
				pile_size
			)


# ---------------------------------------------------------------------------
# Hand-placed pile jitter (Piatto / Scarti)
#
# A small deterministic table of offsets/rotations indexed by stack position.
# Index 0 is the base (no offset); subsequent cards get a subtle, stable
# displacement (within ±7 px, rotation within ~±2.5°) so piles look placed by
# hand yet remain ordered and readable. Deterministic => no per-frame jumping.
# ---------------------------------------------------------------------------

const _PILE_JIT_POS = [
	Vector2(0, 0),
	Vector2(4, -3),
	Vector2(-5, 3),
	Vector2(6, 2),
	Vector2(-3, -4),
	Vector2(3, 5),
	Vector2(-6, -2),
	Vector2(5, 4),
]

const _PILE_JIT_ROT = [
	0.0,
	1.7,
	-2.0,
	2.3,
	-1.4,
	1.2,
	-2.2,
	1.9
]


func _pile_jit(i):
	var n = _PILE_JIT_POS.size()

	return {
		"pos": _PILE_JIT_POS[i % n],
		"rot": _PILE_JIT_ROT[i % n]
	}


# ---------------------------------------------------------------------------
# Discard pile: render the last few discarded cards as a jittered stack.
# TopCard (scene node) is kept as the top card and carries ResolvedValueLabel;
# under-cards (DC*) are added behind it with hand-placed jitter.
# ---------------------------------------------------------------------------

func _update_discard(discard_stack):
	if _discard_pile == null or _discard_top == null:
		return

	# Clear dynamic under-cards from previous snapshots.
	for c in _discard_pile.get_children():
		if c.name.begins_with("DC"):
			c.free()

	var cards = discard_stack if discard_stack != null else []
	var n = cards.size()

	_discard_top.visible = n > 0

	# L'ombra della pila degli Scarti esiste sempre,
	# ma è visibile soltanto quando la pila contiene
	# almeno una carta.
	if _discard_shadow != null:
		_shadow_factory.set_pile_shadow_visible(
			_discard_shadow,
			n > 0
		)

	if n == 0:
		return

	# Under-cards: all but the top, rendered behind TopCard with jitter.
	for i in range(n - 1):
		var cd = cards[i]

		var dc = TextureRect.new()
		dc.name = "DC" + str(i)
		dc.texture = _resolver.texture(cd)
		dc.expand = true
		dc.mouse_filter = 2

		dc.rect_min_size = Vector2(
			203,
			292
		)

		dc.rect_size = Vector2(
			203,
			292
		)

		# Skip the base slot for a varied look.
		var jit = _pile_jit(i + 1)

		dc.rect_position = jit["pos"]
		dc.rect_rotation = jit["rot"]
		dc.rect_pivot_offset = Vector2(
			101.5,
			146.0
		)

		_discard_pile.add_child(dc)

	# Top card: subtle stable tilt so the pile reads
	# as hand-placed yet neat.
	_discard_top.rect_pivot_offset = Vector2(
		101.5,
		146.0
	)

	_discard_top.rect_rotation = 0.8

	# Keep TopCard on top of the under-cards.
	_discard_pile.move_child(
		_discard_top,
		_discard_pile.get_child_count() - 1
	)


# ---------------------------------------------------------------------------
# SR badges (special round indicators) — Fix 5
# ---------------------------------------------------------------------------

func _create_sr_badges(ga, ol):
	"""Create small Label badges on each seat and the local player area."""

	var badges = {}

	if ol == null:
		print("ol null")
		return badges

	# Opponent seats:
	# player_2 (Left), player_3 (Top), player_4 (Right)
	var seat_map = [
		"player_2",
		"player_3",
		"player_4"
	]

	var seat_names = [
		"LeftSeat",
		"TopSeat",
		"RightSeat"
	]

	for i in range(3):
		var s = _ch(
			ol,
			seat_names[i]
		)

		if s != null:
			var badge = main.get_node(
				"GameArea/OpponentsLayer/" +
				seat_names[i] +
				"/SRBadge"
			)

			if badge != null:
				badge.visible = false
				badge.mouse_filter = 2
				badges[seat_map[i]] = badge

				print("YES OPP")

	# Local player (player_1): badge near the hand area
	var lpa = _ch(
		ga,
		"LocalPlayerArea"
	)

	if lpa != null:
		var badge = main.get_node(
			"GameArea/LocalPlayerArea/SRBadge"
		)

		if badge != null:
			badge.visible = false
			badge.mouse_filter = 2
			badges["player_1"] = badge

			print("YES pla")

	print("return badges")

	return badges


func _update_sr_badges(snapshot):
	"""Show the SR badge only on the player who activated the special round."""

	var sr_active = snapshot.get(
		"special_round_active",
		false
	)

	var sr_player = snapshot.get(
		"special_round_player_id",
		null
	)

	GlobalsUtilities.sr_active = sr_active

	for pid in _sr_badges.keys():
		var badge = _sr_badges[pid]

		if badge == null:
			continue

		badge.visible = (
			sr_active and
			pid == sr_player
		)


# ---------------------------------------------------------------------------
# Draw pile jitter — call on each new game to re-randomize position/rotation.
# ---------------------------------------------------------------------------

func randomize_draw_pile():
	if _draw_pile_cardback == null:
		return
	var cb = _draw_pile_cardback
	cb.rect_pivot_offset = Vector2(101.5, 146.0)
	cb.rect_rotation = rand_range(-1.0, 1.0)
	cb.rect_position = Vector2(
		rand_range(-2.0, 2.0),
		rand_range(-2.0, 2.0)
	)


func show_plate_back():
	"""Show the plate cardback (cardbackplate.png) instead of the value."""
	if _permanent_back != null:
		_permanent_back.visible = true
	for c in _permanent_layer.get_children():
		if c.name.begins_with("PL"):
			c.visible = false


func hide_plate_back():
	"""Hide the plate cardback and show the value (plate.png)."""
	if _permanent_back != null:
		_permanent_back.visible = false
	for c in _permanent_layer.get_children():
		if c.name.begins_with("PL"):
			c.visible = true


func apply_snapshot(s):
	if s == null:
		return

	var plate_value = int(
		s.get(
			"piatto",
			0
		)
	)

	if _value_label != null:
		_value_label.text = str(plate_value)

	GlobalsUtilities.plateValue = plate_value

	if _draw_pile_count != null:
		_draw_pile_count.text = str(
			s.get(
				"deck_count",
				0
			)
		)

	if _discard_top != null:
		var t = s.get(
			"discard_top",
			null
		)

		if t != null:
			_discard_top.texture = _resolver.texture(t)
		else:
			_discard_top.texture = null

		_discard_top.visible = t != null

	var vstack = s.get(
		"plateau_visual_stack",
		[]
	)

	var mathSign = ""

	if not int(GlobalsUtilities.selected_value) >= 1:
		mathSign = ""
	else:
		mathSign = "+"

	ResolvedValueLabel.text = (
		mathSign +
		str(GlobalsUtilities.selected_value)
	)

	_update_plateau(vstack)

	_update_discard(
		s.get(
			"discard_stack",
			[]
		)
	)

	_update_opponents(
		s.get(
			"players",
			[]
		)
	)

	_update_sr_badges(s)


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
		if (
			c.name.begins_with("SV") or
			c.name.begins_with("PL")
		):
			c.free()

	# Show/hide the permanent card back (cardbackplate.png)
	var has_card = false

	for item in stack:
		if item["type"] == "card":
			has_card = true
			break

	if _permanent_back != null:
		_permanent_back.visible = has_card

	# Rebuild the visual stack bottom to top.
	# Each card gets a small, stable hand-placed offset/rotation
	# (index 0 stays at origin as the base).
	for i in range(stack.size()):
		var item = stack[i]
		var jit = _pile_jit(i)

		if item["type"] == "card":
			# Card face (Gold/89)
			var c = CARD_FACE.instance()

			c.name = "SV" + str(i)
			c.set_card(
				item["card"],
				false
			)

			c.rect_position = jit["pos"]
			c.rect_rotation = jit["rot"]

			c.rect_pivot_offset = Vector2(
				101.5,
				146.0
			)

			c.rect_min_size = Vector2(
				203,
				292
			)

			c.rect_size = Vector2(
				203,
				292
			)

			c.mouse_filter = 2

			_permanent_layer.add_child(c)

		elif item["type"] == "plate":
			# Carta Piatto (value card)
			var p = TextureRect.new()

			p.name = "PL" + str(i)

			if int(item["value"]) >= 100:
				p.texture = load(
					"res://imgs/spe100.png"
				)
			else:
				p.texture = PLATE_TEXTURE

			p.expand = true
			p.mouse_filter = 2

			# Match PlateauValueCard dimensions from Main.tscn
			p.rect_min_size = Vector2(
				203,
				292
			)

			p.rect_size = Vector2(
				203,
				292
			)

			p.rect_position = jit["pos"]
			p.rect_rotation = jit["rot"]

			p.rect_pivot_offset = Vector2(
				101.5,
				146.0
			)

			# Value label overlay
			var lbl = Label.new()

			lbl.text = str(
				item["value"]
			)

			if int(item["value"]) >= 100:
				lbl.text = ""

			lbl.align = Label.ALIGN_CENTER
			lbl.valign = Label.VALIGN_CENTER

			lbl.anchor_right = 1.0
			lbl.anchor_bottom = 1.0

			# Match the style from Main.tscn's
			# PlateauValueCard ValueLabel
			lbl.margin_left = -7.0
			lbl.margin_top = 62.0

			# Try to load the Dyuthi font at size 105
			var font_data = load(
				"res://fonts/Dyuthi.ttf"
			)

			if font_data != null:
				var dyn_font = DynamicFont.new()

				dyn_font.font_data = font_data
				dyn_font.size = 105
				dyn_font.extra_spacing_char = -10

				lbl.add_font_override(
					"font",
					dyn_font
				)

			p.add_child(lbl)
			_permanent_layer.add_child(p)


func _update_opponents(players):
	for idx in range(
		min(
			_opp_seats.size(),
			players.size() - 1
		)
	):
		var seat = _opp_seats[idx]

		if seat == null:
			continue

		var layer = seat["layer"]
		var rotation = seat["rotation_deg"]
		var pdata = players[idx + 1]

		if pdata == null:
			continue

		var count = pdata.get(
			"hand_count",
			0
		)

		for c in layer.get_children():
			if c.name.begins_with("OP"):
				c.free()

		if count == 0:
			continue

		# Recalculate pivot and rotation using the actual runtime rect_size.
		# (In _ready(), rect_size may be (0,0) before layout is finalized.)
		var pivot = layer.rect_size / 2

		layer.rect_pivot_offset = pivot
		layer.rect_rotation = rotation

		# Fan layout: middle card straight, side cards rotated in opposite
		# directions with bottoms converging; the open side faces the centre.
		var cw = 60
		var ch = 84

		var fan_angle_deg = 12.0

		# offset between adjacent bottom-centres
		var h_spacing = 26

		# index of the straight (middle) card
		var mid = count / 2

		# Compute each card's unrotated transform up front.
		var cfgs = []

		for i in range(count):
			var off = i - mid

			# CCW left / CW right
			var rot = off * fan_angle_deg

			var bcx = off * h_spacing

			cfgs.append({
				"pos":
					Vector2(bcx, 0) -
					Vector2(
						cw / 2.0,
						ch
					),

				"rot": rot,

				"pivot":
					Vector2(
						cw / 2.0,
						ch
					),

				"size":
					Vector2(
						cw,
						ch
					)
			})

		# Pass 1: soft shadows
		# (added first so they render behind the cards).
		for i in range(cfgs.size()):
			var sh = _shadow_factory.make_card_shadow(
				cfgs[i]["pos"],
				cfgs[i]["size"],
				cfgs[i]["rot"],
				cfgs[i]["pivot"]
			)

			if sh != null:
				sh.name = (
					"OPS" +
					str(i) +
					"_" +
					str(idx)
				)

				layer.add_child(sh)

		# Pass 2: the cards themselves.
		for i in range(cfgs.size()):
			var c = CARD_FACE.instance()

			c.name = (
				"OP" +
				str(i) +
				"_" +
				str(idx)
			)

			c.set_card_back()

			c.rect_min_size = cfgs[i]["size"]
			c.rect_size = cfgs[i]["size"]

			c.mouse_filter = 2

			c.rect_rotation = cfgs[i]["rot"]
			c.rect_pivot_offset = cfgs[i]["pivot"]
			c.rect_position = cfgs[i]["pos"]

			layer.add_child(c)

		# Center the fanned group within the layer
		# (using unrotated rects).
		var min_x = 9999
		var max_x = -9999
		var min_y = 9999
		var max_y = -9999

		for c in layer.get_children():
			if not c.name.begins_with("OP"):
				continue

			var p = c.rect_position
			var s = c.rect_size

			if p.x < min_x:
				min_x = p.x

			if p.x + s.x > max_x:
				max_x = p.x + s.x

			if p.y < min_y:
				min_y = p.y

			if p.y + s.y > max_y:
				max_y = p.y + s.y

		var bb_cx = (
			min_x +
			max_x
		) / 2.0

		var bb_cy = (
			min_y +
			max_y
		) / 2.0

		var layer_cx = (
			layer.rect_size.x /
			2.0
		)

		var layer_cy = (
			layer.rect_size.y /
			2.0
		)

		var dx = (
			layer_cx -
			bb_cx
		)

		var dy = (
			layer_cy -
			bb_cy
		)

		for c in layer.get_children():
			if not c.name.begins_with("OP"):
				continue

			c.rect_position = Vector2(
				c.rect_position.x + dx,
				c.rect_position.y + dy
			)


func diagnose():
	print(
		"Board: resolver=" +
		str(_resolver != null) +
		" val=" +
		str(_value_label != null) +
		" deck=" +
		str(_draw_pile_count != null) +
		" disc=" +
		str(_discard_top != null) +
		" perml=" +
		str(_permanent_layer != null) +
		" permb=" +
		str(_permanent_back != null) +
		" seats=" +
		str(_opp_seats.size())
	)


func _diagnose_nodes():
	var pc = (
		_permanent_layer.get_child_count()
		if _permanent_layer != null
		else -1
	)

	return (
		" board(perm=" +
		str(pc) +
		")"
	)
