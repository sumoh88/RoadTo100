extends Node
# Presentation check (shadows + hand-placed piles):
#   - shadows use a rounded-rectangle silhouette shader (NOT radial/circular)
#   - exactly ONE SoftShadow under each table pile
#   - Piatto (PL/SV) and Scarti (DC + TopCard) cards sit within controlled
#     jitter bounds (offset +/-7 px, rotation ~+/-2.5 deg) and a base at origin
#   - opponent CPU cards each have a matching OPS shadow behind them
var passed = 0; var failed = 0

func _a(cond, msg):
	if cond: passed += 1
	else:
		failed += 1
		print("  [FAIL] " + msg)

func _jit_ok(c):
	return (abs(c.rect_position.x) <= 7 and abs(c.rect_position.y) <= 7 and abs(c.rect_rotation) <= 2.5)

func _ready():
	var main = load("res://Main.tscn").instance()
	add_child(main)
	yield(get_tree(), "idle_frame")
	yield(get_tree().create_timer(0.3), "timeout")

	var bp = null
	for c in main.get_children():
		if c.name == "BoardPresenter" and c.has_method("apply_snapshot"):
			bp = c
			break

	print("=== Shadow / Pile Presentation Test ===")
	if bp == null:
		print("FAIL: BoardPresenter not found")
		get_tree().quit(1)
		return

	# -- 1. Shadow shader is a rounded-rectangle SDF (non-circular) --
	var sf = load("res://scripts/ShadowFactory.gd").new()
	var mat = sf.get_material()
	var code = ""
	if mat != null and mat.shader != null:
		code = mat.shader.code
	_a(mat != null, "shadow material created")
	_a(code.find("smoothstep") != -1, "shadow shader uses rect SDF (smoothstep), non-circular")
	_a(code.find("length(d * 2.0)") == -1, "shadow shader is not the old radial blob")

	var ga = main.get_node("GameArea")
	var brd = ga.get_node("BoardArea")

	# -- 2. Exactly ONE SoftShadow under each pile container --
	var piles = [
		["DrawPile", brd.get_node("DrawPile")],
		["DiscardPile", brd.get_node("DiscardPile")],
		["Plateau/PermLayer", brd.get_node("PlateauZone/PermanentCardsLayer")],
	]
	for p in piles:
		var node = p[1]
		if node == null:
			_a(false, p[0] + " not found")
			continue
		var count = 0
		for ch in node.get_children():
			if ch.name == "SoftShadow":
				count += 1
		_a(count == 1, p[0] + " has exactly 1 SoftShadow (got " + str(count) + ")")

	# -- Apply a snapshot with a multi-card plateau + discard stack --
	var gold = {"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"}
	var snap = {
		"piatto": 40,
		"deck_count": 48,
		"discard_top": {"card_id":"i5","name":"+5","value":5,"color":"arancione","card_type":"increment"},
		"discard_stack": [
			{"card_id":"i2","name":"+2","value":2,"color":"arancione","card_type":"increment"},
			{"card_id":"i4","name":"+4","value":4,"color":"arancione","card_type":"increment"},
			{"card_id":"g23","name":"23","value":23,"color":"dorato","card_type":"gold"},
			{"card_id":"i5","name":"+5","value":5,"color":"arancione","card_type":"increment"}
		],
		"plateau_visual_stack": [
			{"type":"plate","value":0},
			{"type":"card","card":gold},
			{"type":"plate","value":28},
			{"type":"plate","value":40}
		],
		"players": [
			{"id":"player_1","hand_count":3},
			{"id":"player_2","hand_count":3},
			{"id":"player_3","hand_count":3},
			{"id":"player_4","hand_count":3}
		],
		"special_round_active": false,
		"special_round_player_id": null
	}
	bp.apply_snapshot(snap)
	yield(get_tree(), "idle_frame")

	# -- 3. Piatto cards (PL/SV) within jitter bounds; base card at origin --
	var pcl = brd.get_node("PlateauZone/PermanentCardsLayer")
	var plat_ok = true
	var base_ok = false
	for ch in pcl.get_children():
		if ch.name.begins_with("PL") or ch.name.begins_with("SV"):
			if not _jit_ok(ch):
				plat_ok = false
			if ch.rect_position == Vector2(0, 0):
				base_ok = true
	_a(plat_ok, "Piatto cards within jitter bounds")
	_a(base_ok, "Piatto has a base card at origin (0,0)")

	# -- 4. Scarti under-cards (DC) + TopCard within jitter bounds; TopCard on top --
	var dpp = brd.get_node("DiscardPile")
	var dc_count = 0
	var disc_ok = true
	for ch in dpp.get_children():
		if ch.name.begins_with("DC"):
			dc_count += 1
			if not _jit_ok(ch):
				disc_ok = false
	var tc = dpp.get_node("TopCard")
	if tc == null:
		_a(false, "DiscardPile/TopCard not found")
	else:
		if not _jit_ok(tc):
			disc_ok = false
	_a(dc_count == 3, "Scarti has 3 under-cards (got " + str(dc_count) + ")")
	_a(disc_ok, "Scarti cards within jitter bounds")
	var last = dpp.get_child(dpp.get_child_count() - 1)
	_a(last == tc, "TopCard is topmost in DiscardPile")

	# -- 5. Opponent CPU cards: one OPS shadow each, behind the cards --
	var ol = ga.get_node("OpponentsLayer")
	for sn in ["TopSeat", "LeftSeat", "RightSeat"]:
		var seat = ol.get_node(sn)
		var cl = seat.get_node("CardsLayer")
		var n_cards = 0; var n_shadows = 0
		var last_shadow_idx = -2
		var first_card_idx = -1
		for i in range(cl.get_child_count()):
			var ch = cl.get_child(i)
			if ch.name.begins_with("OPS"):
				n_shadows += 1
				last_shadow_idx = i
			elif (ch.name.begins_with("OP") and not ch.name.begins_with("OPS")):
				n_cards += 1
				if first_card_idx < 0: first_card_idx = i
		_a(n_cards == 3, sn + " has 3 cards (got " + str(n_cards) + ")")
		_a(n_shadows == n_cards, sn + " one shadow per card (" + str(n_shadows) + "/" + str(n_cards) + ")")
		_a(last_shadow_idx < first_card_idx, sn + " shadows ordered before cards")

	print("\nPassed: " + str(passed) + " Failed: " + str(failed))
	get_tree().quit(0 if failed == 0 else 1)
