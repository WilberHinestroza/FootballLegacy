extends Node

## Preferencias GLOBALES de la app — sobreviven a todos los slots de
## carrera, a diferencia de SaveManager (datos de una carrera concreta).
## Por ahora solo la moneda de visualización ("EUR"/"USD", pedido
## explícito: "en ajustes el jugador elije cual de los dos") — se guarda
## en su propio archivo (`user://preferences.json`), nunca dentro del
## save de una carrera: no es un cambio de esquema de PlayerData/ClubData,
## así que no dispara ninguna migración de SaveManager.

const _PATH := "user://preferences.json"
const VALID_CURRENCIES := ["EUR", "USD"]

var currency: String = "EUR"
## Último balón elegido en la previa (índice en BallDesign.DESIGNS). -1 =
## sin elección → cada partido usa su balón determinista. Solo importa si
## `ball_mode == "fixed"` — en "random" se ignora a propósito (ver
## PreMatch.gd: si lo siguiera usando como default, "aleatorio" terminaría
## siendo "el mismo balón de la última vez que tocaste al azar").
var last_ball: int = -1
## "fixed" (elegís uno y se repite hasta que cambies) | "random" (uno
## nuevo cada partido) — pedido explícito de Wilber.
var ball_mode: String = "fixed"
const BALL_MODES := ["fixed", "random"]
## Ritmo del partido: "lento" | "normal" | "rapido" — escala el await de
## MatchEngine._wait_for_pace().
var match_speed: String = "normal"
const MATCH_SPEED_FACTOR := {"lento": 1.6, "normal": 1.0, "rapido": 0.55}

## Pedir confirmación antes de avanzar días (Hub: día / semana / mes /
## siguiente partido). Por defecto NO (flujo rápido).
var confirm_advance: bool = false
## Menos animaciones: público animado, figuras del estadio, confeti,
## celebraciones largas. Para preferencia o rendimiento.
var reduce_motion: bool = false
## Sonido ambiente de la hinchada durante el partido (bucle).
var crowd_sound: bool = true
## Escala del texto/UI: "normal" | "grande". Aplica content_scale_factor
## a la ventana (agranda todo de forma uniforme).
var text_scale: String = "normal"
const TEXT_SCALE_FACTOR := {"normal": 1.0, "grande": 1.12}

func set_text_scale(v: String) -> void:
	if TEXT_SCALE_FACTOR.has(v):
		text_scale = v
		_apply_text_scale()
		_save()

func _apply_text_scale() -> void:
	var w := get_window()
	if w != null:
		w.content_scale_factor = float(TEXT_SCALE_FACTOR.get(text_scale, 1.0))

## Cámara de la cancha del partido (PitchView.CAM_MODES): "arco" (detrás
## del arco, la de siempre) | "tv" (lateral) | "iso" (isométrica).
var pitch_camera: String = "arco"
const PITCH_CAMERAS := ["arco", "tv", "iso"]

## Partido "en vivo" (10-oct): la jugada se JUEGA con gestos en la cancha,
## sin menú de opciones. Apagado = el sistema anterior, por decisiones.
## 11-oct: APAGADO y sin opción en Ajustes. Wilber lo probó en el teléfono
## ("la jugabilidad está imposible... volver al sistema de botones y full
## decisiones"). El código del modo en vivo queda estacionado hasta armarlo
## aparte y con calma; el partido es por DECISIONES.
var live_play: bool = false

## Ya viste el tutorial de controles del partido en vivo (FootballLegacy H).
var live_tutorial_seen: bool = false

func set_live_tutorial_seen(v: bool) -> void:
	live_tutorial_seen = v
	_save()

## Partido 3D (31-oct, MiniSoccer3D integrado): si eres titular en un partido
## de club se juega en 3D; apagado = el partido en vivo / por momentos.
var match_3d: bool = true

## Asistencia de puntería del remate 3D (P1-04): "alta" | "media" | "manual".
## Endereza el gesto hacia la portería para que el juego sea accesible en el
## móvil sin quitar del todo el control fino. No entra en el save de carrera:
## es una preferencia global.
var aim_assist: String = "media"
const AIM_ASSIST_LEVELS := ["alta", "media", "manual"]

