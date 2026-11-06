extends RefCounted
class_name PlayerDevelopment

## Centraliza TODA la matemática de progresión de atributos y de duración
## de lesiones — mismo principio que DecisionResolver / CoachRelations:
## una sola fórmula, nunca dispersa por pantallas.
##
## Progresión ORGÁNICA (crecer hacia el potencial) = SOLO el sistema de XP
## por atributo de abajo (partidos + "Entrenar"), nunca un dado aparte —
## el "entrenamiento" (Training screen) solo elige el FOCO, nunca acelera
## ni ralentiza el ritmo en sí. El tick SEMANAL (WorldTickEngine, cada 7
## días) queda solo para dos cosas que el sistema de XP no cubre: el
## DECLIVE por edad (veteranos) y el "Suplemento de concentración" de la
## Tienda (garantiza +1 esa semana).
##
## BUG real encontrado y corregido (12-sep): hasta ahora el tick semanal
## TAMBIÉN tiraba un dado de crecimiento (`weekly_growth_chance`, ya
## eliminada) en paralelo al sistema de XP — un jugador activo cobraba el
## progreso DOS VECES y llegaba al potencial en 1-2 temporadas incluso en
## "normal". Wilber lo reportó ("sigo pensando que en normal se evoluciona
## muy rápido") tras confirmarlo con una sim: 70→88 de media en una sola
## temporada con ambos canales; 70→76→80→83→86→89 en 5 con solo el de XP.
##
## Invariante: potential >= overall SIEMPRE (el crecimiento nunca lo cruza).

const DECLINE_START_AGE := 31

## AUDITORÍA 10-oct (Wilber: "revisa la progresión del jugador si funciona de
## manera óptima"; tools/ProgressionAuditProbe, potencial 84, arranque 56):
##   - solo jugando (sin entrenar): pico 72 recién a los 32 — nunca cerca del
##     potencial; arquero 65.
##   - entrenando casi todos los días: tope a los 22 y 14 años sin crecer.
##   - veteranos: a los 36 seguían en 84 (el entrenamiento tapaba el declive).
## Cuatro perillas nuevas, todas acá:
##   MATCH_XP_BASE + MATCH_REST_WEIGHT  jugar rinde más y toca TODOS los
##       atributos (antes los que no eran de tu puesto no subían nunca).
##   age_xp_mult()  la edad pesa en TODA la XP (partidos y entrenos).
##   near_cap_mult()  los últimos puntos antes del potencial cuestan más.
##   weekly_decline_chance()  declive más firme, que el entreno frena pero
##       no anula, y que empieza por lo físico.
const MATCH_XP_BASE := 40.0
const MATCH_REST_WEIGHT := 0.30

## Cuánto rinde la XP según la edad: los jóvenes aprenden rápido, el pico
## físico-técnico es 21-27, después cuesta cada vez más.
static func age_xp_mult(age: int) -> float:
	if age < 21:
		return 1.25
	if age <= 27:
		return 1.0
	if age <= 30:
		return 0.75
	if age <= 33:
		return 0.5
	return 0.32

## Freno cerca del techo: con la media a 14+ del potencial la XP rinde
## entera; pegado al potencial, 22%. Evita llegar al tope a los 22.
static func near_cap_mult(player: PlayerData) -> float:
	var gap: float = float(player.potential - player.overall)
	return clampf(0.22 + gap / 14.0 * 0.78, 0.22, 1.0)

## Dificultad de progresión (PlayerData.growth_difficulty, schema v25,
## elegida en creación de personaje) — pedido explícito: "3 dificultades,
## fácil = rápida progresión, difícil = más lenta". Dos perillas:
##   XP: cuánta XP hace falta para el próximo +1 de atributo (menos = más
##       rápido) — mueve TODA la progresión orgánica.
##       DECLINE: probabilidad semanal de -1 al declinar (veterano).
const DIFFICULTY_XP_MULT := {"easy": 0.62, "normal": 1.0, "hard": 1.55}
const DIFFICULTY_DECLINE_MULT := {"easy": 0.65, "normal": 1.0, "hard": 1.3}

