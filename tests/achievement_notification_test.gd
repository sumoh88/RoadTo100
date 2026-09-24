extends Node


# Tests for the achievement unlock notification (Main.tscn ->
# OverlayLayer/UnlockPopup + UnlockName + UnlockDesc): show/hide ~4s, FIFO
# order, no loss of unlocks, no timer reset on new arrival, demo/tutorial gate,
# secret description revealed after unlock.
# Run: ./Godot3 --path /path/to/project tests/achievement_notification_test.tscn --no-window
#
# NOTE: this Godot 3.4 build has no `await` and coroutine calls are fire-and-
# forget, so the whole test flow is ONE coroutine (_run_tests) with inline
# yield(get_tree(), "idle_frame") wait loops. All helpers are sync-only.

var passed = 0
var failed = 0
var failures = []

var _main = null
var _popup = null
var _name_lbl = null
var _desc_lbl = null
var _stats_inst = null


func _ready():
	_run_tests()


# Single top-level coroutine: runs every test in order (sequential yields).
func _run_tests():
	var out = ""
	out += "========================================\n"
	out += " Achievement Notification Test (UnlockPopup FIFO)\n"
	out += "========================================\n"

	out += _assert(_setup_main(), "Main.tscn instantiated; UnlockPopup/UnlockName/UnlockDesc found")
	out += _assert(_setup_stats_table(), "Stats table loaded for expected name/description checks")
	yield(get_tree(), "idle_frame")  # let Main's _ready() run (signal wired, Stats instanced)

	if _popup != null and _stats_inst != null:
		# ---- Test 1: Unlock -> popup with name+description visible for ~4s -> hidden. ----
		var t_dr = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t_dr) > 6.0 * 1000:
					break
		_reset_locks()
		var id = "jolly_primo"
		out += _assert(not _popup.visible and not GlobalsUtilities.is_achievement_unlocked(id),
			"popup hidden and %s locked before unlock" % id)
		GlobalsUtilities.unlock_achievement(id)

		var t_show = 0.0
		var t0 = OS.get_ticks_msec()
		if not _popup.visible:
			while not _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t0) > 1.0 * 1000:
					t_show = -1.0
					break
		t_show = (OS.get_ticks_msec() - t0) / 1000.0
		out += _assert(t_show >= 0 and t_show <= 0.5, "popup visible within ~1 frame of the unlock (t=%.3fs)" % t_show)
		out += _assert(_name_lbl.text == name_of(id), "UnlockName = '%s'" % _name_lbl.text)
		out += _assert(_desc_lbl.text == desc_of(id), "UnlockDesc matches the Stats definition")

		var t_hide = 0.0
		var t1 = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t1) > 8.0 * 1000:
					t_hide = -1.0
					break
		t_hide = (OS.get_ticks_msec() - t1) / 1000.0
		out += _assert(t_hide >= 3.5 and t_hide <= 6.0, "popup hidden after ~4 seconds (t=%.2fs)" % t_hide)

		# ---- Test 2: FIFO: simultaneous unlocks shown one by one in received order; nothing lost. ----
		var t_dr2 = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t_dr2) > 6.0 * 1000:
					break
		_reset_locks()
		var order = ["gold_prima", "imbroglio_primo", "ottantanove_primo"]
		for x in order:
			GlobalsUtilities.unlock_achievement(x)
		out += _assert(_popup.visible, "first notification shown immediately after the batch")
		out += _assert(_name_lbl.text == name_of(order[0]), "first shown = first unlocked (FIFO)")

		var t1a = 0.0
		var t0a = OS.get_ticks_msec()
		if _name_lbl.text != name_of(order[1]):
			while _name_lbl.text != name_of(order[1]):
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t0a) > 8.0 * 1000:
					t1a = -1.0
					break
		t1a = (OS.get_ticks_msec() - t0a) / 1000.0
		out += _assert(t1a >= 3.0 and t1a <= 5.5, "second shown ~4s after the first started (t=%.2fs)" % t1a)
		out += _assert(_desc_lbl.text == desc_of(order[1]), "description matches the second entry")

		var t2a = 0.0
		var t0b = OS.get_ticks_msec()
		if _name_lbl.text != name_of(order[2]):
			while _name_lbl.text != name_of(order[2]):
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t0b) > 8.0 * 1000:
					t2a = -1.0
					break
		t2a = (OS.get_ticks_msec() - t0b) / 1000.0
		out += _assert(t2a >= 3.0 and t2a <= 5.5, "third shown ~4s after the second started (t=%.2fs)" % t2a)
		out += _assert(_desc_lbl.text == desc_of(order[2]), "description matches the third entry")

		var th = 0.0
		var t1b = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t1b) > 8.0 * 1000:
					th = -1.0
					break
		th = (OS.get_ticks_msec() - t1b) / 1000.0
		out += _assert(th >= 3.0 and th <= 6.0, "hidden after the last notification (t=%.2fs)" % th)
		out += _assert(_main._unlock_queue.size() == 0, "queue empty after all notifications")

		# ---- Test 3: a new unlock during the display is queued; it does NOT reset the current timer. ----
		var t_dr3 = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t_dr3) > 6.0 * 1000:
					break
		_reset_locks()
		GlobalsUtilities.unlock_achievement("gold_prima")   # A displayed at t=0

		var t0c = OS.get_ticks_msec()
		while (OS.get_ticks_msec() - t0c) < 2.0 * 1000:
			yield(get_tree(), "idle_frame")
		out += _assert(_popup.visible and _name_lbl.text == name_of("gold_prima"),
			"A still displayed after 2 seconds")

		GlobalsUtilities.unlock_achievement("imbroglio_primo")   # B queued during A's display

		var tb = 0.0
		var t1c = OS.get_ticks_msec()
		if _name_lbl.text != name_of("imbroglio_primo"):
			while _name_lbl.text != name_of("imbroglio_primo"):
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t1c) > 8.0 * 1000:
					tb = -1.0
					break
		tb = (OS.get_ticks_msec() - t1c) / 1000.0
		out += _assert(tb >= 1.5 and tb <= 3.5,
			"B shown ~4s after A started (timer NOT reset by B's arrival; t=%.2fs)" % tb)

		# ---- Test 4: demo and tutorial runs never generate notifications (and queue nothing). ----
		var t_dr4 = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t_dr4) > 6.0 * 1000:
					break
		_reset_locks()
		GlobalsUtilities.demoStarted = true
		GlobalsUtilities.unlock_achievement("piu_undici_primo")
		out += _assert(not _popup.visible, "no notification while demo is active")
		out += _assert(_main._unlock_queue.size() == 0, "demo unlock not queued for later display")
		GlobalsUtilities.demoStarted = false

		GlobalsUtilities.tutorialStarted = true
		GlobalsUtilities.unlock_achievement("ottantanove_primo")
		out += _assert(not _popup.visible, "no notification while tutorial is active")
		out += _assert(_main._unlock_queue.size() == 0, "tutorial unlock not queued for later display")
		GlobalsUtilities.tutorialStarted = false

		# ---- Test 5: secret achievement: description revealed after unlock (from Stats definition). ----
		var t_dr5 = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t_dr5) > 6.0 * 1000:
					break
		_reset_locks()
		GlobalsUtilities.unlock_achievement("giro_sicuro")

		var t_show2 = 0.0
		var t0d = OS.get_ticks_msec()
		if not _popup.visible:
			while not _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t0d) > 1.0 * 1000:
					t_show2 = -1.0
					break
		t_show2 = (OS.get_ticks_msec() - t0d) / 1000.0
		out += _assert(t_show2 >= 0 and t_show2 <= 0.5, "secret achievement notification shown within ~1 frame (t=%.3fs)" % t_show2)
		out += _assert(_name_lbl.text == name_of("giro_sicuro"), "UnlockName = 'Giro Sicuro'")
		out += _assert(_desc_lbl.text == desc_of("giro_sicuro") and _desc_lbl.text != "Bloccato",
			"secret description revealed after unlock (got '%s')" % _desc_lbl.text)

		var th2 = 0.0
		var t1d = OS.get_ticks_msec()
		if _popup.visible:
			while _popup.visible:
				yield(get_tree(), "idle_frame")
				if (OS.get_ticks_msec() - t1d) > 8.0 * 1000:
					th2 = -1.0
					break
		th2 = (OS.get_ticks_msec() - t1d) / 1000.0
		out += _assert(th2 >= 3.5 and th2 <= 6.0, "secret notification hidden after ~4 seconds (t=%.2fs)" % th2)
	else:
		out += _assert(false, "skipping timed tests: main scene nodes not found")

	print(out)
	out += "========================================\n"
	out += " PASS: %d  FAIL: %d\n" % [passed, failed]
	if failed > 0:
		for f in failures:
			print("FAILED: " + f)
	get_tree().quit(1 if failed > 0 else 0)


