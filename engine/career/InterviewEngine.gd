extends RefCounted
class_name InterviewEngine

## Zona mixta: entrevista de opción múltiple tras un partido DESTACADO
## (nunca tras cada partido menor — fatiga de repetir pantalla). Ahora
## PROCEDURAL de verdad: la pregunta sale de MUCHAS ramas según el contexto
## real (goles, asistencias, roja, racha, contrato por vencer, hito de
## carrera, capitanía, derbi, posición), cada respuesta tiene un TONO, y
## puede haber una REPREGUNTA encadenada según el tono elegido.
##
## Toda la matemática de efectos vive aquí (mismo principio que
## CoachRelations / PlayerDevelopment). Efectos de una respuesta:
##   reputation   → fama pública (0-100)
##   coach_trust  → relación con el DT (0-100)
##   traits       → rasgos de personalidad (dict, 0-100 c/u)
##   fan          → humor de la afición  season["fan_sentiment"]  (0-100, 55 def)
##   dressing     → clima de vestuario   season["dressing_room"]  (0-100, 60 def)
##   narrative    → etiqueta que tiñe la prensa próxima
##                  season["press_narrative"] ("en_racha"|"presion"|"polemica"|"lider"|"")

const SOURCES := ["DEPORTE TOTAL", "GOLAZO TV", "ESTADIO 24", "LA JUGADA", "TRIBUNA", "CANCHA+", "PITCH RADIO", "FÚTBOL HOY"]

const FAN_DEFAULT := 55
const DRESSING_DEFAULT := 60

## ¿Merece la pena ofrecer entrevista tras este partido?
static func is_standout(goals: int, rating: float, won: bool, goal_diff: int) -> bool:
	if goals >= 1:
		return true
	if rating >= 8.0:
		return true
	if not won and rating < 6.0:
		return true
	if goal_diff >= 3:
		return true
	return false

## Contexto base del resultado real (lo comparten MatchSummary y
## PostMatchInterview). `player`/`season` opcionales enriquecen la rama.
static func extract_context(fixture: Dictionary, result: Dictionary, player_club_id: String, player: PlayerData = null, season: Dictionary = {}) -> Dictionary:
	var goals: int = 0
	var assists: int = 0
	for ev in result.get("rating_events", []):
		match String(ev.get("type", "")):
			"goal": goals += 1
			"key_pass_success": assists += 1
	var rating: float = float(result.get("user_rating", 6.5))
	var sc: Dictionary = result.get("score", {})
	var gh: int = int(sc.get("home", 0))
	var ga: int = int(sc.get("away", 0))
	var user_is_home: bool = fixture.get("home_club_id", "") == player_club_id
	var winner_side: String = result.get("shootout_winner", "")

	var won: bool = false
	var drew: bool = gh == ga and winner_side == ""
	if winner_side != "":
		won = (winner_side == "home") == user_is_home
	elif gh != ga:
		won = (gh > ga) == user_is_home

	var ctx := {
		"goals": goals,
		"assists": assists,
		"rating": rating,
		"won": won,
		"drew": drew,
		"goal_diff": absi(gh - ga),
		"red_card": bool(result.get("user_red_carded", false)),
		"competition": String(fixture.get("competition", "league")),
		"is_knockout": bool(fixture.get("is_knockout", false)),
		"is_derby": bool(fixture.get("derby", false)) or bool(fixture.get("is_derby", false)),
		"comp_name": String(fixture.get("name", "")),
		"position": player.position if player != null else "ST",
	}
	if player != null:
		ctx["contract_expiring"] = player.contract_years_remaining <= 1
		ctx["career_goals"] = player.career_goals + goals
		# Hito redondo cruzado ESTE partido (50, 100, 150…).
		var milestone := 0
		for m in [25, 50, 100, 150, 200, 250, 300]:
			if player.career_goals < m and player.career_goals + goals >= m:
				milestone = m
		ctx["goal_milestone"] = milestone
		ctx["reputation"] = player.reputation
	if not season.is_empty():
		ctx["is_captain"] = bool(season.get("is_captain", false))
		ctx["fan_sentiment"] = int(season.get("fan_sentiment", FAN_DEFAULT))
		ctx["streak"] = String(season.get("form_streak", ""))  # "W3" / "L2" si lo setea WorldTick
	return ctx