const FOCUS_GROUPS := {
	"physical": ["speed", "stamina", "strength"],
	"technical": ["control", "passing", "shooting", "dribbling"],
	"mental": ["decision_making", "composure", "leadership"],
}
## "leadership" faltaba acá — bug real encontrado en la auditoría: ya
## estaba en FOCUS_GROUPS["mental"] y en Mi Perfil se mostraba con una
## barra de XP como cualquier otro atributo entrenable, pero
## grant_attribute_xp() descarta todo lo que no esté en esta lista, así
## que esa barra nunca se movía sin importar cuánto entrenaras "Mental".
const ALL_TRAINABLE := [
	"speed", "stamina", "strength", "control", "passing",
	"shooting", "dribbling", "decision_making", "composure", "leadership",
]
const ATTR_ES := {
	"speed": "Velocidad", "stamina": "Resistencia", "strength": "Fuerza",
	"control": "Control", "passing": "Pase", "shooting": "Tiro",
	"dribbling": "Regate", "decision_making": "Decisión", "composure": "Temple",
	"leadership": "Liderazgo",
}

static func attr_es(attr_name: String) -> String:
	return ATTR_ES.get(attr_name, attr_name.capitalize())

## ---------------------------------------------------------------------------
## "Atributos de tarjeta" (RIT/TIR/PAS/REG/DEF/FÍS, estilo EA FC) — ÚNICA
## fuente. Antes esta misma fórmula vivía DUPLICADA en PlayerCard.gd y
## PlayerProfile.gd (idénticas mientras nadie las tocara, pero exactamente
## el riesgo que describe CLAUDE.md: "nunca duplicar una fórmula de
## balance en otro archivo"). `overall` (más abajo) se calcula A PARTIR de
## estas 6, así que además de evitar que las dos pantallas se desincronicen
## entre sí, garantiza que "la media" y lo que el jugador VE en pantalla
## sean, por construcción, lo mismo.
## ---------------------------------------------------------------------------
const CARD_STAT_KEYS := ["RIT", "TIR", "PAS", "REG", "DEF", "FÍS"]

static func card_stat(player: PlayerData, key: String) -> int:
	match key:
		"RIT": return player.speed
		"TIR": return player.shooting
		"PAS": return player.passing
		"REG": return int(round((player.dribbling + player.control) / 2.0))
		"DEF": return int(round(player.decision_making * 0.5 + player.strength * 0.3 + player.speed * 0.2))
		"FÍS": return int(round((player.strength + player.stamina) / 2.0))
	return 0

## `overall` ("la media") es SIEMPRE el promedio de las 6 de arriba — nunca
## un número independiente. Bug real reportado por Wilber (Parte 93):
## "tengo esta media pero mis stats no van en concordancia con eso, por
## que aumenta así". Causa raíz: overall subía por un "banco" 4 puntos de
## atributo = +1 de media que contaba POR IGUAL los 9 atributos entrenables
## (incluye composure/decision_making con peso pleno), mientras las 6
## categorías visibles de arriba solo usan 6 de esos 9 (composure no
## aparece en NINGUNA; decision_making solo pesa 0.5 en DEF) — entrenar
## mental subía la media sin que se notara casi nada en pantalla. Ahora es
## un cálculo directo: por construcción nunca se puede desincronizar.
static func compute_overall(player: PlayerData) -> int:
	var total: int = 0
	for key in CARD_STAT_KEYS:
		total += card_stat(player, key)
	return int(round(float(total) / float(CARD_STAT_KEYS.size())))

## Único punto de mutación de `overall` fuera de la creación de personaje
## (CharacterCreation.gd) — recalcula desde los atributos actuales, clamp a
## `potential` (invariante de PlayerData), y devuelve el delta aplicado.
## Todo lo demás (entrenamiento, partidos, tienda, DM, tick semanal) cambia
## un ATRIBUTO y llama esto — nunca toca `overall` directo.
static func sync_overall(player: PlayerData) -> int:
	var before: int = player.overall
	player.overall = mini(compute_overall(player), player.potential)
	return player.overall - before

