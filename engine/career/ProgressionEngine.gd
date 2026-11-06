extends RefCounted
class_name ProgressionEngine

## NIVEL de carrera, XP de carrera, puntos de habilidad y FORMA (schema
## v33, 9-oct — Wilber: "mejorar la evolución del jugador para que tenga
## sentido y sea divertido"). Toda la matemática vive acá.
##
## Dos progresiones que se complementan:
##  - Atributos (PlayerDevelopment): suben con su propia XP → la MEDIA.
##  - Nivel (acá): sube con todo lo que hacés en la carrera → PUNTOS de
##    habilidad para el árbol (SkillTree), que cambian cómo se juegan los
##    minijuegos. Así cada partido/entreno tiene una recompensa visible
##    aunque la media no se mueva esa semana.

const MAX_LEVEL := 50

## XP de carrera para pasar de `lv` a `lv + 1`.
static func xp_to_next(lv: int) -> int:
	return 120 + lv * 30

## Nivel inicial según la media (creación de personaje y migración v33).
static func initial_level(overall: int) -> int:
	return clampi(int(round(float(overall - 42) / 1.1)), 1, 30)

## Puntos de habilidad que da un nivel: 1, y +1 extra cada 5 niveles.
static func points_for_level(lv: int) -> int:
	return 1 + (1 if lv % 5 == 0 else 0)

## Puntos acumulados por llegar a `lv` desde el nivel 1.
static func points_up_to(lv: int) -> int:
	var t: int = 0
	for l in range(2, lv + 1):
		t += points_for_level(l)
	return t

## Suma XP de carrera y procesa subidas de nivel. Devuelve
## {"xp": int, "levels": int, "points": int, "level": int} para la UI.
static func add_xp(player: PlayerData, amount: int) -> Dictionary:
	var out: Dictionary = {"xp": maxi(amount, 0), "levels": 0, "points": 0, "level": player.level}
	if player == null or amount <= 0:
		return out
	player.career_xp += amount
	while player.level < MAX_LEVEL and player.career_xp >= xp_to_next(player.level):
		player.career_xp -= xp_to_next(player.level)
		player.level += 1
		var pts: int = points_for_level(player.level)
		player.skill_points += pts
		out["levels"] = int(out["levels"]) + 1
		out["points"] = int(out["points"]) + pts
	if player.level >= MAX_LEVEL:
		player.career_xp = 0
	out["level"] = player.level
	return out

## XP de carrera de un partido. Jugar bien y ganar paga más; el banco sin
## minutos, poquito (estar en la lista ya es carrera).
static func match_xp(rating: float, goals: int, assists: int, won: bool, played: bool, friendly: bool, derby: bool = false) -> int:
	if not played:
		return 5
	var v: float = 30.0 * clampf(rating / 6.5, 0.4, 1.8) + goals * 14.0 + assists * 10.0 + (12.0 if won else 0.0)
	if friendly:
		v *= 0.5
	if derby:
		v *= DERBY_XP_MULT   # el clásico vale más (P5)
	return int(round(v))

## XP extra por cómo ejecutaste los gestos en el partido (10-oct, paquete
## de minijuegos): cada "perfecto" 4, cada "bueno" 1, y un premio por la
## mejor racha de aciertos seguidos (3+). Tope para que no rompa la curva.
static func gesture_xp(stats: Dictionary) -> int:
	var v: int = int(stats.get("perfecto", 0)) * 4 + int(stats.get("bueno", 0))
	var best: int = int(stats.get("best_streak", 0))
	if best >= 3:
		v += 4 * (best - 2)
	return mini(v, 60)

## XP de carrera de una sesión de entrenamiento según la intensidad.
static func training_xp(intensity: String) -> int:
	return int(round(14.0 * float(INTENSITY.get(intensity, INTENSITY["normal"])["xp"])))

const DERBY_XP_MULT := 1.5
const MILESTONE_XP := 80     # rasgo desbloqueado / hito
const TITLE_XP := 200        # título ganado

## INTENSIDAD del entrenamiento (season["training_intensity"]). Entrenar NO
## gasta energía (pedido anterior de Wilber: "solo baja jugando") — el costo
## de la intensa es un riesgo chico de golpe leve; la suave recupera algo.
const INTENSITY := {
	"suave": {"name": "Suave", "xp": 0.7, "recover": 8.0, "injury": 0.0},
	"normal": {"name": "Normal", "xp": 1.0, "recover": 0.0, "injury": 0.0},
	"intensa": {"name": "Intensa", "xp": 1.45, "recover": 0.0, "injury": 0.03},
}

## Extras de una sesión según la intensidad: XP de carrera, recuperación
## (suave) y el riesgo de golpe leve (intensa). Devuelve
## {"lv": add_xp(), "recovered": float, "knock_days": int}.
static func after_training(player: PlayerData, intensity: String, rng: RandomNumberGenerator) -> Dictionary:
	var it: Dictionary = INTENSITY.get(intensity, INTENSITY["normal"])
	var out: Dictionary = {"lv": add_xp(player, training_xp(intensity)), "recovered": 0.0, "knock_days": 0}
	var rec: float = float(it["recover"])
	if rec > 0.0:
		var before: float = player.fatigue_physical
		player.fatigue_physical = maxf(0.0, player.fatigue_physical - rec)
		out["recovered"] = before - player.fatigue_physical
	if float(it["injury"]) > 0.0 and player.injury_days_remaining == 0 and rng.randf() < float(it["injury"]):
		player.injury_days_remaining = rng.randi_range(2, 4)
		out["knock_days"] = player.injury_days_remaining
	return out

static func intensity_mult(intensity: String) -> float:
	return float(INTENSITY.get(intensity, INTENSITY["normal"])["xp"])

## --- FORMA (1-5) ----------------------------------------------------------
const FORM_WINDOW := 5

static func push_rating(player: PlayerData, rating: float) -> void:
	player.recent_ratings.append(snappedf(rating, 0.1))
	while player.recent_ratings.size() > FORM_WINDOW:
		player.recent_ratings.pop_front()

## 3 = normal (sin partidos todavía). Promedio de las últimas notas.
static func form(player: PlayerData) -> int:
	if player == null or player.recent_ratings.is_empty():
		return 3
	var s: float = 0.0
	for r in player.recent_ratings:
		s += float(r)
	var avg: float = s / float(player.recent_ratings.size())
	if avg < 5.9:
		return 1
	if avg < 6.5:
		return 2
	if avg < 7.2:
		return 3
	if avg < 7.9:
		return 4
	return 5

const FORM_NAMES := ["", "Pésima", "Baja", "Normal", "Buena", "Enchufado"]
const FORM_ARROWS := ["", "▼▼", "▼", "▶", "▲", "▲▲"]
static func form_color(f: int) -> Color:
	return [Color.GRAY, Color(0.85, 0.25, 0.25), Color(0.95, 0.55, 0.25), Color(0.85, 0.85, 0.85), Color(0.45, 0.85, 0.4), Color(1.0, 0.82, 0.25)][clampi(f, 0, 5)]
