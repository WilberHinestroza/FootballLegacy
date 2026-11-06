extends RefCounted
class_name NationalTeamMatchLauncher

## Arma los dos MatchTeam de UN partido de selección (eliminatoria al
## Mundial — Fase 2) y deja el partido montado en MatchState. Mismo
## criterio que MatchLauncher.prepare() (clubes): NO cambia de escena ni
## toca UI (Sprites/Tweens/sonido), solo prepara MatchState.
##
## Sin CoachData de selección (no hay "entrenador nacional" persistente —
## la convocatoria es por MÉRITO, no una relación, ver
## NationalCallUpEngine.gd): la formación de cada país es DETERMINISTA
## (hash del país ^ world_seed), nadie la "elige".
##
## `user_start_chance`: YA decidida por el llamador (WorldTickEngine, una
## vez por ventana FIFA vía NationalCallUpEngine.resolve — no se recalcula
## acá) — mismo rol que CoachRelations.start_chance en MatchLauncher, pero
## calculada por mérito de selección en vez de confianza de DT de club.
##
## `competition` ("qualifying"|"world_cup"|"national_cup"), `is_knockout`
## (extra tiempo + penales si empata, ver MatchEngine) y `result_key` (la
## clave para grabar el resultado real como override — ver
## WorldTickEngine.record_user_national_result) vienen del fixture que ya
## armó pending_user_national_fixture()/QualifyingEngine.user_fixture_today/
## WorldCupEngine.next_user_fixture/NationalCupEngine.next_user_fixture —
## este launcher solo arma los equipos y monta MatchState, igual que
## MatchLauncher.prepare() con los partidos de club.
##
## Devuelve {ok: bool}. ok=false si falta algún dato del fixture.
static func prepare(world: Dictionary, world_seed: int, season_start_epoch_day: int, player: PlayerData, user_country: String, opponent_country: String, is_home: bool, user_start_chance: float, return_scene: String, instant: bool, competition: String = "qualifying", is_knockout: bool = false, result_key: String = "") -> Dictionary:
	if player == null or user_country == "" or opponent_country == "":
		return {"ok": false}

	var user_squad: Array[PlayerData] = NationalTeamFactory.squad_for(world, world_seed, season_start_epoch_day, user_country, player)
	var opponent_squad: Array[PlayerData] = NationalTeamFactory.squad_for(world, world_seed, season_start_epoch_day, opponent_country, null)
	var user_formation: String = _formation_for(user_country, world_seed)
	var opponent_formation: String = _formation_for(opponent_country, world_seed)

	var home_team: MatchTeam
	var away_team: MatchTeam
	if is_home:
		home_team = MatchTeam.from_national_team(user_country, user_squad, player, user_start_chance, user_formation)
		away_team = MatchTeam.from_national_team(opponent_country, opponent_squad, null, 0.0, opponent_formation)
	else:
		home_team = MatchTeam.from_national_team(opponent_country, opponent_squad, null, 0.0, opponent_formation)
		away_team = MatchTeam.from_national_team(user_country, user_squad, player, user_start_chance, user_formation)

	MatchState.start_new_match(home_team, away_team, player, is_knockout, instant)
	MatchState.return_scene = return_scene
	MatchState.fixture = {
		"competition": competition, "result_key": result_key,
		"home_country": user_country if is_home else opponent_country,
		"away_country": opponent_country if is_home else user_country,
	}
	return {"ok": true}

static func _formation_for(country: String, world_seed: int) -> String:
	var keys: Array = Formations.FORMATIONS.keys()
	if keys.is_empty():
		return ""
	var idx: int = int(absi(hash("nt_formation:%s" % country) ^ world_seed)) % keys.size()
	return String(keys[idx])
