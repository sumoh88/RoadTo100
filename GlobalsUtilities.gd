extends Node


# Emitted when an achievement is actually newly unlocked (was previously locked).
# Main.tscn wires its UnlockPopup notification to this signal.
signal achievement_unlocked(achievement_id)

onready var sr_active = false
onready var music_play = true
onready var sfx_play = true
onready var fullscreen = true
onready var selected_value = ""
onready var gameStarted = false
onready var demoStarted = false
onready var tutorialStarted = false
onready var plateValue = 0
onready var language = ["Italiano", "English"]
onready var currLanguage = "Italiano"

var splash_shown = false

var gamePlayers = 4
# --- Persistent stats & achievements (game records shown in the Stats scene) ---
# Mode-agnostic values. Recording methods below update these; persistence reuses
# the existing ConfigFile system (SaveData / LoadSavedData).
var stats = {
	"games_played": 0,
	"games_won": 0,
	"current_streak": 0,
	"best_streak": 0,
	"fastest_win_turns": -1,   # -1 = no win yet; else turns to win (lower = faster)
	"advantage_rounds": 0,     # Giri di Vantaggio attivati
	"safe_rounds": 0,          # Giri Sicuri attivati
}
var unlocked_achievements = {}

# Per-game temporary tracking for multi-turn achievement conditions. NOT
# persisted; reset via reset_game_tracking() at the start of each game.
var game_tmp = {
	"local_activated_gdv": false,        # local activated a GdV this game (Per un soffio)
	"local_used_jolly": false,           # local played a Jolly this game
	"local_prev_action_imbroglio": false,# local's previous play was an Imbroglio
	"sr_player_id": "",                  # current SR activator (event-tracked so it survives advance_turn clearing)
	"sr_type": "advantage",              # current SR type ("advantage" / "safe")
}

const THRESHOLD_PIANO: int = 30
const THRESHOLD_CELLO: int = 60
const THRESHOLD_VIOLIN: int = 89

var font_data = load("res://fonts/Dyuthi.ttf")

onready var options = load("res://OptionMenu.tscn").instance()
onready var languageNode = options.get_node("VBoxContainer/Language/HBoxContainer/currLanguage")
onready var fullscreenNode = options.get_node("VBoxContainer/Utility/FullscreenLabel/CheckFullScreen")
onready var musicNode = options.get_node("VBoxContainer/Audio/MusicLabel/CheckMusic")
onready var SFXNode = options.get_node("VBoxContainer/Audio/SFXLabel/CheckSFX")
onready var config = ConfigFile.new()
var exe_dir = OS.get_executable_path().get_base_dir()

var config_path

func _ready():
	LoadSavedData()

func setCustomFont(currNode, size, spacing = 0, spacingTop = 12):
	if font_data != null:
		var dyn_font = DynamicFont.new()
		dyn_font.font_data = font_data
		dyn_font.size = size
		dyn_font.outline_size = 2
		dyn_font.outline_color = Color(0, 0, 0, 1)
		dyn_font.extra_spacing_top = spacingTop
		dyn_font.use_filter = true
		dyn_font.use_mipmaps = true
		dyn_font.extra_spacing_char = spacing
		currNode.add_font_override("font", dyn_font)



func setCustomStyle(currNode, type, image):
	var styleN = StyleBoxTexture.new()
	var styleD = StyleBoxTexture.new()
	var styleP = StyleBoxTexture.new()
	var styleH = StyleBoxTexture.new()
	var styleF = StyleBoxEmpty.new()
	var imgPath = "res://imgs/"+image+".png"
	
	styleN.texture = load(imgPath)
	currNode.add_stylebox_override(type, styleN)

	styleD.texture = load("res://imgs/btnDisabled.png")
	currNode.add_stylebox_override("disabled", styleD)

	styleP.texture = load("res://imgs/btnPressed.png")
	currNode.add_stylebox_override("pressed", styleP)

	styleH.texture = load("res://imgs/btnChange.png")
	currNode.add_stylebox_override("hover", styleD)
	
	currNode.add_stylebox_override("focus", styleF)
	