## Pregunta de apertura. {"source", "question", "options": [ {label, text,
## reputation, coach_trust, traits, fan, dressing, narrative, tone} ]}
static func generate_question(context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var source: String = SOURCES[rng.randi() % SOURCES.size()]
	var goals: int = int(context.get("goals", 0))
	var assists: int = int(context.get("assists", 0))
	var rating: float = float(context.get("rating", 6.5))
	var won: bool = context.get("won", false)
	var drew: bool = context.get("drew", false)
	var pos: String = String(context.get("position", "ST"))
	var q: Dictionary = _pick_branch(context, goals, assists, rating, won, drew, pos)
	q["source"] = source
	return q

static func _pick_branch(c: Dictionary, goals: int, assists: int, rating: float, won: bool, drew: bool, pos: String) -> Dictionary:
	# --- Prioridad de ramas (de la más específica a la genérica) ---
	if bool(c.get("red_card", false)):
		return {"question": "Te fuiste expulsado. ¿Qué pasó ahí?", "options": [
			_o("Autocrítico", "Me equivoqué, no puedo dejar al equipo con uno menos. Pido disculpas.", {"rep": 4, "coach": 2, "dressing": 4, "traits": {"professionalism": 4}, "tone": "humilde"}),
			_o("Diplomático", "Fue una jugada dividida. Ya está, toca mirar adelante.", {"rep": 1, "coach": 0, "tone": "neutral"}),
			_o("Polémico", "El árbitro venía a por mí desde el minuto uno. Una vergüenza.", {"rep": -6, "coach": -3, "fan": 2, "traits": {"sportsmanship": -5}, "narrative": "polemica", "tone": "polemica"}),
			_o("Líder", "Asumo la responsabilidad. El grupo respondió con diez y eso me deja orgulloso.", {"rep": 5, "coach": 3, "dressing": 6, "traits": {"loyalty": 3, "determination": 3}, "narrative": "lider", "tone": "lider"}),
		]}
	if int(c.get("goal_milestone", 0)) > 0:
		var m: int = int(c["goal_milestone"])
		return {"question": "Gol número %d de tu carrera. ¿Qué significa para ti?" % m, "options": [
			_o("Humilde", "Son muchos compañeros los que están detrás de cada uno de esos goles.", {"rep": 7, "dressing": 4, "traits": {"loyalty": 4, "sportsmanship": 3}, "tone": "humilde"}),
			_o("Emotivo", "Pienso en mi familia y en todo el camino. Es un día para disfrutar.", {"rep": 6, "fan": 5, "traits": {"determination": 2}, "tone": "humilde"}),
			_o("Ambicioso", "Es un número bonito, pero quiero el doble. No me pienso parar.", {"rep": 4, "coach": 2, "traits": {"ambition": 5}, "narrative": "en_racha", "tone": "ambiciosa"}),
			_o("Récord", "Voy a por todos los récords que se puedan batir. Ese es mi objetivo.", {"rep": 2, "fan": 3, "traits": {"ambition": 6, "sportsmanship": -2}, "tone": "ambiciosa"}),
		]}
	if bool(c.get("contract_expiring", false)):
		return {"question": "Tu contrato termina pronto y hoy fuiste protagonista. ¿Seguirás en el club?", "options": [
			_o("Comprometido", "Estoy feliz acá. Ojalá se resuelva pronto, mi cabeza está en el equipo.", {"rep": 5, "coach": 6, "fan": 8, "dressing": 5, "traits": {"loyalty": 6}, "narrative": "lider", "tone": "lider"}),
			_o("Prudente", "De eso se encarga mi representante. Yo solo pienso en jugar.", {"rep": 2, "coach": 0, "tone": "neutral"}),
			_o("Ambiguo", "El fútbol da muchas vueltas. Nunca se sabe dónde estarás mañana.", {"rep": -2, "coach": -4, "fan": -8, "traits": {"ambition": 4, "loyalty": -4}, "narrative": "presion", "tone": "ambiciosa"}),
			_o("Provocador", "Si el club me quiere, ya sabe lo que tiene que hacer.", {"rep": -5, "coach": -6, "fan": -10, "dressing": -4, "traits": {"ambition": 6, "sportsmanship": -4}, "narrative": "polemica", "tone": "polemica"}),
		]}
	if goals >= 3:
		return {"question": "Hat-trick. ¿Cómo se vive una noche así?", "options": [
			_o("Humilde", "El equipo lo hizo posible. Esto es de todos.", {"rep": 8, "dressing": 5, "traits": {"loyalty": 4, "sportsmanship": 3}, "tone": "humilde"}),
			_o("En racha", "Sabía que iba a ser mi noche. Estoy en el mejor momento de mi carrera.", {"rep": 5, "coach": 2, "traits": {"ambition": 5}, "narrative": "en_racha", "tone": "ambiciosa"}),
			_o("Arrogante", "Era obvio. Ahora mismo no hay defensa que me pare.", {"rep": -5, "fan": 3, "dressing": -3, "traits": {"ambition": 6, "sportsmanship": -5}, "narrative": "polemica", "tone": "polemica"}),
			_o("Líder", "Que no se nos suba. El próximo objetivo es el título.", {"rep": 6, "coach": 4, "dressing": 4, "traits": {"ambition": 4, "determination": 3}, "narrative": "lider", "tone": "lider"}),
		]}
	if goals >= 1 and assists >= 1:
		return {"question": "Gol y asistencia. Partido redondo, ¿no?", "options": [
			_o("Humilde", "Lo importante es que el equipo sumó. Lo mío es una consecuencia.", {"rep": 5, "dressing": 4, "traits": {"loyalty": 3}, "tone": "humilde"}),
			_o("Completo", "Trabajo para ser un jugador total, no solo para marcar.", {"rep": 4, "coach": 3, "traits": {"professionalism": 4, "ambition": 2}, "tone": "neutral"}),
			_o("Ambicioso", "Está bien, pero quiero más. Puedo dar otro nivel.", {"rep": 3, "traits": {"ambition": 4}, "narrative": "en_racha", "tone": "ambiciosa"}),
			_o("Líder", "Cuando todos nos sumamos así, somos un equipo difícil de ganar.", {"rep": 6, "coach": 3, "dressing": 5, "traits": {"loyalty": 4}, "narrative": "lider", "tone": "lider"}),
		]}
	if pos in ["GK", "DF"] and won and c.get("goal_diff", 0) >= 1 and goals == 0 and int(c.get("goal_diff", 0)) >= 1:
		return {"question": "Otra actuación sólida atrás. ¿Cómo valoras el trabajo defensivo?", "options": [
			_o("Humilde", "La portería a cero es de los once. Todos corrieron para atrás.", {"rep": 5, "dressing": 5, "traits": {"loyalty": 4, "professionalism": 2}, "tone": "humilde"}),
			_o("Profesional", "Preparamos bien la semana y se notó. Es cuestión de detalles.", {"rep": 4, "coach": 4, "traits": {"professionalism": 5}, "tone": "neutral"}),
			_o("Ambicioso", "Quiero ser el mejor defensor de la liga, no me conformo.", {"rep": 3, "traits": {"ambition": 4, "determination": 2}, "tone": "ambiciosa"}),
			_o("Líder", "Atrás nos entendemos con los ojos cerrados. Ese es nuestro sello.", {"rep": 6, "coach": 3, "dressing": 4, "traits": {"loyalty": 3}, "narrative": "lider", "tone": "lider"}),
		]}
	if goals >= 1 and won:
		return {"question": "Gol y victoria. ¿Cómo valoras el partido?", "options": [
			_o("Humilde", "Contento por el resultado. Lo importante es el equipo.", {"rep": 5, "dressing": 3, "traits": {"loyalty": 3, "sportsmanship": 2}, "tone": "humilde"}),
			_o("Ambicioso", "Bien. Pero quiero más goles y más victorias.", {"rep": 3, "traits": {"ambition": 4}, "narrative": "en_racha", "tone": "ambiciosa"}),
			_o("Polémico", "Fue fácil contra este rival. Esperaba más de ellos.", {"rep": -5, "dressing": -2, "traits": {"sportsmanship": -5}, "narrative": "polemica", "tone": "polemica"}),
			_o("Líder", "Seguimos unidos. Este es nuestro camino.", {"rep": 7, "coach": 3, "dressing": 5, "traits": {"loyalty": 4, "determination": 2}, "narrative": "lider", "tone": "lider"}),
		]}
	if bool(c.get("is_derby", false)) and not won:
		return {"question": "Se perdió el derbi. ¿Qué le dices a la afición?", "options": [
			_o("Cercano", "Sé lo que significa para ellos. Pido perdón y prometo darlo todo.", {"rep": 4, "fan": 6, "dressing": 2, "traits": {"loyalty": 4}, "tone": "humilde"}),
			_o("Diplomático", "Duele, pero es un partido más. Hay que levantarse rápido.", {"rep": 1, "fan": -4, "tone": "neutral"}),
			_o("Autocrítico", "No competimos como este partido exige. Empezando por mí.", {"rep": 3, "coach": -3, "dressing": 3, "traits": {"determination": 4}, "narrative": "presion", "tone": "humilde"}),
			_o("Caliente", "Nos van a ver la cara en la vuelta. Esto no queda así.", {"rep": 0, "fan": 8, "dressing": 4, "traits": {"determination": 3, "sportsmanship": -3}, "narrative": "polemica", "tone": "polemica"}),
		]}
	if not won and rating < 6.0:
		return {"question": "Noche difícil. ¿Qué salió mal?", "options": [
			_o("Diplomático", "No estuvimos bien. Hay que analizar y corregir.", {"rep": 5, "coach": -3, "traits": {"professionalism": 3}, "tone": "neutral"}),
			_o("Polémico", "El arbitraje fue desastroso. Nos robaron el partido.", {"rep": -4, "coach": -2, "fan": 3, "traits": {"sportsmanship": -4}, "narrative": "polemica", "tone": "polemica"}),
			_o("Autocrítico", "Personalmente me siento mal. Quiero responder ya.", {"rep": 3, "coach": -3, "dressing": 3, "traits": {"determination": 4}, "narrative": "presion", "tone": "humilde"}),
			_o("Líder", "Esto nos hará más fuertes. El equipo sabe responder.", {"rep": 7, "coach": -1, "dressing": 5, "traits": {"loyalty": 2, "determination": 3}, "narrative": "lider", "tone": "lider"}),
		]}
	if drew:
		return {"question": "Empate hoy. ¿Sabe a poco o se rescató un punto?", "options": [
			_o("Positivo", "Sumar de a uno cuando no es tu día también vale.", {"rep": 3, "coach": 2, "traits": {"professionalism": 3}, "tone": "neutral"}),
			_o("Insatisfecho", "Veníamos a ganar. Dos puntos perdidos.", {"rep": 2, "coach": 0, "traits": {"ambition": 3, "determination": 2}, "tone": "ambiciosa"}),
			_o("Crítico", "Nos falta ambición para cerrar los partidos.", {"rep": -3, "coach": -3, "dressing": -3, "traits": {"sportsmanship": -2}, "narrative": "presion", "tone": "polemica"}),
			_o("Líder", "Hay que seguir. Estos puntos suman a final de temporada.", {"rep": 5, "dressing": 3, "traits": {"loyalty": 3}, "narrative": "lider", "tone": "lider"}),
		]}
	return {"question": "¿Cómo describes tu actuación hoy?", "options": [
		_o("Humilde", "Hay cosas que mejorar. Sigo trabajando.", {"rep": 4, "coach": 2, "traits": {"professionalism": 3}, "tone": "humilde"}),
		_o("Ambicioso", "Creo que pude hacer más. Exijo más de mí mismo.", {"rep": 3, "coach": 1, "traits": {"ambition": 3}, "tone": "ambiciosa"}),
		_o("Polémico", "El entrenador no me puso en mi mejor posición.", {"rep": -6, "coach": -4, "dressing": -3, "traits": {"sportsmanship": -3}, "narrative": "polemica", "tone": "polemica"}),
		_o("Líder", "El equipo necesitaba algo de mí y lo di.", {"rep": 5, "coach": 3, "dressing": 4, "traits": {"loyalty": 3, "determination": 2}, "narrative": "lider", "tone": "lider"}),
	]}

## Repregunta encadenada según el TONO de la respuesta elegida. {} = cierra.
static func followup(context: Dictionary, chosen: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var tone: String = String(chosen.get("tone", ""))
	# Solo repreguntan si hay "salsa": tono fuerte o contexto caliente.
	var spicy: bool = tone in ["polemica", "ambiciosa", "lider"] or bool(context.get("contract_expiring", false)) or bool(context.get("is_derby", false))
	if not spicy or rng.randf() > 0.72:
		return {}
	match tone:
		"polemica":
			return {"question": "Palabras fuertes. ¿No teme que le pasen factura?", "options": [
				_o("Se reafirma", "Digo lo que pienso. Si molesta, es su problema.", {"rep": -3, "fan": 4, "dressing": -4, "traits": {"sportsmanship": -4}, "narrative": "polemica", "tone": "polemica"}),
				_o("Matiza", "Fue en caliente. Con la cabeza fría se ven las cosas distinto.", {"rep": 4, "coach": 3, "dressing": 3, "traits": {"professionalism": 3}, "tone": "humilde"}),
				_o("Redirige", "Prefiero hablar de fútbol. El resto es ruido.", {"rep": 2, "coach": 1, "tone": "neutral"}),
			]}
		"ambiciosa":
			return {"question": "Habla de objetivos grandes. ¿El equipo está a esa altura?", "options": [
				_o("Confía", "Este grupo puede pelear cualquier cosa. Lo creo de verdad.", {"rep": 5, "coach": 3, "dressing": 6, "fan": 5, "traits": {"loyalty": 4}, "narrative": "lider", "tone": "lider"}),
				_o("Exige", "Si todos damos un paso más, sí. Yo el primero.", {"rep": 4, "coach": 2, "traits": {"determination": 4, "ambition": 2}, "tone": "ambiciosa"}),
				_o("Se distancia", "Yo pongo lo mío. Lo demás no depende de mí.", {"rep": -4, "dressing": -6, "traits": {"loyalty": -4}, "narrative": "presion", "tone": "polemica"}),
			]}
		"lider":
			return {"question": "Se le ve como una referencia del vestuario. ¿Lo siente así?", "options": [
				_o("Lo asume", "Intento ayudar a los más jóvenes como me ayudaron a mí.", {"rep": 6, "coach": 4, "dressing": 7, "traits": {"leadership": 5, "loyalty": 3}, "narrative": "lider", "tone": "lider"}),
				_o("Humilde", "Aquí hay muchos líderes. Yo solo sumo lo mío.", {"rep": 5, "dressing": 4, "traits": {"sportsmanship": 3}, "tone": "humilde"}),
				_o("Incómodo", "No me gustan las etiquetas. Solo quiero jugar.", {"rep": 1, "tone": "neutral"}),
			]}
	if bool(context.get("contract_expiring", false)):
		return {"question": "Sobre la renovación: ¿pondría usted de su parte?", "options": [
			_o("Sí, sin dudar", "Bajaría pretensiones por seguir donde soy feliz.", {"rep": 6, "coach": 6, "fan": 10, "dressing": 4, "traits": {"loyalty": 7}, "narrative": "lider", "tone": "lider"}),
			_o("Dentro de lo justo", "Quiero seguir, pero también que se me valore.", {"rep": 2, "coach": 1, "tone": "neutral"}),
			_o("Que hable el club", "La pelota está en su tejado, no en el mío.", {"rep": -3, "coach": -4, "fan": -6, "traits": {"ambition": 3}, "narrative": "presion", "tone": "ambiciosa"}),
		]}
	return {}

## `extra` admite: rep, coach, fan, dressing, traits(dict), narrative, tone.
static func _o(label: String, text: String, extra: Dictionary) -> Dictionary:
	return {
		"label": label, "text": text,
		"reputation": int(extra.get("rep", 0)),
		"coach_trust": int(extra.get("coach", 0)),
		"fan": int(extra.get("fan", 0)),
		"dressing": int(extra.get("dressing", 0)),
		"traits": extra.get("traits", {}),
		"narrative": String(extra.get("narrative", "")),
		"tone": String(extra.get("tone", "neutral")),
	}

## Aplica la respuesta. `season` (opcional, se muta pero NO se persiste aquí —
## el llamador hace SaveManager.save_season) recibe fan_sentiment /
## dressing_room / press_narrative.
static func apply_response(player: PlayerData, option: Dictionary, season: Dictionary = {}) -> void:
	player.reputation = clampi(player.reputation + int(option.get("reputation", 0)), 0, 100)
	player.coach_trust = clampi(player.coach_trust + int(option.get("coach_trust", 0)), 0, 100)
	var traits: Dictionary = option.get("traits", {})
	for trait_key in traits:
		# "leadership" es el ATRIBUTO real (PlayerData.leadership, 0-99),
		# no un rasgo de personalidad — bug real encontrado en la auditoría:
		# la respuesta "Lo asume" prometía +5 liderazgo pero lo escribía acá,
		# en personality_traits["leadership"], un dict que nadie más lee.
		if trait_key == "leadership":
			player.leadership = clampi(player.leadership + int(traits[trait_key]), 20, 99)
			continue
		var current: int = player.personality_traits.get(trait_key, 50)
		player.personality_traits[trait_key] = clampi(current + int(traits[trait_key]), 0, 100)
	if season is Dictionary and not season.is_empty():
		var fan: int = int(season.get("fan_sentiment", FAN_DEFAULT)) + int(option.get("fan", 0))
		season["fan_sentiment"] = clampi(fan, 0, 100)
		var dr: int = int(season.get("dressing_room", DRESSING_DEFAULT)) + int(option.get("dressing", 0))
		season["dressing_room"] = clampi(dr, 0, 100)
		var nar: String = String(option.get("narrative", ""))
		if nar != "":
			season["press_narrative"] = nar

## Titular de prensa generado por la respuesta (para PressGenerator / feed).
## {} si la respuesta no da para titular.
static func headline_from_answer(player_name: String, option: Dictionary) -> Dictionary:
	var tone: String = String(option.get("tone", "neutral"))
	match tone:
		"polemica":
			return {"headline": "%s enciende la zona mixta" % player_name,
				"body": "\"%s\", soltó el jugador ante la prensa, dejando titulares para rato." % option.get("text", ""),
				"source": "DEPORTE TOTAL", "sentiment": "CRITICAL"}
		"lider":
			return {"headline": "%s tira del carro también fuera del campo" % player_name,
				"body": "\"%s\". El vestuario agradece el mensaje." % option.get("text", ""),
				"source": "GOLAZO TV", "sentiment": "POSITIVE"}
		"ambiciosa":
			return {"headline": "%s no esconde sus objetivos" % player_name,
				"body": "\"%s\", declaró tras el partido." % option.get("text", ""),
				"source": "TRIBUNA", "sentiment": "NEUTRAL"}
		_:
			return {}
