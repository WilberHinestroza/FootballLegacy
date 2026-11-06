extends RefCounted
class_name MediaOutlets

## Medios deportivos FICTICIOS (9-oct, P1b "logos de las televisoras"):
## antes la prensa firmaba como MARCA / ESPN / AS / Sky... — marcas reales,
## mismo criterio que con los futbolistas (sin licencia, nada real). Cada
## medio tiene logo pixel de PixelLab en assets/media/<id>.png.
##
## Las noticias ya guardadas siguen diciendo "MARCA" etc.: `display()`
## traduce el nombre viejo al nuevo al mostrarlo (no hace falta migrar).

const OUTLETS := [
	{"id": "golazo_tv", "name": "GOLAZO TV", "color": "#e23b3b"},
	{"id": "deporte_total", "name": "DEPORTE TOTAL", "color": "#1f6fd6"},
	{"id": "estadio_24", "name": "ESTADIO 24", "color": "#12a150"},
	{"id": "la_jugada", "name": "LA JUGADA", "color": "#f0a000"},
	{"id": "tribuna", "name": "TRIBUNA", "color": "#7b46d6"},
	{"id": "cancha_mas", "name": "CANCHA+", "color": "#0fb5c9"},
	{"id": "pitch_radio", "name": "PITCH RADIO", "color": "#e8508a"},
	{"id": "futbol_hoy", "name": "FÚTBOL HOY", "color": "#d95a2b"},
]

const LEGACY := {
	"MARCA": "DEPORTE TOTAL", "ESPN": "GOLAZO TV", "SKY SPORTS": "ESTADIO 24",
	"OLÉ": "LA JUGADA", "AS": "TRIBUNA", "L'ÉQUIPE": "CANCHA+",
	"BBC SPORT": "PITCH RADIO", "GOAL": "FÚTBOL HOY", "TYC SPORTS": "ESTADIO 24",
}

## GRÁFICA DE TRANSMISIÓN por canal (10-oct, Wilber: "cada cadena con su
## marcador personalizado"): fondo, acento, curvatura y la placa del
## resultado. Las 4 cadenas que transmiten partidos (Match._add_tv_bug).
const BROADCAST := {
	"golazo_tv":     {"bg": "#1c0c10", "accent": "#e23b3b", "radius": 4,  "plate": "#ffffff", "ink": "#1c0c10", "edge": "top"},
	"deporte_total": {"bg": "#0a1530", "accent": "#2f7fe6", "radius": 16, "plate": "#2f7fe6", "ink": "#ffffff", "edge": "bottom"},
	"estadio_24":    {"bg": "#07170e", "accent": "#18b85c", "radius": 0,  "plate": "#0d2a18", "ink": "#8dffbd", "edge": "left"},
	"cancha_mas":    {"bg": "#05191e", "accent": "#16c4d8", "radius": 22, "plate": "#e8fbff", "ink": "#06303a", "edge": "top"},
}
const TV_CHANNELS := ["golazo_tv", "estadio_24", "cancha_mas", "deporte_total"]

static func names() -> Array:
	return OUTLETS.map(func(o): return String(o["name"]))

## Nombre a mostrar (traduce los de saves viejos).
static func display(source: String) -> String:
	return String(LEGACY.get(source.to_upper(), source))

static func by_name(source: String) -> Dictionary:
	var n: String = display(source).to_upper()
	for o in OUTLETS:
		if String(o["name"]) == n:
			return o
	return {}

## Logo del medio (o el genérico de BrandMark si no es un medio conocido,
## p. ej. "CUERPO TÉCNICO").
static func logo(source: String, px: int) -> Control:
	var o: Dictionary = by_name(source)
	var path: String = "res://assets/media/%s.png" % String(o.get("id", ""))
	if not o.is_empty() and ResourceLoader.exists(path):
		var r := TextureRect.new()
		r.texture = load(path)
		r.custom_minimum_size = Vector2(px, px)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	return BrandMark.build(display(source), px)
