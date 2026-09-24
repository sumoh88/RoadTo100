extends Node

# Tests for the Stats & Achievements system (GlobalsUtilities + Stats scene).
# Run: ./Godot3 --path /path/to/project tests/stats_achievements_test.tscn --no-window

var passed = 0
var failed = 0
var failures = []


func _ready():
	var out = ""
	out += "========================================\n"
	out += " Stats & Achievements Test\n"
	out += "========================================\n"
	out += _test_games_played_incremented()
	out += _test_wins_and_streaks()
	out += _test_special_round_counters()
	out += _test_giro_unlock_on_conclusion()
	out += _test_achievement_unlock_on_condition()
	out += _test_fastest_win()
	out += _test_save_load_persistence()
	out += _test_fresh_install_defaults()
	out += _test_stats_scene_shows_values()
	# --- 10 remaining achievements ---
	out += _test_per_un_soffio()
	out += _test_stratega()
	out += _test_cascata_d_oro()
	out += _test_imbattibile()
	out += _test_contromossa()
	out += _test_jolly_strategico()
	out += _test_oro_vincente()
	out += _test_oro_vincente_deactivation()
	out += _test_all_ultimo_turno()
	out += _test_all_ultimo_turno_deactivation()
	out += _test_carta_della_vittoria()
	out += _test_trasformista()
	out += _test_new_achievements_persist()
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


# Reset stats/achievements to fresh-install values (isolates each test).
func _reset_stats():
	GlobalsUtilities.stats = {
		"games_played": 0,
		"games_won": 0,
		"current_streak": 0,
		"best_streak": 0,
		"fastest_win_turns": -1,
		"advantage_rounds": 0,
		"safe_rounds": 0,
	}
	GlobalsUtilities.unlocked_achievements = {}
	GlobalsUtilities.reset_game_tracking()


# Base snapshot for event-driven tests.
func _snap(local_id = "player_1"):
	return {
		"local_player_id": local_id,
		"players": [],
		"piatto": 0,
		"special_round_active": false,
		"special_round_type": "advantage",
		"special_round_player_id": null,
		"winner": null,
		"turn_number": 0,
		"plateau_cards": [],
		"discard_stack": [],
	}


# Activate a special round (activator) via the real apply_action_result flow.
func _activate_sr(sr_type, activator):
	var s = _snap("player_1")
	s["special_round_active"] = true
	s["special_round_type"] = sr_type
	s["special_round_player_id"] = activator
	GlobalsUtilities.apply_action_result(s, [
		{"type": "advantage_started", "player_id": activator},
	])


# Conclude the currently-tracked special round (advantage_ended, snapshot inactive).
func _conclude_sr():
	var s = _snap("player_1")
	s["special_round_active"] = false
	s["special_round_player_id"] = null
	GlobalsUtilities.apply_action_result(s, [
		{"type": "advantage_ended"},
	])


# 1. Stats update after a game (games played + via record_game_over).
func _test_games_played_incremented():
	var out = ""
	_reset_stats()
	GlobalsUtilities.record_game_result("player_1", "player_2", 5)
	out += _assert(int(GlobalsUtilities.stats["games_played"]) == 1, "games_played incremented to 1 after a game")
	GlobalsUtilities.record_game_over({"local_player_id": "player_1", "winner": "player_3", "turn_number": 4})
	out += _assert(int(GlobalsUtilities.stats["games_played"]) == 2, "games_played incremented via record_game_over")
	return out