## ---------------------------------------------------------------------------
## XP por atributo (schema v23). Modelo VISIBLE que Wilber pidió: cada
## atributo junta XP hacia su siguiente +1; el jugador ve cuánto le falta y
## qué foco entrenar. Convive con el tick semanal de overall de arriba —
## el overall sigue el promedio de atributos vía un "banco" oculto.
## ---------------------------------------------------------------------------

## Umbral de XP para pasar de `attr_value` a `attr_value + 1`. Sube con el
## nivel: los últimos puntos de un atributo cuestan bastante más que los
## primeros (llegar de 88 a 89 es una odisea; de 55 a 56, un par de semanas).
static func xp_needed(attr_value: int, difficulty: String = "normal") -> int:
	var v: float = float(clampi(attr_value, 20, 98))
	var base: float = 60.0 + pow(v, 1.45) * 0.85
	return int(round(base * float(DIFFICULTY_XP_MULT.get(difficulty, 1.0))))

## Foco de entrenamiento que sube este atributo ("physical" | "technical" |
## "mental"), para mostrarlo en Mi Perfil ("entrená FÍSICO para subir esto").
static func attr_focus(attr_name: String) -> String:
	for fkey in FOCUS_GROUPS:
		if attr_name in (FOCUS_GROUPS[fkey] as Array):
			return fkey
	return ""

static func focus_label(focus: String) -> String:
	match focus:
		"physical": return "Físico"
		"technical": return "Técnico"
		"mental": return "Mental"
	return "—"

## Tope al que puede llegar un atributo por XP: un poco por encima del
## potencial global, para que el jugador pueda "especializar" sin romper
## la invariante potential >= overall (el overall nunca cruza el potential).
static func attr_cap(player: PlayerData) -> int:
	return clampi(player.potential + 6, 40, 99)

## Suma XP a varios atributos y procesa las subidas de nivel. `gains` =
## {attr_name: xp_float}. Devuelve {"leveled": {attr: +n}, "overall_delta": int,
## "xp_added": {attr: float}} para feedback en UI.
static func grant_attribute_xp(player: PlayerData, gains: Dictionary, _rng: RandomNumberGenerator = null) -> Dictionary:
	var out: Dictionary = {"leveled": {}, "overall_delta": 0, "xp_added": {}}
	if player == null or gains.is_empty():
		return out
	var bank: Dictionary = player.attribute_xp
	var cap: int = attr_cap(player)
	var difficulty: String = player.growth_difficulty
	for attr_name in gains:
		if not (attr_name in ALL_TRAINABLE):
			continue
		var add: float = maxf(0.0, float(gains[attr_name])) * (1.0 + SkillTree.total(player, "xp")) * near_cap_mult(player)
		if add <= 0.0:
			continue
		out["xp_added"][attr_name] = add
		var cur_val: int = int(player.get(attr_name))
		var pool: float = float(bank.get(attr_name, 0.0)) + add
		var gained: int = 0
		while cur_val < cap and pool >= float(xp_needed(cur_val, difficulty)):
			pool -= float(xp_needed(cur_val, difficulty))
			cur_val += 1
			gained += 1
		if gained > 0:
			player.set(attr_name, cur_val)
			out["leveled"][attr_name] = gained
		bank[attr_name] = pool
	player.attribute_xp = bank
	out["overall_delta"] = sync_overall(player)
	return out

## Punto único para RESINCRONIZAR overall tras subir atributos FUERA del
## ciclo normal de grant_attribute_xp() (gym, campamento de la Tienda,
## regalos de DM...) — quien llama ya actualizó el/los atributo(s) reales
## ANTES de invocar esto. Antes cada uno de esos sistemas subía
## player.overall DIRECTO con su propia probabilidad o con un banco 4:1
## que contaba mal (ver cabecera de sync_overall) — la media se despegaba
## con el tiempo de los atributos que en verdad se ven en pantalla
## (Wilber: "tengo esta media pero mis stats no van en concordancia con
## eso"). `_attr_points` ya no hace falta (el cálculo es directo desde el
## estado actual) — queda solo por compatibilidad de firma con los call
## sites existentes (ShopEngine, SocialEngine, PlannerEngine).
static func bank_overall_progress(player: PlayerData, _attr_points: int) -> int:
	return sync_overall(player)