func setBtnStyle(currNode):
	var styleN = StyleBoxTexture.new()
	var styleD = StyleBoxTexture.new()
	var styleP = StyleBoxTexture.new()
	var styleH = StyleBoxTexture.new()
	var styleF = StyleBoxEmpty.new()
	
	styleN.texture = load("res://imgs/btnChoice.png")
	currNode.add_stylebox_override("normal", styleN)
	
	styleD.texture = load("res://imgs/btnChoice.png")
	currNode.add_stylebox_override("disabled", styleD)

	styleP.texture = load("res://imgs/btnChoicePressed.png")
	currNode.add_stylebox_override("pressed", styleP)

	styleH.texture = load("res://imgs/btnChoiceHover.png")
	currNode.add_stylebox_override("hover", styleH)
	
	currNode.add_stylebox_override("focus", styleF)
	
	
	
func DeleteSavedData():
	var dir = Directory.new()
	if dir.file_exists(config_path):
		dir.remove(config_path)

	# Ripristina anche i dati attualmente caricati in memoria
	stats = {
		"games_played": 0,
		"games_won": 0,
		"current_streak": 0,
		"best_streak": 0,
		"fastest_win_turns": -1,
		"advantage_rounds": 0,
		"safe_rounds": 0,
	}
	unlocked_achievements = {}

func SaveData():
	print("SAVE")
	_write_stats_to_config()
	config.save(config_path)

func LoadSavedData():
	print("G LOAD IF ", OS.get_name())
	
	if OS.get_name() == "Android":
		config_path = "user://RT100.cfg"
	else:
		config_path = OS.get_executable_path().get_base_dir().plus_file("RT100.cfg")
	var data = config.load(config_path)
	if data == OK:
		var lang = config.get_value("LANGUAGE", "language", currLanguage)
		var fs_value = config.get_value("SCREEN", "fullscreen", fullscreen)
		var music_volume = config.get_value("AUDIO", "music_volume", 0.6)
		var sfx_volume = config.get_value("AUDIO", "sfx_volume", 0.4)
		OS.window_fullscreen = fs_value
		options._on_set_language(0, lang)
		options._on_CheckFullScreen_toggled(fs_value)
		options._on_CheckMusic_value_changed(music_volume * 10)
		options._on_CheckSFX_value_changed(sfx_volume * 10)
		_load_stats_from_config()
	else:
		print("G LOAD ELSE")
		options._on_set_language(0, currLanguage)
		options._on_CheckFullScreen_toggled(fullscreen)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(0.6))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(0.4))
		_load_stats_from_config()

# ---------------------------------------------------------------------------
# Stats & achievements — persistence (reuses the shared ConfigFile)
# ---------------------------------------------------------------------------

func _write_stats_to_config():
	if config == null:
		return
	for k in stats.keys():
		config.set_value("STATS", k, stats[k])
	for id in unlocked_achievements.keys():
		config.set_value("ACHIEVEMENTS", id, true)


func _load_stats_from_config():
	if config == null:
		return
	if config.has_section("STATS"):
		for k in stats.keys():
			print("currStat: ", str(k))
			if config.has_section_key("STATS", k):
				stats[k] = config.get_value("STATS", k, stats[k])
	if config.has_section("ACHIEVEMENTS"):
		unlocked_achievements.clear()
		var keys = config.get_section_keys("ACHIEVEMENTS")
		for id in keys:
			if bool(config.get_value("ACHIEVEMENTS", id, false)):
				unlocked_achievements[id] = true
	print("Stats: ", stats)
# ---------------------------------------------------------------------------
# Stats & achievements — recording (mode-agnostic; caller decides when to invoke)
# ---------------------------------------------------------------------------

func get_stats():
	return stats


