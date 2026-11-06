extends RefCounted
class_name MatchTeam

## Representación GENÉRICA de un equipo dentro de un partido.
## Aprendizaje clave de Football Legacy: el MatchEngine NUNCA debe
## depender directamente de ClubData. Si construyes el equipo de club
## o el equipo de selección nacional, ambos se convierten a MatchTeam
## antes de entrar al engine. Esto es lo que les permitió reusar el
## mismo motor de partido para club y selección sin duplicar código.

var team_name: String = ""
var formation: String = ""
var play_style: String = ""   # estilo del DT (solo se usa para el equipo del usuario)
var starting_xi: Array[PlayerData] = []
var bench: Array[PlayerData] = []
## Suplentes convocados por partido (fútbol actual: 9).
const MATCHDAY_BENCH := 9
var is_user_team: bool = false
## NO CONVOCADO (9-oct): el usuario sigue en `bench` internamente (muchos
## sitios detectan su lado con starting_xi/bench.has), pero el motor nunca
## lo hace entrar y la UI no lo lista entre los suplentes.
var user_not_called: bool = false

## En qué PUESTO detallado (LI, DFC, ED, ...) juega cada titular según la
## formación del DT — puede NO ser su posición de oficio (un MCO alineado
## de LI, un DFC de LD por falta de laterales, un cambio por lesión). La
## alineación se muestra con ESTE puesto. Pedido de Wilber: "si el técnico
## pone a un MCO como LI porque es su segunda posición, debe aparecer esa".
var deployed_position: Dictionary = {}   # PlayerData -> código detallado

static func from_club(club: ClubData, all_players: Array[PlayerData], user_player: PlayerData, user_start_chance: float = 0.0, p_formation: String = "", allow_left_out: bool = false) -> MatchTeam:
	return assemble(club.club_name, all_players, user_player, user_start_chance, p_formation, allow_left_out)

## Selecciones nacionales (Fase 2): mismo motor de alineación, sin
## `ClubData` — el nombre del equipo es directamente el país. Ver
## NationalTeamMatchLauncher.gd (arma `all_players` con
## NationalTeamFactory.squad_for()).
static func from_national_team(country: String, all_players: Array[PlayerData], user_player: PlayerData, user_call_chance: float = 0.0, p_formation: String = "") -> MatchTeam:
	return assemble(country, all_players, user_player, user_call_chance, p_formation)

## `user_start_chance` (0.0-1.0): probabilidad de favor del entrenador (ver
## CoachRelations.start_chance en club, NationalCallUpEngine.call_up_probability
## en selección) de que el usuario empiece pese a no ser de los 11 mejores
## por overall. 0.0 = nunca (comportamiento de siempre).
## `p_formation` ("" = ninguna): si se pasa, la XI se arma según los PUESTOS
## de esa formación (Formations.slots_for) — el DT decide la formación
## (CoachData.formation en club; determinista por país en selección), no
## el usuario.
static func assemble(team_name: String, all_players: Array[PlayerData], user_player: PlayerData, user_start_chance: float = 0.0, p_formation: String = "", allow_left_out: bool = false) -> MatchTeam:
	var team := MatchTeam.new()
	team.team_name = team_name
	team.formation = p_formation
	team._build_lineup(all_players, user_player, user_start_chance, allow_left_out)
	return team

## Puesto en el que juega `p` (su código detallado desplegado; si no está
## desplegado, su posición de oficio).
func deployed_code(p: PlayerData) -> String:
	return String(deployed_position.get(p, p.detailed_position))

const _FALLBACK_SLOTS := ["LI", "DFC", "DFC", "LD", "MCD", "MC", "MC", "EI", "DC", "ED"]

