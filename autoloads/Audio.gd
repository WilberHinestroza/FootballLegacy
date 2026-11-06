extends Node

## Audio — autoload.
##  · UI: los .ogg de Kenney "Interface Sounds" (assets/audio/ui/Audio/).
##  · PARTIDO: sonidos reales de Wilber en assets/sound/*.mp3 (silbato,
##    gol, tarjetas, lesión...) con FALLBACK a los .wav procedurales de
##    assets/audio/match/ para los eventos que no tienen mp3.
##  · MÚSICA: game_music_1..5.mp3 — se encadenan al azar con crossfade,
##    bucle sin fin (music_start / music_stop).
##  · Ambiente de estadio: crowd_ambience.mp3 en loop. Cuando suena un
##    evento del partido, el ambiente hace DUCKING (baja y vuelve a subir
##    con un pequeño "swell") para que el efecto resalte y CONVERJA con el
##    fondo — pedido de Wilber.
##
## on/off + volúmenes en user://audio.json (nunca en el save de la carrera).

const _DIR := "res://assets/audio/ui/Audio/"
const _MATCH_DIR := "res://assets/audio/match/"
const _SOUND_DIR := "res://assets/sound/"

const _MAP := {
	"click": "click1.ogg",
	"back": "mouserelease1.ogg",
	"toggle": "switch2.ogg",
	"confirm": "switch10.ogg",
	"error": "switch21.ogg",
	"celebrate": "click3.ogg",
}

## Evento de partido → [archivo mp3 (sin ext), volumen dB, ducking dB,
## duración del ducking s]. El ambiente baja `duck_db` y vuelve en `secs`.
const _SFX_MAP := {
	"kickoff":       ["whistle_kickoff",  -5.0, 4.0, 1.4],
	"fulltime":      ["whistle_fulltime", -4.0, 5.0, 2.2],
	"halftime":      ["whistle_kickoff",  -6.0, 3.0, 1.0],
	"goal":          ["goal",             -2.0, 10.0, 2.4],
	"goal_against":  ["goal_rival",       -4.0, 6.0, 2.0],
	"card_yellow":   ["card_yellow",      -6.0, 5.0, 1.3],
	"card_red":      ["card_red",         -5.0, 7.0, 1.7],
	"injury":        ["injury",           -7.0, 6.0, 1.6],
	"decision_ok":   ["decision_success", -7.0, 4.0, 0.9],
	"decision_fail": ["decision_fail",    -7.0, 4.0, 0.9],
}

## Eventos sin mp3 propio → .wav procedural de siempre + volumen.
const _MATCH_MAP := {
	"foul": ["whistle_foul", -9.0],
	"penalty": ["whistle_foul", -6.0],
	"sub": ["sub_horn", -10.0],
	"tick": ["tick", -16.0],
	"trophy": ["fanfare", -4.0],
}

const _MUSIC_TRACKS := ["game_music_1", "game_music_2", "game_music_3", "game_music_4", "game_music_5"]
const _MUSIC_DB := -13.0
const _MUSIC_FADE := 2.0
const _CROWD_DB := -15.0

const _PREF_PATH := "user://audio.json"
const _POOL_SIZE := 6

## Canales independientes (pedido de Wilber: apagar/bajar cada uno en
## Ajustes). `enabled` es el maestro; cada canal tiene su on/off + volumen.
var enabled: bool = true
var music_enabled: bool = true
var music_volume: float = 1.0
var ambience_enabled: bool = true    # hinchada + efectos del partido
var ambience_volume: float = 1.0
var ui_enabled: bool = true          # clics / botones
var ui_volume: float = 1.0
# alias legado (algún código viejo puede referirlo)
var sfx_volume: float = 1.0

var _streams: Dictionary = {}
var _match_streams: Dictionary = {}   # wav fallback
var _sfx_streams: Dictionary = {}     # mp3 reales
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0

var _crowd: AudioStreamPlayer = null
var _crowd_base_db: float = _CROWD_DB
var _duck_tween: Tween = null

var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_cur: AudioStreamPlayer = null   # el que está sonando
var _music_last: int = -1
var _music_tween: Tween = null
var _music_on: bool = false                 # la música DEBE estar sonando

