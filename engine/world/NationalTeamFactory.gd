extends RefCounted
class_name NationalTeamFactory

## Fuerza de una SELECCIÓN NACIONAL — no existía nada de esto antes
## (WorldFactory solo calcula fuerza POR CLUB, nunca por país). Mismo
## principio "mundo vivo" que todo lo demás: función PURA de
## (world, strength_by_club, country), nunca persistido ni cacheado más
## allá de una temporada.
##
## Escala: 0-99, la MISMA que WorldFactory.squad_strength()/
## WorldTickEngine._strength_by_club — así se pasa tal cual a
## ContinentalEngine/CoefficientEngine (qualified_clubs, los 3 resolvers)
## sin inventar una escala paralela para selecciones.
##
## Fase 1: la fuerza AGREGADA de un país para partidos IA-vs-IA (todos los
## que el usuario no juega) — ver country_strength()/strength_by_country()
## abajo. Fase 2 (agregado 12-sep): el plantel jugable COMPLETO (23
## nombres, reales + relleno sintético) para EL partido del usuario — ver
## squad_for()/team_strength() al final del archivo. Nunca se llama para
## las 199 selecciones a la vez (sería carísimo materializar planteles
## reales de todos los clubes del mundo por cada país) — solo para las DOS
## que juega el usuario ese día.

## Piso determinista por confederación para países SIN liga modelada en
## este mundo y sin entrada en NATIONAL_BASE_REPUTATION — nunca "todos
## iguales" (sería raro que Nauru y Alemania empataran), pero acotado a un
## rango creíble por región.
const CONFEDERATION_FLOOR := {
	"UEFA": [42, 68], "CONMEBOL": [45, 70], "CONCACAF": [38, 60],
	"AFC": [35, 62], "CAF": [36, 62],
}

## Reputación base para selecciones CONOCIDAS que no tienen liga de club
## modelada en este mundo (las que sí tienen liga ya quedan cubiertas por
## LEAGUE_BLUEPRINTS — ver _league_reputation_for). Autorado a mano,
## valores de trabajo (no hay licencia de ranking FIFA real, mismo criterio
## que el resto del juego). Escala 0-99, igual que las ligas.
const NATIONAL_BASE_REPUTATION := {
	"Serbia": 68, "Gales": 58, "Bosnia y Herzegovina": 56, "Bulgaria": 50,
	"Eslovaquia": 52, "Eslovenia": 50, "Islandia": 54, "Finlandia": 48,
	"Israel": 54, "Irán": 66, "Irak": 54, "Catar": 56, "Jordania": 46,
	"Uzbekistán": 52, "Camerún": 62, "Costa de Marfil": 64, "Malí": 56,
	"Túnez": 60, "Argelia": 62, "República Democrática del Congo": 52,
	"Sudáfrica": 54, "Zambia": 46, "Burkina Faso": 50, "Guinea": 48,
	"Gabón": 46, "Mozambique": 42, "Angola": 46, "Cabo Verde": 50,
	"Venezuela": 52, "Bolivia": 48, "Perú": 60, "Canadá": 60,
	"Jamaica": 52, "Nueva Zelanda": 48, "Kazajistán": 44, "Georgia": 46,
	"Armenia": 42, "Montenegro": 46, "Macedonia del Norte": 44,
	"Albania": 48, "Luxemburgo": 38, "Irlanda del Norte": 50,
	"Panamá": 52, "Trinidad y Tobago": 46, "Haití": 44, "Guatemala": 44,
	"El Salvador": 42, "Cuba": 38, "Vietnam": 48, "Tailandia": 50,
	"Indonesia": 46, "Malasia": 42, "Siria": 46, "Líbano": 38,
	"Kuwait": 40, "Omán": 44, "Baréin": 40,
}

## Reputación de la liga tier-1 de `country` en LEAGUE_BLUEPRINTS, o -1 si
## ese país no tiene liga modelada en este juego. No necesita un `world`
## construido — lee la constante estática directamente (útil también antes
## de tener un mundo armado, p. ej. en herramientas de diagnóstico).
static func _league_reputation_for(country: String) -> int:
	for bp in WorldFactory.LEAGUE_BLUEPRINTS:
		if String(bp[2]) == country and int(bp[3]) == 1:
			return int(bp[5])
	return -1

