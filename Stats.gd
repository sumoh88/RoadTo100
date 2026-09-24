extends Control

# ---------------------------------------------------------------------------
# Stats scene — STATISTICHE + TRAGUARDI
#
# UI-only phase: the achievement unlock states are PLACEHOLDER / static data
# used solely to verify the layout. No game logic is wired yet (no GameController
# / rules / save integration, no real unlock conditions, no notifications).
#
# The 7 STATISTICHE rows and both section titles live as STATIC nodes in
# Stats.tscn (fonts/colors applied there, editor-style). Only the TRAGUARDI
# items are built here, because their description visibility is logic-driven
# (secret achievements reveal it only when unlocked) and they must exist as a
# data structure in code.
# ---------------------------------------------------------------------------

const FONT_PATH := "res://fonts/Dyuthi.ttf"
# Placeholder mark for an unlocked achievement (temporary — replaced later with a
# definitive graphic icon). Present only when the achievement is unlocked.
const UNLOCK_MARK := "◌"

# Colours used to distinguish achievement states.
var color_unlocked_name := Color(1.0, 0.82, 0.3)    # gold — sbloccato
var modulate_locked := Color(0.6, 0.6, 0.6)         # grigio — bloccato

# Fonts for the dynamically built achievement items (shared Dyuthi.ttf).
var f_name = null
var f_desc = null


func _ready():
	_setup_fonts()
	_update_stats_display()
	_build_achievements_ui()


# Populate the 7 static statistic values from the persisted stats.
# Percentages and units are computed here (never stored as static text).func _update_stats_display():


func _update_stats_display():
	var s = GlobalsUtilities.get_stats()
	var gp = int(s["games_played"])
	var gw = int(s["games_won"])
	var pct = 0
	if gp > 0:
		pct = int(round(100.0 * gw / gp))
	var fwt = int(s["fastest_win_turns"])
	var fastest_text = str(fwt) + " turni" if fwt >= 0 else "N/D"

	_set_stat_value("games_played", str(gp))
	_set_stat_value("games_won", str(gw) + " (" + str(pct) + "%)")
	_set_stat_value("current_streak", str(int(s["current_streak"])))
	_set_stat_value("best_streak", str(int(s["best_streak"])))
	_set_stat_value("fastest_win_turns", fastest_text)
	_set_stat_value("advantage_rounds", str(int(s["advantage_rounds"])))
	_set_stat_value("safe_rounds", str(int(s["safe_rounds"])))


func _set_stat_value(row_name, text):
	var lbl = get_node_or_null("StatsContainer/StatsList/" + row_name + "/Value")
	if lbl != null:
		lbl.text = text


func _on_BackMenuButton_pressed():
	get_tree().change_scene("res://MainMenu.tscn")


# ---------------------------------------------------------------------------
# ACHIEVEMENTS (23 total). Each carries a stable `id` used to look up its real
# unlock state from GlobalsUtilities. `secret=true` hides the description until
# unlocked; `is_unlocked` is resolved at render time (see _make_achievement_item).
# ---------------------------------------------------------------------------
var achievements := [
	# --- 1-11: NON-SECRET (name + description always visible) ---
	#{"id": "prima_vittoria", "name": "Prima vittoria", "description": "Vinci una partita.", "secret": false},
	#{"id": "cinque_vittorie", "name": "Ci sto prendendo la mano", "description": "Vinci 5 partite.", "secret": false},
	{"id": "dieci_vittorie", "name": "Giocatore abituale", "description": "Vinci 10 partite.", "secret": false},
	{"id": "vittorie_25", "name": "Veterano", "description": "Vinci 25 partite.", "secret": false},
	{"id": "vittorie_50", "name": "Esperto", "description": "Vinci 50 partite.", "secret": false},
	{"id": "vittorie_100", "name": "Centenario", "description": "Vinci 100 partite.", "secret": false},
	{"id": "jolly_primo", "name": "Jolly!", "description": "Gioca il tuo primo Jolly.", "secret": false},
	{"id": "imbroglio_primo", "name": "Che Canaglia!", "description": "Gioca il tuo primo Imbroglio.", "secret": false},
	{"id": "gold_prima", "name": "Spendaccione", "description": "Gioca la tua prima Gold.", "secret": false},
	{"id": "ottantanove_primo", "name": "Quasi alla fine", "description": "Gioca la tua prima 89.", "secret": false},
	{"id": "giro_sicuro", "name": "Giro Sicuro", "description": "Attiva e concludi il tuo\nprimo Giro Sicuro.", "secret": false},
	{"id": "giro_di_vantaggio", "name": "Giro di Vantaggio", "description": "Attiva e concludi il tuo\nprimo Giro di Vantaggio.", "secret": false},
	{"id": "piu_undici_primo", "name": "Undici!", "description": "Gioca la tua prima +11.", "secret": false},
	# --- 12-23: SECRET (description visible only when unlocked) ---
	{"id": "carta_della_vittoria", "name": "Carta della Vittoria", "description": "Vinci con una +11.", "secret": true},
	{"id": "trasformista", "name": "Trasformista", "description": "Trasforma una +11 in Gold.", "secret": true},
	{"id": "per_un_soffio", "name": "Per un soffio", "description": "Perdi una partita mentre sei\nil Giocatore in Vantaggio.", "secret": true},
	{"id": "stratega", "name": "Stratega", "description": "Usa il rimbalzo per togliere la\nvittoria al giocatore successivo.", "secret": true},
	{"id": "imbroglione", "name": "Imbroglione!", "description": "Inizia un turno con tre carte\nImbroglio in mano.", "secret": true},
	{"id": "oro_puro", "name": "Oro puro", "description": "Inizia un turno con tre carte\nGold in mano.", "secret": true},
	{"id": "cascata_d_oro", "name": "Cascata d'oro", "description": "Inizia un turno con tre carte\n89 in mano.", "secret": true},
	{"id": "imbattibile", "name": "Imbattibile", "description": "Inizia un turno con tre carte\n+11 in mano.", "secret": true},
	{"id": "contromossa", "name": "Contromossa", "description": "Vinci dopo aver utilizzato un\nImbroglio nel turno precedente.", "secret": true},
	{"id": "jolly_strategico", "name": "Jolly strategico", "description": "Vinci una partita dopo aver\nutilizzato un Jolly.", "secret": true},
	{"id": "oro_vincente", "name": "Oro vincente", "description": "Vinci una partita mentre sei\nl'attivatore di un Giro Sicuro.", "secret": true},
	{"id": "all_ultimo_turno", "name": "All'ultimo turno", "description": "Vinci proprio nel turno finale\ndi un Giro di Vantaggio.", "secret": true},
]