func _ready() -> void:
	_load_pref()
	for key in _MAP:
		var path: String = _DIR + String(_MAP[key])
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for key in _MATCH_MAP:
		var mp: String = _MATCH_DIR + String(_MATCH_MAP[key][0]) + ".wav"
		if ResourceLoader.exists(mp):
			_match_streams[key] = load(mp)
	for key in _SFX_MAP:
		var sp: String = _SOUND_DIR + String(_SFX_MAP[key][0]) + ".mp3"
		if ResourceLoader.exists(sp):
			_sfx_streams[key] = load(sp)
	for _i in range(_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd.bus = "Master"
	add_child(_crowd)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Master"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Master"
	add_child(_music_b)
	_music_a.finished.connect(_on_music_finished.bind(_music_a))
	_music_b.finished.connect(_on_music_finished.bind(_music_b))

	# GARANTÍA GLOBAL: todo botón que se cree en cualquier pantalla suena al
	# tocarlo (pedido de Wilber). Antes dependía de pasar por
	# Styles.styled_button; ahora se engancha a cualquier BaseButton apenas
	# entra al árbol. Idempotente (no reconecta) y respeta el grupo "silent".
	get_tree().node_added.connect(_wire_button_sound)
	call_deferred("_wire_existing_buttons")

func _wire_button_sound(n: Node) -> void:
	if n is BaseButton and not n.is_in_group("silent"):
		var b := n as BaseButton
		if not b.pressed.is_connected(click):
			b.pressed.connect(click)

func _wire_existing_buttons(root: Node = null) -> void:
	if root == null:
		root = get_tree().root
	_wire_button_sound(root)
	for c in root.get_children():
		_wire_existing_buttons(c)

# ---------------------------------------------------------------------------
# Efectos de partido + ducking del ambiente
# ---------------------------------------------------------------------------

func match_sfx(event: String) -> void:
	if not enabled or not ambience_enabled:
		return
	var vol_mul: float = linear_to_db(clampf(ambience_volume, 0.001, 1.0))
	if _sfx_streams.has(event):
		var cfg: Array = _SFX_MAP[event]
		var p := _pool[_next]
		_next = (_next + 1) % _pool.size()
		p.stream = _sfx_streams[event]
		p.volume_db = float(cfg[1]) + vol_mul
		p.play()
		_duck_crowd(float(cfg[2]), float(cfg[3]), event == "goal" or event == "goal_against")
		return
	# Fallback .wav procedural.
	if _match_streams.has(event):
		var p2 := _pool[_next]
		_next = (_next + 1) % _pool.size()
		p2.stream = _match_streams[event]
		p2.volume_db = float(_MATCH_MAP[event][1]) + vol_mul
		p2.play()
		_duck_crowd(3.0, 0.8, false)

## Baja el ambiente `db` y lo devuelve a su nivel en `secs`. Para goles,
## al volver hace un pequeño "swell" (+3 dB unos segundos): la hinchada
## sigue prendida un rato — convergencia procedural con el fondo.
func _duck_crowd(db: float, secs: float, swell: bool) -> void:
	if _crowd == null or not _crowd.playing:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var base: float = _crowd_base_db
	_duck_tween = create_tween()
	_duck_tween.tween_property(_crowd, "volume_db", base - db, 0.08)
	if swell:
		_duck_tween.tween_property(_crowd, "volume_db", base + 3.0, secs)
		_duck_tween.tween_property(_crowd, "volume_db", base, 3.5)
	else:
		_duck_tween.tween_property(_crowd, "volume_db", base, secs)

# ---------------------------------------------------------------------------
# Ambiente de estadio (loop)
# ---------------------------------------------------------------------------

func crowd_start() -> void:
	if not enabled or not ambience_enabled or _crowd == null or not Preferences.crowd_sound:
		return
	var s: String = _SOUND_DIR + "crowd_ambience.mp3"
	var stream: AudioStream = null
	if ResourceLoader.exists(s):
		stream = load(s)
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
	elif ResourceLoader.exists(_MATCH_DIR + "crowd_loop.wav"):
		stream = load(_MATCH_DIR + "crowd_loop.wav")
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / 2
	if stream == null:
		return
	_crowd_base_db = _CROWD_DB + linear_to_db(clampf(ambience_volume, 0.001, 1.0))
	_crowd.stream = stream
	_crowd.volume_db = _crowd_base_db
	_crowd.play()

func crowd_stop() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if _crowd != null:
		_crowd.stop()

# ---------------------------------------------------------------------------
# Música ambiental (game_music_1..5) — random encadenado, loop infinito
# ---------------------------------------------------------------------------

## Arranca la música si no está sonando. Idempotente: la llaman todas las
## pantallas de navegación (TopBar) sin miedo a reiniciarla.
func music_start() -> void:
	_music_on = true
	if not enabled or not music_enabled:
		return
	if _music_cur != null and _music_cur.playing:
		return
	_play_random_music(true)

func music_stop(fade: float = 0.8) -> void:
	_music_on = false
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for mp in [_music_a, _music_b]:
		if mp != null and mp.playing:
			var t := create_tween()
			t.tween_property(mp, "volume_db", -40.0, fade)
			t.tween_callback(mp.stop)
	_music_cur = null

func _target_music_db() -> float:
	return _MUSIC_DB + linear_to_db(clampf(music_volume, 0.001, 1.0))

func _pick_track() -> int:
	var idx: int = randi() % _MUSIC_TRACKS.size()
	if _MUSIC_TRACKS.size() > 1 and idx == _music_last:
		idx = (idx + 1 + randi() % (_MUSIC_TRACKS.size() - 1)) % _MUSIC_TRACKS.size()
	return idx

func _load_music(idx: int) -> AudioStream:
	var p: String = _SOUND_DIR + _MUSIC_TRACKS[idx] + ".mp3"
	if not ResourceLoader.exists(p):
		return null
	var s: AudioStream = load(p)
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false   # el encadenado lo hacemos acá
	return s

func _play_random_music(fade_in: bool) -> void:
	var idx: int = _pick_track()
	var stream: AudioStream = _load_music(idx)
	if stream == null:
		return
	_music_last = idx
	_music_cur = _music_a if (_music_cur != _music_a) else _music_b
	_music_cur.stream = stream
	_music_cur.volume_db = -40.0 if fade_in else _target_music_db()
	_music_cur.play()
	if fade_in:
		if _music_tween != null and _music_tween.is_valid():
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_cur, "volume_db", _target_music_db(), _MUSIC_FADE)