func _assert(cond, msg):
	if cond:
		passed += 1
	else:
		failed += 1
		failures.append(msg)
	return ("  [PASS] " if cond else "  [FAIL] ") + msg


# Sync: instance Main.tscn (no yield here — node lookup is immediate on add).
func _setup_main():
	var packed = load("res://Main.tscn")
	if packed == null:
		return false
	_main = packed.instance()
	add_child(_main)
	var popup = _main.get_node_or_null("OverlayLayer/UnlockPopup")
	if popup == null or popup.get_node_or_null("UnlockName") == null or popup.get_node_or_null("UnlockDesc") == null:
		return false
	_popup = popup
	_name_lbl = popup.get_node("UnlockName")
	_desc_lbl = popup.get_node("UnlockDesc")
	return true


func _setup_stats_table():
	var packed = load("res://Stats.tscn")
	if packed == null:
		return false
	_stats_inst = packed.instance()
	return true


# Expected name/description from the SAME definition Stats displays.
func _entry(id):
	for a in _stats_inst.achievements:
		if str(a.get("id", "")) == id:
			return a
	return null


func name_of(id):
	var e = _entry(id)
	return str(e.get("name", "")) if e != null else ""


func desc_of(id):
	var e = _entry(id)
	return str(e.get("description", "")) if e != null else ""


# Clear in-memory unlocks so each test starts from a fresh set.
func _reset_locks():
	GlobalsUtilities.unlocked_achievements = {}
