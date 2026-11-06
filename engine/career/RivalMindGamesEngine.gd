extends RefCounted
class_name RivalMindGamesEngine

## "Guerra psicológica": el DT rival suelta una frase antes del partido y
## una reacción después. DETERMINISTA (world_seed + día + clubes), no se
## persiste. Se muestra en la previa (PreMatch) y puede dejar titular.
##
## La frase depende de: estilo del DT rival, lo que está en juego (derbi,
## eliminatoria, final), y tu peso (reputación / apodo).

const _SOURCES := ["DEPORTE TOTAL", "GOLAZO TV", "ESTADIO 24", "LA JUGADA", "TRIBUNA", "FÚTBOL HOY"]

static func _rng(wte, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("mindgames|%s|%d" % [salt, wte.current_epoch_day]) ^ int(wte.world_seed)
	return r

static func _opp_coach(wte, fixture: Dictionary, user_club_id: String) -> CoachData:
	var opp_id: String = String(fixture.get("away_club_id", "")) if String(fixture.get("home_club_id", "")) == user_club_id else String(fixture.get("home_club_id", ""))
	return WorldFactory.find_coach(wte.world, opp_id)

## {coach_name, quote, stakes} o {} si no hay DT rival.
static func pre_match(wte, fixture: Dictionary, user_player: PlayerData) -> Dictionary:
	if wte == null or user_player == null or wte.world.is_empty():
		return {}
	var coach := _opp_coach(wte, fixture, user_player.club_id)
	if coach == null:
		return {}
	var rng := _rng(wte, "pre|" + user_player.club_id)
	var you: String = Nickname.press_name(user_player, int(wte.world_seed))
	var high_profile: bool = user_player.reputation >= 68 or Nickname.for_player(user_player, int(wte.world_seed)) != ""
	var derby: bool = bool(fixture.get("derby", false)) or bool(fixture.get("is_derby", false))
	var ko: bool = bool(fixture.get("is_knockout", false))
	var style: String = coach.play_style

	var pool: Array = []
	if derby:
		pool = [
			"Sabemos lo que significa este partido. Vamos a dejarnos el alma.",
			"En un derbi no hay favoritos. Se gana con actitud, no con nombres.",
			"Respeto a %s, pero la afición nos pide una cosa y se la vamos a dar." % you,
		]
	elif ko:
		pool = [
			"Es a partido único: el que se equivoque, afuera. No nos vamos a equivocar.",
			"Estas noches se juegan con la cabeza fría. La tenemos.",
			"Nadie regala nada en una eliminatoria. Vamos a competir hasta el final.",
		]
	elif high_profile:
		pool = [
			"%s es un jugadorazo, pero un equipo bien parado lo puede neutralizar." % you,
			"Le tenemos preparada una marca especial a %s. No va a estar cómodo." % you,
			"Se habla mucho de %s. Nosotros hablamos de lo colectivo." % you,
			"El que juega contra nosotros sabe que va a correr los 90 minutos, se llame como se llame.",
		]
	else:
		pool = [
			"Venimos a ganar. No especulamos con nada.",
			"Es un rival duro, pero si hacemos lo nuestro tenemos con qué.",
			"Preparamos bien la semana. El equipo está enchufado.",
		]
	match style:
		"Posesión":
			pool.append("Queremos la pelota. Si la tenemos nosotros, ellos no hacen daño.")
		"Contraataque":
			pool.append("Que se vengan. Nosotros los esperamos y les hacemos daño en tres pases.")
		"Presión alta":
			pool.append("No los vamos a dejar respirar. Presión desde el primer minuto.")
		"Directo":
			pool.append("Vamos a ir al frente sin vueltas. El que quiera bonito, que mire otro partido.")

	return {
		"coach_name": coach.coach_name,
		"quote": String(pool[rng.randi() % pool.size()]),
		"stakes": ("derbi" if derby else ("eliminatoria" if ko else "")),
	}

## Reacción tras el partido. {coach_name, quote, headline} o {}.
static func post_match(wte, fixture: Dictionary, result: Dictionary, user_player: PlayerData) -> Dictionary:
	if wte == null or user_player == null or wte.world.is_empty():
		return {}
	var coach := _opp_coach(wte, fixture, user_player.club_id)
	if coach == null:
		return {}
	var rng := _rng(wte, "post|" + user_player.club_id)
	var you: String = Nickname.press_name(user_player, int(wte.world_seed))
	var sc: Dictionary = result.get("score", {})
	var gh: int = int(sc.get("home", 0)); var ga: int = int(sc.get("away", 0))
	var user_home: bool = String(fixture.get("home_club_id", "")) == user_player.club_id
	var winner: String = String(result.get("shootout_winner", ""))
	var user_won: bool
	if winner != "":
		user_won = (winner == "home") == user_home
	else:
		user_won = (gh > ga) == user_home if gh != ga else false
	var drew: bool = gh == ga and winner == ""
	var user_goals: int = 0
	for ev in result.get("rating_events", []):
		if String(ev.get("type", "")) == "goal":
			user_goals += 1

	var pool: Array
	if user_won and user_goals >= 1:
		pool = [
			"%s marcó la diferencia. Poco más que decir." % you,
			"Nos ganó un jugador. Así de simple. A levantarse.",
			"Felicito al rival. %s hoy estuvo imparable." % you,
		]
	elif user_won:
		pool = [
			"El resultado es injusto, pero el fútbol es esto.",
			"Merecimos más. Nos vamos con bronca.",
			"Nos faltó el gol. El planteo fue el correcto.",
		]
	elif drew:
		pool = ["Un punto que sabe a poco.", "Reparto de puntos justo, quizá.", "Nos llevamos algo de un campo difícil."]
	else:
		pool = [
			"Dijimos que %s no iba a estar cómodo, y no lo estuvo." % you,
			"El plan salió perfecto. El equipo fue un bloque.",
			"Tres puntos importantísimos. El vestuario está eufórico.",
		]
	var quote: String = String(pool[rng.randi() % pool.size()])
	return {
		"coach_name": coach.coach_name,
		"quote": quote,
		"headline": {
			"headline": "%s, tras el partido: \"%s\"" % [coach.coach_name, quote.left(48)],
			"body": "El técnico rival valoró así el cruce con el equipo de %s." % you,
			"source": _SOURCES[rng.randi() % _SOURCES.size()],
			"sentiment": "NEUTRAL",
		},
	}
