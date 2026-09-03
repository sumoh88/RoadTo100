extends Node

# =========================
#  AUDIO MANAGER — Musica Dinamica
# =========================
# Gestisce 5 stem musicali indipendenti (Beat, Piano, Cello, Violin, Trumpet)
# e la sezione SoundEffects esistente.
#
# API pubblica:
#   set_menu_music()                  # Menu: tutti e 5 al 100%
#   set_game_music(piatto: int, sr_active: bool)  # Partita: dinamica per Piatto
#   set_plate_value(value: int)       # Aggiorna solo il valore del Piatto
#   set_special_round_active(active: bool)  # True = GS o GdV attivo
#   stop_music()                      # Ferma tutti gli stem
#   play_sfx(name: String)            # Nome SFX (Select, Draw, PlayCard, …)
#   play_sfx2d(audio: AudioStreamPlayer2D, cooldown: float)
#   set_master_volume(v: float)
#   set_sfx_volume(v: float)
#
# Architettura:
#   Ogni stem è un AudioStreamPlayer figlio di MusicPlayer.
#   I 5 stem partono insieme in _ready(), in loop, sincronizzati.
#   Durante menu/partita/non si usa mai stop()/play() per attivare/disattivare
#   uno strumento: l'ingresso/uscita avviene SOLO modificandone il volume
#   con fade-in/fade-out (0.5 s).
#
# Cartelle canzoni: res://sound/<nome_canzone>/
# Ogni cartella deve contenere: beat.mp3, piano.mp3, cello.mp3, violin.mp3, trumpet.mp3
# Aggiungere una nuova sottocartella a res://sound/ basta per renderla disponibile.

# =========================
#  COSTANTI
# =========================
const SOUND_DIR: String = "res://sound/"

# Soglie Piatto per l'attivazione degli stem durante il gameplay
const THRESHOLD_PIANO: int = GlobalsUtilities.THRESHOLD_PIANO
const THRESHOLD_CELLO: int = GlobalsUtilities.THRESHOLD_CELLO
const THRESHOLD_VIOLIN: int = GlobalsUtilities.THRESHOLD_VIOLIN




# Durata fade per ogni transizione di volume (secondi)
const FADE_DURATION: float = 0.7





#
#onready var main = get_tree().current_scene.get_node("Main")
#onready var valueLabel = main.get_node("GameArea/BoardArea/PlateauZone/ValueLabel")




# =========================
#  NODI — stem musicali
# =========================
onready var music_player: AudioStreamPlayer = $MusicPlayer
onready var sfx_player: AudioStreamPlayer = $SFXPlayer

onready var stem_beat: AudioStreamPlayer = $MusicPlayer/Beat
onready var stem_piano: AudioStreamPlayer = $MusicPlayer/Piano
onready var stem_cello: AudioStreamPlayer = $MusicPlayer/Cello
onready var stem_violin: AudioStreamPlayer = $MusicPlayer/Violin
onready var stem_trumpet: AudioStreamPlayer = $MusicPlayer/Trumpet


# =========================
#  STATO
# =========================
# true = in gameplay (dinamica per Piatto), false = menu (tutti al 100%)
var _is_game_active: bool = false

# Valore del Piatto e stato giro speciale (usati solo se _is_game_active)
var _plate_value: int = 0
var _special_round_active: bool = false

# Mappa {nome_stem: AudioStream} caricata dinamicamente all'avvio
var _current_song_paths: Dictionary = {}

# Tween attivi per ogni stem — ciascuno ha il proprio fade indipendente
var _fade_tweens: Dictionary = {}

var currValue = 0
# =========================
#  VOLUMI (0.0 – 1.0)
# =========================
export(float) var master_volume: float = 1.0
export(float) var music_volume: float = 0.01
export(float) var sfx_volume: float = 0.4
export(float) var sfx2d_volume: float = 0.5
export(float) var stemsVolume: float = 0.7


# =========================
#  SFX COOLDOWN (preservato)
# =========================
var sfx_cooldowns: Dictionary = {}
var default_sfx_cooldown: float = 0.15
var sfx2d_cooldowns: Dictionary = {}
export var default_sfx2d_cooldown: float = 0.3








var _linear_volumes := {
	"beat": stemsVolume,
	"piano": stemsVolume,
	"cello": stemsVolume,
	"violin": stemsVolume,
	"trumpet": stemsVolume
}





# =========================
#  READY — rileva, sceglie, carica, avvia TUTTI gli stem
# =========================
func _ready():
	_load_random_song()
	_start_all_stems()
	# Stato iniziale = menu: tutti e 5 al 100%
	set_menu_music()

