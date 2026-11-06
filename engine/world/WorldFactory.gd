extends RefCounted
class_name WorldFactory

## Genera un mundo DETERMINISTA a partir de una semilla: las mismas ligas,
## los mismos clubes y (bajo demanda) las mismas plantillas en cada
## arranque. Así el save solo necesita guardar `world_seed`, no miles de
## objetos.
##
## Reglas:
##  - Usa SIEMPRE un RandomNumberGenerator LOCAL, nunca randi()/randf()
##    global: no debe perturbar la aleatoriedad del MatchEngine ni
##    depender del orden de llamadas de otras partes del juego.
##  - `potential >= overall` en cada PlayerData generado (invariante).
##  - Orden de plantilla GK -> DF -> MF -> ST.
##
## PLACEHOLDER: nombres y fuerzas son generados. Cuando exista el pipeline
## de importación real (ver README) esto se reemplaza, pero la interfaz
## pública (build / make_squad / find_league_for_country) se mantiene.

# Ligas del juego. Fila: [id, nombre, país, tier, nº equipos, reputación, playoffs].
# Formato: doble vuelta salvo Argentina (vuelta única). Copa doméstica: todas.
# El nº de equipos / reputación son valores de trabajo hasta que exista el
# import de JSON con datos reales (ligas, clubes, jugadores, entrenadores).
const LEAGUE_BLUEPRINTS := [
	[2, "LaLiga", "España", 1, 20, 95, false],
	[3, "Premier League", "Inglaterra", 1, 20, 96, false],
	[4, "Bundesliga", "Alemania", 1, 18, 90, false],
	[5, "Ligue 1", "Francia", 1, 18, 82, false],
	[6, "Serie A", "Italia", 1, 20, 89, false],
	[7, "Primeira Liga", "Portugal", 1, 18, 76, false],
	[8, "Eredivisie", "Países Bajos", 1, 18, 75, false],
	[9, "Brasileirão", "Brasil", 1, 20, 80, false],
	[10, "Liga Profesional", "Argentina", 1, 30, 74, true],
	[11, "Liga BetPlay", "Colombia", 1, 20, 62, true],
	[12, "Primera División", "Chile", 1, 16, 58, true],
	[13, "Primera División", "Uruguay", 1, 16, 58, true],
	[14, "Liga Pro", "Ecuador", 1, 16, 57, true],
	[15, "División Profesional", "Paraguay", 1, 12, 54, true],
	[16, "Liga MX", "México", 1, 18, 70, true],
	[17, "MLS", "Estados Unidos", 1, 30, 68, true],
	[18, "Saudi Pro League", "Arabia Saudita", 1, 18, 78, false],
	[19, "J1 League", "Japón", 1, 20, 68, false],
	[20, "Botola Pro", "Marruecos", 1, 16, 56, false],
	[21, "Liga Promerica", "Costa Rica", 1, 12, 52, true],
	[22, "Liga Nacional", "Honduras", 1, 10, 48, true],
	[23, "K League 1", "Corea del Sur", 1, 12, 64, true],
	[24, "Egyptian Premier League", "Egipto", 1, 18, 58, false],
	[25, "Jupiler Pro League", "Bélgica", 1, 16, 74, true],
	[26, "Süper Lig", "Turquía", 1, 20, 74, false],
	[27, "Scottish Premiership", "Escocia", 1, 12, 62, true],
	[28, "Isuzu UTE A-League", "Australia", 1, 12, 58, true],
	[29, "Admiral Bundesliga", "Austria", 1, 12, 64, true],
	[30, "Azerbaijan Premier League", "Azerbaiyán", 1, 10, 50, false],
	[31, "Chinese Super League", "China", 1, 16, 60, false],
	[32, "HNL", "Croacia", 1, 10, 62, false],
	[33, "Cyprus Liga", "Chipre", 1, 14, 56, true],
	[34, "Chance Liga", "República Checa", 1, 16, 60, true],
	[35, "3F Superliga", "Dinamarca", 1, 12, 62, true],
	[36, "Hellas Liga", "Grecia", 1, 14, 62, true],
	[37, "NB I", "Hungría", 1, 12, 52, false],
	[38, "Indian Super League", "India", 1, 14, 50, true],
	[39, "SSE Airtricity Premier Division", "Irlanda", 1, 10, 48, false],
	[40, "Eliteserien", "Noruega", 1, 16, 60, false],
	[41, "PKO BP Ekstraklasa", "Polonia", 1, 18, 60, false],
	[42, "SuperLiga", "Rumanía", 1, 16, 56, true],
	[43, "Allsvenskan", "Suecia", 1, 16, 60, false],
	[44, "Brack Super League", "Suiza", 1, 12, 66, true],
	[45, "Ukrainian Premier League", "Ucrania", 1, 16, 62, false],
	[46, "UAE Pro League", "Emiratos Árabes Unidos", 1, 14, 58, false],
	[60, "LaLiga Hypermotion", "España", 2, 22, 72, false],
	[61, "EFL Championship", "Inglaterra", 2, 24, 78, true],
	[62, "2. Bundesliga", "Alemania", 2, 18, 70, false],
	[63, "Ligue 2 BKT", "Francia", 2, 18, 64, false],
	[64, "Serie BKT", "Italia", 2, 20, 66, false],
	[67, "EFL League One", "Inglaterra", 3, 24, 62, true],
	[68, "EFL League Two", "Inglaterra", 4, 24, 54, true],
	[69, "NPFL", "Nigeria", 1, 20, 50, false],
	[70, "Ghana Premier League", "Ghana", 1, 18, 48, false],
	[71, "Senegalese Ligue 1", "Senegal", 1, 16, 50, false],
]

