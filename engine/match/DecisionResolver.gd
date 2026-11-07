extends RefCounted
class_name DecisionResolver

## Traduce (atributos del jugador + rival + precisión del input táctil)
## en un resultado de éxito/fallo. Mantiene toda la matemática de
## balance en UN solo lugar, separada del engine y de la UI —
## aprendizaje de FL: nunca esparcir fórmulas de balance por varios
## archivos, o corregir el balance se vuelve una cacería.

const BASE_MIN_CHANCE := 0.05

## Precisión del minijuego a partir de la cual la acción SE CONSIGUE sí o sí
## (gol / asistencia / robo…), sin tirar el dado — pedido de Wilber: "si le
## pego bien a la barra, que entre". El desafío pasa a estar en ACERTAR el
## minijuego (zona más chica / barra más rápida cuanto peor el matchup), no
## en un porcentaje oculto. Ver DecisionResolver.difficulty() y Match._start_*.
const CLEAN_HIT := 0.72

## Salida común de cada resolver. Un toque "limpio" (dentro de la zona del
## minijuego → precision alta) es acierto garantizado; por debajo, se cae a
## la probabilidad por atributos (un roce al borde de la zona: media chance).
static func _out(chance: float, precision: float) -> Dictionary:
	if precision >= CLEAN_HIT:
		return {"success": true, "chance": maxf(chance, 0.99)}
	return {"success": randf() <= chance, "chance": chance}

## REMATES (10-oct, Wilber: "quiero que por partido sean números realistas").
## Medido con tools/MatchNumbersProbe: con "toque limpio = gol seguro" un
## delantero de 68 metía 1,5 goles por partido y uno de 88 más de 2 (real:
## 0,3-0,9). En un remate, clavar la zona ya NO es gol seguro: es un remate
## BIEN PEGADO, al arco — y ahí decide tu Tiro/Temple contra el arquero. El
## resto de las acciones (pase, regate, quite) sigue saliendo sí o sí con
## un toque limpio.
##   `quality` = qué tan clara es esa ocasión con un toque limpio y un
##   arquero de tu nivel (mano a mano 0.50 ... tiro libre 0.20).
const FINISH_SKILL_SLOPE := 0.014     # cada punto de ventaja sobre el arquero
const FINISH_PERFECT_BONUS := 0.06    # toque "perfecto" (>= GRADE_PERFECT)
static func _out_finish(player: PlayerData, gk_overall: int, precision: float, quality: float, attr_bonus: int, trait_bonus: float) -> Dictionary:
	var skill: float = float(player.shooting + attr_bonus) * 0.65 + float(player.composure + attr_bonus) * 0.35
	var edge: float = skill - float(gk_overall)
	var chance: float
	if precision >= CLEAN_HIT:
		chance = quality + edge * FINISH_SKILL_SLOPE + trait_bonus * 0.6
		if precision >= 0.93:
			chance += FINISH_PERFECT_BONUS
		chance = clampf(chance, 0.15, 0.80)
	else:
		# Mal pegado: rara vez entra.
		chance = clampf(quality * 0.30 + edge * 0.004 + trait_bonus * 0.3, 0.03, 0.22)
	return {"success": randf() <= chance, "chance": chance, "on_target": precision >= CLEAN_HIT}

## `attr_bonus`: bonus plano a los atributos del jugador SOLO en esta
## acción — hoy lo alimenta el "Suplemento pre-partido" de la Tienda (ver
## ShopEngine / MatchEngine._match_attr_bonus). 0 = sin efecto.

static func resolve_shot(player: PlayerData, gk_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.shooting + attr_bonus) * 0.5 + (player.composure + attr_bonus) * 0.2 + precision * 100.0 * 0.3
	var defense_score := gk_overall * 0.55
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.finish_bonus(player), BASE_MIN_CHANCE, MatchEngine.CONVERSION_CAP)
	return _out_finish(player, gk_overall, precision, 0.40, attr_bonus, Traits.finish_bonus(player))

static func resolve_key_pass(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.passing + attr_bonus) * 0.55 + (player.decision_making + attr_bonus) * 0.2 + precision * 100.0 * 0.25
	var defense_score := defender_overall * 0.5
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.85)
	return _out(chance, precision)

static func resolve_tackle(player: PlayerData, attacker_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.strength + attr_bonus) * 0.4 + (player.decision_making + attr_bonus) * 0.3 + precision * 100.0 * 0.3
	var attack_score := attacker_overall * 0.55
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.5 + Traits.defense_bonus(player), BASE_MIN_CHANCE, 0.9)
	return _out(chance, precision)

static func resolve_penalty(player: PlayerData, gk_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	# Los penales tienen piso de éxito más alto que un remate normal en juego.
	var attack_score := (player.shooting + attr_bonus) * 0.4 + (player.composure + attr_bonus) * 0.4 + precision * 100.0 * 0.2
	var defense_score := gk_overall * 0.35
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.penalty_bonus(player), 0.35, 0.92)
	return _out(chance, precision)

## Regate 1v1 (ST/MF): superar al marcador. Pesa regate + velocidad; tiene
## un piso de +0.15 porque encarar de frente casi siempre "pasa algo".
static func resolve_dribble(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.dribbling + attr_bonus) * 0.5 + (player.speed + attr_bonus) * 0.25 + precision * 100.0 * 0.25
	var defense_score := defender_overall * 0.52
	var chance: float = clamp((attack_score - defense_score) / 100.0 + 0.15 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.82)
	return _out(chance, precision)

## Remate de lejos (MF): más difícil que un remate normal (tope 0.34, el GK
## pesa más) pero la precisión del input cuenta más — es un "todo o nada".
static func resolve_long_shot(player: PlayerData, gk_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.shooting + attr_bonus) * 0.45 + (player.composure + attr_bonus) * 0.15 + precision * 100.0 * 0.4
	var defense_score := gk_overall * 0.62
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.finish_bonus(player), BASE_MIN_CHANCE, 0.34)
	return _out_finish(player, gk_overall, precision, 0.22, attr_bonus, Traits.finish_bonus(player))

## Duelo aéreo (ST rematando de cabeza / DF despejando): fuerza + compostura
## contra el overall del rival que salta. Sin atributo de "juego aéreo"
## propio, la fuerza hace de proxy.
static func resolve_aerial_duel(player: PlayerData, opponent_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.strength + attr_bonus) * 0.45 + (player.composure + attr_bonus) * 0.2 + precision * 100.0 * 0.35
	var defense_score := opponent_overall * 0.55
	var chance: float = clamp((attack_score - defense_score) / 100.0 + 0.1 + Traits.finish_bonus(player), BASE_MIN_CHANCE, 0.8)
	if player.position == "ST":
		return _out_finish(player, opponent_overall, precision, 0.34, attr_bonus, Traits.finish_bonus(player))
	return _out(chance, precision)

## Intercepción (DF/MF/GK): leer el pase y cortarlo. Visión de juego +
## velocidad; piso alto (+0.45) porque anticipar bien suele salir.
static func resolve_interception(player: PlayerData, attacker_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.decision_making + attr_bonus) * 0.4 + (player.speed + attr_bonus) * 0.25 + precision * 100.0 * 0.35
	var attack_score := attacker_overall * 0.5
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.45 + Traits.defense_bonus(player), BASE_MIN_CHANCE, 0.9)
	return _out(chance, precision)

## Mano a mano (ST): quedaste solo contra el arquero. Pesa compostura por
## encima de todo; piso más alto que un remate normal, tope 0.7.
static func resolve_one_on_one(player: PlayerData, gk_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.composure + attr_bonus) * 0.45 + (player.shooting + attr_bonus) * 0.25 + precision * 100.0 * 0.3
	var defense_score := gk_overall * 0.5
	var chance: float = clamp((attack_score - defense_score) / 100.0 + 0.12 + Traits.finish_bonus(player), 0.18, 0.7)
	return _out_finish(player, gk_overall, precision, 0.50, attr_bonus, Traits.finish_bonus(player))

## Tiro libre directo (ST/MF): raro que entre (tope 0.28) pero la precisión
## del input manda. Golazo si sale.
static func resolve_free_kick(player: PlayerData, gk_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.shooting + attr_bonus) * 0.4 + (player.composure + attr_bonus) * 0.25 + precision * 100.0 * 0.35
	var defense_score := gk_overall * 0.6
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.set_piece_bonus(player), BASE_MIN_CHANCE, 0.28)
	return _out_finish(player, gk_overall, precision, 0.20, attr_bonus, Traits.set_piece_bonus(player))

## Pase filtrado al espacio (MF): rompe la línea. Más difícil de completar
## que un centro/pase clave normal, pero si llega el compañero suele quedar
## de cara (la conversión la sube el engine).
static func resolve_through_ball(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.passing + attr_bonus) * 0.5 + (player.decision_making + attr_bonus) * 0.3 + precision * 100.0 * 0.2
	var defense_score := defender_overall * 0.58
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.7)
	return _out(chance, precision)

## Entrada de último hombre (DF): recuperación desesperada. Si sale, salvás
## un gol; si no, casi seguro es ocasión rival y puede haber tarjeta (lo
## resuelve el engine). Fuerza + velocidad.
static func resolve_last_ditch_tackle(player: PlayerData, attacker_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.strength + attr_bonus) * 0.35 + (player.speed + attr_bonus) * 0.35 + precision * 100.0 * 0.3
	var attack_score := attacker_overall * 0.62
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.32 + Traits.defense_bonus(player), BASE_MIN_CHANCE, 0.82)
	return _out(chance, precision)

