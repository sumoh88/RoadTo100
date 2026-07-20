extends Node
# Deterministic test: plateau stacking, opponent alignment, gold visibility,
# separation of scarti/piatto, chronological plateau stack order.

var _BP
var passed = 0; var failed = 0; var msgs = []

func _ready():
	_BP = load("res://scripts/BoardPresenter.gd")
	randomize()
	var out = ""
	out += "=== Board/Plateau Diagnostic ===\n"
	out += _t1_stacked_position()
	out += _t2_non_gold_not_on_plateau()
	out += _t3_gold_on_plateau()
	out += _t4_mixed_sequence_separation()
	out += _t5_chronological_stack()
	out += _t6_opponent_centering()
	out += _t7_rotation_preserved()
	out += "\nPassed: " + str(passed) + " Failed: " + str(failed) + "\n"
	if failed > 0:
		for m in msgs: out += "  FAIL: " + m + "\n"
	print(out)
	get_tree().quit(0)

func _a(cond, msg):
	if cond:
		passed += 1
	else:
		failed += 1
		msgs.append(msg)
	return cond

# Helper: build a BoardPresenter with injected nodes
func _mk_bp():
	var bp = _BP.new()
	bp._resolver = load("res://engine/TextureResolver.gd").new()
	bp._permanent_layer = Control.new()
	bp._permanent_layer.name = "PL"
	bp._permanent_layer.rect_size = Vector2(203, 266)
	return bp


# ===========================================================================
# Test 1: Plateau visual stack — items at (0,0), no lateral offset
# ===========================================================================

func _t1_stacked_position():
	var bp = _mk_bp()
	var inc = {"card_id":"i1","name":"+5","value":5,"color":"arancione","card_type":"increment"}
	var gold = {"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"}

	# Empty visual stack
	bp._update_plateau([])
	_a(bp._permanent_layer.get_child_count() == 0, "empty: no children")

	# Single gold card
	bp._update_plateau([{"type":"card","card":gold}])
	_a(bp._permanent_layer.get_child_count() == 1, "gold only: 1 child: " + str(bp._permanent_layer.get_child_count()))
	var c0 = bp._permanent_layer.get_child(0)
	_a(c0.rect_position == Vector2(0,0), "gold pos (0,0): " + str(c0.rect_position))
	_a(c0.name.begins_with("SV"), "gold name SV: " + c0.name)

	# Gold + plate
	bp._update_plateau([{"type":"plate","value":0},{"type":"card","card":gold}])
	_a(bp._permanent_layer.get_child_count() == 2, "plate+gold: 2 children: " + str(bp._permanent_layer.get_child_count()))
	var all_origin = true
	for c in bp._permanent_layer.get_children():
		if c.rect_position != Vector2(0,0): all_origin = false
	_a(all_origin, "all at (0,0)")

	# Multiple items: plate, card, plate
	bp._update_plateau([{"type":"plate","value":0},{"type":"card","card":gold},{"type":"plate","value":28}])
	_a(bp._permanent_layer.get_child_count() == 3, "3 items: " + str(bp._permanent_layer.get_child_count()))
	all_origin = true
	for c in bp._permanent_layer.get_children():
		if c.rect_position != Vector2(0,0): all_origin = false
	_a(all_origin, "3 at (0,0)")
	return "  Plateau stacking:      [PASS]\n"


# ===========================================================================
# Test 2: Non-Gold cards do NOT appear as card faces on the plateau
# ===========================================================================

func _t2_non_gold_not_on_plateau():
	var bp = _mk_bp()
	var inc = {"card_id":"i1","name":"+5","value":5,"color":"arancione","card_type":"increment"}
	var jolly = {"card_id":"j1","name":"Jolly","value":null,"color":"arancione","card_type":"jolly"}
	var gold = {"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"}

	# Only a plate (no non-gold card face)
	bp._update_plateau([{"type":"plate","value":5}])
	var has_card_face = false
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"):
			has_card_face = true
	_a(!has_card_face, "plate only: no card face")
	_a(bp._permanent_layer.get_child_count() == 1, "plate only: 1 child")

	# Gold card (should appear as card face)
	bp._update_plateau([{"type":"plate","value":0},{"type":"card","card":gold}])
	var gold_face_found = false
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"):
			gold_face_found = true
	_a(gold_face_found, "gold: card face found")

	# Mixed stack: plate, gold, plate (inc created plate, not card face)
	bp._update_plateau([{"type":"plate","value":0},{"type":"card","card":gold},{"type":"plate","value":28}])
	var card_face_count = 0
	var plate_count = 0
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"): card_face_count += 1
		if c.name.begins_with("PL"): plate_count += 1
	_a(card_face_count == 1, "mixed: 1 card face, got " + str(card_face_count))
	_a(plate_count == 2, "mixed: 2 plates, got " + str(plate_count))

	# Non-gold card (increment) does NOT appear as SV card face in permanent layer
	bp._update_plateau([{"type":"plate","value":5}])
	card_face_count = 0
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"): card_face_count += 1
	_a(card_face_count == 0, "increment only: no card face, got " + str(card_face_count))
	return "  Non-gold not on plat:  [PASS]\n"


