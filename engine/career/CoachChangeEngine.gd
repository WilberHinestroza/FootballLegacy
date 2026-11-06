extends RefCounted
class_name CoachChangeEngine

## Destitución del DT a mitad de temporada. El DT del club del usuario es
## DETERMINISTA (WorldFactory) y no se persiste; una destitución se guarda
## como OVERRIDE en season["coach_replacement"] (dict serializado de
## CoachData) y WorldTickEngine lo reinyecta en world["coach_by_club_id"]
## en cada load_runtime. Efecto: te toca reconquistar la confianza desde
## cero (coach_trust baja a NEW_COACH_TRUST) y el nuevo DT trae otra
## formación / estilo.
##
## Se evalúa UNA vez por temporada, en una ventana de mitad de año, con
## probabilidad según la posición del equipo en su liga.

const WINDOW_START_DAY := 130   # ~1 de diciembre (epoch day 0 = 1 de julio)
const WINDOW_END_DAY := 240     # ~1 de marzo
const NEW_COACH_TRUST := 45

## ¿Toca evaluar hoy? (una vez por temporada, dentro de la ventana, si no
## hubo ya un cambio esta temporada).
static func should_evaluate(season: Dictionary, day_in_season: int) -> bool:
	if season.get("coach_replacement", null) != null:
		return false
	if bool(season.get("coach_change_rolled", false)):
		return false
	return day_in_season >= WINDOW_START_DAY and day_in_season <= WINDOW_END_DAY

## Dónde "debería" estar el club según su ambición (0 = 1º, 1 = último).
## Un gigante que espera pelear el título y va 8º está en CRISIS; un club
## modesto 8º está SOBRECUMPLIENDO. Pedido de Wilber: "las IAs realistas".
static func expected_position_ratio(league_ambition: int) -> float:
	if league_ambition >= 80:
		return 0.12
	if league_ambition >= 62:
		return 0.30
	if league_ambition >= 44:
		return 0.50
	if league_ambition >= 30:
		return 0.66
	return 0.80

## Tira el dado (determinista por temporada+seed). `position_ratio`: 0 = 1º,
## 1 = último. `expected_ratio`: dónde se espera que esté el club (según
## su ambición) — lo que dispara la destitución es el HUECO entre lo
## esperado y lo real, no la posición cruda. Un club que va MEJOR de lo
## esperado casi nunca echa al DT.
static func rolls_sacking(world_seed: int, season_start_day: int, position_ratio: float, coach_trust: int, expected_ratio: float = 0.5) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("sack:%d" % season_start_day) ^ world_seed
	var gap: float = position_ratio - expected_ratio   # > 0 = va peor de lo esperado
	# base sube con el hueco vs expectativa; extra si además coquetea con
	# el descenso (últimos puestos duelen aunque el club sea modesto).
	var base: float = clampf(gap * 0.95 + maxf(0.0, position_ratio - 0.72) * 0.45, 0.0, 0.52)
	# Si TU relación con el DT ya está rota, es más probable que el club
	# también lo vea (empujoncito extra, tope +0.1).
	if coach_trust < 35:
		base += 0.10
	return rng.randf() < base

## Genera el DT de reemplazo (dict listo para season["coach_replacement"]).
static func make_replacement(club_id: String, world_seed: int, season_start_day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("newcoach:%d:%s" % [season_start_day, club_id]) ^ world_seed
	var formations: Array = Formations.FORMATIONS.keys()
	var formation: String = String(formations[rng.randi() % formations.size()])
	var styles: Array = CoachData.STYLES
	var play_styles := ["Posesión", "Directo", "Contraataque", "Presión alta"]
	var philosophies := ["Ofensivo", "Equilibrado", "Defensivo"]
	return {
		"coach_name": WorldFactory.synthetic_person_name(hash("newcoach_name:%d:%s" % [season_start_day, club_id]) ^ world_seed),
		"style": String(styles[rng.randi() % styles.size()]),
		"demanding": rng.randi_range(40, 80),
		"formation": formation,
		"philosophy": String(philosophies[rng.randi() % philosophies.size()]),
		"play_style": String(play_styles[rng.randi() % play_styles.size()]),
	}

## Reconstruye una CoachData a partir del dict guardado.
static func coach_from_dict(club_id: String, d: Dictionary) -> CoachData:
	var c := CoachData.new()
	c.coach_id = "replacement:" + club_id
	c.club_id = club_id
	c.coach_name = String(d.get("coach_name", "Nuevo DT"))
	c.style = String(d.get("style", "Pragmático"))
	c.demanding = int(d.get("demanding", 55))
	c.formation = String(d.get("formation", "4-3-3"))
	c.philosophy = String(d.get("philosophy", "Equilibrado"))
	c.play_style = String(d.get("play_style", "Posesión"))
	return c

static func headline(old_name: String, new_name: String) -> Dictionary:
	return {
		"headline": "El club destituye a %s" % old_name,
		"body": "%s se hace cargo del equipo. Nueva idea, nueva formación, y para vos: reconquistar la confianza desde cero." % new_name,
		"source": "DEPORTE TOTAL", "sentiment": "CRITICAL",
	}
