extends RefCounted
class_name NationalCupEngine

## Copa continental de SELECCIONES (Fase 4) — Eurocopa/Copa América/Copa
## Oro/Copa Asiática/Copa Africana de Naciones, con nombres GENÉRICOS sin
## marca (CompetitionNames.national_continental, misma disciplina que el
## resto del juego). Decisión de diseño confirmada con Wilber: las 5 usan
## GRUPOS + eliminación directa — es lo que de verdad son HOY las 5 copas
## reales (a diferencia de las eliminatorias al Mundial, que sí varían de
## formato por confederación, ver QualifyingEngine.gd).
##
## Clasificación: se DERIVA de la tabla de eliminatorias al Mundial de esa
## confederación (QualifyingEngine.resolve) en vez de modelar una
## eliminatoria propia — simplificación consciente para no duplicar 5
## sistemas de clasificación completos.
##
## Reusa ContinentalEngine.build_groups()/group_standings() (hechos
## públicos en la Fase 1 justo para esto) para la fase de grupos, y
## SeasonCalendar.build_continental_bracket() + SeasonEngine.resolve_cup()
## para la eliminatoria — misma maquinaria que las copas de club, ninguna
## fórmula nueva.
##
## Cadencia cada 4 años, un BASE_YEAR distinto por confederación para que
## NO caigan las 5 el mismo año — y ninguno coincide con el resto de
## WorldCupEngine.WC_BASE_YEAR(2026) mod 4 (=2): las 5 bases de acá caen
## en los restos 0/1/3, nunca 2.
const BASE_YEAR := {
	"UEFA": 2024, "CONMEBOL": 2025, "CONCACAF": 2027, "AFC": 2024, "CAF": 2025,
}

## Campo de cada copa — múltiplo de 4 (grupos de 4 exactos, mismo límite
## que ContinentalEngine.build_groups). CONMEBOL solo tiene 10 países en
## este mundo (la CONMEBOL real): 8 es el múltiplo de 4 más grande que
## entra sin inventar invitados de otra confederación (la Copa América
## real completa a 16 con invitados — no modelado acá).
const FIELD_SIZE := {
	"UEFA": 24, "CONMEBOL": 8, "CONCACAF": 16, "AFC": 24, "CAF": 24,
}

const GROUP_START_OFFSET := 250
const KNOCKOUT_OFFSET := 272
const SPAN_TO_FINAL := 78

static func is_cup_year(confederation: String, year: int) -> bool:
	var base: int = int(BASE_YEAR.get(confederation, -9999))
	return base >= 0 and year >= base and (year - base) % 4 == 0

## Campo de la copa: los mejores países de la tabla de eliminatorias al
## Mundial de esa confederación (QualifyingEngine.resolve — direct +
## playoff_pool primero, eliminated de relleno si hiciera falta), cortado
## al múltiplo de 4 de FIELD_SIZE.
static func field(confederation: String, qualifying_resolved: Dictionary) -> Array:
	var pool: Array = []
	pool.append_array(qualifying_resolved.get("direct", []))
	pool.append_array(qualifying_resolved.get("playoff_pool", []))
	pool.append_array(qualifying_resolved.get("eliminated", []))
	var target: int = int(FIELD_SIZE.get(confederation, 16))
	var group_count: int = mini(pool.size(), target) / 4
	return pool.slice(0, group_count * 4)