func is_achievement_unlocked(id):
	return bool(unlocked_achievements.get(id, false))


# Record a finished game result. `winner_id`/`local_player_id` are compared as strings.
func record_game_result(local_player_id, winner_id, turn_number):
	stats["games_played"] = int(stats["games_played"]) + 1
	if str(winner_id) == str(local_player_id):
		stats["games_won"] = int(stats["games_won"]) + 1
		stats["current_streak"] = int(stats["current_streak"]) + 1
		if int(stats["current_streak"]) > int(stats["best_streak"]):
			stats["best_streak"] = stats["current_streak"]
		var t = int(turn_number)
		if t >= 0 and (int(stats["fastest_win_turns"]) < 0 or t < int(stats["fastest_win_turns"])):
			stats["fastest_win_turns"] = t
	else:
		stats["current_streak"] = 0
	var w = int(stats["games_won"])
#	if w >= 1:
#		unlock_achievement("prima_vittoria")
#	if w >= 5:
#		unlock_achievement("cinque_vittorie")
	if w >= 10:
		unlock_achievement("dieci_vittorie")
	if w >= 25:
		unlock_achievement("vittorie_25")
	if w >= 50:
		unlock_achievement("vittorie_50")
	if w >= 100:
		unlock_achievement("vittorie_100")


# Record a special round activation. sr_type: "advantage" (GdV) or "safe" (Giro Sicuro).
# Only rounds the LOCAL player actually activated are counted/unlocked; rounds
# started by opponents are ignored. Increments the counters; the achievements
# (giro_di_vantaggio / giro_sicuro) are unlocked separately when the round is
# actually concluded, in apply_action_result().
func record_special_round_started(sr_type, activator_id, local_player_id):
	if str(activator_id) != str(local_player_id):
		return

	if str(sr_type) == "advantage":
		stats["advantage_rounds"] = int(stats["advantage_rounds"]) + 1
	else:
		stats["safe_rounds"] = int(stats["safe_rounds"]) + 1

	print("SPECIAL ROUND STARTED")
	print("advantage_rounds: ", int(stats["advantage_rounds"]))
	print("safe_rounds: ", int(stats["safe_rounds"]))

	SaveData()

	print("AFTER SAVE")
	print("advantage_rounds: ", int(stats["advantage_rounds"]))
	print("safe_rounds: ", int(stats["safe_rounds"]))


# Record a card played by the LOCAL player (card-based "first time" achievements).
func record_local_card_played(card_type, card_name):
	var ct = str(card_type).to_lower()
	var nm = str(card_name)
	if ct == "jolly":
		unlock_achievement("jolly_primo")
	elif ct == "imbroglio":
		unlock_achievement("imbroglio_primo")
	elif ct == "gold":
		unlock_achievement("gold_prima")
	elif nm == "89":
		unlock_achievement("ottantanove_primo")
	elif nm == "+11":
		unlock_achievement("piu_undici_primo")


# Set an achievement as unlocked (idempotent). Emits achievement_unlocked only
# when the achievement is actually newly unlocked (was previously locked), so
# the notification shows exactly what just happened.
func unlock_achievement(id):
	if not bool(unlocked_achievements.get(id, false)):
		unlocked_achievements[id] = true
		emit_signal("achievement_unlocked", id)
		SaveData()


# Reset per-game temporary tracking (called at the start of each game).
func reset_game_tracking():
	game_tmp["local_activated_gdv"] = false
	game_tmp["local_used_jolly"] = false
	game_tmp["local_prev_action_imbroglio"] = false
	game_tmp["sr_player_id"] = ""
	game_tmp["sr_type"] = "advantage"


