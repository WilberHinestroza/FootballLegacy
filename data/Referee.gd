extends RefCounted
class_name Referee

## Árbitros en pixel art (Paquete 5 del ROADMAP, 9-oct): 3 árbitros
## distintos generados con PixelLab sobre el personaje base de Wilber (ver
## art_src/pixellab/referee/). Pedido de Wilber: "3 tipos de árbitros que
## pueden tocar por partido" — cuál dirige sale DETERMINISTA del partido
## (mismo criterio que el clima, MatchIcons.weather_for), nunca al azar ni
## guardado.
##
## Solo apariencia: el árbitro todavía NO cambia nada del partido (que uno
## sea más tarjetero que otro tocaría el balance → decisión de Wilber).
##
## Animaciones por árbitro en assets/referee/<id>/<anim>_<n>.png:
##   idle (1 cuadro, de frente), pitazo, amarilla, roja (9 cuadros, de
##   frente) y run_<dir> (dir = south/east/north/west).

const _DIR := "res://assets/referee/"

const REFEREES := [
	{"id": "negro", "label": "Árbitro de negro"},
	{"id": "amarillo", "label": "Árbitro de amarillo"},
	{"id": "turquesa", "label": "Árbitro de turquesa"},
]

const ANIM_FPS := 10.0

static var _frames_cache: Dictionary = {}

## Árbitro del partido: determinista por equipos + fecha + world_seed.
static func for_fixture(fixture: Dictionary, world_seed: int) -> String:
	var key := "%s|%s|%s|%s|%d" % [
		String(fixture.get("home_club_id", fixture.get("home_country", ""))),
		String(fixture.get("away_club_id", fixture.get("away_country", ""))),
		String(fixture.get("competition", "")),
		str(fixture.get("epoch_day", fixture.get("matchday", 0))),
		world_seed,
	]
	return String(REFEREES[absi(hash("ref:" + key)) % REFEREES.size()]["id"])

## Cuadros de una animación (vacío si el arte no existe todavía — la
## cancha cae a la ficha redonda de siempre).
static func frames(ref_id: String, anim: String) -> Array:
	var key := ref_id + "/" + anim
	if _frames_cache.has(key):
		return _frames_cache[key]
	var out: Array = []
	var i: int = 0
	while true:
		var p := "%s%s/%s_%d.png" % [_DIR, ref_id, anim, i]
		if not ResourceLoader.exists(p):
			break
		out.append(load(p))
		i += 1
	_frames_cache[key] = out
	return out

## Todas las animaciones disponibles de un árbitro, para PitchView.
static func anim_set(ref_id: String) -> Dictionary:
	var out := {}
	for a in ["idle", "pitazo", "amarilla", "roja", "run_south", "run_east", "run_north", "run_west"]:
		var f: Array = frames(ref_id, a)
		if not f.is_empty():
			out[a] = f
	return out