## Cámara de las jugadas del partido 3D (8-nov, Wilber: "una camara cercana que
## seria la actual y otra mas lejitos"): "cerca" | "lejos". Preferencia global,
## no entra en el save de carrera.
var match_camera: String = "cerca"
const MATCH_CAMERAS := ["cerca", "lejos"]

func set_match_camera(v: String) -> void:
	if MATCH_CAMERAS.has(v):
		match_camera = v
		_save()

func set_aim_assist(v: String) -> void:
	if AIM_ASSIST_LEVELS.has(v):
		aim_assist = v
		_save()

func set_match_3d(v: bool) -> void:
	match_3d = v
	_save()

func set_live_play(v: bool) -> void:
	live_play = v
	_save()

func set_pitch_camera(v: String) -> void:
	if PITCH_CAMERAS.has(v):
		pitch_camera = v
		_save()

func match_pace_factor() -> float:
	return MATCH_SPEED_FACTOR.get(match_speed, 1.0)

func set_match_speed(v: String) -> void:
	if MATCH_SPEED_FACTOR.has(v):
		match_speed = v
		_save()

func set_confirm_advance(v: bool) -> void:
	confirm_advance = v
	_save()

func set_reduce_motion(v: bool) -> void:
	reduce_motion = v
	_save()

func set_crowd_sound(v: bool) -> void:
	crowd_sound = v
	_save()

func _ready() -> void:
	_load()
	_apply_text_scale()

func set_currency(value: String) -> void:
	if not VALID_CURRENCIES.has(value):
		return
	currency = value
	_save()

func set_last_ball(idx: int) -> void:
	last_ball = idx
	_save()

func set_ball_mode(v: String) -> void:
	if BALL_MODES.has(v):
		ball_mode = v
		_save()

func _load() -> void:
	if not FileAccess.file_exists(_PATH):
		return
	var f := FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and VALID_CURRENCIES.has(parsed.get("currency", "")):
		currency = parsed["currency"]
	if parsed is Dictionary and parsed.has("last_ball"):
		last_ball = int(parsed["last_ball"])
	if parsed is Dictionary and BALL_MODES.has(parsed.get("ball_mode", "")):
		ball_mode = parsed["ball_mode"]
	if parsed is Dictionary and MATCH_SPEED_FACTOR.has(parsed.get("match_speed", "")):
		match_speed = parsed["match_speed"]
	if parsed is Dictionary and parsed.has("confirm_advance"):
		confirm_advance = bool(parsed["confirm_advance"])
	if parsed is Dictionary and parsed.has("reduce_motion"):
		reduce_motion = bool(parsed["reduce_motion"])
	if parsed is Dictionary and parsed.has("crowd_sound"):
		crowd_sound = bool(parsed["crowd_sound"])
	if parsed is Dictionary and TEXT_SCALE_FACTOR.has(parsed.get("text_scale", "")):
		text_scale = parsed["text_scale"]
	if parsed is Dictionary and PITCH_CAMERAS.has(parsed.get("pitch_camera", "")):
		pitch_camera = "arco"   # 11-oct: una sola cámara (se ignora lo guardado)
	if parsed is Dictionary and parsed.has("live_play"):
		live_play = false   # se ignora lo guardado (ver arriba)
	if parsed is Dictionary and parsed.has("match_3d"):
		match_3d = true   # 6-nov: siempre 3D (se ignora un "apagado" guardado)
	if parsed is Dictionary and AIM_ASSIST_LEVELS.has(parsed.get("aim_assist", "")):
		aim_assist = parsed["aim_assist"]
	if parsed is Dictionary and MATCH_CAMERAS.has(parsed.get("match_camera", "")):
		match_camera = parsed["match_camera"]
	if parsed is Dictionary and parsed.has("live_tutorial_seen"):
		live_tutorial_seen = bool(parsed["live_tutorial_seen"])

func _save() -> void:
	var f := FileAccess.open(_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"currency": currency, "last_ball": last_ball, "ball_mode": ball_mode, "match_speed": match_speed,
		"confirm_advance": confirm_advance, "reduce_motion": reduce_motion, "crowd_sound": crowd_sound,
		"text_scale": text_scale, "pitch_camera": pitch_camera, "live_play": live_play,
		"live_tutorial_seen": live_tutorial_seen, "match_3d": match_3d,
		"aim_assist": aim_assist, "match_camera": match_camera,
	}))
	f.close()