## Semilla centinela: un world_seed real (randi(), o absi(hash(...)) en
## migraciones) nunca da negativo, así que -1 es inconfundible con
## cualquier semilla procedural de verdad. Cuando el slot activo tiene
## este valor, build() sirve el mundo importado por el usuario (ver
## WorldImporter.gd) en vez de generar uno.
const IMPORTED_SEED := -1
const IMPORTED_WORLD_PATH := "user://imported_world.json"

static var _import_cache: Dictionary = {}
static var _import_cache_mtime: int = -1

const _CLUB_PREFIX := ["Deportivo", "Real", "Atlético", "Sporting", "Unión", "Club", "Racing", "Athletic"]
const _CLUB_ROOTS := [
	"Nalca", "Vforce", "Tampia", "Quiroga", "Brenta", "Solari", "Munták", "Cerdano",
	"Ilbao", "Ravena", "Toluma", "Pinares", "Aldera", "Sotomar", "Vendral", "Caxias",
	"Ortuño", "Belmar", "Rquena", "Tandil", "Osorno", "Palena", "Zubia", "Marfil",
	"Landio", "Vesper", "Korlan", "Amaru", "Brelno", "Tavora", "Nurek", "Salby",
	"Corvex", "Mirano", "Puyol", "Estar", "Ontal", "Vibora", "Halden", "Ceura",
	"Torlan", "Aegir", "Moksha", "Baruna", "Selvar", "Cintra", "Odemar", "Vallun",
]
const _CLUB_SUFFIX := ["FC", "CF", "SC", "United", "City", "", "", ""]

# Pares (primario, secundario) para ClubData.primary_color_hex/secondary_color_hex —
# dormidos desde el día 1, activados aquí para que el Hub tenga identidad
# de club real en la cabecera.
const _CLUB_PALETTES := [
	["#C8102E", "#FFFFFF"], ["#0057B8", "#FFD700"], ["#1B5E20", "#FFFFFF"],
	["#212121", "#FFD700"], ["#7B1FA2", "#FFFFFF"], ["#F57C00", "#212121"],
	["#01579B", "#FFFFFF"], ["#B71C1C", "#FFD54F"], ["#37474F", "#E0E0E0"],
	["#00695C", "#FFFFFF"], ["#4E342E", "#FFCA28"], ["#283593", "#FFFFFF"],
]

const _FIRST_NAMES := [
	"Mateo", "Luca", "Diego", "Iván", "Sergio", "Bruno", "Nico", "Andrés", "Tomás",
	"Pablo", "Marco", "Julián", "Emil", "Kofi", "Yuki", "Omar", "Samir", "Aris",
	"Dani", "Hugo", "Aleks", "Rui", "Facu", "Thiago", "Noah", "Elías", "Rafa", "Kai",
]
const _LAST_NAMES := [
	"Ferrán", "Costález", "Morández", "Vintar", "Okambe", "Lindqual", "Haasen", "Buronne",
	"Nakabe", "Adeyle", "Sorel", "Petrusk", "Kovásc", "Menshar", "Rossoni", "Silvén",
	"Duárez", "Nowalk", "Bjornsi", "Marchetel", "Quispar", "Oduyen", "Vargen", "Reuszen",
	"Cardés", "Nkanta", "Berlac", "Ferreux",
]

