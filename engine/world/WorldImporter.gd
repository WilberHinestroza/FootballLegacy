extends RefCounted
class_name WorldImporter

## Construye un `world` (misma forma que WorldFactory.build(): {seed,
## leagues, clubs_by_league, club_meta_by_id, coach_by_club_id}) a partir
## de un JSON externo que el USUARIO elige e importa desde la pantalla
## "Importar mundo" (scenes/ImportWorld/).
##
## La disciplina de "sin nombres reales sin licencia FIFPro" (ver
## CLAUDE.md) sigue aplicando a lo que el juego GENERA por su cuenta
## (WorldFactory), no a lo que el propio usuario decide traer en su
## archivo — la responsabilidad de esos nombres es suya, no del juego.
##
## Formato esperado:
## {
##   "leagues": [{id, name, country, tier, startMonth?}],
##   "clubs":   [{id, leagueId, name, shortName?, city?, primaryColor?,
##                secondaryColor?, prestige?, foundedYear?, stadiumName?,
##                stadiumCapacity?}],
##   "players": [{clubId, firstName, lastName, nationality?, birthYear?,
##                primaryPosition, overall, potential?, isAcademy?,
##                shirtNumber?, contractYear?, marketValueEur?,
##                weeklyWage?, secondaryPositions?}],
##   "coaches": [{clubId, firstName, lastName, philosophy?, personality?,
##                demandLevel?, ...}]   # opcional, no todos los clubes
##                                       # necesitan tener uno
## }

## Errores en español, listos para mostrar en la UI — vacío = válido. Se
## valida ANTES de tocar nada: un JSON a medias no debe dejar un mundo
## importado corrupto pisando al anterior.
static func validate(raw: Variant) -> Array:
	var errors: Array = []
	if not (raw is Dictionary):
		errors.append("El archivo no tiene la forma esperada (debe ser un objeto JSON).")
		return errors

	for key in ["leagues", "clubs", "players"]:
		if not raw.has(key):
			errors.append("Falta la clave \"%s\"." % key)
		elif not (raw[key] is Array):
			errors.append("\"%s\" debería ser una lista." % key)
		elif (raw[key] as Array).is_empty():
			errors.append("\"%s\" está vacía." % key)
	if not errors.is_empty():
		return errors

	var league_ids: Dictionary = {}
	for lg in raw["leagues"]:
		if not (lg is Dictionary) or not lg.has("id") or not lg.has("name") or not lg.has("country") or not lg.has("tier"):
			errors.append("Hay una liga sin id/name/country/tier.")
			return errors
		league_ids[int(lg["id"])] = true

	var club_ids: Dictionary = {}
	for c in raw["clubs"]:
		if not (c is Dictionary) or not c.has("id") or not c.has("leagueId") or not c.has("name"):
			errors.append("Hay un club sin id/leagueId/name.")
			return errors
		if not league_ids.has(int(c["leagueId"])):
			errors.append("El club \"%s\" apunta a una liga (id %s) que no existe." % [c.get("name", "?"), str(c["leagueId"])])
			return errors
		club_ids[int(c["id"])] = true

	for p in raw["players"]:
		if not (p is Dictionary) or not p.has("clubId") or not p.has("primaryPosition") or not p.has("overall"):
			errors.append("Hay un jugador sin clubId/primaryPosition/overall.")
			return errors
		if not club_ids.has(int(p["clubId"])):
			errors.append("Un jugador apunta a un club (id %s) que no existe." % str(p["clubId"]))
			return errors

	return errors

## Resumen rápido para mostrar antes/después de importar: {leagues, clubs,
## players, coaches} (conteos).
static func summarize(raw: Dictionary) -> Dictionary:
	return {
		"leagues": (raw.get("leagues", []) as Array).size(),
		"clubs": (raw.get("clubs", []) as Array).size(),
		"players": (raw.get("players", []) as Array).size(),
		"coaches": (raw.get("coaches", []) as Array).size(),
	}

const _SUSPICIOUS_MAX := 15

## Nombres (club/estadio/jugador/DT) que, DESPUÉS de la reparación
## automática de `WorldFactory.repair_imported_text()`, todavía traen
## señales de corrupción de codificación (mojibake que no encaja en ningún
## par conocido, como la "Â" de "MÂS Monumental" en el archivo real de
## Wilber). No se puede adivinar la letra correcta, así que se le avisa acá
## en vez de dejarlo pasar en silencio — "prcheemos esas letras raras a
## futuro, pueden haber nombres de futbolistas o equipos raros".
static func _check_suspicious(found: Array[String], label: String, text: String) -> void:
	if found.size() >= _SUSPICIOUS_MAX or text.is_empty():
		return
	var fixed := WorldFactory.repair_imported_text(text)
	if WorldFactory.looks_corrupted(fixed):
		found.append("%s: \"%s\"" % [label, fixed])

