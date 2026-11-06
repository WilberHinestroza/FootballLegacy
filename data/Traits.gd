extends RefCounted
class_name Traits

## Catálogo de RASGOS de jugador (schema v21, PlayerData.traits = Array de
## ids). Se desbloquean por hitos de carrera (TraitEngine.check_unlocks) y
## no se pierden nunca. Cada rasgo aplica UN modificador concreto; toda la
## matemática vive acá y en DecisionResolver (finalización) — nunca dispersa.
##
## Efectos (sumados si el jugador tiene varios del mismo tipo):
##   finish   → +chance en remate / mano a mano / remate lejano / cabezazo
##   set_piece→ +chance en tiro libre directo
##   penalty  → +chance en penal
##   playmk   → +chance en pase clave / regate / pase filtrado / presión
##   defense  → +chance en entrada / intercepción / despeje / última entrada
##   fatigue_factor → multiplica la fatiga que ganás (1.0 = normal)
##   rep_factor     → multiplica la reputación ganada por eventos

const CATALOG := {
	"killer_instinct": {
		"name": "Instinto asesino", "icon": "res://assets/medals/killer_instinct.png",
		"desc": "Si tenés medio metro, la clavás. +6% al definir.",
		"finish": 0.06, "set_piece": 0.03,
	},
	"penalty_king": {
		"name": "Rey del punto de penal", "icon": "res://assets/medals/penalty_king.png",
		"desc": "Desde los once metros no fallás. +13% en penales.",
		"penalty": 0.13,
	},
	"engine": {
		"name": "Motor incansable", "icon": "res://assets/medals/engine.png",
		"desc": "Corrés los 90 sin acusarlo. Ganás 20% menos de fatiga.",
		"fatigue_factor": 0.80,
	},
	"rock": {
		"name": "Roca defensiva", "icon": "res://assets/medals/rock.png",
		"desc": "Pasar por vos cuesta el doble. +5% en acciones defensivas.",
		"defense": 0.05,
	},
	"dead_ball": {
		"name": "Especialista a balón parado", "icon": "res://assets/medals/dead_ball.png",
		"desc": "Faltas y penales son tu firma. +8% en tiros libres, +5% en penales.",
		"set_piece": 0.08, "penalty": 0.05,
	},
	"talisman": {
		"name": "Talismán", "icon": "res://assets/medals/talisman.png",
		"desc": "Con vos en cancha, todo sale un poco mejor. +2% a todas tus acciones.",
		"finish": 0.02, "set_piece": 0.02, "penalty": 0.02, "playmk": 0.02, "defense": 0.02,
	},

	# --- Rasgos POR POSICIÓN (pedido de Wilber) ---
	"poacher": {
		"name": "Oportunista del área", "icon": "res://assets/medals/poacher.png",
		"desc": "Delantero: vivís de los rebotes y los mano a mano. +7% al definir.",
		"finish": 0.07,
	},
	"aerial_threat": {
		"name": "Bestia por arriba", "icon": "res://assets/medals/aerial_threat.png",
		"desc": "Delantero: en los centros mandás vos. +8% al definir de cabeza y en el área.",
		"finish": 0.08,
	},
	"playmaker": {
		"name": "Cerebro del mediocampo", "icon": "res://assets/medals/playmaker.png",
		"desc": "Mediocampista: ves el pase antes que nadie. +7% en pases clave, regate y filtrados.",
		"playmk": 0.07,
	},
	"ball_winner": {
		"name": "Recuperador", "icon": "res://assets/medals/ball_winner.png",
		"desc": "Medio o defensa: la pelota vuelve a tus pies. +5% en robos y +4% al presionar.",
		"defense": 0.05, "playmk": 0.04,
	},
	"sweeper": {
		"name": "Líbero moderno", "icon": "res://assets/medals/sweeper.png",
		"desc": "Defensa: cortás todo lo que pasa por el medio. +6% en acciones defensivas.",
		"defense": 0.06,
	},
	"keeper_wall": {
		"name": "Muro bajo los palos", "icon": "res://assets/medals/keeper_wall.png",
		"desc": "Portero: tu arco es un búnker. El rival genera 8% menos de peligro.",
		"concede_factor": 0.92,
	},

	# --- Segunda tanda ---
	"goal_machine": {
		"name": "Máquina de gol", "icon": "res://assets/medals/goal_machine.png",
		"desc": "Delantero de época. +10% al definir, encima de todo lo demás.",
		"finish": 0.10,
	},
	"speedster": {
		"name": "Gambeta eléctrica", "icon": "res://assets/medals/speedster.png",
		"desc": "Nadie te sigue el ritmo. +6% en regate, presión y pases filtrados.",
		"playmk": 0.06,
	},
	"iron_man": {
		"name": "Hombre de hierro", "icon": "res://assets/medals/iron_man.png",
		"desc": "Temporada tras temporada, siempre. Ganás 25% menos de fatiga.",
		"fatigue_factor": 0.75,
	},
	"free_kick_master": {
		"name": "Maestro del tiro libre", "icon": "res://assets/medals/free_kick_master.png",
		"desc": "El área chica tiembla cuando cobrás una falta. +10% en tiros libres.",
		"set_piece": 0.10,
	},
	"pressing_monster": {
		"name": "Presión asfixiante", "icon": "res://assets/medals/pressing_monster.png",
		"desc": "Medio o delantero: no dejás salir a nadie. +5% al presionar y +3% defendiendo.",
		"playmk": 0.05, "defense": 0.03,
	},
	"last_man": {
		"name": "Último hombre", "icon": "res://assets/medals/last_man.png",
		"desc": "Defensa: la barrida salvadora es tu especialidad. +6% en despejes y entradas de último recurso.",
		"defense": 0.06,
	},
	"mentor": {
		"name": "Referente del vestuario", "icon": "res://assets/medals/mentor.png",
		"desc": "Ya lo ganaste todo y el grupo te escucha. +3% a todas tus acciones.",
		"finish": 0.03, "set_piece": 0.03, "penalty": 0.03, "playmk": 0.03, "defense": 0.03,
	},
	"big_game_player": {
		"name": "Jugador de grandes citas", "icon": "res://assets/medals/big_game_player.png",
		"desc": "Cuanto más importa el partido, mejor jugás. +4% al definir, defender y a balón parado.",
		"finish": 0.04, "defense": 0.04, "set_piece": 0.04,
	},
	"fan_idol": {
		"name": "Ídolo de la afición", "icon": "res://assets/medals/fan_idol.png",
		"desc": "La tribuna corea tu nombre. Ganás 40% más de reputación por eventos y jugás con más confianza (+3% al definir).",
		"finish": 0.03, "rep_factor": 1.4,
	},
	"cat_reflexes": {
		"name": "Reflejos felinos", "icon": "res://assets/medals/cat_reflexes.png",
		"desc": "Portero veterano: llegás a todo. El rival genera otro 10% menos de peligro.",
		"concede_factor": 0.90,
	},

	# --- Tercera tanda (10-oct, Wilber: "expande más los rasgos"): rasgos de
	# HISTORIA de carrera (club, selección, rival, edad) y de ATRIBUTO. ---
	"captain": {
		"name": "Capitán nato", "icon": "res://assets/medals/captain.png", "cat": "carrera",
		"desc": "El equipo te sigue. +2% a todas tus acciones.",
		"finish": 0.02, "set_piece": 0.02, "penalty": 0.02, "playmk": 0.02, "defense": 0.02,
	},
	"one_club": {
		"name": "Hombre de la casa", "icon": "res://assets/medals/one_club.png", "cat": "carrera",
		"desc": "Años en el mismo club: la gente te adora. +30% de reputación por eventos y +2% al definir y crear.",
		"finish": 0.02, "playmk": 0.02, "rep_factor": 1.3,
	},
	"globetrotter": {
		"name": "Trotamundos", "icon": "res://assets/medals/globetrotter.png", "cat": "carrera",
		"desc": "Te adaptás a cualquier vestuario. 10% menos de fatiga y +3% al crear juego.",
		"playmk": 0.03, "fatigue_factor": 0.90,
	},
	"national_hero": {
		"name": "Héroe nacional", "icon": "res://assets/medals/national_hero.png", "cat": "carrera",
		"desc": "La camiseta del país no te pesa. +3% al definir, defender y a balón parado.",
		"finish": 0.03, "defense": 0.03, "set_piece": 0.03,
	},
	"world_champion": {
		"name": "Campeón del mundo", "icon": "res://assets/medals/world_champion.png", "cat": "carrera",
		"desc": "Ya ganaste lo más grande. +3% a todas tus acciones.",
		"finish": 0.03, "set_piece": 0.03, "penalty": 0.03, "playmk": 0.03, "defense": 0.03,
	},
	"nemesis_slayer": {
		"name": "Verdugo", "icon": "res://assets/medals/nemesis_slayer.png", "cat": "carrera",
		"desc": "A tu rival personal le ganás siempre. +4% al definir y al defender.",
		"finish": 0.04, "defense": 0.04,
	},
	"golden_boy": {
		"name": "Niño de oro", "icon": "res://assets/medals/golden_boy.png", "cat": "carrera",
		"desc": "Explotaste muy joven. +4% al definir y al crear juego.",
		"finish": 0.04, "playmk": 0.04,
	},
	"veteran": {
		"name": "Zorro viejo", "icon": "res://assets/medals/veteran.png", "cat": "carrera",
		"desc": "Lo que perdés en piernas lo ganás en oficio. +6% en penales, +4% a balón parado, +2% al defender.",
		"penalty": 0.06, "set_piece": 0.04, "defense": 0.02,
	},
	"assist_king": {
		"name": "Rey de la asistencia", "icon": "res://assets/medals/assist_king.png",
		"desc": "El último pase es tuyo. +9% en pases clave, regate y filtrados.",
		"playmk": 0.09,
	},
	"award_winner": {
		"name": "Coleccionista de premios", "icon": "res://assets/medals/award_winner.png", "cat": "carrera",
		"desc": "Tres premios individuales en la vitrina. +3% al definir y +20% de reputación por eventos.",
		"finish": 0.03, "rep_factor": 1.2,
	},
	"centurion": {
		"name": "Centenario", "icon": "res://assets/medals/centurion.png",
		"desc": "150 goles de carrera. +9% al definir, desde cualquier puesto.",
		"finish": 0.09,
	},
	"marathon": {
		"name": "Maratonista", "icon": "res://assets/medals/marathon.png",
		"desc": "300 partidos en las piernas y seguís entero. Ganás 30% menos de fatiga.",
		"fatigue_factor": 0.70,
	},
	"clutch": {
		"name": "Sangre fría", "icon": "res://assets/medals/clutch.png",
		"desc": "Temple de 82 o más: el pulso no te tiembla. +8% en penales y +3% al definir.",
		"penalty": 0.08, "finish": 0.03,
	},
	"sprinter": {
		"name": "Rayo", "icon": "res://assets/medals/sprinter.png",
		"desc": "Velocidad de 86 o más. +4% al crear juego y +3% al definir.",
		"playmk": 0.04, "finish": 0.03,
	},
	"strongman": {
		"name": "Roble", "icon": "res://assets/medals/strongman.png",
		"desc": "Fuerza de 85 o más: no te mueven. +5% en acciones defensivas.",
		"defense": 0.05,
	},
	"penalty_stopper": {
		"name": "Atajapenales", "icon": "res://assets/medals/penalty_stopper.png",
		"desc": "Portero: te agrandás en los mano a mano. El rival genera 7% menos de peligro.",
		"concede_factor": 0.93,
	},
}