# 2. Wins and streaks update correctly.
func _test_wins_and_streaks():
	var out = ""
	_reset_stats()
	GlobalsUtilities.record_game_result("player_1", "player_1", 10)
	out += _assert(int(GlobalsUtilities.stats["games_won"]) == 1, "games_won = 1 after a win")
	out += _assert(int(GlobalsUtilities.stats["current_streak"]) == 1, "current_streak = 1 after a win")
	out += _assert(int(GlobalsUtilities.stats["best_streak"]) == 1, "best_streak = 1 after a win")
	GlobalsUtilities.record_game_result("player_1", "player_1", 8)
	out += _assert(int(GlobalsUtilities.stats["current_streak"]) == 2, "current_streak = 2 after two wins")
	out += _assert(int(GlobalsUtilities.stats["best_streak"]) == 2, "best_streak = 2 after two wins")
	GlobalsUtilities.record_game_result("player_1", "player_2", 6)
	out += _assert(int(GlobalsUtilities.stats["current_streak"]) == 0, "current_streak resets to 0 on a loss")
	out += _assert(int(GlobalsUtilities.stats["best_streak"]) == 2, "best_streak unchanged on a loss")
	return out


# 3. GdV / Giro Sicuro counters: only rounds the LOCAL player activates count.
# Counters increment on activation; the achievements unlock ONLY on conclusion
# (covered in _test_giro_unlock_on_conclusion).
func _test_special_round_counters():
	var out = ""
	_reset_stats()
	# Local activation -> counter +1, but achievement still LOCKED (not on activation).
	GlobalsUtilities.record_special_round_started("advantage", "player_1", "player_1")
	out += _assert(int(GlobalsUtilities.stats["advantage_rounds"]) == 1, "GdV counter = 1 after local activation")
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("giro_di_vantaggio"),
		"giro_di_vantaggio still LOCKED after activation alone (no conclusion yet)")
	# Opponent activation -> NOT counted, no unlock.
	GlobalsUtilities.record_special_round_started("advantage", "player_2", "player_1")
	out += _assert(int(GlobalsUtilities.stats["advantage_rounds"]) == 1, "GdV counter unchanged by opponent activation")
	# Safe round: local counts, achievement still locked.
	GlobalsUtilities.record_special_round_started("safe", "player_1", "player_1")
	out += _assert(int(GlobalsUtilities.stats["safe_rounds"]) == 1, "GS counter = 1 after local GS activation")
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("giro_sicuro"),
		"giro_sicuro still LOCKED after activation alone (no conclusion yet)")
	GlobalsUtilities.record_special_round_started("safe", "player_3", "player_1")
	out += _assert(int(GlobalsUtilities.stats["safe_rounds"]) == 1, "GS counter unchanged by opponent activation")
	return out


# Giro di Vantaggio / Giro Sicuro unlock ONLY when P1 activates AND concludes
# the round (via the real apply_action_result flow). Covers:
#   1) activation without conclusion -> locked;
#   2) activation + conclusion -> unlocked;
#   3) round activated by an opponent -> no local unlock.
func _test_giro_unlock_on_conclusion():
	var out = ""
	# --- GdV: activation without conclusion -> locked. ---
	_reset_stats()
	_activate_sr("advantage", "player_1")
	out += _assert(int(GlobalsUtilities.stats["advantage_rounds"]) == 1,
		"GdV counter incremented on local activation")
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("giro_di_vantaggio"),
		"giro_di_vantaggio still LOCKED after activation without conclusion")

	# --- GdV: activation + conclusion -> unlocked. ---
	_conclude_sr()
	out += _assert(GlobalsUtilities.is_achievement_unlocked("giro_di_vantaggio"),
		"giro_di_vantaggio UNLOCKS on conclusion of a P1-activated GdV")

	# --- GdV: opponent-activated round concluded -> no local unlock. ---
	_reset_stats()
	_activate_sr("advantage", "player_2")
	out += _assert(int(GlobalsUtilities.stats["advantage_rounds"]) == 0,
		"GdV counter unchanged when an opponent activates it")
	_conclude_sr()
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("giro_di_vantaggio"),
		"giro_di_vantaggio NOT unlocked when an opponent's GdV concludes")

	# --- GS: same three cases. ---
	_reset_stats()
	_activate_sr("safe", "player_1")
	out += _assert(int(GlobalsUtilities.stats["safe_rounds"]) == 1,
		"GS counter incremented on local activation")
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("giro_sicuro"),
		"giro_sicuro still LOCKED after activation without conclusion")
	_conclude_sr()
	out += _assert(GlobalsUtilities.is_achievement_unlocked("giro_sicuro"),
		"giro_sicuro UNLOCKS on conclusion of a P1-activated GS")

	_reset_stats()
	_activate_sr("safe", "player_2")
	_conclude_sr()
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("giro_sicuro"),
		"giro_sicuro NOT unlocked when an opponent's GS concludes")
	return out