## Torneo completo de `confederation` en `year`. {} si no es año de copa o
## el pool no da ni para 2 grupos. `current_epoch_day` gatea grupos →
## cuadro final (mundo vivo: nada existe antes de que su fecha llegue).
static func resolve(confederation: String, year: int, world_seed: int, strength_by_country: Dictionary, qualifying_resolved: Dictionary, season_start_day: int, current_epoch_day: int, overrides: Dictionary = {}) -> Dictionary:
	if not is_cup_year(confederation, year):
		return {}
	var f: Array = field(confederation, qualifying_resolved)
	var group_count: int = f.size() / 4
	if group_count < 1:
		return {}

	var cup_id: String = "natcup_%s_%d" % [confederation, year]
	var cup_name: String = CompetitionNames.national_continental(confederation)
	var group_start: int = season_start_day + GROUP_START_OFFSET
	var knockout_start: int = season_start_day + KNOCKOUT_OFFSET
	var groups: Array = ContinentalEngine.build_groups(f, group_count, world_seed, strength_by_country, current_epoch_day, group_start, overrides)

	var out := {
		"cup_id": cup_id, "cup_name": cup_name, "confederation": confederation,
		"groups": groups, "rounds": [], "champion_country": "",
		"group_start": group_start, "knockout_start": knockout_start,
	}

	if group_count < 2:
		return out # un solo grupo: no hay con qué armar cuadro final real
	var groups_done: bool = current_epoch_day >= knockout_start
	if not groups_done:
		return out

	var advancers: Array = []
	for g in groups:
		for row in (g["standings"] as Array).slice(0, 2):
			advancers.append(String(row["club_id"]))
	var bracket: Dictionary = SeasonCalendar.build_continental_bracket(advancers, cup_id, cup_name, knockout_start, SPAN_TO_FINAL)
	var resolved: Dictionary = SeasonEngine.resolve_cup(bracket, world_seed, strength_by_country, overrides, current_epoch_day)
	out["rounds"] = resolved.get("rounds", [])
	for rnd in out["rounds"]:
		if String(rnd.get("round_name", "")) == "Final" and rnd.get("decided", false):
			for m in rnd.get("matches", []):
				out["champion_country"] = String(m.get("winner_club_id", ""))
	return out

## Próximo partido de `country` en el torneo (grupo o cuadro) que caiga
## HOY, o {} — mismo contrato que WorldCupEngine.next_user_fixture. `key`
## en el resultado es la clave para grabar el resultado real como
## override (ver nota de QualifyingEngine.user_fixture_today) si se
## juega de verdad.
static func next_user_fixture(tournament: Dictionary, country: String, current_epoch_day: int, results: Dictionary) -> Dictionary:
	if tournament.is_empty() or country == "":
		return {}
	for g in tournament.get("groups", []):
		var group_index: int = int(g.get("group_index", -1))
		var in_group: bool = false
		for r in g.get("standings", []):
			if String(r["club_id"]) == country:
				in_group = true
		if not in_group:
			continue
		for fx in g.get("fixtures", []):
			if String(fx["home_club_id"]) != country and String(fx["away_club_id"]) != country:
				continue
			if int(fx.get("epoch_day", -1)) != current_epoch_day:
				continue
			var key: String = ContinentalEngine.group_fixture_key(group_index, int(fx["matchday"]), String(fx["home_club_id"]), String(fx["away_club_id"]))
			if results.has(key):
				continue
			return {
				"competition": "national_cup", "phase": "group", "key": key,
				"round_name": "Fase de grupos", "epoch_day": int(fx["epoch_day"]),
				"home_country": String(fx["home_club_id"]), "away_country": String(fx["away_club_id"]),
				"is_knockout": false,
			}
	for rnd in tournament.get("rounds", []):
		if int(rnd.get("epoch_day", 0)) != current_epoch_day:
			continue
		for m in rnd.get("matches", []):
			if String(m.get("home_club_id", "")) != country and String(m.get("away_club_id", "")) != country:
				continue
			var key2: String = SeasonEngine.cup_result_key(int(rnd["round"]), String(m["home_club_id"]), String(m["away_club_id"]))
			if results.has(key2):
				continue
			return {
				"competition": "national_cup", "phase": "knockout", "key": key2,
				"round_name": String(rnd.get("round_name", "Eliminatoria")),
				"epoch_day": int(rnd["epoch_day"]),
				"home_country": String(m["home_club_id"]), "away_country": String(m["away_club_id"]),
				"is_knockout": true,
			}
	return {}