## Despeje bajo presión en el área propia (DF/GK): decisión + fuerza. Piso
## alto (+0.4), sale casi siempre; si no, rebote peligroso.
static func resolve_clearance(player: PlayerData, pressure_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.strength + attr_bonus) * 0.35 + (player.decision_making + attr_bonus) * 0.35 + precision * 100.0 * 0.3
	var attack_score := pressure_overall * 0.5
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.4 + Traits.defense_bonus(player), BASE_MIN_CHANCE, 0.93)
	return _out(chance, precision)

## Presión alta (MF/ST): ir a robarla en campo rival. Velocidad + lectura +
## resistencia. Si sale, se roba arriba y hay chance de ocasión inmediata.
static func resolve_pressing(player: PlayerData, opponent_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.speed + attr_bonus) * 0.35 + (player.decision_making + attr_bonus) * 0.3 + (player.stamina + attr_bonus) * 0.15 + precision * 100.0 * 0.2
	var defense_score := opponent_overall * 0.5
	var chance: float = clamp((attack_score - defense_score) / 100.0 + 0.1 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.75)
	return _out(chance, precision)

## ---------------------------------------------------------------------------
## 12 momentos nuevos (Parte 91h, pedido de Wilber: "crea más situaciones de
## partido para actuar... distribuidas entre todas las posiciones y ataque,
## transición y defensa") — 5 de ataque, 4 de transición, 3 de defensa.
## Mismo criterio que todo lo de arriba: una fórmula por acción, balance
## centralizado acá, nunca duplicada en MatchEngine/Match.gd.

## Volea (ST/MF): remate a un balón que no está bajo control — más difícil
## que un remate normal, golazo si entra. Pesa disparo + control del balón.
static func resolve_volley(player: PlayerData, gk_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.shooting + attr_bonus) * 0.4 + (player.dribbling + attr_bonus) * 0.15 + precision * 100.0 * 0.35
	var defense_score := gk_overall * 0.58
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.finish_bonus(player), BASE_MIN_CHANCE, 0.42)
	return _out_finish(player, gk_overall, precision, 0.30, attr_bonus, Traits.finish_bonus(player))

## Globito (ST): el arquero adelantado, hay que picarla con delicadeza por
## encima — pesa compostura, más fácil que una volea, más difícil que un
## mano a mano limpio.
static func resolve_chip_shot(player: PlayerData, gk_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.composure + attr_bonus) * 0.45 + (player.shooting + attr_bonus) * 0.2 + precision * 100.0 * 0.3
	var defense_score := gk_overall * 0.5
	var chance: float = clamp((attack_score - defense_score) / 100.0 + 0.08 + Traits.finish_bonus(player), BASE_MIN_CHANCE, 0.55)
	return _out_finish(player, gk_overall, precision, 0.38, attr_bonus, Traits.finish_bonus(player))

## Pase atrás desde el fondo (ST/MF): asistencia servida desde la línea de
## fondo para que un compañero defina de cara al arco. Pesa regate (llegar
## hasta ahí) + pase (servirla bien).
static func resolve_cutback(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.dribbling + attr_bonus) * 0.35 + (player.passing + attr_bonus) * 0.35 + precision * 100.0 * 0.25
	var defense_score := defender_overall * 0.55
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.72)
	return _out(chance, precision)

## Centro al área (MF): cruzar buscando a un compañero. Pesa pase + visión.
static func resolve_cross(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.passing + attr_bonus) * 0.5 + (player.decision_making + attr_bonus) * 0.2 + precision * 100.0 * 0.3
	var defense_score := defender_overall * 0.52
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.78)
	return _out(chance, precision)

## Pared / uno-dos (MF/ST): triangulación rápida con un compañero. Pesa
## decisión + pase.
static func resolve_one_two(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.decision_making + attr_bonus) * 0.4 + (player.passing + attr_bonus) * 0.35 + precision * 100.0 * 0.25
	var defense_score := defender_overall * 0.5
	var chance: float = clamp((attack_score - defense_score) / 100.0 + 0.1 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.75)
	return _out(chance, precision)

## Arrancar el contragolpe (MF/ST): ganás el espacio a la carrera tras
## robar. Pesa velocidad + regate.
static func resolve_counter_run(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.speed + attr_bonus) * 0.45 + (player.dribbling + attr_bonus) * 0.25 + precision * 100.0 * 0.25
	var defense_score := defender_overall * 0.5
	var chance: float = clamp((attack_score - defense_score) / 100.0 + 0.12 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.7)
	return _out(chance, precision)

## Cambio de frente (MF): diagonal larga que cambia el juego de lado. Pesa
## pase + visión — el más "de riesgo calculado" de los pases largos.
static func resolve_switch_play(player: PlayerData, defender_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.passing + attr_bonus) * 0.45 + (player.decision_making + attr_bonus) * 0.3 + precision * 100.0 * 0.25
	var defense_score := defender_overall * 0.55
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.68)
	return _out(chance, precision)

## Recuperación en transición (MF/DF): volver a robarla apenas se pierde —
## más urgente que una intercepción común. Pesa velocidad + decisión.
static func resolve_recovery_tackle(player: PlayerData, attacker_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.speed + attr_bonus) * 0.4 + (player.decision_making + attr_bonus) * 0.3 + precision * 100.0 * 0.3
	var attack_score := attacker_overall * 0.52
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.35 + Traits.defense_bonus(player), BASE_MIN_CHANCE, 0.85)
	return _out(chance, precision)

## Salida en largo (GK): despeje/pase largo que lanza el contragolpe — un
## arquero con buenos pies, no solo reflejos. Pesa pase + decisión.
static func resolve_distribution(player: PlayerData, pressure_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var attack_score := (player.passing + attr_bonus) * 0.45 + (player.decision_making + attr_bonus) * 0.3 + precision * 100.0 * 0.25
	var defense_score := pressure_overall * 0.5
	var chance: float = clamp((attack_score - defense_score) / 100.0 + Traits.playmaking_bonus(player), BASE_MIN_CHANCE, 0.75)
	return _out(chance, precision)

## Bloqueo con el cuerpo (DF): te tirás a tapar el remate — piso alto (el
## cuerpo siempre tapa algo) pero no es un robo limpio como una entrada.
## Pesa fuerza + decisión.
static func resolve_block_shot(player: PlayerData, attacker_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.strength + attr_bonus) * 0.35 + (player.decision_making + attr_bonus) * 0.35 + precision * 100.0 * 0.3
	var attack_score := attacker_overall * 0.58
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.38 + Traits.defense_bonus(player), BASE_MIN_CHANCE, 0.88)
	return _out(chance, precision)

## Mano a mano del arquero (GK): la versión defensiva del "one_on_one" del
## ST — el delantero rival queda solo, el arquero achica. Pesa compostura +
## fuerza (un arquero grande impone).
static func resolve_keeper_one_on_one(player: PlayerData, attacker_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.composure + attr_bonus) * 0.45 + (player.strength + attr_bonus) * 0.25 + precision * 100.0 * 0.3
	var attack_score := attacker_overall * 0.52
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.15 + Traits.defense_bonus(player), 0.15, 0.75)
	return _out(chance, precision)

## Arquero-líbero (GK): salís de la línea a cortar un pase filtrado antes
## que llegue el delantero — todo o nada. Pesa velocidad + decisión.
static func resolve_sweeper_keeper(player: PlayerData, attacker_overall: int, precision: float, attr_bonus: int = 0) -> Dictionary:
	var defense_score := (player.speed + attr_bonus) * 0.4 + (player.decision_making + attr_bonus) * 0.35 + precision * 100.0 * 0.25
	var attack_score := attacker_overall * 0.55
	var chance: float = clamp((defense_score - attack_score) / 100.0 + 0.25 + Traits.defense_bonus(player), BASE_MIN_CHANCE, 0.82)
	return _out(chance, precision)

## ---------------------------------------------------------------------------
## DIFICULTAD del minijuego (0 = regalado, 1 = brutal). La usa la pantalla de
## partido para dimensionar la zona/velocidad de la barra: buen jugador +
## rasgos equipados + rival flojo → zona ancha y lenta; mal matchup → zona
## fina y rápida. MISMA ponderación de atributos que el resolver de esa
## acción (nada de una 2ª fórmula de balance, ver cabecera).
## `rival_overall` = arquero para remates/mano a mano/tiro libre/penal,
## defensor para el resto.
static func difficulty(kind: String, player: PlayerData, rival_overall: int, attr_bonus: int = 0) -> float:
	if player == null:
		return 0.5
	var skill: float = _action_skill(kind, player, attr_bonus)      # ~30..100
	var ease: float = _perk_ease(kind, player)                       # 0..~0.30
	# skill≈rival → ~0.42 (media). Divisor 70 (antes 55): la ventaja de
	# nivel se nota pero NO aplana el juego — un crack sigue viendo "Media"
	# salvo contra rivales muy flojos (la sim daba todo "Fácil" con 55).
	var raw: float = (float(rival_overall) - skill) / 70.0 + 0.42 - ease
	var b: Array = _diff_bounds(kind)
	return clampf(raw, float(b[0]), float(b[1]))

