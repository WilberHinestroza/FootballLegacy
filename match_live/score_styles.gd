class_name ScoreStyles
extends RefCounted
## Gráficas de marcador. Las de cadena (5 televisoras ficticias de
## FootballCareer) y las de torneo (diseños propios, sin logos reales):
##   "copa_sud"      tipo Libertadores: negro y dorado, copa al centro.
##   "copa_euro"     tipo Champions: azul noche, balón de estrellas.
##   "internacional" otros torneos internacionales de clubes: globo.
##   "selecciones"   partidos de selecciones: escudo con estrella.
## Layouts: "bar" (barra compacta), "center" (emblema entre los goles,
## reloj debajo — como la Premier), "banner" (franja con bloques en flecha
## y reloj arriba — como LaLiga).

const STYLES := {
	"golazo_tv":     {"name": "GOLAZO TV", "layout": "bar", "bg": "#1c0c10", "accent": "#e23b3b", "radius": 4, "plate": "#ffffff", "ink": "#1c0c10", "edge": "top"},
	"deporte_total": {"name": "DEPORTE TOTAL", "layout": "banner", "bg": "#0b2a8a", "accent": "#3a6ff0", "radius": 2, "plate": "#ffffff", "ink": "#0b2a8a", "edge": "bottom", "emblem": "ball"},
	"estadio_24":    {"name": "ESTADIO 24", "layout": "bar", "bg": "#07170e", "accent": "#18b85c", "radius": 0, "plate": "#0d2a18", "ink": "#8dffbd", "edge": "left"},
	"cancha_mas":    {"name": "CANCHA+", "layout": "center", "bg": "#2b0a3d", "accent": "#00e08a", "radius": 6, "plate": "#ffffff", "ink": "#2b0a3d", "edge": "", "emblem": "crown"},
	"tribuna":       {"name": "TRIBUNA", "layout": "bar", "bg": "#160d26", "accent": "#7b46d6", "radius": 8, "plate": "#f3ecff", "ink": "#2a1450", "edge": "bottom"},
	"copa_sud":      {"name": "COPA CONTINENTAL", "layout": "center", "bg": "#141414", "accent": "#d4a531", "radius": 10, "plate": "#d4a531", "ink": "#141414", "edge": "", "emblem": "cup", "channel": "golazo_tv"},
	"copa_euro":     {"name": "COPA DE CAMPEONES", "layout": "center", "bg": "#0a1446", "accent": "#c9d4ff", "radius": 4, "plate": "#ffffff", "ink": "#0a1446", "edge": "", "emblem": "stars", "channel": "estadio_24"},
	"internacional": {"name": "TORNEO INTERNACIONAL", "layout": "center", "bg": "#062a2e", "accent": "#36d1c4", "radius": 8, "plate": "#e8fffd", "ink": "#062a2e", "edge": "", "emblem": "globe", "channel": "cancha_mas"},
	"selecciones":   {"name": "SELECCIONES", "layout": "center", "bg": "#f4f4f4", "accent": "#c8102e", "radius": 6, "plate": "#c8102e", "ink": "#ffffff", "edge": "", "emblem": "shield", "channel": "tribuna", "text": "#14213d"},
}
const CHANNELS := ["golazo_tv", "deporte_total", "estadio_24", "cancha_mas", "tribuna"]

static func get_style(id: String) -> Dictionary:
	return STYLES.get(id, STYLES["golazo_tv"])

## Qué gráfica usa un partido de FootballLegacy (dict `fixture`).
static func style_for_fixture(fixture: Dictionary) -> String:
	if fixture.has("home_country"):
		return "selecciones"
	var comp: String = String(fixture.get("competition", "league"))
	if comp in ["continental", "club_world_cup"] or String(fixture.get("supercup_kind", "")) == "continental":
		var conf: String = String(fixture.get("cont_conf", "")).to_lower()
		var tier: int = int(fixture.get("cont_tier", 1))
		if comp == "continental" and tier == 1 and (conf.contains("conmebol") or conf.contains("sud") or conf.contains("sam")):
			return "copa_sud"
		if comp == "continental" and tier == 1 and (conf.contains("uefa") or conf.contains("eur")):
			return "copa_euro"
		return "internacional"
	var key: String = String(fixture.get("home_club_id", "")) + String(fixture.get("away_club_id", ""))
	return CHANNELS[absi(hash(key)) % CHANNELS.size()]