## Categorías para el menú de rasgos (10-oct). "todos" no está acá.
const CATEGORIES := [
	["ataque", "Ataque"], ["creacion", "Creación"], ["defensa", "Defensa"],
	["parado", "Balón parado"], ["fisico", "Físico"], ["arquero", "Arquero"], ["carrera", "Carrera"],
]

## Categoría de un rasgo: la explícita ("cat") o la que sale de su efecto.
static func category_of(id: String) -> String:
	var cfg: Dictionary = CATALOG.get(id, {})
	if cfg.has("cat"):
		return String(cfg["cat"])
	if cfg.has("concede_factor"):
		return "arquero"
	if cfg.has("fatigue_factor"):
		return "fisico"
	if cfg.has("rep_factor"):
		return "carrera"
	var f: float = float(cfg.get("finish", 0.0))
	var p: float = float(cfg.get("playmk", 0.0))
	var d: float = float(cfg.get("defense", 0.0))
	var s: float = float(cfg.get("set_piece", 0.0)) + float(cfg.get("penalty", 0.0))
	var touched: int = int(f > 0.0) + int(p > 0.0) + int(d > 0.0) + int(s > 0.0)
	if touched >= 3:
		return "carrera"   # auras (talismán, referente)
	var best: float = maxf(maxf(f, p), maxf(d, s))
	if best == f:
		return "ataque"
	if best == p:
		return "creacion"
	if best == d:
		return "defensa"
	return "parado"