## "Nivel" del jugador en una acción (0..~100), con los mismos pesos que su
## resolver. Sirve solo para escalar la dificultad del minijuego.
static func _action_skill(kind: String, p: PlayerData, b: int) -> float:
	match kind:
		"shot_on_goal", "long_shot":
			return (p.shooting + b) * 0.6 + (p.composure + b) * 0.4
		"penalty", "penalty_shootout":
			return (p.composure + b) * 0.55 + (p.shooting + b) * 0.45
		"one_on_one":
			# Bug real de la auditoría (ronda 4): antes incluía dribbling,
			# un atributo que resolve_one_on_one (arriba) NUNCA usa —
			# desalineaba la dificultad mostrada del minijuego con la
			# probabilidad real de éxito. Mismos 2 atributos que el
			# resolver (composure, shooting), proporción equivalente.
			return (p.composure + b) * 0.64 + (p.shooting + b) * 0.36
		"free_kick":
			return (p.shooting + b) * 0.55 + (p.composure + b) * 0.45
		"key_pass", "through_ball":
			return (p.passing + b) * 0.6 + (p.decision_making + b) * 0.4
		"dribble":
			return (p.dribbling + b) * 0.6 + (p.speed + b) * 0.4
		"aerial_duel":
			return (p.strength + b) * 0.55 + (p.composure + b) * 0.45
		"pressing":
			return (p.speed + b) * 0.45 + (p.decision_making + b) * 0.35 + (p.stamina + b) * 0.2
		# Bug real de la auditoría (ronda 4): "tackle" e "interception"
		# compartían una fórmula con 3 atributos que no coincidía con
		# NINGUNO de los dos resolvers reales — resolve_tackle nunca usa
		# speed, resolve_interception nunca usa strength. Separados, cada
		# uno con los 2 atributos que su resolver de verdad pesa.
		"tackle":
			return (p.strength + b) * 0.57 + (p.decision_making + b) * 0.43
		"interception":
			return (p.decision_making + b) * 0.62 + (p.speed + b) * 0.38
		"clearance":
			return (p.strength + b) * 0.5 + (p.decision_making + b) * 0.5
		"last_ditch_tackle":
			return (p.strength + b) * 0.5 + (p.speed + b) * 0.5
		"volley":
			return (p.shooting + b) * 0.7 + (p.dribbling + b) * 0.3
		"chip_shot":
			return (p.composure + b) * 0.6 + (p.shooting + b) * 0.4
		"cutback":
			return (p.dribbling + b) * 0.5 + (p.passing + b) * 0.5
		"cross", "switch_play":
			return (p.passing + b) * 0.6 + (p.decision_making + b) * 0.4
		"one_two":
			return (p.decision_making + b) * 0.5 + (p.passing + b) * 0.5
		"counter_run":
			return (p.speed + b) * 0.6 + (p.dribbling + b) * 0.4
		"recovery_tackle":
			return (p.speed + b) * 0.5 + (p.decision_making + b) * 0.5
		"distribution":
			return (p.passing + b) * 0.6 + (p.decision_making + b) * 0.4
		"block_shot":
			return (p.strength + b) * 0.5 + (p.decision_making + b) * 0.5
		"one_on_one_save":
			return (p.composure + b) * 0.6 + (p.strength + b) * 0.4
		"sweep_keeper":
			return (p.speed + b) * 0.5 + (p.decision_making + b) * 0.5
		_:
			return float(p.overall + b)

## Cuánto ABARATA la dificultad el/los rasgo(s) equipado(s) que tocan esta
## acción (reusa los mismos buckets que el bonus de acierto, ×2.4).
static func _perk_ease(kind: String, p: PlayerData) -> float:
	var v: float = 0.0
	match kind:
		"shot_on_goal", "long_shot", "one_on_one", "aerial_duel", "volley", "chip_shot":
			v = Traits.finish_bonus(p)
		"free_kick":
			v = Traits.set_piece_bonus(p)
		"penalty", "penalty_shootout":
			v = Traits.penalty_bonus(p)
		"key_pass", "through_ball", "dribble", "pressing", "cutback", "cross", "one_two", "counter_run", "switch_play", "distribution":
			v = Traits.playmaking_bonus(p)
		"tackle", "interception", "clearance", "last_ditch_tackle", "recovery_tackle", "block_shot", "one_on_one_save", "sweep_keeper":
			v = Traits.defense_bonus(p)
	return clampf(v * 2.4, 0.0, 0.34)

## Suelo/techo de dificultad por tipo — las acciones "seguras" nunca son
## brutales; las de golazo (tiro libre, bombazo) nunca son un regalo.
static func _diff_bounds(kind: String) -> Array:
	match kind:
		"free_kick":
			return [0.42, 0.95]
		"long_shot":
			return [0.32, 0.92]
		"shot_on_goal":
			return [0.14, 0.90]
		"one_on_one", "aerial_duel", "penalty":
			return [0.10, 0.82]
		"penalty_shootout":
			return [0.14, 0.80]
		"key_pass", "dribble", "through_ball", "pressing":
			return [0.10, 0.85]
		"tackle", "interception":
			return [0.08, 0.78]
		"clearance":
			return [0.05, 0.62]
		"last_ditch_tackle":
			return [0.14, 0.86]
		"volley":
			return [0.30, 0.92]
		"chip_shot":
			return [0.16, 0.85]
		"cutback", "cross", "one_two", "switch_play":
			return [0.10, 0.82]
		"counter_run":
			return [0.12, 0.80]
		"recovery_tackle":
			return [0.08, 0.78]
		"distribution":
			return [0.10, 0.80]
		"block_shot":
			return [0.06, 0.70]
		"one_on_one_save":
			return [0.16, 0.82]
		"sweep_keeper":
			return [0.10, 0.85]
		_:
			return [0.10, 0.88]

static func resolve_shootout_kick(taker_composure: int, gk_overall: int, taker_shooting: int = 60) -> bool:
	# Versión "ambiental" (sin input táctil) para los pateadores que no
	# son el usuario, usada en la tanda de penales de muerte súbita.
	# El tiro pesa igual que el temple (con 60/60 da lo mismo que antes).
	var attack_score := taker_composure * 0.45 + taker_shooting * 0.3 + 25.0
	var defense_score := gk_overall * 0.35
	var chance: float = clamp((attack_score - defense_score) / 100.0, 0.45, 0.9)
	return randf() <= chance

## --- Ajustes del minijuego "aim" (cabezazo / puntería a un palo) ---
## Bug real de la auditoría: esta matemática vivía duplicada en Match.gd
## (el ajuste de precision post-toque, antes de mandarla al engine),
## violando la regla de oro de este archivo. Se movió acá tal cual estaba,
## sin cambiar ningún número — Match.gd solo llama a estas dos funciones.

## Cabezazo (aerial_duel): ganarle el salto al marcador. Un toque flojo
## pierde más duelos; uno bien conectado (verde) se respeta. Devuelve el
## multiplicador que Match.gd aplica sobre `precision`.
static func aim_aerial_duel_multiplier(difficulty: float, aim_tap_ms: float, aim_zone: int, precision: float) -> float:
	var quick: float = clampf(1.0 - aim_tap_ms / 1300.0, 0.0, 1.0)
	var win_odds: float = clampf(lerpf(0.85, 0.32, difficulty) + quick * 0.25, 0.15, 0.97)
	var won_duel: bool = randf() < win_odds
	var adjusted: float = precision * (1.0 if won_duel else 0.5)
	if aim_zone == 0:
		adjusted = clampf(adjusted * (1.15 if adjusted >= 0.78 else 0.8), 0.0, 1.0)
	return adjusted

## Remate a un palo elegido (aim_zone 0/1/2): el arquero puede adivinar el
## palo — afecta el margen (y la nota), pero no anula un disparo bien
## pegado. Devuelve el multiplicador que Match.gd aplica sobre `precision`.
static func aim_shot_gk_multiplier(difficulty: float, aim_tap_ms: float, aim_zone: int, precision: float) -> float:
	var telegraph: float = clampf(1.0 - aim_tap_ms / 1400.0, 0.0, 1.0)
	var gk_read: float = lerpf(0.12, 0.50, difficulty) + telegraph * 0.28
	var beaten: bool = randf() > gk_read or randi() % 3 != aim_zone
	return precision * (1.0 if beaten else 0.45)

## Penal con el arco dividido en 9 zonas (pedido de Wilber, 9-oct):
## zone = fila * 3 + columna, fila 0 = arriba, columna 0 = izquierda.
## El arquero adivina la COLUMNA con la MISMA probabilidad que en
## aim_shot_gk_multiplier (lectura por dificultad + cuánto telegrafiaste),
## así el penal no se vuelve ni más fácil ni más difícil en promedio.
## Lo nuevo es el riesgo/premio de la altura:
##  - ángulos de ARRIBA (zonas 0 y 2): aunque el arquero adivine el lado,
##    no llega.
##  - fila de arriba en general: más fácil de errar — un toque que NO fue
##    limpio pierde un 15% (el toque limpio sigue entrando siempre, regla de
##    Wilber aplicada en Match.gd).
static func aim_penalty_grid_multiplier(difficulty: float, aim_tap_ms: float, zone: int, precision: float) -> float:
	var row: int = floori(zone / 3.0)
	var col: int = zone % 3
	var telegraph: float = clampf(1.0 - aim_tap_ms / 1400.0, 0.0, 1.0)
	var gk_read: float = lerpf(0.12, 0.50, difficulty) + telegraph * 0.28
	var guessed: bool = randf() <= gk_read and randi() % 3 == col
	var top_corner: bool = row == 0 and col != 1
	var mult: float = 0.45 if (guessed and not top_corner) else 1.0
	if row == 0 and precision < CLEAN_HIT:
		mult *= 0.85
	return precision * mult