func _build_lineup(all_players: Array[PlayerData], user_player: PlayerData, user_start_chance: float = 0.0, allow_left_out: bool = false) -> void:
	# Reglas duras aprendidas en FL (nunca romperlas):
	# 1) Un portero real + 10 de campo, nunca elegir solo por overall.
	# 2) El jugador del usuario SIEMPRE aparece (XI o banca), sin importar overall.
	# 3) Orden de posiciones en toda la UI: GK -> DF -> MF -> ST.
	var gks: Array[PlayerData] = all_players.filter(func(p): return p.position == "GK")
	var others: Array[PlayerData] = all_players.filter(func(p): return p.position != "GK")

	gks.sort_custom(func(a, b): return a.overall > b.overall)
	others.sort_custom(func(a, b): return a.overall > b.overall)

	starting_xi = []
	deployed_position = {}
	if gks.size() > 0:
		starting_xi.append(gks[0])
		deployed_position[gks[0]] = "POR"

	var slots: Array = _FALLBACK_SLOTS
	if formation != "" and Formations.FORMATIONS.has(formation):
		slots = Formations.slots_for(formation)

	# `pool` ya viene ordenado por overall desc → cada pasada toma el MEJOR
	# jugador disponible que encaje.
	var pool: Array = others.duplicate()

	# Pasada 1: posición PRINCIPAL exacta.
	var rem1: Array = _fill_slots(slots, pool, func(p, code): return p.detailed_position == code)
	# Pasada 2: SEGUNDA posición exacta (el DT lo alinea ahí a propósito).
	var rem2: Array = _fill_slots(rem1, pool, func(p, code): return String(p.secondary_detailed_position) == code)
	# Pasada 3: misma LÍNEA amplia — fuera de puesto por necesidad.
	var rem3: Array = _fill_slots(rem2, pool, func(p, code): return Positions.broad_of(p.detailed_position) == Positions.broad_of(code))
	# Pasada 4: el mejor que quede (línea entera corta / muchas lesiones).
	for code in rem3:
		if pool.is_empty():
			break
		var pick: PlayerData = pool.pop_front()
		starting_xi.append(pick)
		deployed_position[pick] = code

	starting_xi = starting_xi.slice(0, 11)

	# La banca SIEMPRE se puebla con los de campo que no entraron a la XI,
	# MÁS los arqueros suplentes (gks[1..]) — bug real encontrado probando
	# la lista de suplentes nueva de PreMatch (Parte 93f): un plantel real
	# siempre trae 2 arqueros (WorldFactory arma "GK","GK",...), pero acá
	# solo se usaba gks[0] — el segundo desaparecía sin ir ni a la XI ni
	# al banco, no existía para nada. La IA necesita banco para cambios.
	# CONVOCATORIA de partido (9-oct, Wilber: "en los partidos uno puede ser
	# titular, suplente o no convocado — mostrar solo titulares y
	# suplentes"): antes el banco era TODO el resto del plantel (~14). Ahora
	# 11 + MATCHDAY_BENCH: el mejor arquero suplente + los mejores de campo,
	# con un mínimo por línea si hay. El resto = no convocado (no aparece).
	bench = []
	var gk_pool: Array = gks.slice(1)
	gk_pool.sort_custom(func(a, b): return a.overall > b.overall)
	if not gk_pool.is_empty():
		bench.append(gk_pool[0])
	var field: Array = []
	for p in others:
		if not starting_xi.has(p) and p.position != "GK":
			field.append(p)
	field.sort_custom(func(a, b): return a.overall > b.overall)
	for line in ["DF", "MF", "ST"]:
		var got: int = 0
		for p in field:
			if got >= 2:
				break
			if p.position == line and not bench.has(p):
				bench.append(p)
				got += 1
	for p in field:
		if bench.size() >= MATCHDAY_BENCH:
			break
		if not bench.has(p):
			bench.append(p)

	if user_player != null and not starting_xi.has(user_player):
		if not bench.has(user_player) and allow_left_out:
			# Sin méritos para los 9 y el DT no confía en vos → NO CONVOCADO.
			# El banco real queda intacto; vos vas al final, oculto.
			user_not_called = true
			bench.append(user_player)
		elif not bench.has(user_player):
			# Si no, entrás a la convocatoria: se le hace lugar sacando
			# al de campo de menor media.
			if bench.size() >= MATCHDAY_BENCH:
				var weakest_i: int = -1
				for i in range(bench.size()):
					if bench[i].position == "GK":
						continue
					if weakest_i < 0 or bench[i].overall < bench[weakest_i].overall:
						weakest_i = i
				if weakest_i >= 0:
					bench.remove_at(weakest_i)
			bench.append(user_player)
		# Favor del entrenador (Fase 6): pese a no ser de los mejores, puede
		# empezar. La fórmula vive SOLO en CoachRelations.
		if not user_not_called and user_start_chance > 0.0 and randf() < user_start_chance:
			_promote_user_to_starting_xi(user_player)

	_sort_by_deployed(starting_xi)
	_sort_by_position(bench)