## XP de un partido, repartida por atributo según cómo rindió el jugador.
## `rating` 0..10 (nota del partido). Mejor nota = más XP (pedido explícito).
## Los goles/asistencias dan un extra a tiro/pase.
static func match_xp_gains(player: PlayerData, rating: float, goals: int, assists: int) -> Dictionary:
	var perf: float = clampf(rating / 6.5, 0.35, 1.9)
	var base: float = MATCH_XP_BASE * perf * age_xp_mult(player.age)
	var gains: Dictionary = {}
	# Reparto por posición: lo que más se usa en tu puesto recibe más; el
	# resto recibe una parte chica (un partido entrena todo el cuerpo).
	var weights: Dictionary = _match_attr_weights(player.position)
	for attr_name in ALL_TRAINABLE:
		gains[attr_name] = base * float(weights.get(attr_name, MATCH_REST_WEIGHT))
	gains["shooting"] = float(gains.get("shooting", 0.0)) + float(goals) * 9.0
	gains["passing"] = float(gains.get("passing", 0.0)) + float(assists) * 8.0
	return gains

static func _match_attr_weights(position: String) -> Dictionary:
	match position:
		"GK":
			return {"composure": 0.9, "decision_making": 0.9, "strength": 0.5, "passing": 0.4}
		"DF":
			return {"strength": 0.9, "decision_making": 0.85, "speed": 0.6, "passing": 0.5, "composure": 0.5}
		"MF":
			return {"passing": 0.95, "control": 0.85, "decision_making": 0.7, "stamina": 0.6, "dribbling": 0.5}
		_:
			return {"shooting": 0.95, "dribbling": 0.8, "control": 0.6, "speed": 0.6, "composure": 0.5}

## Probabilidad de bajar overall -1 esta semana (veteranos).
## Bug real de la auditoría de balance (ronda 6): la pendiente 0.06/año +
## bajar DOS atributos por vez en _nudge_attributes() (en vez de uno,
## contradiciendo el propio comentario de esta función) acumulaba una
## pérdida esperada de ~94 puntos entre los 33 y los 37 años — más de lo
## que una carrera entera de entrenamiento junta, y mucho más de lo que
## el ritmo de entrenamiento a esa edad (multiplicador 0.55) puede
## reponer. Pendiente bajada a 0.04/año; el otro factor (1 atributo en
## vez de 2 por vez) está en apply_weekly_development().
static func weekly_decline_chance(age: int, difficulty: String = "normal") -> float:
	if age < DECLINE_START_AGE:
		return 0.0
	# 10-oct: 0.04/año desde los 32 no se notaba (el entreno lo reponía todo).
	# Ahora 0.11/año desde los 31: ~-1 de media por año a los 32-33, ~-2 a
	# los 35-36 para alguien que sigue jugando y entrenando normal.
	var chance: float = float(age - DECLINE_START_AGE + 1) * 0.10 + float(maxi(0, age - 34)) * 0.06
	return clampf(chance * float(DIFFICULTY_DECLINE_MULT.get(difficulty, 1.0)), 0.0, 0.95)