func _process(delta):
	set_special_round_active(GlobalsUtilities.sr_active)

# =========================
#  CARICAMENTO CANZONI — rileva sottocartelle, sceglie casuale
# =========================
func _load_random_song():
	var dir = Directory.new()
	var err = dir.open(SOUND_DIR)
	if err != OK:
		printerr("[AudioManager] Impossibile aprire ", SOUND_DIR, " (error ", err, ")")
		return

	var song_folders: Array = []

	dir.list_dir_begin(true, true)
	var item_name: String = dir.get_next()

	while item_name != "":
		if dir.current_is_dir():
			var folder_path: String = SOUND_DIR + item_name

			if dir.file_exists(folder_path + "/beat.mp3"):
				song_folders.append(item_name)

		item_name = dir.get_next()

	dir.list_dir_end()

	if song_folders.size() == 0:
		printerr("[AudioManager] Nessuna canzone trovata in ", SOUND_DIR)
		return

	var chosen: String = song_folders[randi() % song_folders.size()]
	print("[AudioManager] Canzone selezionata: ", chosen)

	_current_song_paths = {
		"beat": load(SOUND_DIR + chosen + "/beat.mp3"),
		"piano": load(SOUND_DIR + chosen + "/piano.mp3"),
		"cello": load(SOUND_DIR + chosen + "/cello.mp3"),
		"violin": load(SOUND_DIR + chosen + "/violin.mp3"),
		"trumpet": load(SOUND_DIR + chosen + "/trumpet.mp3"),
	}


# =========================
#  AVVIO STEM — tutti insieme, in loop, sincronizzati
#   (non si fermano mai durante menu/partita)
# =========================
func _start_all_stems():
	for stem_name in ["beat", "piano", "cello", "violin", "trumpet"]:
		var stream = _current_song_paths.get(stem_name)
		if stream == null:
			continue
		var player: AudioStreamPlayer = _get_stem_player(stem_name)
		if player == null:
			continue
			
		if stream is AudioStreamOGGVorbis:
			stream.loop = true
		player.stream = stream
		player.play()


# =========================
#  STATO MENU — tutti e 5 al 100%
# =========================
func set_menu_music():
	_is_game_active = false
	var targets: Dictionary = {
		"beat": stemsVolume,
		"piano": stemsVolume,
		"cello": stemsVolume,
		"violin": stemsVolume,
		"trumpet": stemsVolume,
	}
	for stem_name in targets.keys():
		_fade_to(stem_name, targets[stem_name])


# =========================
#  STATO GAME — dinamica per Piatto
#   Beat SEMPRE 100%
#   Piatto >= 30 → Piano 100%
#   Piatto >= 60 → Cello 100%
#   Piatto >= 89 → Violin 100%
#   GS/GdV attivo → Trumpet 100%
# =========================
func set_game_music(piatto: int, sr_active: bool):
	_is_game_active = true

	_plate_value = piatto
	_special_round_active = sr_active

	var targets: Dictionary = {}

	targets["beat"] = stemsVolume
	targets["piano"] = stemsVolume if _plate_value >= THRESHOLD_PIANO else 0.0
	targets["cello"] = stemsVolume if _plate_value >= THRESHOLD_CELLO else 0.0
	targets["violin"] = stemsVolume if _plate_value >= THRESHOLD_VIOLIN else 0.0
	targets["trumpet"] = stemsVolume if _special_round_active else 0.0

	for stem_name in targets.keys():
		_fade_to(stem_name, targets[stem_name])

# =========================
#  AGGIorna SOLO il valore del Piatto (senza cambiare stato)
# =========================
func set_plate_value(value: int):
	_plate_value = value

	if _is_game_active:
		var piano_on: bool = _plate_value >= THRESHOLD_PIANO
		var cello_on: bool = _plate_value >= THRESHOLD_CELLO
		var violin_on: bool = _plate_value >= THRESHOLD_VIOLIN

		_fade_to("piano", stemsVolume if piano_on else 0.0)
		_fade_to("cello", stemsVolume if cello_on else 0.0)
		_fade_to("violin", stemsVolume if violin_on else 0.0)


# =========================
#  Aggiorna SOLO lo stato del giro speciale (senza cambiare stato)
# =========================
func set_special_round_active(active: bool):
	_special_round_active = active
	if _is_game_active:
		var trumpet_on: bool = active
		_fade_to("trumpet", stemsVolume if trumpet_on else 0.0)