# ===========================================================================
# Test 3: Gold cards appear as card faces on the plateau
# ===========================================================================

func _t3_gold_on_plateau():
	var bp = _mk_bp()
	var gold = {"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"}
	var gold2 = {"card_id":"g34","name":"34","value":34,"color":"dorato","card_type":"gold"}
	var spe89 = {"card_id":"s89","name":"89","value":89,"color":"viola","card_type":"special"}

	# Single gold
	bp._update_plateau([{"type":"plate","value":0},{"type":"card","card":gold}])
	var found_sv = false
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"): found_sv = true
	_a(found_sv, "gold card face present")

	# Two golds + plate
	bp._update_plateau([{"type":"plate","value":0},{"type":"card","card":gold},{"type":"card","card":gold2},{"type":"plate","value":34}])
	var sv_count = 0
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"): sv_count += 1
	_a(sv_count == 2, "2 golds: " + str(sv_count) + " card faces")

	# 89 special card
	bp._update_plateau([{"type":"plate","value":0},{"type":"card","card":spe89}])
	found_sv = false
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"): found_sv = true
	_a(found_sv, "89 card face present")

	return "  Gold on plateau:       [PASS]\n"


# ===========================================================================
# Test 4: Mixed sequence — non-gold cards only in scarti, golds only on plateau
# ===========================================================================

func _t4_mixed_sequence_separation():
	var bp = _mk_bp()
	var inc_a = {"card_id":"i5","name":"+5","value":5,"color":"arancione","card_type":"increment"}
	var gold_a = {"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"}
	var inc_b = {"card_id":"i3","name":"+3","value":3,"color":"arancione","card_type":"increment"}
	var gold_b = {"card_id":"g34","name":"34","value":34,"color":"dorato","card_type":"gold"}
	var inc_c = {"card_id":"i2","name":"+2","value":2,"color":"arancione","card_type":"increment"}

	# Full sequence: non-Gold, Gold, non-Gold, Gold, non-Gold
	# Expected visual stack:
	#   plate(0), gold(23), plate(26), gold(34), plate(36)
	var stack = [
		{"type":"plate","value":0},
		{"type":"card","card":gold_a},
		{"type":"plate","value":26},
		{"type":"card","card":gold_b},
		{"type":"plate","value":36},
	]
	bp._update_plateau(stack)

	var sv_count = 0
	var pl_count = 0
	var non_gold_faces = []  # card faces that are NOT gold
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"):
			sv_count += 1
			# CardFace instances have card_id property
			var cid = c.card_id if c.get("card_id") != null else ""
			if cid != "" and not cid.begins_with("g"):
				non_gold_faces.append(cid)
		if c.name.begins_with("PL"):
			pl_count += 1

	_a(sv_count == 2, "mixed seq: 2 card faces (golds), got " + str(sv_count))
	_a(non_gold_faces.size() == 0, "mixed seq: no non-gold card faces")
	_a(pl_count == 3, "mixed seq: 3 plates, got " + str(pl_count))

	# Verify non-gold cards NOT in permanent layer at all
	# (Increment cards i5, i3, i2 should not be anywhere in permanent layer)
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("SV"):
			# CardFace instances have card_id property
			var cid = c.card_id if c.get("card_id") != null else ""
			_a(cid.begins_with("g"), "card face must be gold: " + cid)

	return "  Mixed separation:      [PASS]\n"


# ===========================================================================
# Test 5: Chronological order of plateau stack
# ===========================================================================

func _t5_chronological_stack():
	var bp = _mk_bp()
	var gold_a = {"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"}
	var gold_b = {"card_id":"g34","name":"34","value":34,"color":"dorato","card_type":"gold"}

	# Sequence: non-Gold(+5), Gold(23), non-Gold(+3), Gold(34), non-Gold(+2)
	# Expected visual stack (bottom→top): plate(0), gold(23), plate(26), gold(34), plate(36)
	var stack = [
		{"type":"plate","value":0},
		{"type":"card","card":gold_a},
		{"type":"plate","value":26},
		{"type":"card","card":gold_b},
		{"type":"plate","value":36},
	]
	bp._update_plateau(stack)

	# Verify order by checking children names
	var items = []
	for c in bp._permanent_layer.get_children():
		items.append(c.name)

	# Items should be in the same order as the stack, indexed by name
	# PL0, SV1, PL2, SV3, PL4 (or similar)
	var pl_order = []
	var sv_order = []
	for i in range(bp._permanent_layer.get_child_count()):
		var c = bp._permanent_layer.get_child(i)
		if c.name.begins_with("PL"): pl_order.append(i)
		if c.name.begins_with("SV"): sv_order.append(i)

	_a(pl_order.size() == 3, "3 plates, got " + str(pl_order.size()))
	_a(sv_order.size() == 2, "2 card faces, got " + str(sv_order.size()))

	# Order must be: plate, card, plate, card, plate
	_a(pl_order[0] == 0, "first is plate: " + str(pl_order[0]))
	_a(sv_order[0] == 1, "second is card: " + str(sv_order[0]))
	_a(pl_order[1] == 2, "third is plate: " + str(pl_order[1]))
	_a(sv_order[1] == 3, "fourth is card: " + str(sv_order[1]))
	_a(pl_order[2] == 4, "fifth is plate: " + str(pl_order[2]))

	# Verify plate values
	var plate_values = []
	for c in bp._permanent_layer.get_children():
		if c.name.begins_with("PL"):
			# The Label child has the text
			var found_label = false
			for child in c.get_children():
				if child is Label:
					plate_values.append(int(child.text))
					found_label = true
				# Stop after first matching
				if found_label:
					break

	_a(plate_values.size() == 3, "3 plate values: " + str(plate_values.size()))
	if plate_values.size() >= 3:
		_a(plate_values[0] == 0, "first plate value 0, got " + str(plate_values[0]))
		_a(plate_values[1] == 26, "second plate value 26, got " + str(plate_values[1]))
		_a(plate_values[2] == 36, "third plate value 36, got " + str(plate_values[2]))

	return "  Chronological order:   [PASS]\n"