## Aplica el tick semanal a `player`. El crecimiento orgánico YA NO se
## decide acá (ver cabecera) — sale solo del sistema de XP por atributo
## (grant_attribute_xp, vía partidos/entrenamiento). Este tick solo cubre
## lo que el sistema de XP no puede: el "Suplemento de concentración"
## (`boosted`, garantiza +1 esa semana si hay hueco) y el declive por edad
## de los veteranos. Devuelve un resumen para feedback en UI:
## {"overall_delta": int, "attribute_deltas": {nombre: delta, ...}}
static func apply_weekly_development(player: PlayerData, focus: String, rng: RandomNumberGenerator, boosted: bool = false) -> Dictionary:
	var summary: Dictionary = {"overall_delta": 0, "attribute_deltas": {}}
	var gap: int = player.potential - player.overall

	if gap > 0 and boosted:
		_nudge_attributes(player, focus, 1, rng, summary)
		summary["overall_delta"] = sync_overall(player)
	elif player.overall > 30 and rng.randf() < weekly_decline_chance(player.age, player.growth_difficulty):
		# Bug real de la auditoría: acá se bajaban 2 atributos por vez (el
		# mismo _pick_count que el crecimiento), pero el comentario de
		# weekly_decline_chance() siempre dijo "-1" — un solo atributo por
		# vez, no dos.
		# El cuerpo se va primero: 2 de cada 3 veces baja un atributo físico.
		_nudge_attributes(player, "physical" if rng.randf() < 0.66 else focus, -1, rng, summary, 1)
		summary["overall_delta"] = sync_overall(player)

	return summary

## Sesión de entrenamiento MANUAL (botón "Entrenar" que avanza 1 día).
## Es UNA de las dos fuentes de XP orgánica (la otra son los partidos,
## match_xp_gains) — no hay ningún dado semanal aparte, ver cabecera.
## Ganancias de UNA sesión de entrenamiento, SIN mutar nada (ni tirar RNG) —
## fuente única para training_session() (la aplica de verdad) y para
## Training.gd (que solo necesita mostrar "qué sube este plan"). Bug real
## de la auditoría: Training._plan_gain_text() reproducía esta fórmula a
## mano pese a su propio comentario diciendo que no lo hacía — quedaba
## desincronizada de esto apenas alguien tocara los números acá.
static func session_gains_preview(player: PlayerData, focus: String) -> Dictionary:
	var group: Array = (FOCUS_GROUPS.get(focus, []) as Array)
	if group.is_empty():
		group = ALL_TRAINABLE
	var gains: Dictionary = {}
	var per_focus: float = 34.0 / float(maxi(group.size(), 1))
	for attr_name in group:
		gains[attr_name] = per_focus
	for attr_name in ALL_TRAINABLE:
		gains[attr_name] = float(gains.get(attr_name, 0.0)) + 4.0
	# Los jóvenes aprovechan más cada sesión; los veteranos, menos.
	var age_mult: float = age_xp_mult(player.age)
	for k in gains:
		gains[k] = float(gains[k]) * age_mult
	return gains

static func training_session(player: PlayerData, focus: String, rng: RandomNumberGenerator, xp_mult: float = 1.0) -> Dictionary:
	var summary: Dictionary = {"overall_delta": 0, "attribute_deltas": {}, "leveled": {}}
	# XP de la sesión: va al foco elegido (repartida) + una pizca a todo.
	# Determinista — entrenar suma progreso VISIBLE, no tira un dado.
	# `xp_mult` = intensidad elegida (ProgressionEngine.INTENSITY, v33).
	var gains: Dictionary = session_gains_preview(player, focus)
	for k in gains:
		gains[k] = float(gains[k]) * xp_mult
	var res: Dictionary = grant_attribute_xp(player, gains, rng)
	summary["overall_delta"] = int(res.get("overall_delta", 0))
	summary["leveled"] = res.get("leveled", {})
	for attr_name in (res.get("leveled", {}) as Dictionary):
		summary["attribute_deltas"][attr_name] = int(res["leveled"][attr_name])
	return summary

static func _nudge_attributes(player: PlayerData, focus: String, delta: int, rng: RandomNumberGenerator, summary: Dictionary, pick_count: int = 2) -> void:
	var group: Array = (FOCUS_GROUPS.get(focus, []) as Array).duplicate()
	if group.is_empty():
		group = ALL_TRAINABLE.duplicate()
	var picks: Array = _pick_random(group, mini(pick_count, group.size()), rng)
	for attr_name in picks:
		var current: int = player.get(attr_name)
		var updated: int = clampi(current + delta, 20, 99)
		if updated != current:
			player.set(attr_name, updated)
			summary["attribute_deltas"][attr_name] = updated - current
			# El tick semanal movió el atributo por su cuenta: la barra de XP
			# hacia ese +1 ya no aplica, se reinicia (v23) — SOLO si subió.
			# Bug real de la auditoría: si el atributo BAJÓ (declive por
			# edad), esto también borraba el progreso ya juntado hacia el
			# próximo +1 — un doble castigo (perdés el punto Y el progreso
			# ahorrado para recuperarlo).
			if delta > 0 and player.attribute_xp.has(attr_name):
				player.attribute_xp[attr_name] = 0.0