# 4. An achievement unlocks when its condition occurs.
# (Giro di Vantaggio / Giro Sicuro now unlock on CONCLUSION, not activation —
#  verified in _test_giro_unlock_on_conclusion.)
func _test_achievement_unlock_on_condition():
	var out = ""
	_reset_stats()
	GlobalsUtilities.record_game_result("player_1", "player_1", 5)
	#out += _assert(GlobalsUtilities.is_achievement_unlocked("prima_vittoria"), "Prima vittoria unlocks on first win")
	# Activation alone does NOT unlock the special-round achievement.
	GlobalsUtilities.record_special_round_started("advantage", "player_1", "player_1")
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("giro_di_vantaggio"),
		"Giro di Vantaggio stays locked after activation alone")
	GlobalsUtilities.record_local_card_played("jolly", "Jolly")
	out += _assert(GlobalsUtilities.is_achievement_unlocked("jolly_primo"), "Jolly! unlocks when local player plays a Jolly")
	return out


# Fastest win tracked as the lowest winning turn count.
func _test_fastest_win():
	var out = ""
	_reset_stats()
	GlobalsUtilities.record_game_result("player_1", "player_1", 10)
	out += _assert(int(GlobalsUtilities.stats["fastest_win_turns"]) == 10, "fastest_win_turns = 10 after first win")
	GlobalsUtilities.record_game_result("player_1", "player_1", 6)
	out += _assert(int(GlobalsUtilities.stats["fastest_win_turns"]) == 6, "fastest_win_turns updates to lower value (6)")
	return out


# 5. Data survives save/load (real serialization helpers, isolated ConfigFile).
func _test_save_load_persistence():
	var out = ""
	_reset_stats()
	GlobalsUtilities.stats["games_played"] = 7
	GlobalsUtilities.stats["games_won"] = 3
	GlobalsUtilities.stats["advantage_rounds"] = 2
	GlobalsUtilities.unlock_achievement("giro_di_vantaggio")

	var tmp_path = "user://stats_test_tmp.cfg"
	var old_config = GlobalsUtilities.config
	var cf = ConfigFile.new()
	GlobalsUtilities.config = cf
	GlobalsUtilities._write_stats_to_config()
	var rc_save = cf.save(tmp_path)

	# Reset in-memory, then reload from the saved file.
	_reset_stats()
	var rc_load = cf.load(tmp_path)
	GlobalsUtilities._load_stats_from_config()

	out += _assert(rc_save == OK, "config save returns OK")
	out += _assert(rc_load == OK, "config load returns OK")
	out += _assert(int(GlobalsUtilities.stats["games_played"]) == 7, "games_played persisted (7)")
	out += _assert(int(GlobalsUtilities.stats["games_won"]) == 3, "games_won persisted (3)")
	out += _assert(int(GlobalsUtilities.stats["advantage_rounds"]) == 2, "advantage_rounds persisted (2)")
	out += _assert(GlobalsUtilities.is_achievement_unlocked("giro_di_vantaggio"), "achievement flag persisted")

	GlobalsUtilities.config = old_config
	return out