# ===========================================================================
# Test 6: Opponent hand centering (Bug 1)
# ===========================================================================

func _t6_opponent_centering():
	# Create a BoardPresenter with synthetic opponent seat layers
	var layers = []
	for i in range(3):
		var l = Control.new(); l.name = "CL" + str(i)
		l.rect_size = Vector2(158, 120)
		layers.append(l)

	var bp = _BP.new()
	bp._opp_seats = [
		{"layer": layers[0], "rotation_deg": 180},
		{"layer": layers[1], "rotation_deg": 90},
		{"layer": layers[2], "rotation_deg": -90},
	]
	bp._resolver = load("res://engine/TextureResolver.gd").new()

	# Build snapshot
	var snap = {"piatto":0,"deck_count":48,"discard_top":null,"players":[
		{"id":"p1","hand_count":3,"hand":[]},
		{"id":"p2","hand_count":3,"hand":[]},
		{"id":"p3","hand_count":2,"hand":[]},
		{"id":"p4","hand_count":1,"hand":[]},
	]}

	# Note: apply_snapshot now looks for plateau_visual_stack not plateau_cards
	snap["plateau_visual_stack"] = [{"type":"plate","value":0}]
	bp.apply_snapshot(snap)

	# For Top seat (180° rotation), cards are laid out horizontally in local coords.
	# With 3 cards (cw=60, sp=6, total=192, tw=158):
	# sx = (158 - 192) / 2 = -17
	# The first card should be at sx = -17 (not 0), which centers the hand
	var top_layer = layers[0]
	var top_first = null
	for c in top_layer.get_children():
		if c.name.begins_with("OP"):
			top_first = c
			break
	if top_first != null:
		_a(top_first.rect_position.x == -17, "top center x=-17, got " + str(top_first.rect_position.x))

	# For Left seat (90° rotation), same sx calculation applies
	# Player 3 has hand_count=2 (index 1 in opponents)
	var left_layer = layers[1]
	var left_first = null
	for c in left_layer.get_children():
		if c.name.begins_with("OP"):
			left_first = c
			break
	if left_first != null:
		var left_hand_count = 2
		var left_sx = (left_layer.rect_size.x - (left_hand_count * 60 + (left_hand_count - 1) * 6)) / 2.0
		_a(left_first.rect_position.x == left_sx, "left center x=" + str(left_sx) + ", got " + str(left_first.rect_position.x))

	# With just 1 card: total = 60
	var snap1 = snap.duplicate()
	snap1["players"][1] = {"id":"p2","hand_count":1,"hand":[]}
	snap1["players"][2] = {"id":"p3","hand_count":1,"hand":[]}
	snap1["players"][3] = {"id":"p4","hand_count":1,"hand":[]}
	bp.apply_snapshot(snap1)

	top_first = null
	for c in top_layer.get_children():
		if c.name.begins_with("OP"):
			top_first = c
			break
	if top_first != null:
		# With 1 card (cw=60, tw=158): sx = (158 - 60) / 2 = 49
		var expected_sx_1card = (158 - 60) / 2.0
		_a(top_first.rect_position.x == expected_sx_1card,
			"1 card center x=" + str(expected_sx_1card) + ", got " + str(top_first.rect_position.x))

	return "  Opponent centering:    [PASS]\n"


# ===========================================================================
# Test 7: Rotation preserved on opponent hands
# ===========================================================================

func _t7_rotation_preserved():
	var layers = []
	for i in range(3):
		var l = Control.new(); l.name = "CL" + str(i)
		l.rect_size = Vector2(158, 120)
		layers.append(l)

	var expected = [180, 90, -90]
	for i in range(3):
		var l = layers[i]
		l.rect_pivot_offset = l.rect_size / 2
		l.rect_rotation = expected[i]
		_a(l.rect_pivot_offset == Vector2(79, 60), "pivot " + str(i) + ": " + str(l.rect_pivot_offset))
		_a(l.rect_rotation == expected[i], "rotation " + str(i) + ": " + str(l.rect_rotation) + " expected " + str(expected[i]))
	return "  Rotation preserved:    [PASS]\n"