## Elige `count` elementos de `pool` sin repetir, con el RNG LOCAL que nos
## pasaron — nunca Array.shuffle(): usa el estado GLOBAL de aleatoriedad
## de Godot, no la semilla (world_seed, día) de esta función, y de paso
## perturbaría esa aleatoriedad global para el resto del juego. Bug real
## encontrado en esta misma función.
static func _pick_random(pool: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var copy: Array = pool.duplicate()
	var picks: Array = []
	for i in range(mini(count, copy.size())):
		var idx: int = rng.randi() % copy.size()
		picks.append(copy[idx])
		copy.remove_at(idx)
	return picks

## Duración (en días) de una lesión sufrida en partido. Sesgada hacia
## golpes leves; las graves son poco frecuentes.
static func roll_injury_days(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.6:
		return rng.randi_range(3, 7)     # golpe leve
	if roll < 0.9:
		return rng.randi_range(10, 21)   # lesión media
	return rng.randi_range(30, 60)       # lesión grave

## Desgaste físico de UN partido jugado — CLUB o SELECCIÓN, misma fórmula
## (Parte 91, pedido de Wilber: "fatiga/lesión cruzada entre selección y
## club" — antes un partido de selección no restaba nada de
## `fatigue_physical`, así que jugar un Mundial no cansaba para nada de
## cara al siguiente partido de liga). La energía SOLO baja jugando; la
## resistencia (stamina) amortigua. `full_intensity`: true para un
## partido oficial completo, false para uno de menor exigencia (amistoso
## de pretemporada). Devuelve el `fatigue_physical` nuevo YA clampeado —
## quien llama debe asignarlo.
static func physical_fatigue_after_match(player: PlayerData, full_intensity: bool = true) -> float:
	var stam_soft: float = clampf(1.0 - float(player.stamina) / 260.0, 0.42, 1.0)
	var phys_hit: float = (30.0 if full_intensity else 15.0) * stam_soft * clampf(1.0 - SkillTree.total(player, "fatigue"), 0.6, 1.0)
	return clampf(player.fatigue_physical + phys_hit, 0.0, 100.0)

## Aplica (si corresponde) la lesión sufrida en un partido — CLUB o
## SELECCIÓN, mismo criterio: si ya estaba lesionado no se pisa la baja
## en curso con una más corta. `rng` debe ser determinista (mismo patrón
## que el resto del mundo vivo: seed por día + world_seed).
## LESIÓN CON DECISIÓN (P5, 9-oct): apurar la vuelta = ~55% de los días,
## pero más chance de recaer los próximos partidos (MatchEngine la lee).
const RUSH_FACTOR := 0.55
const REINJURY_MULT := 3.0
const REINJURY_MATCHES := 4

static func rushed_injury_days(days: int) -> int:
	return maxi(1, int(ceil(float(days) * RUSH_FACTOR)))

static func rush_injury(player: PlayerData) -> void:
	player.injury_days_remaining = rushed_injury_days(player.injury_days_remaining)
	player.active_effects["reinjury_risk_matches"] = REINJURY_MATCHES

static func reinjury_active(player: PlayerData) -> bool:
	return player != null and int(player.active_effects.get("reinjury_risk_matches", 0)) > 0

static func apply_match_injury(player: PlayerData, injured: bool, rng: RandomNumberGenerator) -> void:
	if not injured or player.injury_days_remaining > 0:
		return
	var raw_days: int = roll_injury_days(rng)
	player.injury_days_remaining = maxi(1, int(round(raw_days * StaffEngine.injury_factor(player))))
