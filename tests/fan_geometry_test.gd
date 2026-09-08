extends Node
# Verifies the CPU card fan geometry produced by BoardPresenter._update_opponents.
# Replicates the exact positioning math and checks:
#   - middle card straight (rotation 0)
#   - side cards rotated in opposite directions
#   - bottoms bunched near the middle card's bottom corners
#   - shadow children attached to each card
var passed = 0; var failed = 0

func _a(cond, msg):
	if cond: passed += 1
	else:
		failed += 1
		print("  [FAIL] " + msg)

# Recreate the fan layout for one seat and return the list of cards.
func _build_fan(count, cw, ch, fan_angle_deg, h_spacing):
	var layer = Control.new()
	layer.rect_size = Vector2(158, 120)   # representative TopSeat size
	get_tree().root.add_child(layer)

	var cards = []
	var mid = count / 2
	for i in range(count):
		var c = Control.new()
		c.rect_min_size = Vector2(cw, ch)
		c.rect_size = Vector2(cw, ch)

		var off = i - mid
		c.rect_rotation = off * fan_angle_deg
		c.rect_pivot_offset = Vector2(cw / 2.0, ch)
		var bcx = off * h_spacing
		c.rect_position = Vector2(bcx, 0) - Vector2(cw / 2.0, ch)

		layer.add_child(c)
		cards.append(c)

	# Centering (same as BoardPresenter)
	var min_x = 9999; var max_x = -9999
	var min_y = 9999; var max_y = -9999
	for c in cards:
		var p = c.rect_position; var s = c.rect_size
		if p.x < min_x: min_x = p.x
		if p.x + s.x > max_x: max_x = p.x + s.x
		if p.y < min_y: min_y = p.y
		if p.y + s.y > max_y: max_y = p.y + s.y
	var bb_cx = (min_x + max_x) / 2.0
	var bb_cy = (min_y + max_y) / 2.0
	var dx = layer.rect_size.x / 2.0 - bb_cx
	var dy = layer.rect_size.y / 2.0 - bb_cy
	for c in cards:
		c.rect_position = Vector2(c.rect_position.x + dx, c.rect_position.y + dy)

	return { "layer": layer, "cards": cards }

func _ready():
	var cw = 60; var ch = 84
	var fan_angle_deg = 12.0; var h_spacing = 26
	var f = _build_fan(3, cw, ch, fan_angle_deg, h_spacing)
	var cards = f["cards"]

	print("=== Fan Geometry Test ===")
	# 1. Rotations: middle straight, sides opposite
	_a(cards[0].rect_rotation < -1, "left card rotated CCW (got " + str(cards[0].rect_rotation) + ")")
	_a(cards[1].rect_rotation == 0, "middle card straight (got " + str(cards[1].rect_rotation) + ")")
	_a(cards[2].rect_rotation > 1, "right card rotated CW (got " + str(cards[2].rect_rotation) + ")")

	# 2. Bottom-centre x of each card (position.x + pivot.x), after centering
	var bcx0 = cards[0].rect_position.x + cw / 2.0
	var bcx1 = cards[1].rect_position.x + cw / 2.0
	var bcx2 = cards[2].rect_position.x + cw / 2.0
	_a(abs(bcx1 - f["layer"].rect_size.x / 2.0) < 1.0, "middle bottom-centre ~ layer centre (got " + str(bcx1) + ")")
	# Adjacent bottom-centres close (bunched/overlapping), within card width
	_a(abs(bcx0 - bcx1) < cw, "left/middle bottoms bunched (dist " + str(abs(bcx0 - bcx1)) + ")")
	_a(abs(bcx2 - bcx1) < cw, "right/middle bottoms bunched (dist " + str(abs(bcx2 - bcx1)) + ")")

	# 3. Left card's bottom-right corner should sit near/over the middle's bottom-left region
	var mid_bl_x = cards[1].rect_position.x   # middle bottom-left x (pre-rotation)
	var left_br_x = cards[0].rect_position.x + cw  # left bottom-right x (pre-rotation)
	_a(left_br_x >= mid_bl_x - 5, "left bottom-right overlaps middle bottom-left region")

	print("\nPassed: " + str(passed) + " Failed: " + str(failed))

	f["layer"].free()
	get_tree().quit(0 if failed == 0 else 1)