## Reputación base de la SELECCIÓN de `country`, en la misma escala 0-99
## que las ligas: liga tier-1 modelada > tabla autorada > piso determinista
## por confederación. Nunca -1, nunca al azar (mismo país + mismo mundo =
## siempre el mismo número).
static func country_base_reputation(country: String) -> int:
	var league_rep: int = _league_reputation_for(country)
	if league_rep >= 0:
		return league_rep
	if NATIONAL_BASE_REPUTATION.has(country):
		return int(NATIONAL_BASE_REPUTATION[country])
	var confederation: String = Confederations.confederation_of(country)
	var bounds: Array = CONFEDERATION_FLOOR.get(confederation, [35, 60])
	var lo: int = int(bounds[0])
	var hi: int = int(bounds[1])
	var span: int = maxi(hi - lo, 1)
	return lo + int(absi(hash("nt_floor:" + country)) % (span + 1))

## Fuerza de la selección de `country` PARA ESTE MUNDO — si tiene liga
## tier-1 modelada, saca lo mejor de su club MÁS FUERTE (una selección
## convoca a las estrellas de su club grande, no el promedio de la liga);
## si no, cae a `country_base_reputation()`. `strength_by_club` es el
## mismo diccionario que ya arma WorldTickEngine.load_runtime()
## (club_id -> int 30-99) — se pasa por fuera para no depender del
## autoload desde el motor de mundo (regla: WorldFactory no conoce autoloads).
static func country_strength(world: Dictionary, strength_by_club: Dictionary, country: String) -> int:
	var league: LeagueData = WorldFactory.find_league_for_country(world, country)
	if league != null:
		var clubs: Array = world.get("clubs_by_league", {}).get(league.league_id, [])
		var best: int = -1
		for club in clubs:
			var s: int = int(strength_by_club.get(club.club_id, 0))
			if s > best:
				best = s
		if best >= 0:
			return clampi(best, 30, 99)
	return clampi(country_base_reputation(country), 30, 99)

## Fuerza de TODOS los países de una confederación, de una — para sembrar
## `ContinentalEngine`/`CoefficientEngine`/`QualifyingEngine` sin recalcular
## país por país. Se arma UNA VEZ por temporada (mismo momento que
## WorldTickEngine._strength_by_club), nunca a diario.
static func strength_by_country(world: Dictionary, strength_by_club: Dictionary, confederation: String = "") -> Dictionary:
	var out: Dictionary = {}
	for country in Confederations.COUNTRY_TO_CONFEDERATION:
		if confederation != "" and Confederations.confederation_of(country) != confederation:
			continue
		out[country] = country_strength(world, strength_by_club, country)
	return out

const SQUAD_SIZE := 23

## Plantel JUGABLE completo de la selección de `country` (Fase 2) — SOLO se
## llama para las dos selecciones del partido que el usuario va a jugar hoy,
## nunca para las 199. Junta jugadores REALES de todos los clubes del mundo
## con esa nacionalidad (la mayoría de los países tienen pocos o ninguno —
## ver WorldFactory._squad_country, generación de nacionalidad escasa) y
## completa a SQUAD_SIZE con relleno sintético (WorldFactory.
## synthetic_filler, mismo mecanismo que ya usan los clubes chicos). El
## usuario SIEMPRE aparece si su país es `country`, sin importar mérito —
## mismo invariante que MatchTeam._build_lineup ya garantiza para clubes.
static func squad_for(world: Dictionary, world_seed: int, season_start_epoch_day: int, country: String, user_player: PlayerData = null) -> Array[PlayerData]:
	var candidates: Array[PlayerData] = []
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in club_meta_by_id:
		var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(world, club_id, world_seed, season_start_epoch_day)
		for p in squad:
			if p.country == country:
				candidates.append(p)
	return _finish_squad(candidates, country, user_player)