# 7. Fresh install / no data keeps valid initial values.
func _test_fresh_install_defaults():
	var out = ""
	_reset_stats()
	var s = GlobalsUtilities.get_stats()
	out += _assert(int(s["games_played"]) == 0, "fresh games_played = 0")
	out += _assert(int(s["games_won"]) == 0, "fresh games_won = 0")
	out += _assert(int(s["current_streak"]) == 0, "fresh current_streak = 0")
	out += _assert(int(s["best_streak"]) == 0, "fresh best_streak = 0")
	out += _assert(int(s["fastest_win_turns"]) == -1, "fresh fastest_win_turns = -1 (none yet)")
	#out += _assert(not GlobalsUtilities.is_achievement_unlocked("prima_vittoria"), "no achievements unlocked on fresh install")
	return out


# 6. Stats scene reads and displays the persistent values.
# Uses values distinct from the .tscn placeholders so a pass only occurs when the
# display logic actually runs; _update_stats_display is invoked on an instanced
# (unattached) scene so no tree setup is required.
func _test_stats_scene_shows_values():
	var out = ""
	_reset_stats()
	GlobalsUtilities.stats["games_played"] = 123
	GlobalsUtilities.stats["games_won"] = 45        # 45/123 -> 37%
	GlobalsUtilities.stats["current_streak"] = 3
	GlobalsUtilities.stats["best_streak"] = 7
	GlobalsUtilities.stats["fastest_win_turns"] = 9
	GlobalsUtilities.stats["advantage_rounds"] = 12
	GlobalsUtilities.stats["safe_rounds"] = 40

	var scene = load("res://Stats.tscn")
	if scene == null:
		out += _assert(false, "could not load Stats.tscn")
		return out
	var inst = scene.instance()
	inst._update_stats_display()

	var v1 = inst.get_node_or_null("StatsContainer/StatsList/games_played/Value")
	var v2 = inst.get_node_or_null("StatsContainer/StatsList/games_won/Value")
	var v5 = inst.get_node_or_null("StatsContainer/StatsList/fastest_win_turns/Value")
	out += _assert(v1 != null and v1.text == "123", "Partite giocate shows 123 (got '" + str(v1.text if v1 else null) + "')")
	out += _assert(v2 != null and v2.text == "45 (37%)", "Partite vinte shows '45 (37%)' (got '" + str(v2.text if v2 else null) + "')")
	out += _assert(v5 != null and v5.text == "9 turni", "Vittoria più veloce shows '9 turni' (got '" + str(v5.text if v5 else null) + "')")

	inst.queue_free()
	return out


# Per un soffio: lose a game while being the Giro di Vantaggio activator.
func _test_per_un_soffio():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "advantage_started", "player_id": "player_1"},
	])
	var s2 = _snap("player_1")
	s2["winner"] = "player_2"
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "game_won", "player_id": "player_2"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("per_un_soffio"),
		"Per un soffio unlocks when local loses as GdV activator")

	_reset_stats()
	var s3 = _snap("player_1")
	s3["winner"] = "player_2"
	GlobalsUtilities.apply_action_result(s3, [
		{"type": "game_won", "player_id": "player_2"},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("per_un_soffio"),
		"Per un soffio NOT unlocked on a plain loss (no GdV activation)")
	return out


# Stratega: use the bounce to make the Piatto drop (removes next player's win).
func _test_stratega():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	s1["discard_stack"] = [
		{"card_id": "c1", "name": "+5", "card_type": "increment", "value": 5},
	]
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "card_played", "player_id": "player_1", "card_id": "c1", "resolved_value": 5},
		{"type": "piatto_changed", "old_value": 98, "new_value": 97},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("stratega"),
		"Stratega unlocks when a local play makes the Piatto drop (bounce)")

	_reset_stats()
	var s2 = _snap("player_1")
	s2["discard_stack"] = [
		{"card_id": "c1", "name": "+5", "card_type": "increment", "value": 5},
	]
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "card_played", "player_id": "player_1", "card_id": "c1", "resolved_value": 5},
		{"type": "piatto_changed", "old_value": 50, "new_value": 52},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("stratega"),
		"Stratega NOT unlocked when the Piatto rises (no bounce)")
	return out