## Resumen de lo que suman los rasgos EQUIPADOS + maestrías, para el menú.
## → [["Definición", 0.13], ...] solo lo que es > 0.
static func active_summary(player: PlayerData) -> Array:
	var out: Array = []
	for row in [["Definición", finish_bonus(player)], ["Creación", playmaking_bonus(player)],
			["Defensa", defense_bonus(player)], ["Tiro libre", set_piece_bonus(player)], ["Penal", penalty_bonus(player)]]:
		if float(row[1]) > 0.0005:
			out.append(row)
	return out

static func has(player: PlayerData, id: String) -> bool:
	return player != null and id in player.traits

## --- Slots de rasgos para el PARTIDO -------------------------------------
## El jugador solo lleva EQUIPADOS unos pocos rasgos a cada partido. Se
## abren slots al subir de media: slot 1 desde siempre, 2 a los 64, 3 a
## los 73, 4 a los 82 ("cada x cantidad de overall", pedido de Wilber).
const MAX_MATCH_SLOTS := 4
const SLOT_UNLOCK_OVERALL := [0, 64, 73, 82]

static func slots_for(overall: int) -> int:
	var n: int = 0
	for th in SLOT_UNLOCK_OVERALL:
		if overall >= int(th):
			n += 1
	return clampi(n, 1, MAX_MATCH_SLOTS)