## Construye el esqueleto del mundo (ligas + clubes + metadatos). Las
## plantillas NO se materializan aquí; pídelas con make_squad() cuando
## haga falta un partido, para no crear miles de PlayerData en el arranque.
static func build(world_seed: int) -> Dictionary:
	if world_seed == IMPORTED_SEED:
		var imported := _load_imported_world()
		if not imported.is_empty():
			return imported
		# El archivo importado se borró o esta sesión aún no lo tiene: cae al
		# mundo procedural de siempre en vez de dejar la carrera sin mundo.
		world_seed = 20260904

	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	var leagues: Array[LeagueData] = []
	var clubs_by_league: Dictionary = {}
	var club_meta_by_id: Dictionary = {}
	var coach_by_club_id: Dictionary = {}
	var club_by_id: Dictionary = {} # índice O(1) para find_club() — ver ahí

	for bp in LEAGUE_BLUEPRINTS:
		var league := LeagueData.new()
		league.league_id = bp[0]
		league.league_name = bp[1]
		league.country = bp[2]
		league.tier = bp[3]
		league.team_count = bp[4]
		league.reputation = bp[5]
		league.has_playoffs = bp[6]
		league.format = LeagueData.FORMAT_SINGLE_RR if bp[2] == "Argentina" else LeagueData.FORMAT_DOUBLE_RR
		league.has_domestic_cup = true
		leagues.append(league)

		var league_base: float = 40.0 + league.reputation * 0.35
		var league_clubs: Array[ClubData] = []
		for t in range(league.team_count):
			var club_seed: int = rng.randi()
			var crng := _seeded_rng(club_seed)

			var club := ClubData.new()
			club.club_id = "c_%d_%d" % [league.league_id, t]
			club.league_id = league.league_id
			club.club_name = _make_club_name(crng)
			club.short_name = _short_name_of(club.club_name)

			var strength_roll: float = crng.randf_range(-8.0, 8.0)
			var base_overall: int = int(round(clampf(league_base + strength_roll, 35.0, 90.0)))
			club.league_ambition = clampi(base_overall + 5, 30, 99)
			club.cup_ambition = clampi(base_overall, 20, 99)
			var palette: Array = _CLUB_PALETTES[crng.randi() % _CLUB_PALETTES.size()]
			club.primary_color_hex = palette[0]
			club.secondary_color_hex = palette[1]

			league_clubs.append(club)
			club_by_id[club.club_id] = club
			club_meta_by_id[club.club_id] = {
				"club_seed": club_seed,
				"league_id": league.league_id,
				"base_overall": base_overall,
				"name": club.club_name,
				"country": league.country,
			}
			coach_by_club_id[club.club_id] = _make_coach(club, club_seed)
		clubs_by_league[league.league_id] = league_clubs

	return {
		"seed": world_seed,
		"leagues": leagues,
		"clubs_by_league": clubs_by_league,
		"club_meta_by_id": club_meta_by_id,
		"coach_by_club_id": coach_by_club_id,
		"club_by_id": club_by_id,
		"league_by_country": _index_leagues_by_country(leagues),
		"league_by_id": _index_leagues_by_id(leagues),
	}

static func has_imported_world() -> bool:
	return FileAccess.file_exists(IMPORTED_WORLD_PATH)

## Se llama después de guardar un archivo importado nuevo, para que la
## próxima build() lo lea de disco en vez de servir la versión vieja
## cacheada en memoria.
static func clear_imported_world_cache() -> void:
	_import_cache = {}
	_import_cache_mtime = -1

