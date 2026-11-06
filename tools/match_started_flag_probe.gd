extends Node

## Prueba dirigida: "me está sumando titularidades cuando solo he sido
## suplente" — MatchEngine._maybe_substitute_user() reemplaza el lugar
## del usuario en starting_xi cuando entra de cambio (para que la
## simulación lo trate como "en cancha"), así que después del partido
## starting_xi.has(user_player) ya no distingue titular de suplente que
## entró. Arreglado exponiendo "user_started" en el resultado de
## run_match() (MatchEngine._user_is_starter, fijado UNA vez al kickoff).
## Este probe arma un partido con el usuario GARANTIZADO en el banco
## (user_start_chance=0.0), lo fuerza a pedir entrar, corre el partido
## completo, y confirma:
##   1) starting_xi SÍ termina conteniendo al usuario (la mutación existe
##      de verdad — si esto fallara, el probe no estaría probando nada).
##   2) el resultado expuesto por el motor (`user_started`) es FALSE de
##      todos modos — la señal correcta para MatchSummary.gd.
##   godot --headless res://tools/MatchStartedFlagProbe.tscn

func _ready() -> void:
	seed(20260906) # RNG global determinista — mismo criterio que los sims de carrera

	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var league: LeagueData = world.get("leagues", [])[0]
	var clubs: Array = world.get("clubs_by_league", {}).get(league.league_id, [])
	var home_club: ClubData = clubs[0]
	var away_club: ClubData = clubs[1]
	var home_squad: Array[PlayerData] = WorldFactory.make_squad(world["club_meta_by_id"][home_club.club_id])
	var away_squad: Array[PlayerData] = WorldFactory.make_squad(world["club_meta_by_id"][away_club.club_id])

	var user := PlayerData.new()
	user.player_name = "Probe Suplente"
	user.position = "MF"
	user.detailed_position = "MC"
	user.overall = 40 # bajo a propósito: nunca entraría a la XI por mérito
	user.potential = 60
	user.club_id = home_club.club_id

	# user_start_chance = 0.0 -> MatchTeam._build_lineup() lo deja SIEMPRE
	# en el banco (ver la condición "if user_start_chance > 0.0 and...").
	var home_team := MatchTeam.from_club(home_club, home_squad, user, 0.0, "")
	var away_team := MatchTeam.from_club(away_club, away_squad, null, 0.0, "")

	var ok: bool = true
	if home_team.starting_xi.has(user):
		print("PROBE FAIL (precondición rota: el usuario ya arrancó titular, no sirve para probar el bug)")
		get_tree().quit(1)
		return
	if not home_team.bench.has(user):
		print("PROBE FAIL (precondición rota: el usuario ni siquiera quedó en el banco)")
		get_tree().quit(1)
		return
	print("precondición OK: usuario arranca en el BANCO (starting_xi no lo tiene, bench sí)")

	MatchState.start_new_match(home_team, away_team, user, false, true)
	MatchState.engine._user_wants_on = true # "pediste entrar" — el DT lo evalúa desde el min 58

	var result: Dictionary = await MatchState.engine.run_match()

	var mutated_into_starting_xi: bool = home_team.starting_xi.has(user)
	print("¿starting_xi lo tiene DESPUÉS del partido (la mutación de siempre)?: %s" % mutated_into_starting_xi)
	print("user_started (lo que ahora lee MatchSummary.gd): %s" % result.get("user_started", "FALTA LA CLAVE"))

	if not mutated_into_starting_xi:
		print("(el usuario no llegó a entrar de cambio en este partido puntual — no se puede confirmar el caso, pero tampoco hay falso positivo)")
	elif bool(result.get("user_started", true)) != false:
		print("FALLA: entró de cambio (mutó starting_xi) pero user_started sigue diciendo que fue titular")
		ok = false
	else:
		print("Confirmado: entró de cambio Y user_started dice false — el bug de 'titularidades de suplente' está arreglado.")

	# "user_played" (v28, cuenta season_matches_played): si mutó
	# starting_xi es porque entró de cambio y tuvo minutos -> debería
	# jugar como PARTIDO JUGADO aunque no haya sido titular.
	print("user_played (lo que ahora suma season_matches_played): %s" % result.get("user_played", "FALTA LA CLAVE"))
	if mutated_into_starting_xi and bool(result.get("user_played", false)) != true:
		print("FALLA: entró de cambio y tuvo minutos, pero user_played da false — no sumaría 'partidos jugados'")
		ok = false

	# --- Caso contrario: un titular DE VERDAD sigue contando bien
	# (regresión — este es justo el bug que se arregló en la Parte 91d) ---
	var user2 := PlayerData.new()
	user2.player_name = "Probe Titular"
	user2.position = "ST"
	user2.detailed_position = "DC"
	user2.overall = 60
	user2.potential = 70
	user2.club_id = home_club.club_id
	# user_start_chance=1.0 -> el usuario SIEMPRE es promovido a la XI
	# (MatchTeam._promote_user_to_starting_xi) — el jugador humano no
	# compite por mérito contra el plantel generado, entra por favor del
	# DT con esta probabilidad (ver CoachRelations.start_chance en el
	# camino real). Con 1.0 queda garantizado para este caso de prueba.
	var home_team2 := MatchTeam.from_club(home_club, home_squad, user2, 1.0, "")
	var away_team2 := MatchTeam.from_club(away_club, away_squad, null, 0.0, "")
	if not home_team2.starting_xi.has(user2):
		print("FALLA: con user_start_chance=1.0 debería haber entrado siempre a la XI")
		ok = false
	else:
		MatchState.start_new_match(home_team2, away_team2, user2, false, true)
		var result2: Dictionary = await MatchState.engine.run_match()
		print("titular real -> user_started: %s (esperado true)" % result2.get("user_started", "FALTA LA CLAVE"))
		if bool(result2.get("user_started", false)) != true:
			print("FALLA: un titular de verdad debería seguir contando (regresión de la Parte 91d)")
			ok = false
		if bool(result2.get("user_played", false)) != true:
			print("FALLA: un titular de verdad debería contar como user_played=true también")
			ok = false

	# --- Tercer caso: se quedó TODO el partido en el banco, sin entrar
	# nunca (nunca pidió entrar) — no jugó ningún minuto, no debería
	# sumar ni titularidad ni partido jugado. ---
	var user3 := PlayerData.new()
	user3.player_name = "Probe Nunca Entra"
	user3.position = "MF"
	user3.detailed_position = "MC"
	user3.overall = 40
	user3.potential = 60
	user3.club_id = home_club.club_id
	var home_team3 := MatchTeam.from_club(home_club, home_squad, user3, 0.0, "")
	var away_team3 := MatchTeam.from_club(away_club, away_squad, null, 0.0, "")
	MatchState.start_new_match(home_team3, away_team3, user3, false, true)
	# _user_wants_on se queda en false (default) -> el DT nunca lo mete.
	var result3: Dictionary = await MatchState.engine.run_match()
	print("nunca entró -> user_started: %s, user_played: %s (ambos esperados false)" % [result3.get("user_started", "?"), result3.get("user_played", "?")])
	if bool(result3.get("user_started", true)) != false or bool(result3.get("user_played", true)) != false:
		print("FALLA: se quedó todo el partido en el banco sin jugar ni un minuto, no debería contar como partido jugado")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