## Remate en la cancha 2D (minijuego interactivo, 9-oct — pedido de Wilber:
## "que uno pueda interferir en las acciones"): arrastrás desde la pelota
## hacia el arco mientras el arquero se mueve, y soltás.
##   sep   0..1 = qué tan lejos del arquero apuntaste (1 = el palo opuesto).
##   power 0..1+ = largo del arrastre (fuerza); ideal SHOT_POWER_IDEAL.
##   wide  = apuntaste afuera de los palos.
## Misma ESCALA que la barra clásica (Match._meter_precision): "clavarla"
## (lejos del arquero + fuerza justa) da 0.82-1.0 → >= CLEAN_HIT, entra; lo
## demás cae a <= 0.70. Lo exigente sube con la dificultad igual que el
## ancho de la zona de la barra (0.34 → 0.10): hay que alejarse más del
## arquero y la banda de fuerza se achica. `width_mod` = clima/fatiga/
## visitante (Match._context_mods()[0]), igual que en la barra.
const SHOT_POWER_IDEAL := 0.62

static func pitch_shot_precision(difficulty: float, sep: float, power: float, wide: bool, width_mod: float = 1.0) -> float:
	var d: float = clampf(difficulty, 0.0, 1.0)
	if wide:
		return 0.18
	var need: float = lerpf(0.40, 0.80, d)                 # separación mínima del arquero
	var band: float = lerpf(0.20, 0.08, d) * width_mod     # medio ancho de la banda de fuerza
	var pow_dist: float = absf(power - SHOT_POWER_IDEAL)
	var sep_ok: bool = sep >= need
	var pow_ok: bool = pow_dist <= band
	if sep_ok and pow_ok:
		var off: float = maxf(pow_dist / maxf(band, 0.001), (1.0 - sep) / maxf(1.0 - need, 0.001) * 0.5)
		return lerpf(1.0, 0.82, clampf(off, 0.0, 1.0))
	var sep_score: float = clampf(sep / maxf(need, 0.001), 0.0, 1.0)
	var pow_score: float = clampf(1.0 - (pow_dist - band) / (band + 0.15), 0.0, 1.0) if not pow_ok else 1.0
	return 0.70 * minf(sep_score, pow_score)

## --- ATAJAR UN PENAL siendo arquero (P4, 9-oct) -------------------------
## Dificultad del minijuego: pateador con temple vs. tu reflejo/lectura.
static func penalty_save_difficulty(taker_composure: int, keeper: PlayerData) -> float:
	var k: float = float(keeper.composure + keeper.decision_making) * 0.5 if keeper != null else 55.0
	return clampf((float(taker_composure) - k) / 70.0 + 0.5, 0.2, 0.9)

## Adivinar el lado: el pateador elige una de las 9 zonas al azar; tirarte
## a la misma columna te da mucha ventaja, a la contigua poca, al otro
## lado casi nada. Multiplica la precisión del reflejo (barra).
static func penalty_save_multiplier(dive_zone: int, precision: float) -> float:
	var shot_zone: int = randi() % 9
	var dc: int = absi(dive_zone % 3 - shot_zone % 3)
	var same_row: bool = floori(dive_zone / 3.0) == floori(shot_zone / 3.0)
	var m: float = [1.25, 0.7, 0.25][dc]
	if dc == 0 and same_row:
		m = 1.4
	return clampf(precision * m, 0.0, 1.0)

## ¿Atajaste? El penal sigue siendo favorable al que patea.
static func resolve_penalty_save(keeper: PlayerData, taker_composure: int, precision: float) -> bool:
	var k: float = float(keeper.composure + keeper.decision_making) * 0.5 if keeper != null else 55.0
	var chance: float = clampf(0.06 + precision * 0.6 + (k - float(taker_composure)) / 220.0, 0.05, 0.82)
	return randf() < chance

## --- TIRO LIBRE en la cancha (P4, 9-oct): la barrera tapa el medio ------
## `off` = 0 al centro del arco … 1 al palo. Multiplica la puntería.
static func free_kick_wall_factor(off: float) -> float:
	return lerpf(0.45, 1.12, smoothstep(0.22, 0.72, clampf(off, 0.0, 1.2)))

## --- CABEZAZO por timing (P4, 9-oct) ------------------------------------
## `err_ms` = adelanto (<0) / atraso (>0) del toque respecto del momento
## justo (HeaderTiming). Dentro de la ventana (más chica cuanto más difícil)
## = toque limpio; afuera cae rápido. Sin toque (9999) = 0.1.
static func header_timing_precision(err_ms: float, difficulty: float) -> float:
	if err_ms > 9000.0:
		return 0.1
	var window: float = lerpf(170.0, 80.0, clampf(difficulty, 0.0, 1.0))
	var e: float = absf(err_ms)
	if e <= window:
		return lerpf(1.0, CLEAN_HIT, e / window)
	return clampf(CLEAN_HIT - (e - window) / 400.0, 0.1, CLEAN_HIT - 0.01)

static func header_duration(difficulty: float) -> float:
	return lerpf(1.45, 0.85, clampf(difficulty, 0.0, 1.0))

## --- CLÁSICO (P5, 9-oct): presión ---------------------------------------
## Con temple alto el clásico te agranda (+2% de zona); si no, te achica.
static func derby_pressure(composure: int) -> float:
	return 0.02 if composure >= 70 else -0.04

## --- COMBO (P4, 9-oct): regate ganado → remate más fácil un rato ------
const COMBO_MINUTES := 8
const COMBO_EASE := 0.15
static func combo_ease(kind: String, active: bool) -> float:
	if not active:
		return 0.0
	return COMBO_EASE if skill_bucket(kind) == "finish" else 0.0

## --- RPG (schema v33): habilidades + forma sobre la barra ----------------
## Devuelve [mult. de ancho de zona verde, mult. de velocidad]. Las
## habilidades (SkillTree) ensanchan la zona de SU tipo de acción y
## frenan la barra; la FORMA (ProgressionEngine.form, 1-5) suma o resta
## un 4% de zona por escalón respecto de "normal".
const FORM_WIDTH_STEP := 0.04
static func skill_bucket(kind: String) -> String:
	match kind:
		"shot_on_goal", "long_shot", "one_on_one", "volley", "chip_shot":
			return "finish"
		"aerial_duel", "clearance":
			return "aerial"
		"free_kick":
			return "set_piece"
		"penalty", "penalty_shootout":
			return "penalty"
		"dribble":
			return "dribble"
		"key_pass", "through_ball", "cutback", "cross", "one_two", "counter_run", "switch_play", "distribution":
			return "playmaking"
		"one_on_one_save", "sweep_keeper":
			return "gk"
		_:
			return "defense"

## Química (P5): hasta +8% de zona en los pases con un plantel "hermano".
static func chemistry_width(kind: String, chemistry: int) -> float:
	return float(clampi(chemistry, 0, 100)) / 100.0 * 0.08 if skill_bucket(kind) == "playmaking" else 0.0

static func rpg_meter_mods(player: PlayerData, kind: String, chemistry: int = 0) -> Array:
	if player == null:
		return [1.0, 1.0]
	var w: float = 1.0 + SkillTree.total(player, "w_" + skill_bucket(kind)) + chemistry_width(kind, chemistry)
	w += float(ProgressionEngine.form(player) - 3) * FORM_WIDTH_STEP
	w += SocialLifeEngine.mood_width(player)   # ánimo (vida social, v33)
	var s: float = clampf(1.0 - SkillTree.total(player, "bar_slow"), 0.6, 1.0)
	return [clampf(w, 0.8, 1.6), s]

## --- APUNTAR y después BARRA (9-oct, Wilber: "primero se apunte y luego
## se acierte en la barra en movimiento"). El apuntado da un `aim_score`
## (1 = buena puntería, <1 = cuánto le faltó, <0 = afuera) y la barra
## clásica da `bar` (misma escala: zona verde = 0.82-1.0). Regla: con buena
## puntería manda la barra (clavar el verde = sale); con mala puntería la
## barra no te salva (tope 0.70, escalado por lo que le faltó).
## 11-oct (Wilber, probando en el teléfono: "en los remates siempre fallo").
## Causa: para que el remate contara había que pasar DOS filtros muy finos
## y recién ahí se jugaba la chance contra el arquero:
##  - apuntar a 0.40-0.80 de "separación" del arquero. Apuntando al palo con
##    el arquero en el medio la separación es 0.56: en las jugadas difíciles
##    no alcanzaba NUNCA, había que adivinar el vaivén del arquero;
##  - y si no alcanzaba, el remate quedaba en 0.70 como máximo (por debajo
##    de CLEAN_HIT): fallo asegurado aunque la fuerza fuera perfecta.
## Ahora apuntar a un palo con el arquero en el medio SIEMPRE alcanza, y
## quedarse un poco corto resta, no anula (pitch_aim_bar_precision).
const SHOT_AIM_NEED_EASY := 0.25
const SHOT_AIM_NEED_HARD := 0.52
static func pitch_shot_aim_score(difficulty: float, sep: float, wide: bool, player: PlayerData = null) -> float:
	if wide:
		return -1.0
	var need: float = lerpf(SHOT_AIM_NEED_EASY, SHOT_AIM_NEED_HARD, clampf(difficulty, 0.0, 1.0)) * (1.0 - SkillTree.total(player, "aim"))
	return sep / maxf(need, 0.001)