static func scan_suspicious_names(raw: Dictionary) -> Array[String]:
	var found: Array[String] = []

	for c in raw.get("clubs", []):
		if not (c is Dictionary) or found.size() >= _SUSPICIOUS_MAX:
			continue
		_check_suspicious(found, "Club", String(c.get("name", "")))
		_check_suspicious(found, "Estadio de %s" % String(c.get("name", "?")), String(c.get("stadiumName", "")))

	for p in raw.get("players", []):
		if found.size() >= _SUSPICIOUS_MAX:
			break
		if not (p is Dictionary):
			continue
		_check_suspicious(found, "Jugador", ("%s %s" % [String(p.get("firstName", "")), String(p.get("lastName", ""))]).strip_edges())

	for co in raw.get("coaches", []):
		if found.size() >= _SUSPICIOUS_MAX:
			break
		if not (co is Dictionary):
			continue
		_check_suspicious(found, "DT", ("%s %s" % [String(co.get("firstName", "")), String(co.get("lastName", ""))]).strip_edges())

	return found

## Clubes que aparecen MAS DE UNA VEZ en el JSON con el mismo nombre pero
## ids distintos -- normalmente el mismo club real duplicado por error en
## la fuente (ej. Leeds United en Premier League Y en EFL Championship a
## la vez, con dos ids). Esto no es una corrupción de texto (scan_
## suspicious_names ya cubre eso) sino un problema de datos DISTINTO: dos
## registros separados que representan el mismo club real, cada uno
## jugando su propia liga -- cualquier sistema que asuma "un club, una
## sola posición en la tabla" (ascensos/descensos, por ejemplo) los trata
## como dos clubes genuinamente distintos, lo cual puede leerse raro
## (aparecer "ascendido" y "descendido" el mismo año, por ejemplo).
## Encontrado investigando un reporte de simulación real de Wilber.
static func scan_duplicate_clubs(raw: Dictionary) -> Array[String]:
	var by_name: Dictionary = {}
	for c in raw.get("clubs", []):
		if not (c is Dictionary):
			continue
		var name: String = String(c.get("name", ""))
		if name == "":
			continue
		var entries: Array = by_name.get(name, [])
		entries.append(c)
		by_name[name] = entries

	var league_names: Dictionary = {}
	for lg in raw.get("leagues", []):
		if lg is Dictionary:
			league_names[int(lg.get("id", -1))] = String(lg.get("name", "?"))

	var found: Array[String] = []
	for name in by_name:
		var entries: Array = by_name[name]
		if entries.size() < 2 or found.size() >= _SUSPICIOUS_MAX:
			continue
		var league_labels: Array = []
		for e in entries:
			var lid: int = int((e as Dictionary).get("leagueId", -1))
			league_labels.append(String(league_names.get(lid, "liga %d" % lid)))
		found.append("%s: aparece %d veces (%s)" % [name, entries.size(), ", ".join(league_labels)])
	return found