# Cascata d'oro: P1 starts a turn with exactly three 89 in hand.
func _test_cascata_d_oro():
	var out = ""
	_reset_stats()
	# Turn start: turn_changed to local with 3x89 in hand.
	var s1 = _snap("player_1")
	s1["players"] = [{"id": "player_1", "hand": [
		{"card_id": "a", "name": "89", "card_type": "special"},
		{"card_id": "b", "name": "89", "card_type": "special"},
		{"card_id": "c", "name": "89", "card_type": "special"},
	]}]
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "turn_changed", "player_id": "player_1", "turn_number": 3},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("cascata_d_oro"),
		"Cascata d'oro unlocks when P1 starts a turn with three 89")

	_reset_stats()
	var s2 = _snap("player_1")
	s2["players"] = [{"id": "player_1", "hand": [
		{"card_id": "a", "name": "89", "card_type": "special"},
		{"card_id": "b", "name": "89", "card_type": "special"},
	]}]
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "turn_changed", "player_id": "player_1", "turn_number": 3},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("cascata_d_oro"),
		"Cascata d'oro NOT unlocked when P1 starts a turn with only two 89")
	return out


# Imbattibile: P1 starts a turn with exactly three +11 in hand.
func _test_imbattibile():
	var out = ""
	_reset_stats()
	# Turn start: turn_changed to local with 3x+11 in hand.
	var s1 = _snap("player_1")
	s1["players"] = [{"id": "player_1", "hand": [
		{"card_id": "a", "name": "+11", "card_type": "increment"},
		{"card_id": "b", "name": "+11", "card_type": "increment"},
		{"card_id": "c", "name": "+11", "card_type": "increment"},
	]}]
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "turn_changed", "player_id": "player_1", "turn_number": 3},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("imbattibile"),
		"Imbattibile unlocks when P1 starts a turn with three +11")

	_reset_stats()
	var s2 = _snap("player_1")
	s2["players"] = [{"id": "player_1", "hand": [
		{"card_id": "a", "name": "+11", "card_type": "increment"},
		{"card_id": "b", "name": "+11", "card_type": "increment"},
	]}]
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "turn_changed", "player_id": "player_1", "turn_number": 3},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("imbattibile"),
		"Imbattibile NOT unlocked when P1 starts a turn with only two +11")
	return out


# Contromossa: win after having played an Imbroglio in the previous turn.
func _test_contromossa():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	s1["discard_stack"] = [
		{"card_id": "imb", "name": "Imbroglio", "card_type": "imbroglio"},
	]
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "card_played", "player_id": "player_1", "card_id": "imb", "resolved_value": 5},
	])
	var s2 = _snap("player_1")
	s2["winner"] = "player_1"
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("contromossa"),
		"Contromossa unlocks when local wins right after playing an Imbroglio")

	_reset_stats()
	var s3 = _snap("player_1")
	s3["winner"] = "player_1"
	GlobalsUtilities.apply_action_result(s3, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("contromossa"),
		"Contromossa NOT unlocked when there was no prior Imbroglio")
	return out


# Jolly strategico: win a game after having used a Jolly.
func _test_jolly_strategico():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	s1["discard_stack"] = [
		{"card_id": "jol", "name": "Jolly", "card_type": "jolly"},
	]
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "card_played", "player_id": "player_1", "card_id": "jol", "resolved_value": 5},
	])
	var s2 = _snap("player_1")
	s2["winner"] = "player_1"
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("jolly_strategico"),
		"Jolly strategico unlocks when local wins after having used a Jolly")

	_reset_stats()
	var s3 = _snap("player_1")
	s3["winner"] = "player_1"
	GlobalsUtilities.apply_action_result(s3, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("jolly_strategico"),
		"Jolly strategico NOT unlocked when no Jolly was used")
	return out