# Process a post-action snapshot+events pair for stats/achievements.
# Handles: special round counters, first-card achievements, turn-start hand
# checks (Cascata d'oro / Imbattibile), +11->Gold transformation, bounce
# (Stratega) and all win-condition achievements. The special-round state is
# reconstructed from events because the final snapshot is taken AFTER
# advance_turn(), which can deactivate the round on its concluding turn and
# thus hide a win that occurred while the round was still live.
func apply_action_result(snapshot, events):
	if snapshot == null:
		return
	var local_player_id = str(snapshot.get("local_player_id", "player_1"))
	var evs = events if events != null else []

	# --- Parse the event batch once. ---
	var had_adv_started = false
	var adv_start_pid = ""
	var had_adv_ended = false
	var winner_id = ""
	for e in evs:
		var t = str(e.get("type", ""))
		if t == "advantage_started" and not had_adv_started:
			had_adv_started = true
			adv_start_pid = str(e.get("player_id", ""))
		elif t == "advantage_ended":
			had_adv_ended = true
		elif t == "game_won" and winner_id == "":
			winner_id = str(e.get("player_id", ""))

	# --- Reconstruct the special-round state as it was when the card was played.
	# The final snapshot is taken AFTER advance_turn(), which can deactivate the
	# round on its concluding turn; that would hide a win that happened while the
	# round was still in effect. game_tmp keeps the last known active round so we
	# can recover it here when the snapshot has already been cleared. ---
	var sr_active_now = bool(snapshot.get("special_round_active", false))
	var sr_type_now = str(snapshot.get("special_round_type", "advantage"))
	var sr_pid_now = snapshot.get("special_round_player_id", null)

	var eff_sr_active = false
	var eff_sr_type = "advantage"
	var eff_sr_pid = ""
	if sr_active_now:
		eff_sr_active = true
		eff_sr_type = sr_type_now
		eff_sr_pid = "" if sr_pid_now == null else str(sr_pid_now)
	elif had_adv_started:
		# Round started on this action; snapshot reflects it.
		eff_sr_active = true
		eff_sr_type = sr_type_now
		eff_sr_pid = adv_start_pid
	elif had_adv_ended and str(game_tmp.get("sr_player_id", "")) != "":
		# Round ended at this turn's advance; it was live while the card played.
		eff_sr_active = true
		eff_sr_type = str(game_tmp.get("sr_type", "advantage"))
		eff_sr_pid = str(game_tmp.get("sr_player_id", ""))
	print("SR DEBUG | had_adv_started=", had_adv_started,
		" adv_start_pid=", adv_start_pid,
		" local_player_id=", local_player_id,
		" eff_sr_type=", eff_sr_type)
	# --- 1) Special-round counters + activation achievement (LOCAL only). ---
	var local_plus11_activated_gdv = false

	for e in evs:
		if str(e.get("type", "")) == "card_played" \
		and str(e.get("player_id", "")) == local_player_id \
		and str(e.get("card_id", "")).begins_with("plus11_"):
			if _plus11_transformed_to_89(snapshot):
				local_plus11_activated_gdv = true
			break

	if had_adv_started and adv_start_pid == local_player_id:
		record_special_round_started(eff_sr_type, adv_start_pid, local_player_id)
		SaveData()
		if eff_sr_type == "advantage":
			game_tmp["local_activated_gdv"] = true
	elif local_plus11_activated_gdv:
		# +11 transformed 78 into 89: this activates GdV without
		# emitting the normal advantage_started event.
		record_special_round_started("advantage", local_player_id, local_player_id)
		SaveData()
		game_tmp["local_activated_gdv"] = true

	# --- 2) Last card played by the local player in this action. ---
	var local_play = null
	for e in evs:
		if str(e.get("type", "")) == "card_played" and str(e.get("player_id", "")) == local_player_id:
			local_play = e

	if local_play != null:
		var card = _find_card_in_snapshot(snapshot, str(local_play.get("card_id", "")))
		if card != null:
			var ct = str(card.get("card_type", "")).to_lower()
			var nm = str(card.get("name", ""))
			record_local_card_played(ct, nm)          # first-card achievements
			if nm == "+11" and _plus11_transformed_to_gold(snapshot):
				unlock_achievement("trasformista")
			_detect_bounce(evs, card, local_play)     # Stratega

	# --- 3) Hand achievements at the LOCAL player's turn start (Cascata/Imbattibile).
	# The post-advance snapshot shows the hand the local player starts this turn with. ---
	var local_turn_start = false
	for e in evs:
		if str(e.get("type", "")) == "turn_changed" and str(e.get("player_id", "")) == local_player_id:
			local_turn_start = true
			break
	if local_turn_start:
		_check_hand_achievements(snapshot, local_player_id)

	# --- 4) Win / loss achievements (use the reconstructed SR state). ---
	if winner_id != "":
		_finalize_win_achievements(local_player_id, winner_id, snapshot, evs, eff_sr_active, eff_sr_type, eff_sr_pid)

	# --- 5) Persist this action's SR state for the next round; clear it when it ends. ---
	if sr_active_now:
		game_tmp["sr_player_id"] = "" if sr_pid_now == null else str(sr_pid_now)
		game_tmp["sr_type"] = sr_type_now
	elif had_adv_started:
		game_tmp["sr_player_id"] = adv_start_pid
		game_tmp["sr_type"] = eff_sr_type
	if had_adv_ended and not sr_active_now and not had_adv_started:
		# The round genuinely finished this turn: unlock the achievement only if
		# P1 was the real activator of the round just concluded.
		var ended_pid = str(game_tmp.get("sr_player_id", ""))
		var ended_type = str(game_tmp.get("sr_type", "advantage"))
		if ended_pid == local_player_id:
			if ended_type == "advantage":
				unlock_achievement("giro_di_vantaggio")
			elif ended_type == "safe":
				unlock_achievement("giro_sicuro")
		game_tmp["sr_player_id"] = ""
		game_tmp["sr_type"] = "advantage"

	# --- 6) Update action-level temp flags for multi-turn win conditions (after checks). ---
	if local_play != null:
		var card2 = _find_card_in_snapshot(snapshot, str(local_play.get("card_id", "")))
		if card2 != null:
			var ct2 = str(card2.get("card_type", "")).to_lower()
			var nm2 = str(card2.get("name", "")).to_lower()
			if ct2 == "jolly" or nm2 == "jolly":
				game_tmp["local_used_jolly"] = true
			game_tmp["local_prev_action_imbroglio"] = (ct2 == "imbroglio" or nm2 == "imbroglio")