# =========================
#  FADE a target — ciascuno stem ha il proprio tween indipendente
# =========================
func _fade_to(stem_name: String, target_volume: float):
	var player: AudioStreamPlayer = _get_stem_player(stem_name)
	if player == null or not player.is_inside_tree():
		return

	# Elimina il vecchio tween di QUESTO stem
	if _fade_tweens.has(stem_name):
		var old_tw = _fade_tweens[stem_name]
		if is_instance_valid(old_tw):
			old_tw.remove_all()
			old_tw.queue_free()

	var current_db: float = player.volume_db
	
	# Evita linear2db(0)
	var target_db: float
	if target_volume <= 0.0:
		target_db = -30.0
	else:
		target_db = linear2db(clamp(target_volume, 0.0, 1.0))

	var tw: Tween = Tween.new()
	add_child(tw)

	tw.interpolate_property(
		player,
		"volume_db",
		current_db,
		target_db,
		FADE_DURATION,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)

	tw.start()
	_fade_tweens[stem_name] = tw




func _set_stem_linear_volume(linear_volume: float, stem_name: String):
	var player: AudioStreamPlayer = _get_stem_player(stem_name)
	if player == null:
		return

	if linear_volume <= 0.0001:
		player.volume_db = -80.0
	else:
		player.volume_db = linear2db(linear_volume)



# =========================
#  OTTIENI NODO STEM PER NOME
# =========================
func _get_stem_player(stem_name: String) -> AudioStreamPlayer:
	var path: String = "MusicPlayer/" + stem_name.capitalize()
	var player = get_node_or_null(path) as AudioStreamPlayer
	if player == null:
		printerr("[AudioManager] Stem non trovato: ", path)
	return player


# =========================
#  ARRESTA MUSICA (stop tutti gli stem)
# =========================
func stop_music():
	# Ferma il player principale
	if music_player != null and music_player.is_inside_tree():
		music_player.stop()

	# Ferma tutti e 5 gli stem
	for stem_name in ["beat", "piano", "cello", "violin", "trumpet"]:
		var player: AudioStreamPlayer = _get_stem_player(stem_name)
		if player != null and player.is_inside_tree():
			player.stop()


# =========================
#  AGGIorna VOLUMI (Master, Music, SFX)
# =========================
func _update_volumes():
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(
			master_bus,
			linear2db(clamp(master_volume, 0.0, 1.0))
		)

	if music_player != null and music_player.is_inside_tree():
		music_player.volume_db = linear2db(clamp(music_volume, 0.0, 1.0))

	if sfx_player != null and sfx_player.is_inside_tree():
		sfx_player.volume_db = linear2db(clamp(sfx_volume, 0.0, 1.0))


# =========================
#  SFX (CON COoldOWn — preservato)
# =========================
func play_sfx(stream: AudioStreamPlayer, cooldown: float = default_sfx_cooldown):
	var key: String = str(stream.stream)
	var now: float = OS.get_ticks_msec() * 0.001

	if sfx_cooldowns.has(key):
		if now - sfx_cooldowns[key] < cooldown:
			return

	sfx_cooldowns[key] = now
	sfx_player.pitch_scale = stream.pitch_scale
	sfx_player.stream = stream.stream
	sfx_player.play()


func play_sfx2d(audio: AudioStreamPlayer2D, cooldown: float = default_sfx2d_cooldown):
	if audio == null or audio.stream == null:
		return

	if audio.playing:
		return
	var key: String = str(audio.get_instance_id())
	var now: float = OS.get_ticks_msec() * 0.001

	if sfx2d_cooldowns.has(key):
		if now - sfx2d_cooldowns[key] < cooldown:
			return

	sfx2d_cooldowns[key] = now
	audio.play()


# =========================
#  SFX per nome (usa i nodi SFXPlayer/Select, ecc.)
# =========================
func play_sfx_by_name(name: String, cooldown: float = default_sfx_cooldown):
	var key: String = name
	var now: float = OS.get_ticks_msec() * 0.001

	if sfx_cooldowns.has(key):
		if now - sfx_cooldowns[key] < cooldown:
			return

	sfx_cooldowns[key] = now

	var sfx_node = get_node_or_null("SFXPlayer/" + name) as AudioStreamPlayer2D
	if sfx_node != null and sfx_node.is_inside_tree():
		sfx_node.play()


# =========================
#  IMPOSTA VOLUMI (API)
# =========================
func set_master_volume(v: float):
	master_volume = clamp(v, 0.0, 1.0)
	_update_volumes()

func set_music_volume(v: float):
	music_volume = clamp(v, 0.0, 1.0)
	_update_volumes()

func set_sfx_volume(v: float):
	sfx_volume = clamp(v, 0.0, 1.0)
	_update_volumes()