# Oro vincente: win while being the activator of a Giro Sicuro.
func _test_oro_vincente():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	s1["winner"] = "player_1"
	s1["special_round_active"] = true
	s1["special_round_type"] = "safe"
	s1["special_round_player_id"] = "player_1"
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("oro_vincente"),
		"Oro vincente unlocks when local wins as Giro Sicuro activator")

	_reset_stats()
	var s2 = _snap("player_1")
	s2["winner"] = "player_1"
	s2["special_round_active"] = true
	s2["special_round_type"] = "safe"
	s2["special_round_player_id"] = "player_2"
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("oro_vincente"),
		"Oro vincente NOT unlocked when another player activated the Giro Sicuro")
	return out


# All'ultimo turno: win during the concluding turn of a Giro di Vantaggio.
func _test_all_ultimo_turno():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	s1["winner"] = "player_1"
	s1["special_round_active"] = true
	s1["special_round_type"] = "advantage"
	s1["special_round_player_id"] = "player_1"
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("all_ultimo_turno"),
		"All'ultimo turno unlocks when local wins as the GdV advantage player")

	_reset_stats()
	var s2 = _snap("player_1")
	s2["winner"] = "player_1"
	s2["special_round_active"] = false
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("all_ultimo_turno"),
		"All'ultimo turno NOT unlocked when no GdV round is active")
	return out


# All'ultimo turno (deactivation-on-win): the snapshot is taken AFTER advance_turn,
# which deactivates the GdV on its concluding turn. The achievement must still
# unlock because the special-round state is reconstructed from events + tracked state.
func _test_all_ultimo_turno_deactivation():
	var out = ""
	_reset_stats()
	# Action 1: P1 activates the GdV (snapshot after advance still shows it active).
	var s1 = _snap("player_1")
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "advantage_started", "player_id": "player_1"},
	])
	out += _assert(str(GlobalsUtilities.game_tmp.get("sr_player_id", "")) == "player_1"
		and str(GlobalsUtilities.game_tmp.get("sr_type", "")) == "advantage",
		"GdV state tracked after activation")

	# Action 2 (concluding turn): P1 wins. advance_turn deactivates the GdV, so the
	# final snapshot shows special_round_active=false and emits advantage_ended.
	var s2 = _snap("player_1")
	s2["winner"] = "player_1"
	s2["special_round_active"] = false
	s2["special_round_player_id"] = null
	s2["discard_stack"] = [
		{"card_id": "w", "name": "+5", "card_type": "increment", "value": 5},
	]
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "card_played", "player_id": "player_1", "card_id": "w", "resolved_value": 5},
		{"type": "piatto_changed", "old_value": 95, "new_value": 100},
		{"type": "game_won", "player_id": "player_1"},
		{"type": "turn_changed", "player_id": "player_2", "turn_number": 4},
		{"type": "advantage_ended"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("all_ultimo_turno"),
		"All'ultimo turno unlocks on a concluding-turn win even though the snapshot shows the round deactivated")
	return out


# Oro vincente (deactivation-on-win): same reconstruction applies to Giro Sicuro.
func _test_oro_vincente_deactivation():
	var out = ""
	_reset_stats()
	# Action 1: P1 activates a Giro Sicuro.
	var s1 = _snap("player_1")
	s1["special_round_type"] = "safe"
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "advantage_started", "player_id": "player_1"},
	])
	# Action 2 (concluding turn): P1 wins; GS deactivated by advance_turn.
	var s2 = _snap("player_1")
	s2["winner"] = "player_1"
	s2["special_round_active"] = false
	s2["special_round_player_id"] = null
	s2["discard_stack"] = [
		{"card_id": "w", "name": "+5", "card_type": "increment", "value": 5},
	]
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "card_played", "player_id": "player_1", "card_id": "w", "resolved_value": 5},
		{"type": "piatto_changed", "old_value": 95, "new_value": 100},
		{"type": "game_won", "player_id": "player_1"},
		{"type": "turn_changed", "player_id": "player_2", "turn_number": 4},
		{"type": "advantage_ended"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("oro_vincente"),
		"Oro vincente unlocks on a concluding-turn win even though the snapshot shows the round deactivated")
	return out