# True when a local +11 play transformed into a Gold (transformed card on plateau).
func _plus11_transformed_to_gold(snapshot):
	var pc = snapshot.get("plateau_cards", [])
	if pc.empty():
		return false
	return str(pc[pc.size() - 1].get("card_id", "")).begins_with("transformed_gold_")

func _plus11_transformed_to_89(snapshot):
	var pc = snapshot.get("plateau_cards", [])
	if pc.empty():
		return false
	return str(pc[pc.size() - 1].get("card_id", "")).begins_with("transformed_gold_89")

# Turn-start hand checks: Cascata d'oro (exactly 3x89) / Imbattibile (exactly 3x+11).
func _check_hand_achievements(snapshot, local_player_id):
	var hand = _get_player_hand(snapshot, local_player_id)
	var c89 = 0
	var c11 = 0
	var imb = 0
	var gold = 0
	for hc in hand:
		var n = str(hc.get("name", ""))
		if n == "89":
			c89 += 1
			gold += 1
		elif n == "+11":
			c11 += 1
		elif n == "Imbroglio":
			imb += 1
		elif n == "12" or n == "23" or n == "34" or n == "45" or n == "56" or n == "67" or n == "78":
			gold += 1
	if c89 == 3:
		unlock_achievement("cascata_d_oro")
	if c11 == 3:
		unlock_achievement("imbattibile")
	if imb == 3:
		unlock_achievement("imbroglione")
	if gold == 3:
		unlock_achievement("oro_puro")