## Cachea el mundo importado en memoria (WorldFactory.build() se llama muy
## seguido — cada slot del MainMenu, cada pantalla de WorldExplorer — y un
## JSON de miles de jugadores no se debería re-parsear en cada llamada).
## Invalida sola si el archivo cambió de fecha de modificación (reimport).
static func _load_imported_world() -> Dictionary:
	if not FileAccess.file_exists(IMPORTED_WORLD_PATH):
		return {}
	var mtime: int = FileAccess.get_modified_time(IMPORTED_WORLD_PATH)
	if not _import_cache.is_empty() and mtime == _import_cache_mtime:
		return _import_cache
	var file := FileAccess.open(IMPORTED_WORLD_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var raw: Variant = JSON.parse_string(text)
	if not (raw is Dictionary):
		return {}
	var world := WorldImporter.build_world(raw)
	_import_cache = world
	_import_cache_mtime = mtime
	return world

## Nombre de persona determinista para relleno (DTs sin dato real en una
## importación, jugadores de más para completar una plantilla incompleta,
## etc.) — mismo generador que usa el mundo procedural, expuesto para que
## WorldImporter no duplique las listas de nombres.
static func synthetic_person_name(seed_value: int) -> String:
	return _make_person_name(_seeded_rng(seed_value))

## Repara el mojibake más común en JSONs scrapeados/exportados desde otra
## herramienta: un "á" (UTF-8 correcto = bytes C3 A1) que en algún punto de
## la fuente se decodificó byte a byte como Latin-1/CP1252 en vez de UTF-8,
## dejando 2 caracteres visibles ("Ã¡") en vez de 1 ("á"). Tabla acotada a
## los pares más comunes en nombres reales de clubes/jugadores/estadios
## (español/portugués/francés/italiano) — pedido de Wilber tras encontrar
## "MÂS Monumental" en vez de "Más Monumental" en su fuente real: "prcheemos
## esas letras raras a futuro, pueden haber nombres de futbolistas o
## equipos raros". Expuesto acá (no en WorldImporter.gd) porque tanto
## clubes/DTs (WorldImporter) como jugadores (`_player_from_import` abajo)
## necesitan la misma reparación.
const _MOJIBAKE_FIXES := {
	"Ã¡": "á", "Ã©": "é", "Ã­": "í", "Ã³": "ó", "Ãº": "ú", "Ã±": "ñ", "Ã¼": "ü",
	"Ã ": "à", "Ã¨": "è", "Ã¬": "ì", "Ã²": "ò", "Ã¹": "ù",
	"Ã¢": "â", "Ãª": "ê", "Ã®": "î", "Ã´": "ô", "Ã»": "û",
	"Ã£": "ã", "Ãµ": "õ", "Ã§": "ç",
}

static func repair_imported_text(s: String) -> String:
	var out := s
	for bad: String in _MOJIBAKE_FIXES:
		if out.find(bad) != -1:
			out = out.replace(bad, _MOJIBAKE_FIXES[bad])
	return out

## true si, después de `repair_imported_text()`, el texto TODAVÍA trae
## señales de corrupción que no encajan en ningún par conocido (como la
## "Â" suelta de "MÂS Monumental" — no hay forma segura de adivinar qué
## letra iba ahí, así que se avisa en vez de forzar un reemplazo). Se usa
## en la pantalla de importar para no dejar pasar esto en silencio.
static func looks_corrupted(s: String) -> bool:
	if s.find("�") != -1:
		return true
	# "Â"/"Ã" sueltas son letras de verdad (Ângelo, El Âdfaoui, MÂS
	# Monumental): se aceptan. Solo es mojibake si van pegadas a un símbolo
	# del rango U+0080–U+00BF (Ã©, Ã±, Â°, Â´...), que ningún nombre real usa.
	for i in range(s.length() - 1):
		var c: String = s[i]
		if c == "Ã" or c == "Â":
			var nxt: int = s.unicode_at(i + 1)
			if nxt >= 0x80 and nxt <= 0xBF:
				return true
	return false

## Entrenador determinista de un club (generado a partir de su semilla, no
## se persiste). Nunca null para un club_id existente en el mundo.
static func _make_coach(club: ClubData, club_seed: int) -> CoachData:
	var rng := _seeded_rng(club_seed ^ 0x1234ABCD)
	var coach := CoachData.new()
	coach.coach_id = "coach_%s" % club.club_id
	coach.club_id = club.club_id
	coach.coach_name = _make_person_name(rng)
	coach.style = CoachData.STYLES[rng.randi() % CoachData.STYLES.size()]
	coach.demanding = rng.randi_range(35, 75)
	# IA propia del DT: formación + filosofía + estilo de juego, deterministas.
	coach.formation = Formations.formation_for(coach, club, club_seed)
	coach.philosophy = Formations.philosophy_for(coach, coach.formation)
	coach.play_style = Formations.play_style_for(coach, club, club_seed)
	return coach

## Entrenador de un club, o null si el club no existe en este mundo.
static func find_coach(world: Dictionary, club_id: String) -> CoachData:
	return world.get("coach_by_club_id", {}).get(club_id, null)

## Plantilla determinista de un club a partir de su metadato
## (el dict guardado en world["club_meta_by_id"][club_id]).
static func make_squad(club_meta: Dictionary, size: int = 22) -> Array[PlayerData]:
	if club_meta.has("imported_players"):
		return _make_squad_from_import(club_meta["imported_players"] as Array, int(club_meta.get("base_overall", 55)))

	var rng := _seeded_rng(int(club_meta.get("club_seed", 0)) ^ 0x9E3779B9)
	var base: int = int(club_meta.get("base_overall", 55))
	var home_country: String = String(club_meta.get("country", ""))

	var slots := ["GK", "GK", "DF", "DF", "DF", "DF", "DF", "DF",
		"MF", "MF", "MF", "MF", "MF", "MF", "ST", "ST", "ST", "ST"]
	var fillers := ["DF", "MF", "ST"]
	while slots.size() < size:
		slots.append(fillers[rng.randi() % fillers.size()])

	# rng aparte para la 2ª posición: no perturba la secuencia principal
	# (nombres/stats/fichajes por índice quedan estables).
	var srng := _seeded_rng(int(club_meta.get("club_seed", 0)) ^ 0x51ED270B)

	var squad: Array[PlayerData] = []
	for i in range(size):
		var p := PlayerData.new()
		# Puesto DETALLADO de plantilla — así cada club tiene laterales de
		# los dos lados, pivotes, extremos, etc. (antes era al azar dentro
		# de la línea → salían plantillas sin LI, con 3 ED...). Pedido de
		# Wilber. El _detailed_for(rng,...) se sigue llamando para NO correr
		# la secuencia RNG (mismo mundo determinista).
		var rolled: String = _detailed_for(rng, slots[i])
		var dcode: String = String(_DETAILED_TEMPLATE[i]) if i < _DETAILED_TEMPLATE.size() else rolled
		p.detailed_position = dcode
		p.position = Positions.broad_of(dcode)
		p.secondary_detailed_position = _secondary_for(srng, dcode)
		p.player_name = _make_person_name(rng)
		var starter_bonus: int = 4 if i < 11 else -6
		var ov: int = clampi(base + starter_bonus + rng.randi_range(-6, 6), 30, 95)
		p.overall = ov
		p.potential = clampi(ov + rng.randi_range(0, 12), ov, 99)
		p.age = rng.randi_range(17, 34)
		p.country = _squad_country(rng, home_country)
		p.speed = _spread(rng, ov)
		p.stamina = _spread(rng, ov)
		p.strength = _spread(rng, ov)
		p.control = _spread(rng, ov)
		p.passing = _spread(rng, ov)
		p.shooting = _spread(rng, ov)
		p.dribbling = _spread(rng, ov)
		p.decision_making = _spread(rng, ov)
		p.composure = _spread(rng, ov)
		p.ensure_potential_floor()
		p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
		squad.append(p)
	return squad

## Plantel de un club YA CON los fichajes de la temporada aplicados — el
## "cambio de equipo real" pedido explícito: un jugador vendido sale de
## acá, uno comprado aparece. `origin_index` (guardado en cada fichaje de
## TransferMarketEngine) identifica al jugador dentro del plantel BASE
## (make_squad sin fichajes) de su club de origen — no hace falta darle
## una identidad propia persistida, alcanza con reconstruir su plantel de
## origen y tomar ese mismo índice, siempre determinista.
static func make_squad_with_transfers(world: Dictionary, club_id: String, world_seed: int, season_start_epoch_day: int, size: int = 22) -> Array[PlayerData]:
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	if not club_meta_by_id.has(club_id):
		return []
	var base_squad: Array[PlayerData] = make_squad(club_meta_by_id[club_id], size)
	var season_year: int = CalendarUtils.season_start_year(season_start_epoch_day)
	var academy: Array[PlayerData] = _academy_intake(club_meta_by_id[club_id], season_year, world_seed)
	var transfers: Array = TransferMarketEngine.season_transfers_cached(world, world_seed, season_start_epoch_day)
	if transfers.is_empty():
		base_squad.append_array(academy)
		return base_squad

	var outgoing_indices: Dictionary = {}
	var incoming: Array[PlayerData] = []
	for t in transfers:
		if String(t["origin_club_id"]) == club_id:
			outgoing_indices[int(t["origin_index"])] = true
		if String(t["destination_club_id"]) == club_id:
			var origin_meta: Dictionary = club_meta_by_id.get(String(t["origin_club_id"]), {})
			if origin_meta.is_empty():
				continue
			var origin_squad: Array[PlayerData] = make_squad(origin_meta, size)
			var idx: int = int(t["origin_index"])
			if idx < origin_squad.size():
				incoming.append(origin_squad[idx])

	var result: Array[PlayerData] = []
	for i in range(base_squad.size()):
		if not outgoing_indices.has(i):
			result.append(base_squad[i])
	result.append_array(incoming)
	# Cantera: cada club sube promesas propias. Se muestran las 3 camadas
	# vivas (la de esta temporada + las 2 anteriores) — así un canterano
	# "crece" 3 años a la vista (16→18, overall +3/año) y después gradúa.
	# Determinista por world_seed ^ club_seed ^ año — nada se persiste.
	result.append_array(academy)
	return result

## Promesas de cantera vivas de un club. `cohort_age` sube de 16 a 18 según
## de qué camada es cada uno; el overall arranca bajo y sube con la edad,
## el potencial se mantiene alto.
static func _academy_intake(club_meta: Dictionary, season_year: int, world_seed: int) -> Array[PlayerData]:
	if club_meta.has("imported_players"):
		return []  # un mundo importado trae sus propias plantillas
	var club_seed: int = int(club_meta.get("club_seed", 0))
	var base: int = int(club_meta.get("base_overall", 55))
	var out: Array[PlayerData] = []
	for cohort_year in range(season_year - 2, season_year + 1):
		var rng := _seeded_rng(club_seed ^ world_seed ^ 0x0CA47E20 ^ (cohort_year * 2654435761))
		var count: int = 1 + rng.randi() % 2  # 1-2 por camada
		var cohort_age: int = 16 + (season_year - cohort_year)  # 16, 17 o 18
		var years_grown: int = season_year - cohort_year
		for _n in range(count):
			var p := PlayerData.new()
			var broad: String = ["GK", "DF", "DF", "MF", "MF", "MF", "ST", "ST"][rng.randi() % 8]
			p.position = broad
			p.detailed_position = _detailed_for(rng, broad)
			p.player_name = _make_person_name(rng)
			p.age = cohort_age
			var start_ov: int = clampi(base - 18 + rng.randi_range(-3, 5), 38, 60)
			p.overall = clampi(start_ov + years_grown * 3, 38, 72)
			p.potential = clampi(p.overall + rng.randi_range(14, 32), p.overall + 8, 93)
			p.speed = _spread(rng, p.overall)
			p.stamina = _spread(rng, p.overall)
			p.strength = _spread(rng, p.overall)
			p.control = _spread(rng, p.overall)
			p.passing = _spread(rng, p.overall)
			p.shooting = _spread(rng, p.overall)
			p.dribbling = _spread(rng, p.overall)
			p.decision_making = _spread(rng, p.overall)
			p.composure = _spread(rng, p.overall)
			p.origin = "Cantera del club"
			p.country = _squad_country(rng, String(club_meta.get("country", "")))
			p.ensure_potential_floor()
			p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
			out.append(p)
	return out

## Plantilla de un club IMPORTADO: convierte los jugadores crudos del JSON
## (guardados tal cual en club_meta_by_id["imported_players"] por
## WorldImporter, sin materializar en el arranque — mismo criterio "bajo
## demanda" que la plantilla procedural) a PlayerData reales. Si al club le
## faltan jugadores para un XI válido (sin GK, o menos de 11), se completa
## con relleno sintético — un JSON de usuario incompleto no debe romper un
## partido.
static func _make_squad_from_import(raw_players: Array, base_overall: int) -> Array[PlayerData]:
	var squad: Array[PlayerData] = []
	for p_raw in raw_players:
		if p_raw is Dictionary:
			squad.append(_player_from_import(p_raw as Dictionary))
	_ensure_squad_minimum(squad, base_overall)
	squad.sort_custom(func(a, b): return _BROAD_ORDER.get(a.position, 9) < _BROAD_ORDER.get(b.position, 9))
	return squad

const _BROAD_ORDER := {"GK": 0, "DF": 1, "MF": 2, "ST": 3}

static func _player_from_import(p_raw: Dictionary) -> PlayerData:
	var p := PlayerData.new()
	p.player_name = repair_imported_text(("%s %s" % [String(p_raw.get("firstName", "")), String(p_raw.get("lastName", ""))]).strip_edges())
	if p.player_name == "":
		p.player_name = "Jugador"
	p.country = String(p_raw.get("nationality", ""))

	var detailed: String = String(p_raw.get("primaryPosition", "MC")).strip_edges().to_upper()
	if not Positions.is_valid_detailed(detailed):
		detailed = "MC"
	p.detailed_position = detailed
	p.position = Positions.broad_of(detailed)

	p.overall = clampi(int(p_raw.get("overall", 60)), 1, 99)
	p.potential = clampi(int(p_raw.get("potential", p.overall)), p.overall, 99)

	var current_year: int = Time.get_date_dict_from_system()["year"]
	var birth_year: int = int(p_raw.get("birthYear", 0))
	p.age = clampi(current_year - birth_year, 16, 42) if birth_year > 0 else 24

	# Sin sub-atributos en el JSON importado (solo overall/potential): se
	# reparten deterministamente igual que en la plantilla procedural
	# (_spread), sembrado por jugador para que reimportar el mismo archivo
	# dé siempre el mismo reparto.
	var seed_key: String = "%s|%s|%s" % [p.player_name, str(p_raw.get("clubId", 0)), str(p_raw.get("shirtNumber", 0))]
	var rng := _seeded_rng(absi(hash(seed_key)))
	p.speed = _spread(rng, p.overall)
	p.stamina = _spread(rng, p.overall)
	p.strength = _spread(rng, p.overall)
	p.control = _spread(rng, p.overall)
	p.passing = _spread(rng, p.overall)
	p.shooting = _spread(rng, p.overall)
	p.dribbling = _spread(rng, p.overall)
	p.decision_making = _spread(rng, p.overall)
	p.composure = _spread(rng, p.overall)

	# El JSON trae el valor en EUROS de verdad (Mbappé = 157000000); todo el
	# resto del juego maneja el dinero en MILES DE EURO (ver TransferMarket
	# Engine / CurrencyFormat). Sin esta división, un importado se mostraba
	# ×1000 (Mbappé = "€157.000M").
	p.market_value = maxi(int(round(float(p_raw.get("marketValueEur", 0)) / 1000.0)), 0)
	if p.market_value <= 0:
		p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
	# PlayerData.wage es sueldo de TEMPORADA en MILES DE EURO en todo el
	# resto del código (ver ContractEngine.weekly_income(), que divide por
	# 52). El JSON trae semanal en euros: se anualiza Y se pasa a miles acá.
	p.wage = maxi(int(round(float(p_raw.get("weeklyWage", 0)) * 52.0 / 1000.0)), 0)
	var contract_year: int = int(p_raw.get("contractYear", 0))
	p.contract_years_remaining = maxi(contract_year - current_year, 0) if contract_year > 0 else 1

	# Columna opcional "skin" (0-5): fija SOLO el tono de piel del avatar;
	# el resto de la cara sigue siendo determinista por nombre. Ver
	# Avatar.config_for_player.
	var skin: int = int(p_raw.get("skin", -1))
	if skin >= 0 and skin < Avatar.TINTS["base"]["palette"].size():
		p.avatar = {"skin": skin}

	# 2ª posición (el JSON no la trae): plausible según el puesto, con un
	# rng aparte para no correr la secuencia de _spread de arriba.
	var srng := _seeded_rng(absi(hash(seed_key + "|sec")))
	p.secondary_detailed_position = _secondary_for(srng, detailed)

	p.ensure_potential_floor()
	return p

static func _ensure_squad_minimum(squad: Array[PlayerData], base_overall: int) -> void:
	var has_gk: bool = false
	for p in squad:
		if p.position == Positions.BROAD_GK:
			has_gk = true
			break
	if not has_gk:
		squad.append(synthetic_filler("relleno:gk:%d" % squad.size(), Positions.BROAD_GK, base_overall))
	while squad.size() < 11:
		squad.append(synthetic_filler("relleno:%d" % squad.size(), Positions.BROAD_MF, base_overall))

## Público (antes `_synthetic_filler`) desde selecciones nacionales, Fase 2:
## `NationalTeamFactory.squad_for()` completa a 23 con esto para países sin
## suficientes jugadores reales generados (la mayoría de los 199, ver
## WorldFactory._squad_country) — misma fórmula, un solo lugar.
## `country` (opcional): cuando se pasa, el nombre sale de
## NationalNames.make_name() (nombres/apellidos reales y comunes de la
## región cultural de ESE país, pedido de Wilber: "investiga nombres y
## apellidos de esos países para que sea más realista" — antes salía
## siempre el mismo pool "internacional" genérico sin importar el país) y
## se deja escrito en `p.country` (antes NUNCA se seteaba en el relleno de
## selección — un jugador sintético de un país sin liga real quedaba con
## `country=""`, un bug real de datos encontrado al agregar esto). Sin
## `country` (relleno de plantel de CLUB, el uso de siempre) el
## comportamiento no cambia un pelo.
static func synthetic_filler(seed_key: String, broad: String, base_overall: int, country: String = "") -> PlayerData:
	var rng := _seeded_rng(absi(hash(seed_key)))
	var p := PlayerData.new()
	p.position = broad
	p.detailed_position = _detailed_for(rng, broad)
	if country != "":
		p.player_name = NationalNames.make_name(rng, country, _FIRST_NAMES, _LAST_NAMES)
		p.country = country
	else:
		p.player_name = _make_person_name(rng)
	p.overall = clampi(base_overall + rng.randi_range(-6, 6), 30, 90)
	p.potential = clampi(p.overall + rng.randi_range(0, 10), p.overall, 99)
	p.age = rng.randi_range(18, 32)
	p.speed = _spread(rng, p.overall)
	p.stamina = _spread(rng, p.overall)
	p.strength = _spread(rng, p.overall)
	p.control = _spread(rng, p.overall)
	p.passing = _spread(rng, p.overall)
	p.shooting = _spread(rng, p.overall)
	p.dribbling = _spread(rng, p.overall)
	p.decision_making = _spread(rng, p.overall)
	p.composure = _spread(rng, p.overall)
	p.ensure_potential_floor()
	return p

## Fuerza aproximada de un club (media de overall de sus 11 mejores).
## Útil para generar ofertas y, más adelante, simular partidos de IA.
static func squad_strength(squad: Array[PlayerData]) -> int:
	if squad.is_empty():
		return 50
	var sorted := squad.duplicate()
	sorted.sort_custom(func(a, b): return a.overall > b.overall)
	var top: Array = sorted.slice(0, mini(11, sorted.size()))
	var total: int = 0
	for p in top:
		total += p.overall
	return int(round(float(total) / top.size()))

## Busca un club por id en todo el mundo (o null). O(1) vía world["club_by_id"]
## (armado en build()/WorldImporter.build_world()) — antes era una doble
## búsqueda lineal sobre las ~928 selecciones de club de las 55 ligas,
## repetida en CADA fila de CADA tabla/lista que muestra un escudo (pulido
## de rendimiento pedido por Wilber, hallazgo de auditoría general).
## Si el mundo no trae el índice (alguna construcción manual más vieja
## que no pasó por acá), cae al escaneo de siempre — nunca rompe nada.
static func find_club(world: Dictionary, club_id: String) -> ClubData:
	var idx: Dictionary = world.get("club_by_id", {})
	if not idx.is_empty():
		return idx.get(club_id, null)
	for arr in world.get("clubs_by_league", {}).values():
		for club in arr:
			if club.club_id == club_id:
				return club
	return null

## Aplica overrides de liga (club_id -> league_id actual) sobre un `world`
## recien construido por build()/WorldImporter.build_world() -- Ascensos y
## Descensos NUNCA se persisten en el mundo en si (world es funcion pura de
## world_seed, se reconstruye entero en cada carga), asi que esto se
## re-corre siempre despues de build() Y tambien en caliente al cerrar una
## temporada (mismo mundo vivo). Compara contra el league_id ACTUAL del
## club (no contra un "from" guardado aparte), asi es idempotente: sirve
## igual para aplicar TODO el historial acumulado o solo las entradas
## nuevas de esta temporada, siempre da el mismo resultado.
static func apply_league_overrides(world: Dictionary, overrides: Dictionary) -> void:
	if overrides.is_empty():
		return
	var clubs_by_league: Dictionary = world.get("clubs_by_league", {})
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in overrides:
		var target_league_id: int = int(overrides[club_id])
		var club: ClubData = find_club(world, String(club_id))
		if club == null or club.league_id == target_league_id:
			continue
		var from_id: int = club.league_id
		var from_arr: Array = clubs_by_league.get(from_id, [])
		var idx: int = -1
		for i in range(from_arr.size()):
			if from_arr[i].club_id == club.club_id:
				idx = i
				break
		if idx == -1:
			continue  # defensivo: no deberia pasar si club_by_id esta sincronizado
		from_arr.remove_at(idx)
		clubs_by_league[from_id] = from_arr
		if not clubs_by_league.has(target_league_id):
			clubs_by_league[target_league_id] = []
		(clubs_by_league[target_league_id] as Array).append(club)
		club.league_id = target_league_id  # Resource por referencia: mismo objeto que club_by_id[club_id]
		if club_meta_by_id.has(String(club_id)):
			club_meta_by_id[String(club_id)]["league_id"] = target_league_id
	world["clubs_by_league"] = clubs_by_league
	world["club_meta_by_id"] = club_meta_by_id

## Indexa `leagues` por país (clave normalizada), quedándose con la de
## MENOR tier (la más alta) cuando un país tiene más de una — mismo
## criterio que la búsqueda lineal de siempre, armado una sola vez acá en
## vez de recalcularlo en cada find_league_for_country().
static func _index_leagues_by_country(leagues: Array) -> Dictionary:
	var out: Dictionary = {}
	for league in leagues:
		var key: String = String(league.country).strip_edges().to_lower()
		if not out.has(key) or league.tier < (out[key] as LeagueData).tier:
			out[key] = league
	return out

## Índice O(1) por league_id — mismo criterio que club_by_id/
## league_by_country (pulido de rendimiento, hallazgo de auditoría
## general: WorldTickEngine._find_league() escaneaba las ~55 ligas cada
## vez, llamada 10 veces distintas desde ese archivo).
static func _index_leagues_by_id(leagues: Array) -> Dictionary:
	var out: Dictionary = {}
	for league in leagues:
		out[int(league.league_id)] = league
	return out

## Devuelve la liga de MENOR tier (la más alta) de un país, o null si ese
## país no tiene ninguna liga en el juego. O(1) vía world["league_by_country"]
## cuando existe (ver find_club() por el mismo criterio de fallback).
static func find_league_for_country(world: Dictionary, country: String) -> LeagueData:
	var needle := country.strip_edges().to_lower()
	var idx: Dictionary = world.get("league_by_country", {})
	if not idx.is_empty():
		return idx.get(needle, null)
	var best: LeagueData = null
	for league in world.get("leagues", []):
		if league.country.to_lower() == needle and (best == null or league.tier < best.tier):
			best = league
	return best

# --- Helpers privados ---

## País de un jugador de plantilla: ~62% del país del club, el resto de un
## pool de países futboleros (determinista con el RNG local).
const _FOREIGN_POOL := [
	"Brasil", "Argentina", "Francia", "España", "Portugal", "Inglaterra",
	"Alemania", "Italia", "Países Bajos", "Colombia", "Uruguay", "Croacia",
	"Bélgica", "Senegal", "Nigeria", "México", "Japón", "Marruecos", "Serbia",
	"Ghana", "Chile", "Ucrania", "Polonia", "Dinamarca", "Suecia", "Noruega",
]
static func _squad_country(rng: RandomNumberGenerator, home_country: String) -> String:
	if home_country != "" and rng.randf() < 0.62:
		return home_country
	return _FOREIGN_POOL[rng.randi() % _FOREIGN_POOL.size()]

static func _seeded_rng(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng

static func _spread(rng: RandomNumberGenerator, ov: int) -> int:
	return clampi(ov + rng.randi_range(-10, 10), 20, 99)

static func _detailed_for(rng: RandomNumberGenerator, broad: String) -> String:
	var codes: Array = Positions.codes_for_broad(broad)
	if codes.is_empty():
		return Positions.default_detailed_for_broad(broad)
	return codes[rng.randi() % codes.size()]

## Composición DETALLADA de una plantilla base (22): 2 porteros, laterales
## de las dos bandas, centrales, pivotes, interiores, bandas, enganche,
## delanteros — más 4 de fondo de banquillo. Índices 0-21 encajan con
## `slots` (2 GK + 6 DF + 6 MF + 4 ST) salvo que ahora `p.position` sale
## de broad_of(código), así que el detalle manda.
const _DETAILED_TEMPLATE := [
	"POR", "POR",
	"LI", "LD", "DFC", "DFC", "DFC", "CAD",
	"MCD", "MC", "MC", "MI", "MD", "MCO",
	"DC", "DC", "SD", "SD",
	"DFC", "MC", "EI", "DC",
]

## 2ª posición plausible de un jugador según su puesto (o "" ~35%).
const _SECONDARY_OPTIONS := {
	"LI": ["LD", "CAI", "MI"], "LD": ["LI", "CAD", "MD"],
	"DFC": ["MCD", "LD", "LI"], "CAI": ["LI", "MI"], "CAD": ["LD", "MD"],
	"MCD": ["DFC", "MC"], "MC": ["MCD", "MCO", "MI"],
	"MI": ["EI", "MC"], "MD": ["ED", "MC"],
	"MCO": ["MP", "MC", "SD"], "MP": ["MCO", "SD"],
	"ED": ["MD", "EI", "SD"], "EI": ["MI", "ED", "SD"],
	"SD": ["DC", "MCO"], "DC": ["SD"],
}

static func _secondary_for(rng: RandomNumberGenerator, primary: String) -> String:
	var opts: Array = _SECONDARY_OPTIONS.get(primary, [])
	if opts.is_empty() or rng.randf() < 0.35:
		return ""
	return String(opts[rng.randi() % opts.size()])

static func _make_club_name(rng: RandomNumberGenerator) -> String:
	var pre: String = _CLUB_PREFIX[rng.randi() % _CLUB_PREFIX.size()]
	var root: String = _CLUB_ROOTS[rng.randi() % _CLUB_ROOTS.size()]
	var suf: String = _CLUB_SUFFIX[rng.randi() % _CLUB_SUFFIX.size()]
	return ("%s %s %s" % [pre, root, suf]).strip_edges()

static func _short_name_of(club_name: String) -> String:
	var letters := club_name.replace(" ", "")
	return letters.substr(0, 3).to_upper() if letters.length() >= 3 else letters.to_upper()

static func _make_person_name(rng: RandomNumberGenerator) -> String:
	var first: String = _FIRST_NAMES[rng.randi() % _FIRST_NAMES.size()]
	var last: String = _LAST_NAMES[rng.randi() % _LAST_NAMES.size()]
	return "%s %s" % [first, last]