# Colpo di fortuna: win with a +11.
func _test_carta_della_vittoria():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	s1["winner"] = "player_1"
	s1["discard_stack"] = [
		{"card_id": "p11", "name": "+11", "card_type": "increment"},
	]
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "card_played", "player_id": "player_1", "card_id": "p11", "resolved_value": 11},
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("carta_della_vittoria"),
		"Colpo di fortuna unlocks when local wins with a +11")

	_reset_stats()
	var s2 = _snap("player_1")
	s2["winner"] = "player_1"
	s2["discard_stack"] = [
		{"card_id": "p8", "name": "+8", "card_type": "increment", "value": 8},
	]
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "card_played", "player_id": "player_1", "card_id": "p8", "resolved_value": 8},
		{"type": "game_won", "player_id": "player_1"},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("carta_della_vittoria"),
		"Colpo di fortuna NOT unlocked when winning with a non-+11 card")
	return out


# Trasformista: transform a +11 into a Gold.
func _test_trasformista():
	var out = ""
	_reset_stats()
	var s1 = _snap("player_1")
	s1["plateau_cards"] = [
		{"card_id": "transformed_gold_23", "name": "23", "card_type": "gold"},
	]
	s1["discard_stack"] = [
		{"card_id": "p11", "name": "+11", "card_type": "increment"},
	]
	GlobalsUtilities.apply_action_result(s1, [
		{"type": "card_played", "player_id": "player_1", "card_id": "p11", "resolved_value": 11},
	])
	out += _assert(GlobalsUtilities.is_achievement_unlocked("trasformista"),
		"Trasformista unlocks when a local +11 transforms into a Gold")

	_reset_stats()
	var s2 = _snap("player_1")
	s2["plateau_cards"] = []
	s2["discard_stack"] = [
		{"card_id": "p11", "name": "+11", "card_type": "increment"},
	]
	GlobalsUtilities.apply_action_result(s2, [
		{"type": "card_played", "player_id": "player_1", "card_id": "p11", "resolved_value": 11},
	])
	out += _assert(not GlobalsUtilities.is_achievement_unlocked("trasformista"),
		"Trasformista NOT unlocked when no +11->Gold transformation occurred")
	return out


# The newly-implemented achievements persist through save/load.
func _test_new_achievements_persist():
	var out = ""
	_reset_stats()
	GlobalsUtilities.unlock_achievement("stratega")
	GlobalsUtilities.unlock_achievement("cascata_d_oro")
	GlobalsUtilities.unlock_achievement("carta_della_vittoria")

	var tmp_path = "user://stats_test_new_ach.cfg"
	var old_config = GlobalsUtilities.config
	var cf = ConfigFile.new()
	GlobalsUtilities.config = cf
	GlobalsUtilities._write_stats_to_config()
	var rc_save = cf.save(tmp_path)

	_reset_stats()
	var rc_load = cf.load(tmp_path)
	GlobalsUtilities._load_stats_from_config()

	out += _assert(rc_save == OK, "new-achievement config save returns OK")
	out += _assert(GlobalsUtilities.is_achievement_unlocked("stratega"), "stratega persisted")
	out += _assert(GlobalsUtilities.is_achievement_unlocked("cascata_d_oro"), "cascata_d_oro persisted")
	out += _assert(GlobalsUtilities.is_achievement_unlocked("carta_della_vittoria"), "carta_della_vittoria persisted")

	GlobalsUtilities.config = old_config
	return out