func _on_music_finished(who: AudioStreamPlayer) -> void:
	# Solo reacciona si ESE reproductor era el activo y la música sigue on.
	if who != _music_cur or not _music_on or not enabled or not music_enabled:
		return
	_crossfade_next()

func _crossfade_next() -> void:
	var idx: int = _pick_track()
	var stream: AudioStream = _load_music(idx)
	if stream == null:
		return
	_music_last = idx
	var old: AudioStreamPlayer = _music_cur
	var nxt: AudioStreamPlayer = _music_b if old == _music_a else _music_a
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	_music_cur = nxt
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(nxt, "volume_db", _target_music_db(), _MUSIC_FADE)
	if old != null and old.playing:
		_music_tween.tween_property(old, "volume_db", -40.0, _MUSIC_FADE)
		_music_tween.chain().tween_callback(old.stop)

func set_music_enabled(v: bool) -> void:
	music_enabled = v
	if v:
		if _music_on:
			music_start()
	else:
		music_stop()
	_save_pref()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	if _music_cur != null and _music_cur.playing and (_music_tween == null or not _music_tween.is_valid()):
		_music_cur.volume_db = _target_music_db()
	_save_pref()

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func set_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	sfx_volume = ambience_volume
	if _crowd != null and _crowd.playing:
		_crowd_base_db = _CROWD_DB + linear_to_db(clampf(ambience_volume, 0.001, 1.0))
		if _duck_tween == null or not _duck_tween.is_valid():
			_crowd.volume_db = _crowd_base_db
	_save_pref()

## alias legado
func set_sfx_volume(v: float) -> void:
	set_ambience_volume(v)

func set_ambience_enabled(v: bool) -> void:
	ambience_enabled = v
	if not v:
		crowd_stop()
	_save_pref()

func set_ui_enabled(v: bool) -> void:
	ui_enabled = v
	_save_pref()

func set_ui_volume(v: float) -> void:
	ui_volume = clampf(v, 0.0, 1.0)
	_save_pref()

func play(key: String, volume_db: float = -7.0) -> void:
	if not enabled or not ui_enabled or not _streams.has(key):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[key]
	p.volume_db = volume_db + linear_to_db(clampf(ui_volume, 0.001, 1.0))
	p.play()

func click() -> void:
	play("click")
	Haptics.hit("tap")   # feedback háptico en cada botón (mismo hook)

func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		music_stop(0.3)
		crowd_stop()
	elif _music_on:
		music_start()
	_save_pref()

func _load_pref() -> void:
	if not FileAccess.file_exists(_PREF_PATH):
		return
	var f := FileAccess.open(_PREF_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		if parsed.has("enabled"):
			enabled = bool(parsed["enabled"])
		if parsed.has("music_enabled"):
			music_enabled = bool(parsed["music_enabled"])
		if parsed.has("music_volume"):
			music_volume = clampf(float(parsed["music_volume"]), 0.0, 1.0)
		if parsed.has("ambience_enabled"):
			ambience_enabled = bool(parsed["ambience_enabled"])
		# `sfx_volume` es la clave vieja de "volumen de efectos"
		if parsed.has("ambience_volume"):
			ambience_volume = clampf(float(parsed["ambience_volume"]), 0.0, 1.0)
		elif parsed.has("sfx_volume"):
			ambience_volume = clampf(float(parsed["sfx_volume"]), 0.0, 1.0)
		if parsed.has("ui_enabled"):
			ui_enabled = bool(parsed["ui_enabled"])
		if parsed.has("ui_volume"):
			ui_volume = clampf(float(parsed["ui_volume"]), 0.0, 1.0)
		sfx_volume = ambience_volume

func _save_pref() -> void:
	var f := FileAccess.open(_PREF_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"enabled": enabled,
		"music_enabled": music_enabled, "music_volume": music_volume,
		"ambience_enabled": ambience_enabled, "ambience_volume": ambience_volume,
		"ui_enabled": ui_enabled, "ui_volume": ui_volume,
	}))
	f.close()