func _get_player_hand(snapshot, player_id):
	for p in snapshot.get("players", []):
		if str(p.get("id", "")) == player_id:
			return p.get("hand", [])
	return []


# Stratega: a local increment/jolly play made the Piatto drop (regola del rimbalzo).
func _detect_bounce(evs, card, local_play):
	var ct = str(card.get("card_type", "")).to_lower()
	var nm = str(card.get("name", ""))
	if ct == "gold" or nm == "89" or nm == "+11":
		return  # these never bounce
	var eff = 0
	var rv = local_play.get("resolved_value", null)
	if rv != null:
		eff = int(rv)
	else:
		var cv = card.get("value", 0)
		eff = int(cv) if cv != null else 0
	if eff <= 0:
		return  # Imbroglio (negative) or unknown — not a bounce
	var old_p = null
	var new_p = null
	for e in evs:
		if str(e.get("type", "")) == "piatto_changed":
			old_p = e.get("old_value")
			new_p = e.get("new_value")
			break
	if old_p == null or new_p == null:
		return
	if int(new_p) < int(old_p):
		unlock_achievement("stratega")


# Win-condition achievements, evaluated at the moment a winner is set.
# sr_active/sr_type/sr_pid are the special-round state RECONSTRUCTED at action
# time (see apply_action_result), because the final snapshot is taken after
# advance_turn() and may already reflect the round's deactivation.
func _finalize_win_achievements(local_player_id, winner_id, snapshot, evs, sr_active, sr_type, sr_pid):
	var local_won = (winner_id == local_player_id)

	if not local_won:
		# Per un soffio: P1 lost while being the Giro di Vantaggio player.
		if bool(game_tmp.get("local_activated_gdv", false)):
			unlock_achievement("per_un_soffio")
		return

	# Colpo di fortuna: the winning card was a +11.
	var last_play = null
	for e in evs:
		if str(e.get("type", "")) == "card_played" and str(e.get("player_id", "")) == local_player_id:
			last_play = e
	if last_play != null:
		var c = _find_card_in_snapshot(snapshot, str(last_play.get("card_id", "")))
		if c != null and str(c.get("name", "")) == "+11":
			unlock_achievement("carta_della_vittoria")

	# Oro vincente: won during a Giro Sicuro activated by P1.
	if sr_active and sr_type == "safe" and sr_pid == local_player_id:
		unlock_achievement("oro_vincente")

	# All'ultimo turno: won during the concluding turn of a GdV (P1 advantage player).
	if sr_active and sr_type == "advantage" and sr_pid == local_player_id:
		unlock_achievement("all_ultimo_turno")

	# Jolly strategico: won after having used a Jolly this game.
	if bool(game_tmp.get("local_used_jolly", false)):
		unlock_achievement("jolly_strategico")

	# Contromossa: won right after an Imbroglio on the previous action.
	if bool(game_tmp.get("local_prev_action_imbroglio", false)):
		unlock_achievement("contromossa")


# Record a finished game from its final snapshot (game over point).
func record_game_over(snapshot):
	if snapshot == null or snapshot.get("winner", null) == null:
		return
	record_game_result(
		str(snapshot.get("local_player_id", "player_1")),
		str(snapshot.get("winner", "")),
		int(snapshot.get("turn_number", 0)))


func _find_card_in_snapshot(snapshot, card_id):
	if card_id == "":
		return null
	for p in snapshot.get("players", []):
		for c in p.get("hand", []):
			if str(c.get("card_id", "")) == card_id:
				return c
	for c in snapshot.get("discard_stack", []):
		if str(c.get("card_id", "")) == card_id:
			return c
	for c in snapshot.get("plateau_cards", []):
		if str(c.get("card_id", "")) == card_id:
			return c
	var dt = snapshot.get("discard_top", null)
	if dt != null and str(dt.get("card_id", "")) == card_id:
		return dt
	return null