static func pitch_pass_aim_score(difficulty: float, clearance: float, width_mod: float = 1.0, player: PlayerData = null) -> float:
	var need: float = lerpf(0.035, 0.075, clampf(difficulty, 0.0, 1.0)) / maxf(width_mod, 0.5) * (1.0 - SkillTree.total(player, "pass_aim"))
	return clearance / maxf(need, 0.001)

static func pitch_aim_bar_precision(bar: float, aim_score: float) -> float:
	if aim_score < 0.0:
		return 0.18
	if aim_score >= 1.0:
		return bar
	# Cerca del arquero: resta en proporción (antes: tope 0.70 = nunca entraba).
	return bar * lerpf(0.55, 1.0, clampf(aim_score, 0.0, 1.0))

## --- Minijuegos interactivos en la cancha (pase / regate / defensa /
## arquero), 9-oct. Misma ESCALA que la barra clásica y que
## pitch_shot_precision: dentro de la "ventana" = 0.82-1.0 (>= CLEAN_HIT,
## sale), afuera <= 0.70. La ventana se achica con la dificultad igual que
## la zona de la barra (0.34 → 0.10 de ancho) y la ensancha/achica
## `width_mod` (clima/fatiga/visitante, Match._context_mods()[0]).

## Momento justo (regate, quite/anticipo, arquero): `err` = segundos de
## diferencia con el instante ideal, `correct` = elegiste el lado bien.
## Ventana: de `easy_window` (dificultad 0) a `hard_window` (dificultad 1).
static func pitch_timing_precision(difficulty: float, err: float, correct: bool, easy_window: float, hard_window: float, width_mod: float = 1.0) -> float:
	if not correct:
		return 0.15
	var w: float = lerpf(easy_window, hard_window, clampf(difficulty, 0.0, 1.0)) * width_mod
	var e: float = absf(err)
	if e <= w:
		return lerpf(1.0, 0.82, e / maxf(w, 0.001))
	return 0.70 * clampf(1.0 - (e - w) / (w + 0.35), 0.0, 1.0)

## Pase: `clearance` = distancia (en coordenadas de cancha) del rival más
## cercano a la línea de pase cuando tocaste. Más difícil = hace falta una
## línea más limpia.
static func pitch_pass_precision(difficulty: float, clearance: float, width_mod: float = 1.0) -> float:
	var need: float = pass_lane_need(difficulty) / maxf(width_mod, 0.5)
	if clearance >= need:
		return lerpf(0.82, 1.0, clampf((clearance - need) / need, 0.0, 1.0))
	return 0.70 * clampf(clearance / need, 0.0, 1.0)

## Arquero: te tiraste ANTES del remate (adivinaste). Si fue al lado bien,
## vale, pero menos que reaccionar — premia leer al delantero sin volverlo
## la mejor estrategia.
static func pitch_keeper_guess_precision(correct: bool, early_by: float) -> float:
	if not correct:
		return 0.15
	return 0.76 if early_by <= 0.25 else 0.55

# =====================================================================
#  VAR real y árbitro con personalidad (10-oct, decisión de Wilber)
# =====================================================================

## De cada gol de jugada (nunca penales), cuántos revisa el VAR y cuántas
## de esas revisiones terminan en gol ANULADO. 12% × 30% ≈ 3,6% de los
## goles anulados: se nota (uno cada ~8 partidos) sin tocar el marcador
## promedio de forma apreciable.
const VAR_REVIEW_CHANCE := 0.12
const VAR_OVERTURN_CHANCE := 0.30
const VAR_REASONS := ["fuera de juego", "mano en la jugada", "falta previa"]

## → {reviewed: bool, overturned: bool, reason: String}. `var_mult` = del
## árbitro (uno "de VAR" revisa más).
static func var_review(var_mult: float = 1.0) -> Dictionary:
	if randf() >= VAR_REVIEW_CHANCE * var_mult:
		return {"reviewed": false, "overturned": false, "reason": ""}
	var over: bool = randf() < VAR_OVERTURN_CHANCE
	return {"reviewed": true, "overturned": over,
		"reason": String(VAR_REASONS[randi() % VAR_REASONS.size()]) if over else ""}

## FUERA DE JUEGO EN EL PARTIDO 3D (6-nov). La geometría vive en m3d/Offside.gd;
## acá solo el azar humano: el juez de línea se equivoca con las jugadas muy
## justas (a 10 cm duda mucho; a más de 1 m nunca) y el VAR lo corrige casi siempre
## si acaba en gol. `var_mult` = del árbitro (el "amigo del VAR" revisa más fino).
const OFFSIDE_FLAG_MISS_MAX := 0.45   # chance de no levantar la bandera en línea
const OFFSIDE_FLAG_SURE_AT := 1.0     # m de adelanto a partir del cual nunca falla
const VAR_OFFSIDE_CATCH := 0.9

static func offside_flag_missed(margin_m: float) -> bool:
	var doubt := 1.0 - clampf(margin_m / OFFSIDE_FLAG_SURE_AT, 0.0, 1.0)
	return randf() < OFFSIDE_FLAG_MISS_MAX * doubt * doubt

static func var_catches_offside(var_mult: float = 1.0) -> bool:
	return randf() < clampf(VAR_OFFSIDE_CATCH * lerpf(0.9, 1.1, clampf(var_mult - 0.8, 0.0, 1.0)), 0.0, 0.99)

## Personalidad del árbitro, DETERMINISTA por su nombre (el mismo árbitro
## siempre pita igual). card_mult multiplica la chance de tarjeta por
## minuto; var_mult la de revisión del VAR.
const REFEREE_STYLES := [
	{"id": "permisivo", "label": "Deja jugar", "desc": "Saca pocas tarjetas.", "card_mult": 0.65, "var_mult": 0.8, "foul_mult": 0.8},
	{"id": "equilibrado", "label": "Equilibrado", "desc": "Ni muy muy, ni tan tan.", "card_mult": 1.0, "var_mult": 1.0, "foul_mult": 1.0},
	{"id": "equilibrado", "label": "Equilibrado", "desc": "Ni muy muy, ni tan tan.", "card_mult": 1.0, "var_mult": 1.0, "foul_mult": 1.0},
	{"id": "estricto", "label": "Estricto", "desc": "Corta todo: más faltas y amarillas.", "card_mult": 1.3, "var_mult": 1.0, "foul_mult": 1.25},
	{"id": "tarjetero", "label": "Tarjetero", "desc": "Mano rápida al bolsillo. Cuidá las entradas.", "card_mult": 1.6, "var_mult": 1.0, "foul_mult": 1.15},
	{"id": "var", "label": "Amigo del VAR", "desc": "Revisa cada gol dudoso.", "card_mult": 1.0, "var_mult": 1.9, "foul_mult": 1.0},
]

static func referee_profile(referee_name: String) -> Dictionary:
	if referee_name == "":
		return REFEREE_STYLES[1]
	return REFEREE_STYLES[absi(hash("refstyle:" + referee_name)) % REFEREE_STYLES.size()]

# =====================================================================
#  Paquete de minijuegos (10-oct): calificación del gesto, potencia del
#  remate y presión del momento. Solo números; la UI vive en Match.gd.
# =====================================================================

## Nota de un gesto según su precisión final (misma escala que todo lo
## demás: ≥ 0.82 = dentro de la zona).
const GRADE_PERFECT := 0.93
const GRADE_GOOD := 0.82
const GRADE_OK := 0.50
static func gesture_grade(precision: float) -> String:
	if precision >= GRADE_PERFECT:
		return "perfecto"
	if precision >= GRADE_GOOD:
		return "bueno"
	if precision >= GRADE_OK:
		return "regular"
	return "flojo"

## ¿Este gesto mantiene la racha? (perfecto o bueno).
static func gesture_keeps_streak(grade: String) -> bool:
	return grade == "perfecto" or grade == "bueno"

## REMATE CON POTENCIA (mantener y soltar): dónde está la zona y qué tan
## rápido carga. Mejor Tiro = zona más ancha. → {center, width, secs}
##   center  punto ideal de la carga (0..1)
##   width   ancho de la zona verde
##   secs    segundos para cargar de 0 a 1 (menos = más difícil)
static func shot_power_zone(difficulty: float, shooting: int, width_mod: float = 1.0) -> Dictionary:
	var d: float = clampf(difficulty, 0.0, 1.0)
	var skill: float = clampf((float(shooting) - 50.0) / 45.0, 0.0, 1.0)
	return {
		"center": 0.74,
		"width": lerpf(0.30, 0.17, d) * lerpf(0.9, 1.25, skill) * width_mod,   # 11-oct: era 0.26-0.10
		"secs": lerpf(1.35, 0.90, d),                                          # 11-oct: era 1.25-0.70
	}