## `raw` YA validado (llamar validate() antes). Arma el `world` completo.
## Las plantillas NO se materializan aquí (igual que WorldFactory.build()):
## cada club guarda sus jugadores CRUDOS del JSON en club_meta_by_id, y
## WorldFactory.make_squad() los convierte a PlayerData bajo demanda la
## primera vez que hacen falta — nunca miles de Resources en el arranque.
static func build_world(raw: Dictionary) -> Dictionary:
	var players_by_club: Dictionary = {}
	for p in raw.get("players", []):
		if not (p is Dictionary) or not p.has("clubId"):
			continue
		var cid: int = int(p["clubId"])
		if not players_by_club.has(cid):
			players_by_club[cid] = []
		(players_by_club[cid] as Array).append(p)

	var coaches_by_club: Dictionary = {}
	for co in raw.get("coaches", []):
		if co is Dictionary and co.has("clubId"):
			coaches_by_club[int(co["clubId"])] = co

	var clubs_by_json_league: Dictionary = {} # leagueId (int) -> Array[Dictionary crudo]
	for c in raw.get("clubs", []):
		if not (c is Dictionary) or not c.has("leagueId"):
			continue
		var lid: int = int(c["leagueId"])
		if not clubs_by_json_league.has(lid):
			clubs_by_json_league[lid] = []
		(clubs_by_json_league[lid] as Array).append(c)

	var leagues: Array[LeagueData] = []
	var clubs_by_league: Dictionary = {}
	var club_meta_by_id: Dictionary = {}
	var coach_by_club_id: Dictionary = {}
	var club_by_id: Dictionary = {} # mismo índice O(1) que WorldFactory.build()

	for lg_raw in raw.get("leagues", []):
		var league_id: int = int(lg_raw["id"])
		var json_clubs: Array = clubs_by_json_league.get(league_id, [])
		if json_clubs.is_empty():
			# El JSON puede declarar una liga sin haber cargado ni un club
			# para ella (cobertura parcial de la fuente de datos) — una
			# liga sin equipos no es jugable ni puede mandar a nadie a
			# torneos continentales, así que directamente no se crea: ni
			# aparece para elegir, ni hay que filtrarla después en cada
			# lugar que recorre el mundo.
			continue

		var league := LeagueData.new()
		league.league_id = league_id
		league.league_name = String(lg_raw["name"])
		league.country = String(lg_raw["country"])
		league.tier = int(lg_raw["tier"])
		league.team_count = json_clubs.size()
		league.format = LeagueData.FORMAT_DOUBLE_RR
		league.has_domestic_cup = true
		league.has_playoffs = false
		league.reputation = _league_reputation(json_clubs)
		leagues.append(league)

		var league_clubs: Array[ClubData] = []
		for c_raw in json_clubs:
			var json_id: int = int(c_raw["id"])
			var club_id: String = "imp_%d" % json_id
			var roster: Array = players_by_club.get(json_id, [])

			var club := ClubData.new()
			club.club_id = club_id
			club.club_name = WorldFactory.repair_imported_text(String(c_raw.get("name", "?")))
			club.short_name = WorldFactory.repair_imported_text(String(c_raw.get("shortName", _short_name_of(club.club_name))))
			club.league_id = league_id
			club.primary_color_hex = _valid_hex(c_raw.get("primaryColor", ""), "#1B5E20")
			club.secondary_color_hex = _valid_hex(c_raw.get("secondaryColor", ""), "#FFD54F")
			club.stadium_name = WorldFactory.repair_imported_text(String(c_raw.get("stadiumName", "")))
			var prestige: int = clampi(int(c_raw.get("prestige", 55)), 1, 99)
			club.league_ambition = clampi(prestige + 5, 30, 99)
			club.cup_ambition = clampi(prestige, 20, 99)
			league_clubs.append(club)
			club_by_id[club_id] = club

			club_meta_by_id[club_id] = {
				"league_id": league_id,
				"base_overall": _base_overall_for(roster, prestige, league.reputation),
				"name": club.club_name,
				"imported_players": roster,
			}
			coach_by_club_id[club_id] = _build_coach(club_id, coaches_by_club.get(json_id, null))

		clubs_by_league[league_id] = league_clubs

	return {
		"seed": WorldFactory.IMPORTED_SEED,
		"leagues": leagues,
		"clubs_by_league": clubs_by_league,
		"club_meta_by_id": club_meta_by_id,
		"coach_by_club_id": coach_by_club_id,
		"club_by_id": club_by_id,
		"league_by_country": WorldFactory._index_leagues_by_country(leagues),
		"league_by_id": WorldFactory._index_leagues_by_id(leagues),
	}

static func _league_reputation(json_clubs: Array) -> int:
	if json_clubs.is_empty():
		return 50
	var total: int = 0
	for c in json_clubs:
		total += clampi(int((c as Dictionary).get("prestige", 55)), 1, 99)
	return clampi(int(round(float(total) / json_clubs.size())), 1, 99)

## Tamaño de plantel "que realmente compite" (11 titulares + rotación
## habitual) para medir la fuerza de un club — promediar TODO el roster
## (incluye reservas/juveniles, hasta 39 jugadores en algunos JSON reales)
## hundía a los clubes grandes con plantillas profundas casi al nivel de
## uno chico con plantilla corta: Real Madrid (39 jugadores, estrellas de
## 85-91 mezcladas con juveniles de 60) terminaba con la MISMA fuerza que
## Real Sociedad (32 jugadores, techo real ~83) — bug real reportado
## ("los resultados no tienen lógica"), la Champions/liga jugaba a
## coinflip entre grandes y chicos.
const TOP_SQUAD_SIZE := 14

