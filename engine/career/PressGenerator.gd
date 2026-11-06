extends RefCounted
class_name PressGenerator

## Titulares de prensa tras el partido del usuario — adaptado del
## PressGenerator.kt del prototipo de Football Legacy que compartió
## Wilber. Backlog: estado persistente (PlayerData.press_feed), NUNCA un
## popup efímero — sobrevive a cerrar el juego y a los rollovers de
## temporada.
##
## No cada partido da titular: solo cuando hay algo que contar (gol,
## partidazo sin marcar, o noche mala). Un partido gris no genera prensa,
## igual que no siempre te ofrecen zona mixta (InterviewEngine.is_standout).

const MAX_ENTRIES := 20
const SOURCES := ["DEPORTE TOTAL", "GOLAZO TV", "ESTADIO 24", "LA JUGADA", "TRIBUNA", "CANCHA+"]
const SENSATIONALIST := ["THE SUN", "BILD", "DAILY STAR"]

## {headline, body, source, sentiment} según goles/nota, o {} si el
## partido no dio para titular. `narrative` (season["press_narrative"], lo
## fija la zona mixta) tiñe el titular: en_racha / presion / polemica / lider.
## `ctx` (opcional): {won, opp, is_rival, is_final, career_goals (total tras
## este partido), debut}. Da titulares CON CONTEXTO: gol en el clásico, en
## una final, en el debut, o al cruzar una cifra redonda de carrera — que
## pesan más que el titular genérico. Pedido de Wilber: "IAs realistas".
static func headline_for_match(player_name: String, goals: int, rating: float, rng: RandomNumberGenerator, narrative: String = "", nick: String = "", ctx: Dictionary = {}) -> Dictionary:
	# La prensa usa el apodo (si ya se lo ganó) parte de las veces.
	var surname: String = nick if (nick != "" and rng.randf() < 0.45) else _surname_of(player_name)

	# --- HITOS (mandan sobre el titular genérico) ---
	if goals >= 1:
		if bool(ctx.get("debut", false)):
			return _news("Debut soñado de %s" % surname,
				"%s marca en su estreno. No se le puede pedir más a un primer partido." % player_name,
				_pick(SOURCES, rng), "POSITIVE")
		if bool(ctx.get("is_rival", false)):
			var opp_r: String = String(ctx.get("opp", "el eterno rival"))
			return _news("%s le da el clásico a los suyos" % surname,
				"%s apareció en el partido del año ante %s. Su afición lo lleva en andas." % [player_name, opp_r],
				_pick(SOURCES, rng), "POSITIVE")
		if bool(ctx.get("is_final", false)):
			return _news("%s escribe la final" % surname,
				"En el partido más importante, %s dio un paso al frente. De esos que se recuerdan toda la vida." % player_name,
				_pick(SOURCES, rng), "POSITIVE")
		var cg: int = int(ctx.get("career_goals", 0))
		var ms: int = _milestone_crossed(cg, goals)
		if ms > 0:
			return _news("%s llega a los %d goles" % [surname, ms],
				"%s alcanza una cifra redonda en su carrera. Y el camino sigue." % player_name,
				_pick(SOURCES, rng), "POSITIVE")

	# La narrativa activa puede generar titular aunque el partido sea gris.
	if narrative != "" and goals == 0 and rating >= 5.0 and rating < 8.0 and rng.randf() < 0.5:
		match narrative:
			"en_racha":
				return _news("%s mantiene el vuelo" % surname,
					"%s no marcó, pero el entorno sigue rendido a su mejor momento." % player_name,
					_pick(SOURCES, rng), "POSITIVE")
			"presion":
				return _news("Lupa sobre %s" % surname,
					"Otra actuación discreta de %s. Las miradas empiezan a pesar." % player_name,
					_pick(SENSATIONALIST, rng), "CRITICAL")
			"polemica":
				return _news("%s, otra vez en el foco" % surname,
					"Dentro y fuera del campo, todo lo que rodea a %s genera debate." % player_name,
					_pick(SENSATIONALIST, rng), "NEUTRAL")
			"lider":
				return _news("%s, voz de mando" % surname,
					"%s vuelve a ejercer de referente, se note o no en el marcador." % player_name,
					_pick(SOURCES, rng), "POSITIVE")
	if goals >= 3:
		return _news(
			"HAT-TRICK DE %s" % surname,
			"%s firmó tres goles en una actuación estelar." % player_name,
			_pick(SOURCES, rng), "POSITIVE",
		)
	if goals == 2:
		return _news(
			"DOBLETE DE %s" % surname,
			"%s marcó dos veces y fue la figura del encuentro con una nota de %.1f." % [player_name, rating],
			_pick(SOURCES, rng), "POSITIVE",
		)
	if goals == 1:
		return _news(
			"%s marca y suma" % surname,
			"%s anotó en el partido. Su rendimiento sigue en alza." % player_name,
			_pick(SOURCES, rng), "POSITIVE",
		)
	if rating >= 8.0:
		var lost_it: bool = ctx.has("won") and not bool(ctx["won"])
		if lost_it:
			return _news(
				"%s se salva de la quema" % surname,
				"El equipo cayó, pero %s fue de lo poco rescatable con un %.1f." % [player_name, rating],
				_pick(SOURCES, rng), "NEUTRAL",
			)
		return _news(
			"Partidazo de %s" % surname,
			"Sin marcar, %s fue clave con una actuación de %.1f." % [player_name, rating],
			_pick(SOURCES, rng), "POSITIVE",
		)
	if rating < 5.0:
		var also_lost: bool = ctx.has("won") and not bool(ctx["won"])
		return _news(
			"Noche para olvidar de %s" % surname,
			("%s no estuvo a la altura y el equipo lo pagó. La afición espera una reacción." if also_lost
				else "%s no estuvo a la altura. La afición espera una reacción.") % player_name,
			_pick(SENSATIONALIST, rng), "CRITICAL",
		)
	return {}

## Cifra redonda de carrera cruzada EN este partido (0 si ninguna).
## Hitos: 25, 50, 75, 100, y de ahí cada 50.
static func _milestone_crossed(total_after: int, scored: int) -> int:
	var before: int = total_after - scored
	var marks: Array = [25, 50, 75, 100]
	var m: int = 150
	while m <= total_after + 50:
		marks.append(m)
		m += 50
	for mk in marks:
		if before < int(mk) and total_after >= int(mk):
			return int(mk)
	return 0

static func _surname_of(full_name: String) -> String:
	var parts: PackedStringArray = full_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else full_name

static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	return pool[rng.randi() % pool.size()]

static func _news(headline: String, body: String, source: String, sentiment: String) -> Dictionary:
	return {"headline": headline, "body": body, "source": source, "sentiment": sentiment}

## Añade `entry` (si no está vacío) al feed persistente de `player`,
## fechado con `day`, más reciente primero, recortado a MAX_ENTRIES.
static func append_to_feed(player: PlayerData, entry: Dictionary, day: int) -> void:
	if entry.is_empty():
		return
	var stamped: Dictionary = entry.duplicate()
	stamped["day"] = day
	var feed: Array = player.press_feed.duplicate()
	feed.push_front(stamped)
	if feed.size() > MAX_ENTRIES:
		feed = feed.slice(0, MAX_ENTRIES)
	player.press_feed = feed