# ---------------------------------------------------------------------------
# Fonts — reuse the shared Dyuthi.ttf used across the project.
# ---------------------------------------------------------------------------
func _setup_fonts():
	var font_data = load(FONT_PATH)
	f_name = _make_font(font_data, 28, 25)
	f_desc = _make_font(font_data, 22, -1)


func _make_font(font_data, size, extra_top):
	var f = DynamicFont.new()
	f.font_data = font_data
	f.size = size
	f.outline_size = 2
	f.outline_color = Color(0, 0, 0, 1)
	f.extra_spacing_top = extra_top
	f.extra_spacing_char = -1
	f.use_filter = true
	f.use_mipmaps = true
	return f


# ---------------------------------------------------------------------------
# TRAGUARDI — one item per achievement (23 total).
# ---------------------------------------------------------------------------
func _build_achievements_ui():
	var list = get_node_or_null("StatsContainer/UnlockList/AchievementsScroll/ListContainer/AchievementsList")
	if list == null:
		return

	for a in achievements:
		list.add_child(_make_achievement_item(a))

	# Spazio finale per evitare che l'ultimo traguardo venga tagliato
	var bottom_space = Control.new()
	bottom_space.rect_min_size = Vector2(0, 25)
	list.add_child(bottom_space)

func _make_achievement_item(a):
	var is_secret = bool(a["secret"])
	# Unlock state comes from the persisted flags (not hardcoded placeholders).
	var is_unlocked = GlobalsUtilities.is_achievement_unlocked(str(a.get("id", "")))

	var item = VBoxContainer.new()
	item.add_constant_override("separation", 1)

	if not is_unlocked:
		item.modulate = modulate_locked

	# -----------------------------------------------------------------------
	# RIGA 1 — nome
	# -----------------------------------------------------------------------
	var top = HBoxContainer.new()
	top.add_constant_override("separation", 8)

	var name = Label.new()
	name.text = a["name"]
	name.add_font_override("font", f_name)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.valign = Label.ALIGN_CENTER

	if is_unlocked:
		name.add_color_override("font_color", color_unlocked_name)
	else:
		name.add_color_override("font_color", Color(0.95, 0.95, 0.95))

	top.add_child(name)
	item.add_child(top)

	# -----------------------------------------------------------------------
	# RIGA 2 — descrizione / Bloccato
	# -----------------------------------------------------------------------
	var descRow = Control.new()

	var icon = Label.new()
	icon.text = UNLOCK_MARK if is_unlocked else ""
	icon.add_font_override("font", f_name)

	if is_unlocked:
		icon.add_color_override("font_color", color_unlocked_name)

	icon.rect_min_size = Vector2(26, 26)
	icon.rect_position.y = -29

	descRow.add_child(icon)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 20)

	var desc = Label.new()
	desc.add_font_override("font", f_desc)
	desc.add_color_override("font_color", Color(0.82, 0.82, 0.82))
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_EXPAND

	if is_secret and not is_unlocked:
		desc.text = "Bloccato"
	else:
		desc.text = a["description"]

	margin.add_child(desc)
	descRow.add_child(margin)

	item.add_child(descRow)
	if desc.text.length() > 35:
		var extra_space = Control.new()
		extra_space.rect_min_size = Vector2(0, 20)
		item.add_child(extra_space)
	return item