## Precisión de la carga: dentro de la zona 0.82-1.0; pasado = se va alta,
## corto = sale flojo. Misma curva que la barra clásica.
static func shot_power_precision(value: float, center: float, width: float) -> float:
	var half: float = maxf(width * 0.5, 0.001)
	var dist: float = absf(value - center)
	if dist <= half:
		return lerpf(1.0, 0.82, dist / half)
	return clampf(0.70 - (dist - half) / (half + 0.06) * 0.70, 0.0, 0.70)

## PRESIÓN DEL MOMENTO sobre el ancho de la zona (multiplicador):
##  - piernas: con la estamina en vivo por debajo de 45% la zona se achica
##    (hasta -18% con el tanque vacío).
##  - partido grande (final / eliminatoria): con Temple 75+ te agrandás un
##    poco, si no, te pesa.
static func stamina_width_factor(stamina_pct: float) -> float:
	if stamina_pct >= 45.0:
		return 1.0
	return lerpf(0.82, 1.0, clampf(stamina_pct / 45.0, 0.0, 1.0))

static func big_match_width_factor(is_final: bool, is_knockout: bool, composure: int) -> float:
	if not is_final and not is_knockout:
		return 1.0
	var weight: float = 1.0 if is_final else 0.5
	return 1.0 + (0.03 if composure >= 75 else -0.07) * weight

## JUGADA ENCADENADA (10-oct): un regate ganado puede dejarte de frente al
## arco para definir VOS la jugada en el mismo momento (remate o pase), en
## vez de que la termine un compañero por sorteo. Reemplaza ese sorteo (no
## se suma a él), así los goles por partido no se mueven: cambia QUIÉN la
## termina, no cuántas entran.
## 11-oct (Wilber: "cuando encaro, si estoy cerca del arco debería poder
## patear"): ganar el regate casi siempre te deja elegir cómo terminarla
## (rematar, pase al compañero o pase atrás), en vez de 1 de cada 3 veces.
const CHAIN_CHANCE := 0.85
const CHAIN_KINDS := ["shot_on_goal", "key_pass", "cutback"]

## Cuánta de la xG "ambiental" del equipo se queda el usuario (10-oct): un
## delantero titular YA aporta sus propios goles y asistencias con sus
## momentos clave; sin este recorte se sumaban a los del equipo y el
## partido promedio pasaba de 2,7 goles.
const USER_XG_SHARE := {"ST": 0.80, "MF": 0.90, "DF": 0.98, "GK": 1.0}
## Multiplicador de TODAS las chances de que un pase/regate tuyo termine en
## gol de un compañero (asistencia). Antes un volante sacaba 0,86 por partido.
const ASSIST_SCALE := 0.26

# =====================================================================
#  Rebotes, paredes y línea de pase (10-oct, Wilber: "jugadas en las que se
#  puedan hacer varios pases... o rebotes que dé el arquero y uno pueda
#  rematar otra vez")
# =====================================================================
## REBOTE: un remate BIEN PEGADO que el arquero ataja puede quedar vivo y
## la jugada sigue en tus pies (segunda definición). Chance baja a
## propósito: medido con tools/MatchNumbersProbe, suma ~0,03-0,05 goles
## por partido a un delantero.
const REBOUND_CHANCE := 0.22
const REBOUND_KINDS := ["volley", "shot_on_goal"]

## Qué tan lejos tiene que estar el rival más cercano de la línea de pase
## para que el pase esté "libre" (coordenadas de cancha). ÚNICA fuente: la
## usan pitch_pass_precision y el dibujo LIBRE/MARCADO del minijuego.
static func pass_lane_need(difficulty: float) -> float:
	return lerpf(0.035, 0.075, clampf(difficulty, 0.0, 1.0))

## PAREDES: cuántos toques previos (tocar y devolver) tiene la jugada antes
## del pase final. Cada pared bien hecha "abre" un poco el pase final.
const COMBO_PASSES := {"one_two": 2, "key_pass": 1, "through_ball": 1, "switch_play": 1}
const COMBO_TOUCH_BONUS := 0.10    # +10% de línea libre por pared limpia
static func combo_passes(kind: String) -> int:
	return int(COMBO_PASSES.get(kind, 0))

## Línea del pase final, mejorada por las paredes previas (`prior` = la
## línea libre que tenía cada toque previo).
static func combo_pass_clearance(final_clearance: float, prior: Array, difficulty: float) -> float:
	var need: float = pass_lane_need(difficulty)
	var mult: float = 1.0
	for c in prior:
		if float(c) >= need:
			mult += COMBO_TOUCH_BONUS
	return final_clearance * minf(mult, 1.25)

# =====================================================================
#  OPORTUNIDAD EN VIVO (10-oct, Wilber: "que sea la oportunidad en cierta
#  zona y, atacando o defendiendo, uno hace la acción en vez de siempre ser
#  decisiones"). Ya no hay menú: el GESTO es la decisión y la ejecución.
#  Acá viven los números; PitchMinigame solo mide y Match solo traduce.
# =====================================================================
## Segundos hasta que el marcador se te tira encima (atacando). Pasado ese
## momento (+ un respiro) perdiste la pelota.
static func live_pressure_secs(difficulty: float) -> float:
	return lerpf(4.4, 2.7, clampf(difficulty, 0.0, 1.0))

## Pase a un compañero ADELANTADO: fuera de juego. Casi nunca prospera
## (queda un resto: "el línea no la vio").
const OFFSIDE_PRECISION := 0.05

## BARRIDA (planchazo): llegás con más margen que el quite de pie...
const SLIDE_WINDOW := 1.55
static func live_slide_precision(difficulty: float, err: float, width_mod: float = 1.0) -> float:
	return pitch_timing_precision(difficulty, err, true, 0.34 * SLIDE_WINDOW, 0.14 * SLIDE_WINDOW, width_mod)
## ...pero si fallás es FALTA: chance de tarjeta, y de que sea roja directa.
const SLIDE_FOUL_CARD_CHANCE := 0.50
const SLIDE_RED_CHANCE := 0.07

# ---------------------------------------------------------------------
#  ETAPA 2 — LA JUGADA CONTINÚA (10-oct): después de una acción tuya que
#  sale bien y no termina en gol, la pelota puede volver a vos y seguís
#  participando (hasta CHAIN_MAX_LINKS intervenciones seguidas). Medido
#  con tools/MatchNumbersProbe para no inflar los goles por partido.
# ---------------------------------------------------------------------
## CUÁNDO TERMINA LA JUGADA (regla de Wilber, 10-oct):
##  - Atacando: sigue mientras la pelota siga en tu equipo; termina cuando
##    te la roban / el pase se pierde / se va afuera / termina en remate.
##  - Defendiendo: sigue mientras el rival tenga la pelota; termina con gol,
##    pelota afuera, robo (tuyo o de un compañero) o atajada del arquero.
## Por eso: en ATAQUE continúa lo que SALE BIEN; en DEFENSA continúa lo que
## SALE MAL (te pasaron y el rival sigue). CONTINUE_* son la chance de que
## la jugada vuelva a pasar por vos en vez de resolverse entre los demás.
const CHAIN_MAX_LINKS := 4
const CONTINUE_PASS_CHANCE := 0.62      # te la devuelven y seguís (11-oct: era 0.50)
const CONTINUE_DEFENSE_CHANCE := 0.50   # te pasaron: volvés a tener una chance de frenarlo
## 11-oct (Wilber: "encadenar acciones... tener caminos y múltiples
## situaciones para elegir tanto en defensa, medio y ataque"): si ROBÁS la
## pelota, la jugada no termina ahí — salís jugando y elegís cómo.
## SEGUNDA PELOTA (11-oct, Wilber: "si un jugador rechaza el balón y le cae
## al rival, se inicia una jugada desde ahí"): un despeje no siempre termina
## la jugada — a veces le queda al rival y hay que volver a defender.
const SECOND_BALL_CHANCE := 0.45
const _SECOND_BALL := ["clearance"]
const CONTINUE_WIN_BALL_CHANCE := 0.60
const _WIN_BALL := ["pressing", "tackle", "interception", "recovery_tackle", "last_ditch_tackle", "block_shot"]
const CONTINUE_DECAY := 0.75            # cada eslabón siguiente es algo menos probable
const _CONT_PASS := ["key_pass", "through_ball", "cutback", "cross", "one_two", "switch_play"]
const _CONT_DEFENSE := ["pressing", "tackle", "interception", "recovery_tackle"]

## FALTA A FAVOR (10-oct): te sacan la pelota en un regate, pero a veces es
## con falta → tiro libre tuyo. (La barrida que falla, al revés, es falta
## TUYA: SLIDE_*.)
const FOUL_WON_CHANCE := 0.20
## De esas faltas, cuántas son DENTRO del área (penal que pateás vos).
const PENALTY_FROM_FOUL_CHANCE := 0.18
const _CONT_DRIBBLE := ["dribble", "counter_run"]
static func is_foul_won(kind: String, ok: bool) -> bool:
	return not ok and kind in _CONT_DRIBBLE