## Plantel COMPLETO (23) para cada país de `countries`, en UN solo
## recorrido de todos los clubes del mundo (bucketing por país) en vez de
## uno por país — evita pagar O(países × clubes) al armar goleadores/
## asistentes de un torneo entero (Mundial de 48, copa continental — ver
## TopPerformersEngine.compute_national_tournament). Misma terminación
## (mérito + relleno sintético + garantía de arquero) que squad_for(),
## factorizada en _finish_squad() para no duplicar la fórmula.
static func squads_for_countries(world: Dictionary, world_seed: int, season_start_epoch_day: int, countries: Array, user_player: PlayerData = null) -> Dictionary:
	var wanted: Dictionary = {}
	for c in countries:
		wanted[String(c)] = true
	var candidates_by_country: Dictionary = {}
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in club_meta_by_id:
		var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(world, club_id, world_seed, season_start_epoch_day)
		for p in squad:
			if wanted.has(p.country):
				if not candidates_by_country.has(p.country):
					candidates_by_country[p.country] = []
				(candidates_by_country[p.country] as Array).append(p)

	var out: Dictionary = {}
	for country in wanted:
		out[country] = _finish_squad(candidates_by_country.get(country, []), country, user_player)
	return out

static func _finish_squad(candidates_in: Array, country: String, user_player: PlayerData) -> Array[PlayerData]:
	var candidates: Array[PlayerData] = []
	for p in candidates_in:
		candidates.append(p)

	var is_user_eligible: bool = user_player != null and user_player.country == country
	if is_user_eligible and not candidates.has(user_player):
		candidates.append(user_player)

	candidates.sort_custom(func(a, b): return a.overall > b.overall)
	# Pedido explícito de Wilber (auditoría de balance, ronda 6): la
	# convocatoria a selección tiene que ser por MÉRITO REAL — antes el
	# usuario entraba SIEMPRE a los 23 (sacando al peor por overall si
	# hacía falta), así que NationalCallUpEngine.rank_in_position() nunca
	# podía reflejar de verdad si el usuario compite o no con los 23
	# mejores reales del país. Sacado: si no entra por overall, no entra acá
	# — MatchTeam._build_lineup() (línea ~111) YA garantiza por su cuenta
	# que el usuario aparezca en el PARTIDO (banco como mínimo) cuando de
	# verdad lo convocan, así que esto no le rompe nada a un partido real;
	# solo deja de inflar el "pool" que decide si te convocan o no.
	var squad_out: Array[PlayerData] = candidates.slice(0, SQUAD_SIZE)

	var base_overall: int = country_base_reputation(country)
	var fill_i: int = 0
	while squad_out.size() < SQUAD_SIZE:
		squad_out.append(WorldFactory.synthetic_filler("nt:%s:%d" % [country, fill_i], Positions.BROAD_MF, base_overall, country))
		fill_i += 1
	var has_gk: bool = false
	for p in squad_out:
		if p.position == Positions.BROAD_GK:
			has_gk = true
			break
	if not has_gk:
		# Bug real encontrado en la auditoría: esto pisaba SIEMPRE el último
		# puesto del plantel — pero si el usuario había entrado ahí por la
		# garantía de arriba ("el usuario SIEMPRE está"), lo volvía a sacar
		# silenciosamente. MatchTeam._promote_user_to_starting_xi ya se
		# cuida de este mismo caso (nunca pisa el puesto del usuario); acá
		# no se cuidaba.
		var fill_idx: int = squad_out.size() - 1
		if is_user_eligible and squad_out[fill_idx] == user_player and fill_idx > 0:
			fill_idx -= 1
		squad_out[fill_idx] = WorldFactory.synthetic_filler("nt:%s:gk" % country, Positions.BROAD_GK, base_overall, country)

	return squad_out

## Fuerza del plantel completo de `squad` — delega a WorldFactory.
## squad_strength() (top-11 de overall), NUNCA una fórmula aparte (regla:
## balance centralizado, un solo lugar).
static func team_strength(squad: Array[PlayerData]) -> int:
	return WorldFactory.squad_strength(squad)