## Para cada código en `codes`, saca de `pool` (in-place) el primer jugador
## que cumpla `match_fn(player, code)` y lo alinea en ese puesto. Devuelve
## los códigos que quedaron SIN cubrir.
func _fill_slots(codes: Array, pool: Array, match_fn: Callable) -> Array:
	var unfilled: Array = []
	for code in codes:
		var pick: PlayerData = null
		for p in pool:
			if match_fn.call(p, code):
				pick = p
				break
		if pick != null:
			pool.erase(pick)
			starting_xi.append(pick)
			deployed_position[pick] = code
		else:
			unfilled.append(code)
	return unfilled

## Líneas amplias donde el DT puede alinear al usuario: su posición
## principal y, si la tiene, su SEGUNDA posición (pedido de Wilber).
func _user_lines(user_player: PlayerData) -> Array:
	var lines: Array = [user_player.position]
	var sec: String = String(user_player.secondary_detailed_position)
	if sec != "":
		var sb: String = Positions.broad_of(sec)
		if sb != "" and sb != user_player.position and not lines.has(sb):
			lines.append(sb)
	return lines

func _promote_user_to_starting_xi(user_player: PlayerData) -> void:
	# Saca de la XI al peor jugador de SU LÍNEA (principal o segunda
	# posición) y mete al usuario en su PUESTO. Nunca toca al portero si el
	# usuario no es portero, y viceversa.
	var candidates: Array[PlayerData]
	if user_player.position == "GK":
		candidates = starting_xi.filter(func(p): return p.position == "GK")
	else:
		var lines: Array = _user_lines(user_player)
		var outfield: Array[PlayerData] = starting_xi.filter(func(p): return p.position != "GK")
		var same_line: Array[PlayerData] = outfield.filter(func(p): return Positions.broad_of(deployed_code(p)) in lines)
		candidates = same_line if same_line.size() > 0 else outfield

	if candidates.is_empty():
		return # red de seguridad

	var weakest: PlayerData = candidates[0]
	for p in candidates:
		if p.overall < weakest.overall:
			weakest = p

	# El usuario hereda el PUESTO del que sale: si su 2ª posición encaja
	# ahí, se muestra esa; si no, igual juega ahí "por decisión del DT".
	var slot: String = deployed_code(weakest)
	var user_sec: String = String(user_player.secondary_detailed_position)
	if slot != user_player.detailed_position and user_sec != "" and Positions.broad_of(user_sec) == Positions.broad_of(slot):
		slot = user_sec

	starting_xi.erase(weakest)
	deployed_position.erase(weakest)
	if not bench.has(weakest):
		bench.append(weakest)
	bench.erase(user_player)
	starting_xi.append(user_player)
	deployed_position[user_player] = slot

func _detailed_order() -> Dictionary:
	var order := {}
	for i in range(Positions.DETAILED.size()):
		order[String(Positions.DETAILED[i]["code"])] = i
	return order

func _sort_by_deployed(list: Array[PlayerData]) -> void:
	var order := _detailed_order()
	list.sort_custom(func(a, b): return order.get(deployed_code(a), 99) < order.get(deployed_code(b), 99))

func _sort_by_position(list: Array[PlayerData]) -> void:
	var order := {"GK": 0, "DF": 1, "MF": 2, "ST": 3}
	list.sort_custom(func(a, b): return order.get(a.position, 9) < order.get(b.position, 9))