## Con qué sigue la jugada después de `kind` ([] = terminó).
static func continue_kinds(kind: String, ok: bool) -> Array:
	if is_foul_won(kind, ok):
		return ["free_kick"]
	if ok and kind in _CONT_PASS:
		return ["dribble", "through_ball", "long_shot"]   # la recibís de nuevo: encarar, filtrar o probar de lejos
	if ok and kind in _SECOND_BALL:
		return ["interception", "tackle", "pressing"]     # tu rechazo le cayó a un rival: hay que volver a defender
	if ok and kind in _WIN_BALL:
		return ["counter_run", "key_pass", "switch_play"] # la robaste: salir corriendo, pase adelante o cambiar de frente
	if not ok and kind in _CONT_DEFENSE:
		return ["recovery_tackle", "block_shot"]      # te superó: lo corrés o le tapás el remate
	return []

static func continue_chance(kind: String, ok: bool, depth: int) -> float:
	var base: float = 0.0
	if is_foul_won(kind, ok):
		return FOUL_WON_CHANCE
	if ok and kind in _CONT_PASS:
		base = CONTINUE_PASS_CHANCE
	elif ok and kind in _SECOND_BALL:
		base = SECOND_BALL_CHANCE
	elif ok and kind in _WIN_BALL:
		base = CONTINUE_WIN_BALL_CHANCE
	elif not ok and kind in _CONT_DEFENSE:
		base = CONTINUE_DEFENSE_CHANCE
	return base * pow(CONTINUE_DECAY, float(depth))

static func continue_narration(kind: String, ok: bool = false) -> String:
	if kind in _CONT_DRIBBLE:
		return "¡Falta! Te bajaron cuando te ibas: tiro libre para vos."
	if ok and kind in _SECOND_BALL:
		return "La sacaste, pero el rechazo le cae a un rival: vuelven a venir. Seguís vos."
	if ok and kind in _WIN_BALL:
		return "¡La robaste! La pelota es tuya y hay espacio: elegí cómo salir."
	if kind in _CONT_DEFENSE:
		return "Te pasó, pero la jugada sigue: volvé y cerrale el camino al arco."
	return "Tu pase rompió la línea y te la devuelven: la jugada sigue en tus pies."

# ---------------------------------------------------------------------
#  ATAQUE "CONGELADO" + DESMARQUE (10-oct, Wilber: "todo quieto hasta que
#  hago algo... y cuando tiro el pase todo se mueve hasta que yo la vuelva
#  a tener", "mover a mi jugador arrastrando el dedo, según su velocidad").
# ---------------------------------------------------------------------
## Regate sin reloj: no importa CUÁNDO sino POR DÓNDE. `clearance` =
## distancia del rival más cercano al camino por el que te vas.
static func live_dribble_precision(difficulty: float, clearance: float, width_mod: float = 1.0) -> float:
	return pitch_pass_precision(difficulty, clearance * 0.85, width_mod)

## DESMARQUE: segundos que tenés para moverte sin pelota antes de que te
## la devuelvan, y a qué velocidad corre tu jugador (unidades de cancha por
## segundo) según su atributo Velocidad.
const RUN_SECS := 2.6
static func run_speed(speed_attr: int) -> float:
	return lerpf(0.09, 0.20, clampf((float(speed_attr) - 40.0) / 55.0, 0.0, 1.0))
## Los rivales que te siguen corren a esta fracción de una velocidad media.
const MARKER_SPEED := 0.105
## Recibir LIBRE hace más fácil lo que sigue; recibir marcado, más difícil.
## `open_dist` = distancia al rival más cercano al recibir.
static func receive_difficulty_mod(open_dist: float) -> float:
	return lerpf(0.14, -0.12, clampf((open_dist - 0.05) / 0.13, 0.0, 1.0))

# ---------------------------------------------------------------------
#  CÓMO LE PEGÁS (11-oct, Wilber: "que yo apunte, luego decida cómo pegarle
#  a la pelota y luego la potencia"). Tres golpes, cada uno con su trueque.
#  Todo pasa por la PRECISIÓN (lo único que lee el motor), así el balance de
#  goles sigue saliendo de _out_finish.
#    zone = multiplicador del ancho de la zona de fuerza
#    aim  = multiplicador de la separación del arquero que hace falta
#    cap  = tope de precisión (por debajo de 0.93 no hay bonus de "perfecto")
#    plus = suma a la precisión si el golpe salió limpio
# ---------------------------------------------------------------------
const STRIKES := {
	"colocado": {"label": "Colocado", "desc": "Más fácil de pegarle bien. Sin el premio del remate perfecto.", "zone": 1.30, "aim": 1.0, "cap": 0.92, "plus": 0.0},
	"potente": {"label": "Potente", "desc": "Zona de fuerza más chica. Si sale limpio, es más difícil de atajar.", "zone": 0.78, "aim": 1.0, "cap": 1.0, "plus": 0.06},
	# 11-oct (Wilber: "hay combas hacia dentro y hacia fuera"):
	#  - hacia ADENTRO (rosca, con el interior): sale abierta y se cierra
	#    sobre el palo. La más fácil de las dos.
	#  - hacia AFUERA (tres dedos, con el exterior): sale al arquero y se le
	#    escapa. Más difícil de pegarle, pero es la que menos puntería pide.
	"comba": {"label": "Comba hacia adentro", "desc": "Rosca: sale abierta y se cierra al palo. No hace falta apuntar tan al borde.", "zone": 0.95, "aim": 0.72, "cap": 0.96, "plus": 0.0},
	"comba_fuera": {"label": "Comba hacia afuera", "desc": "Tres dedos: va al arquero y se le escapa. Difícil de pegarle; la que menos puntería pide.", "zone": 0.80, "aim": 0.58, "cap": 1.0, "plus": 0.0},
}
const STRIKE_ORDER := ["colocado", "potente", "comba", "comba_fuera"]

static func strike(kind: String) -> Dictionary:
	return STRIKES.get(kind, STRIKES["colocado"])

## Puntería ya medida (`aim_score` de pitch_shot_aim_score) ajustada por el
## golpe: con comba hace falta menos separación del arquero.
static func strike_aim_score(aim_score: float, strike_kind: String) -> float:
	if aim_score < 0.0:
		return aim_score
	return aim_score / maxf(float(strike(strike_kind)["aim"]), 0.01)

## Precisión final del remate según el golpe elegido.
static func strike_precision(precision: float, strike_kind: String) -> float:
	var st: Dictionary = strike(strike_kind)
	var p: float = precision
	if p >= CLEAN_HIT:
		p += float(st["plus"])
	return clampf(minf(p, float(st["cap"])), 0.0, 1.0)

# =====================================================================
#  NOTA EN VIVO (la usa el partido 3D a través de Match3DBridge).
# =====================================================================

const RATING_GOAL := 1.0
const RATING_GOAL_LATE := 0.35
const RATING_ASSIST := 0.7
const RATING_TEAM_GOAL := 0.1
const RATING_GOAL_AGAINST := -0.1
const RATING_YELLOW := -0.4
const RATING_RED := -1.8
const RATING_SECOND_YELLOW := -1.5
const RATING_PEN_MISS := -0.6
const RATING_INJURY := -0.2
const RATING_GOAL_AGAINST_GK := -0.3
const RATING_GK_SAVE := 0.3
# ---- partido 3D (MiniSoccer3D en res://match3d/, 31-oct; Wilber: "integrarlo
# con football career ... y los partidos"). Toda la cuenta del 3D vive acá.
## Goles por minuto SIMULADO (entre jugada y jugada) desde la xG real de
## MatchEngine. Tus jugadas ya traen goles propios (ataque) y del rival
## (defensa / portero): la parte simulada se recorta para no duplicarlos.
const M3D_SIM_SHARE_US := 0.6
const M3D_SIM_SHARE_THEM := 0.75
const M3D_GK_SIM_SHARE_THEM := 0.45   # de arquero tus jugadas ya son sus ocasiones
## Nota del usuario: base + lo que hiciste en las jugadas.
const M3D_R_BASE := 6.2
const M3D_R_KEY_PASS := 0.2
const M3D_R_SHOT := 0.05
const M3D_R_RECOV := 0.3
const M3D_R_MOMENT_OK := 0.15
const M3D_R_MOMENT_FAIL := -0.15
const M3D_R_CONCEDED := -0.2         # gol rival en una jugada tuya de defensa

const M3D_R_YELLOW := -0.3            # amarilla tuya en el 3D (planchazo)
const M3D_R_RED := -1.2               # expulsado por doble amarilla
## Con uno menos tras tu expulsión: [tus goles, goles rivales] del resto del partido.
const M3D_SENT_OFF_RATES := [0.7, 1.35]

## Tus stats para el partido 3D según la energía con la que llegas (100 - fatiga física).
## Por debajo de 70 empiezan a pesar: lo físico baja hasta un 25% y lo técnico hasta un 10%
## con el tanque vacío. Devuelve {"stats": {...}, "note": texto para la ficha o ""}.
static func m3d_energy_stats(stats: Dictionary, energy: float) -> Dictionary:
	var tired: float = clampf((70.0 - energy) / 70.0, 0.0, 1.0)
	if tired <= 0.0:
		return {"stats": stats.duplicate(), "note": ""}
	var out := {}
	for k in stats:
		var physical: bool = k in ["speed", "stamina", "strength"]
		out[k] = int(round(float(stats[k]) * (1.0 - tired * (0.25 if physical else 0.10))))
	var note: String = "Llegas fundido (energía %d%%): corres y aguantas menos" % int(energy) if energy < 35.0 		else "Llegas cansado (energía %d%%)" % int(energy)
	return {"stats": out, "note": note}

