extends RefCounted
class_name MatchLauncher

## Arma los dos MatchTeam de un fixture del calendario y deja el partido
## montado en MatchState. Esta lógica vivía SOLO dentro de
## Hub._launch_fixture; se extrajo para que el Calendario ("Simular hasta
## esta fecha", que también resuelve tus partidos por el camino) no la
## duplique — regla de CLAUDE.md: nunca copiar una lógica central en otro
## archivo.
##
## NO cambia de escena ni toca UI (Sprites/Tweens/sonido): solo prepara
## MatchState. El que llama decide a dónde navegar y, si `instant`, corre
## el partido:
##     var prep := MatchLauncher.prepare(world, player, fixture, ret, true)
##     if prep.ok:
##         MatchState.match_result = await MatchState.engine.run_match()
##         get_tree().change_scene_to_file(".../MatchSummary.tscn")
##
## Devuelve {ok: bool, user_playing: bool}. ok=false si el fixture apunta a
## clubes que no están en el mundo.
static func prepare(world: Dictionary, player: PlayerData, fixture: Dictionary, return_scene: String, instant: bool) -> Dictionary:
	if player == null:
		return {"ok": false}
	var home_id: String = String(fixture.get("home_club_id", ""))
	var away_id: String = String(fixture.get("away_club_id", ""))
	var home_club: ClubData = WorldFactory.find_club(world, home_id)
	var away_club: ClubData = WorldFactory.find_club(world, away_id)
	var meta: Dictionary = world.get("club_meta_by_id", {})
	if home_club == null or away_club == null or not meta.has(home_id) or not meta.has(away_id):
		push_error("MatchLauncher: fixture con clubes desconocidos (%s vs %s)" % [home_id, away_id])
		return {"ok": false}

	var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var world_seed: int = WorldTickEngine.world_seed
	var home_squad := WorldFactory.make_squad_with_transfers(world, home_id, world_seed, season_start)
	var away_squad := WorldFactory.make_squad_with_transfers(world, away_id, world_seed, season_start)
	var user_is_home: bool = home_id == player.club_id

	# SANCIÓN: si te queda(n) partido(s) de suspensión, este lo ves desde la
	# tribuna — el equipo juega sin vos y no cuenta para tus estadísticas.
	var comp: String = String(fixture.get("competition", ""))
	var suspended: bool = comp != "friendly" and int(WorldTickEngine.season.get("suspended_matches", 0)) > 0
	# CANTERA (AcademyEngine): si no te convocaron, el primer equipo juega sin
	# ti; mismo camino que la sanción (lo ves desde fuera, sin estadísticas).
	var academy_out: bool = AcademyEngine.sits_out(player, fixture, WorldTickEngine.world_seed)
	MatchState.user_suspended = suspended or academy_out
	var user_for_match: PlayerData = null if (suspended or academy_out) else player

	var user_start_chance: float = CoachRelations.start_chance(player.coach_trust)
	if not suspended:
		# Favor del agente (AgentEngine.request_starting), un solo uso —
		# se consume acá mismo, que es donde de verdad se decide la XI.
		user_start_chance = AgentEngine.apply_lobby_boost(player, user_start_chance)
		# Promesa de titularidad al fichar (TransferOfferEngine.execute_pending),
		# varios partidos — mismo criterio, se consume acá.
		user_start_chance = TransferOfferEngine.apply_role_boost(player, user_start_chance)
	var home_coach: CoachData = WorldFactory.find_coach(world, home_id)
	var away_coach: CoachData = WorldFactory.find_coach(world, away_id)
	var home_form: String = home_coach.formation if home_coach != null else ""
	var away_form: String = away_coach.formation if away_coach != null else ""
	# NO CONVOCADO: nunca en amistosos; la regla vive en CoachRelations.
	var left_out_ok: bool = comp != "friendly" and CoachRelations.can_be_left_out(user_start_chance)
	var home_team := MatchTeam.from_club(home_club, home_squad, user_for_match if user_is_home else null, user_start_chance if user_is_home else 0.0, home_form, left_out_ok and user_is_home)
	var away_team := MatchTeam.from_club(away_club, away_squad, null if user_is_home else user_for_match, 0.0 if user_is_home else user_start_chance, away_form, left_out_ok and not user_is_home)
	var user_coach: CoachData = home_coach if user_is_home else away_coach
	if user_coach != null:
		(home_team if user_is_home else away_team).play_style = user_coach.play_style

	var is_knockout: bool = bool(fixture.get("is_knockout", false))
	MatchState.start_new_match(home_team, away_team, user_for_match, is_knockout, instant)
	MatchState.return_scene = return_scene
	# Árbitro con personalidad (10-oct): el del partido, por su nombre.
	var ref_prof: Dictionary = DecisionResolver.referee_profile(Venue.referee(fixture, world_seed))
	MatchState.engine.referee_card_mult = float(ref_prof["card_mult"])
	MatchState.engine.referee_var_mult = float(ref_prof["var_mult"])
	MatchState.engine.referee_foul_mult = float(ref_prof.get("foul_mult", 1.0))

	# Marcar el CLÁSICO en el fixture: sin esto, la guerra psicológica del
	# DT rival, la zona mixta y la prensa nunca lo tienen en cuenta.
	var rival_id: String = RivalryEngine.club_rival_for(world, player.club_id, world_seed)
	var fx_for_state: Dictionary = fixture.duplicate()
	if rival_id != "" and (rival_id == home_id or rival_id == away_id) and comp != "friendly":
		fx_for_state["derby"] = true
	MatchState.fixture = fx_for_state

	return {"ok": true, "user_playing": not suspended}