## Overall al que se abre el PRÓXIMO slot (o -1 si ya están los 4).
static func next_slot_overall(overall: int) -> int:
	for th in SLOT_UNLOCK_OVERALL:
		if overall < int(th):
			return int(th)
	return -1

## Rasgos que REALMENTE aplican en partido: el subconjunto equipado
## (player.equipped_traits) filtrado a los desbloqueados y recortado a los
## slots disponibles. Si no eligió nada → auto: los primeros N desbloqueados
## en el orden del catálogo (estable).
static func active(player: PlayerData) -> Array:
	if player == null:
		return []
	var unlocked: Array = player.traits
	if unlocked.is_empty():
		return []
	var slots: int = slots_for(player.overall)
	var chosen: Array = []
	for id in player.equipped_traits:
		if id in unlocked and not (id in chosen):
			chosen.append(id)
		if chosen.size() >= slots:
			break
	if chosen.is_empty():
		for id in CATALOG.keys():
			if id in unlocked:
				chosen.append(id)
			if chosen.size() >= slots:
				break
	return chosen

static func _sum(player: PlayerData, key: String) -> float:
	if player == null:
		return 0.0
	var total: float = 0.0
	for id in active(player):
		var cfg: Dictionary = CATALOG.get(String(id), {})
		total += float(cfg.get(key, 0.0))
	return total

## Rasgos equipados + MAESTRÍA de la rama (CareerRpgEngine, 10-oct): la
## maestría entra al balance por el mismo camino que los rasgos, así todo lo
## que ya los usaba (DecisionResolver) la recibe sin tocar otra fórmula.
static func finish_bonus(player: PlayerData) -> float: return _sum(player, "finish") + CareerRpgEngine.mastery_bonus(player, "finish")
static func set_piece_bonus(player: PlayerData) -> float: return _sum(player, "set_piece")
static func penalty_bonus(player: PlayerData) -> float: return _sum(player, "penalty")
static func playmaking_bonus(player: PlayerData) -> float: return _sum(player, "playmk") + CareerRpgEngine.mastery_bonus(player, "playmk")
static func defense_bonus(player: PlayerData) -> float: return _sum(player, "defense") + CareerRpgEngine.mastery_bonus(player, "defense")

## Multiplicador del peligro que genera el RIVAL cuando el usuario es
## portero (rasgos "Muro bajo los palos" / "Reflejos felinos"). 1.0 = sin efecto.
static func concede_factor(player: PlayerData) -> float:
	return _factor(player, "concede_factor")

## Multiplicador de la reputación ganada por eventos (rasgo "Ídolo").
static func rep_factor(player: PlayerData) -> float:
	return _factor(player, "rep_factor")

static func _factor(player: PlayerData, key: String) -> float:
	if player == null:
		return 1.0
	var f: float = 1.0
	for id in active(player):
		var cfg: Dictionary = CATALOG.get(String(id), {})
		if cfg.has(key):
			f *= float(cfg[key])
	return f

## Multiplicador de fatiga ganada (compone: dos rasgos de 0.8 → 0.64).
static func fatigue_factor(player: PlayerData) -> float:
	if player == null:
		return 1.0
	var f: float = 1.0
	for id in active(player):
		var cfg: Dictionary = CATALOG.get(String(id), {})
		if cfg.has("fatigue_factor"):
			f *= float(cfg["fatigue_factor"])
	return f

static func name_of(id: String) -> String:
	return String(CATALOG.get(id, {}).get("name", id))

static func desc_of(id: String) -> String:
	return String(CATALOG.get(id, {}).get("desc", ""))

static func icon_of(id: String) -> String:
	return String(CATALOG.get(id, {}).get("icon", ""))