static func m3d_goal_rates(xg_us: float, xg_them: float, user_gk: bool) -> Array:
	var us: float = clampf(xg_us, 0.2, 3.5) * M3D_SIM_SHARE_US / 90.0
	var them: float = clampf(xg_them, 0.2, 3.5) * (M3D_GK_SIM_SHARE_THEM if user_gk else M3D_SIM_SHARE_THEM) / 90.0
	return [us, them]

## Posesión del equipo del usuario (0-100) por la diferencia de xG.
static func m3d_possession(xg_us: float, xg_them: float, r: float) -> int:
	var tot: float = maxf(xg_us + xg_them, 0.2)
	return clampi(int(round(50.0 + (xg_us - xg_them) / tot * 22.0 + (r - 0.5) * 8.0)), 28, 72)

## `me` = match_stats.me del partido 3D (goals, assists, shots, key_passes,
## recov, saves, conceded, moments_ok); `moments` = jugadas que te tocaron.
## Nota del jugador en el partido 3D: SOLO por lo que haces tú (7-nov, Wilber: "mi nota
## depende de mis acciones, no del partido y mis compañeros; si tiro un pase y mi
## compañero se come el gol no debería quitarme puntos"). Ya no suma ni resta ganar o
## perder, ni los goles que encaja el equipo en la simulación, y una jugada solo cuenta
## como fallada si el fallo fue tuyo (me.moments_fail). Única fórmula: la usan la nota
## en vivo (SoccerMatch.live_rating) y la final (Match3DBridge.to_match_result).
static func m3d_user_rating(me: Dictionary) -> float:
	var r: float = M3D_R_BASE
	r += int(me.get("goals", 0)) * RATING_GOAL + int(me.get("assists", 0)) * RATING_ASSIST
	r += int(me.get("key_passes", 0)) * M3D_R_KEY_PASS + int(me.get("shots", 0)) * M3D_R_SHOT
	r += int(me.get("recov", 0)) * M3D_R_RECOV + int(me.get("saves", 0)) * RATING_GK_SAVE
	r += int(me.get("moments_ok", 0)) * M3D_R_MOMENT_OK + int(me.get("moments_fail", 0)) * M3D_R_MOMENT_FAIL
	r += int(me.get("conceded", 0)) * M3D_R_CONCEDED # gol rival en TU jugada de defensa/portería
	r = clampf(r, 3.0, 10.0)
	r += M3D_R_YELLOW * mini(int(me.get("yellows", 0)), 1) + (M3D_R_RED if bool(me.get("red", false)) else 0.0)
	return clampf(r, 1.0, 10.0)

## Empate en un cruce: tanda de penaltis resuelta por la diferencia de xG.

## Desde el banco en el partido 3D: ¿te mete el míster y en qué minuto?
## Más confianza = más probable y antes. 999 = no entras.
const M3D_BENCH_ENTRY_BASE := 0.55
const M3D_BENCH_ENTRY_TRUST := 0.004    # × confianza del DT (0-100)

static func m3d_bench_entry_minute(trust: int, r_enter: float, r_minute: float) -> float:
	var p: float = clampf(M3D_BENCH_ENTRY_BASE + trust * M3D_BENCH_ENTRY_TRUST, 0.4, 0.95)
	if r_enter >= p:
		return 999.0
	return clampf(55.0 + r_minute * 25.0 - trust * 0.08, 46.0, 82.0)

## Jugadas de peligro (como World Soccer Champs): qué parte son ocasiones A
## FAVOR (el resto, en contra en tu área), por el dominio real del partido.
static func m3d_attack_share(xg_us: float, xg_them: float) -> float:
	var tot: float = maxf(xg_us + xg_them, 0.2)
	return clampf(0.5 + (xg_us - xg_them) / tot * 0.35, 0.3, 0.75)


## ---------- Partido 3D: tanda de penales y paradas del portero ----------
## (antes vivían en match3d/scripts/match.gd; mismos números, ahora centralizados)

const M3D_SHOOTOUT_BASE := 0.76
const M3D_SHOOTOUT_SHOOTING := 0.18
const M3D_SHOOTOUT_COMPOSURE := 0.08
const M3D_SHOOTOUT_KEEPER := 0.16
const M3D_SHOOTOUT_SAVED_BAND := 0.18 # de lo que no entra, esta parte la para el portero

## Penal de la tanda simulada (no el tuyo): "goal" / "saved" / "miss".
## Stats 0..1 (0,5 = media). `r` = tirada 0..1.
static func m3d_shootout_outcome(shooting: float, composure: float, keeper_skill: float, r: float) -> String:
	var p: float = M3D_SHOOTOUT_BASE
	p += (shooting - 0.5) * M3D_SHOOTOUT_SHOOTING
	p += (composure - 0.5) * M3D_SHOOTOUT_COMPOSURE
	p -= (keeper_skill - 0.5) * M3D_SHOOTOUT_KEEPER
	p = clampf(p, 0.6, 0.9)
	if r < p:
		return "goal"
	if r < p + M3D_SHOOTOUT_SAVED_BAND:
		return "saved"
	return "miss"

## Estirada: probabilidad de que el tiro le supere según velocidad (m/s), lo
## lejos que pasa de él (m), si va a la escuadra y su nivel de portero (0..1).
## (8-nov: algo más difícil marcar — antes 0,4 por velocidad, 0,12 por metro y
## +0,15 a la escuadra, con el nivel de portero entre x1,4 y x0,6.)
static func m3d_keeper_dive_beaten(speed: float, lateral: float, top_corner: bool, keeper_skill: float) -> float:
	var beaten: float = (speed - 15.0) / 16.0 * 0.34 + maxf(lateral - 1.4, 0.0) * 0.1
	if top_corner:
		beaten += 0.13
	return clampf(beaten * lerpf(1.3, 0.5, keeper_skill), 0.03, 0.8)

## Cuánto más lejos llega estirándose (múltiplo del alcance natural de la animación).
static func m3d_keeper_reach(keeper_skill: float) -> float:
	return lerpf(1.35, 1.65, keeper_skill)

## Hasta dónde sale a achicar (m desde su portería) con un rival con balón a
## `holder_dist` m. Un buen portero sale antes y más; de lejos no deja la portería.
static func m3d_keeper_rush(holder_dist: float, keeper_skill: float) -> float:
	if holder_dist > 20.0:
		return 1.2
	var k: float = lerpf(0.3, 0.42, keeper_skill)
	return clampf(holder_dist * k, 1.2, lerpf(4.5, 6.5, keeper_skill))

## Si la para en la estirada: ¿blocaje (true) o despeje? Solo tiros no muy fuertes.
static func m3d_keeper_dive_catches(speed: float, r: float) -> bool:
	return speed < 19.0 and r < 0.55

## Balón que llega al portero sin estirada: probabilidad de que le supere.
static func m3d_keeper_contact_beaten(speed: float, lateral: float, keeper_skill: float) -> float:
	var beaten: float = clampf((speed - 17.0) / 14.0 * 0.3 + lateral * 0.2, 0.0, 0.55)
	return clampf(beaten * lerpf(1.3, 0.5, keeper_skill), 0.0, 0.7)


## Volea: velocidad (m/s) y error angular (rad) según el tiro, la sangre fría y lo
## cómodo que llega el balón (lo ideal, a la altura de la rodilla ~0,7 m).
static func m3d_volley(shooting: float, composure: float, ball_y: float) -> Dictionary:
	var comfort: float = clampf(1.0 - absf(ball_y - 0.7) / 0.7, 0.0, 1.0)
	var skill: float = clampf(shooting * 0.7 + composure * 0.3, 0.0, 1.0)
	return {"speed": lerpf(16.0, 26.0, skill) * lerpf(0.8, 1.0, comfort),
		"spread": (1.0 - skill) * 0.16 + (1.0 - comfort) * 0.12,
		"lift": lerpf(2.5, 0.6, comfort)} # mal cogida, se va hacia arriba


## Chilena: velocidad (m/s), error angular (rad) y elevación. Más difícil que la
## volea: la técnica pesa más y lo ideal es que llegue a ~1,8 m.
static func m3d_bicycle(shooting: float, dribbling: float, composure: float, ball_y: float) -> Dictionary:
	var comfort: float = clampf(1.0 - absf(ball_y - 1.8) / 0.6, 0.0, 1.0)
	var skill: float = clampf(shooting * 0.45 + dribbling * 0.35 + composure * 0.2, 0.0, 1.0)
	return {"speed": lerpf(14.0, 24.0, skill) * lerpf(0.75, 1.0, comfort),
		"spread": (1.0 - skill) * 0.22 + (1.0 - comfort) * 0.14,
		"lift": lerpf(1.2, -1.5, comfort)} # bien cogida, va hacia abajo


## Presión del equipo sin balón (0,75..1,35): quien pierde al final aprieta (la
## mentalidad en metros que adelanta líneas) y el equipo mejor físicamente y en
## lectura presiona más alto. `skill_diff` = media propia − media rival (0..1).
static func m3d_press_intensity(mentality_m: float, skill_diff: float) -> float:
	return clampf(1.0 + mentality_m * 0.035 + skill_diff * 0.8, 0.75, 1.35)