static func _avg_overall(roster: Array, fallback: int) -> int:
	if roster.is_empty():
		return fallback
	var overalls: Array = []
	for p in roster:
		overalls.append(int((p as Dictionary).get("overall", fallback)))
	overalls.sort()
	overalls.reverse()
	var top: Array = overalls.slice(0, mini(TOP_SQUAD_SIZE, overalls.size()))
	var total: int = 0
	for o in top:
		total += o
	return int(round(float(total) / top.size()))

## `_avg_overall()` (arriba) sale mucho más plano que el `prestige` real del
## club: en LaLiga el prestige va de 57 a 89 (32 puntos) pero el promedio de
## plantel solo de 74 a 85.6 (11.5 puntos), y ni siquiera queda ordenado
## igual (Rayo Vallecano por encima de Sevilla pese a menor prestige) — el
## prestige que trae el JSON casi no influía en NINGÚN resultado de IA
## (`base_overall` alimenta `_strength_by_club` en WorldTickEngine.gd, que
## es lo único que decide tablas/copas/todo — reportado por Wilber jugando:
## "el nivel de los clubes no es muy real"). Se corrige empujando el
## promedio hacia donde el prestige dice que debería estar RELATIVO al
## promedio de su propia liga, sin reemplazar el dato real de plantel (que
## sigue siendo la base — el roster real importa, solo se le da más peso al
## prestige del que tenía antes).
const _PRESTIGE_CORRECTION_WEIGHT := 0.35

static func _base_overall_for(roster: Array, prestige: int, league_avg_prestige: int) -> int:
	if roster.is_empty():
		return prestige
	var roster_avg: int = _avg_overall(roster, prestige)
	var prestige_gap: float = float(prestige - league_avg_prestige)
	var corrected: float = float(roster_avg) + prestige_gap * _PRESTIGE_CORRECTION_WEIGHT
	return clampi(int(round(corrected)), 30, 99)

static func _valid_hex(value: Variant, fallback: String) -> String:
	var s: String = String(value)
	if s.length() >= 4 and s.begins_with("#"):
		return s
	return fallback

static func _short_name_of(club_name: String) -> String:
	var letters := club_name.replace(" ", "")
	return letters.substr(0, 3).to_upper() if letters.length() >= 3 else letters.to_upper()

## DT real si el JSON trae uno para este club; si no, uno genérico
## determinista (el JSON solo trae DTs para una parte de los clubes —
## faltar uno es normal, no un error de importación).
static func _build_coach(club_id: String, coach_raw: Variant) -> CoachData:
	var coach := CoachData.new()
	coach.coach_id = "coach_%s" % club_id
	coach.club_id = club_id
	if coach_raw is Dictionary:
		var first: String = String(coach_raw.get("firstName", ""))
		var last: String = String(coach_raw.get("lastName", ""))
		coach.coach_name = WorldFactory.repair_imported_text(("%s %s" % [first, last]).strip_edges())
		coach.style = _style_from(String(coach_raw.get("philosophy", "")), String(coach_raw.get("personality", "")))
		coach.demanding = clampi(int(coach_raw.get("demandLevel", 50)), 0, 100)
	else:
		var seed_value: int = absi(hash(club_id))
		coach.coach_name = WorldFactory.synthetic_person_name(seed_value)
		coach.style = CoachData.STYLES[seed_value % CoachData.STYLES.size()]
		coach.demanding = 50
	if coach.coach_name == "":
		coach.coach_name = WorldFactory.synthetic_person_name(absi(hash(club_id)))
	var fseed: int = absi(hash(club_id))
	coach.formation = Formations.formation_for(coach, null, fseed)
	coach.philosophy = Formations.philosophy_for(coach, coach.formation)
	coach.play_style = Formations.play_style_for(coach, null, fseed)
	return coach

static func _style_from(philosophy: String, personality: String) -> String:
	var p: String = philosophy.to_upper()
	if p in ["POSESION", "OFENSIVO"]:
		return "Cercano"
	if p in ["PRAGMATICO", "DEFENSIVO"]:
		return "Pragmático"
	var q: String = personality.to_upper()
	if q in ["PERFECCIONISTA", "EXIGENTE"]:
		return "Exigente"
	if q == "DISCIPLINADO":
		return "Disciplinario"
	return "Paternal"
