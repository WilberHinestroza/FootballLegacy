extends RefCounted
class_name ControversyEngine

## Polémicas en redes: algo que hiciste (una roja, un post picante, comerte tus
## palabras, festejar ante el rival) se vuelve tendencia y tienes que responder:
## pedir perdón, ignorarlo o redoblar la apuesta. Mueve ánimo, reputación,
## afición, seguidores, confianza del DT y el patrocinio.
##
## Se guarda en season["controversy"] (la temporada no se versiona: sin cambio
## de esquema). Solo una polémica viva a la vez y un respiro entre una y otra.
##   {id, kind, severity 1-3, day, title, text, choice ("" = sin responder),
##    outcome (texto del desenlace), resolved_day}

const ANSWER_DAYS := 3          # sin respuesta en estos días = "ignorar"
const COOLDOWN_DAYS := 14       # mínimo entre una polémica y la siguiente
const SHOW_OUTCOME_DAYS := 3    # el desenlace sigue visible en el feed

## Probabilidad de que cada cosa se vuelva polémica.
const CHANCE := {
	"red_card": 0.6,
	"words": 0.7,
	"rival_celebration": 0.25,
	"fiery_post": 0.35,
}

const KINDS := {
	"red_card": {
		"severity": 2,
		"title": "Tu roja incendia las redes",
		"text": "El vídeo de la entrada de %s da la vuelta al mundo. Unos piden sanción ejemplar; otros dicen que fue sin querer.",
		"headline": "Polémica por la expulsión de %s",
	},
	"words": {
		"severity": 1,
		"title": "Te comiste tus palabras",
		"text": "Tu publicación de la semana vuelve a circular después de la derrota. Los memes con la cara de %s no paran.",
		"headline": "Las redes no perdonan a %s",
	},
	"words_fiery": {
		"severity": 2,
		"title": "Te comiste tus palabras",
		"text": "Avisaste que \"en la cancha se ve todo\"... y se vio. Captura de tu post en todas partes. %s, tendencia.",
		"headline": "%s, en el ojo del huracán tras su mensaje",
	},
	"rival_celebration": {
		"severity": 1,
		"title": "Tu festejo ante la grada rival",
		"text": "El gesto de %s mirando a la hinchada rival divide opiniones: provocación o pura pasión.",
		"headline": "El festejo de %s, a debate",
	},
	"fiery_post": {
		"severity": 2,
		"title": "Tu mensaje se vuelve viral",
		"text": "Tu publicación picante suma miles de citas. En el vestuario rival ya la imprimieron. %s, en boca de todos.",
		"headline": "El mensaje de %s enciende la previa",
	},
}

## Respuestas posibles (orden de la UI).
const CHOICES := [
	{"id": "apologize", "label": "Pedir disculpas", "hint": "Calma a la afición y al patrocinador; te pesa en el ánimo."},
	{"id": "ignore", "label": "Ignorarlo", "hint": "Se apaga solo... o no. El patrocinador mira."},
	{"id": "double_down", "label": "Redoblar la apuesta", "hint": "Muchos seguidores, pero el DT y la marca se enfadan."},
]


## La polémica viva (sin responder) o {}.
static func active(season: Dictionary) -> Dictionary:
	var c: Dictionary = season.get("controversy", {})
	if c.is_empty() or String(c.get("choice", "")) != "":
		return {}
	return c


## La última polémica ya resuelta, si sigue fresca para enseñarla en el feed.
static func recent_outcome(season: Dictionary, day: int) -> Dictionary:
	var c: Dictionary = season.get("controversy", {})
	if c.is_empty() or String(c.get("choice", "")) == "":
		return {}
	if day - int(c.get("resolved_day", -99)) > SHOW_OUTCOME_DAYS:
		return {}
	return c


static func days_left(season: Dictionary, day: int) -> int:
	var c := active(season)
	if c.is_empty():
		return 0
	return maxi(ANSWER_DAYS - (day - int(c.get("day", day))), 0)


static func _can_start(season: Dictionary, day: int) -> bool:
	var c: Dictionary = season.get("controversy", {})
	if c.is_empty():
		return true
	if String(c.get("choice", "")) == "":
		return false
	return day - int(c.get("day", -999)) >= COOLDOWN_DAYS


## Tras un partido: ctx = {red_card, rating, won, goals, is_rival}. Devuelve la
## polémica creada o {}. El llamador guarda player y season.
static func check_match(player: PlayerData, season: Dictionary, ctx: Dictionary, day: int, rng: RandomNumberGenerator) -> Dictionary:
	if player == null or season.is_empty() or not _can_start(season, day):
		return {}
	var kind := ""
	if bool(ctx.get("red_card", false)) and rng.randf() < float(CHANCE["red_card"]):
		kind = "red_card"
	elif not bool(ctx.get("won", false)) and float(ctx.get("rating", 6.0)) < 6.0:
		var lp: Dictionary = season.get("social", {}).get("last_post", {})
		var tint := String(lp.get("tint", ""))
		if not lp.is_empty() and day - int(lp.get("day", -99)) <= 7 and tint in ["GOLD", "RED"] \
				and rng.randf() < float(CHANCE["words"]):
			kind = "words_fiery" if tint == "RED" else "words"
	if kind == "" and bool(ctx.get("is_rival", false)) and int(ctx.get("goals", 0)) > 0 \
			and rng.randf() < float(CHANCE["rival_celebration"]):
		kind = "rival_celebration"
	if kind == "":
		return {}
	return _start(player, season, kind, day)


## Tras publicar: un post picante a veces se va de las manos.
static func check_post(player: PlayerData, season: Dictionary, option_id: String, day: int, rng: RandomNumberGenerator) -> Dictionary:
	if player == null or option_id != "fiery" or not _can_start(season, day):
		return {}
	if rng.randf() >= float(CHANCE["fiery_post"]):
		return {}
	return _start(player, season, "fiery_post", day)


static func _start(player: PlayerData, season: Dictionary, kind: String, day: int) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var surname := _surname(player.player_name)
	var c := {
		"id": "%s_%d" % [kind, day], "kind": kind, "severity": int(k["severity"]), "day": day,
		"title": String(k["title"]), "text": String(k["text"]) % surname,
		"choice": "", "outcome": "", "resolved_day": -1,
	}
	season["controversy"] = c
	PressGenerator.append_to_feed(player, PressGenerator._news(String(k["headline"]) % surname,
		String(k["text"]) % surname, "Redes", "CRITICAL"), day)
	return c


## Si pasó el plazo sin responder, cuenta como "ignorar". Devuelve el desenlace
## aplicado ("" si no hacía falta). El llamador guarda.
static func expire_if_due(player: PlayerData, season: Dictionary, day: int, rng: RandomNumberGenerator) -> String:
	var c := active(season)
	if c.is_empty() or day - int(c.get("day", day)) < ANSWER_DAYS:
		return ""
	return respond(player, season, "ignore", day, rng)


## Aplica tu respuesta. Devuelve el texto del desenlace. El llamador guarda.
static func respond(player: PlayerData, season: Dictionary, choice: String, day: int, rng: RandomNumberGenerator) -> String:
	var c := active(season)
	if c.is_empty() or player == null:
		return ""
	var sev: int = int(c.get("severity", 1))
	var parts: Array = []
	var fans := 0
	var mood := 0
	var rep := 0
	var trust := 0
	var followers := 0
	var sponsor_risk := 0.0
	var base_followers: int = SocialEngine.followers(player, int(season.get("social", {}).get("bonus_followers", 0)))
	match choice:
		"apologize":
			mood = -3 - sev
			fans = 2 + sev
			rep = 1 if sev <= 1 else 0
			sponsor_risk = 0.0
			parts.append("Tu disculpa calma las aguas")
		"double_down":
			mood = 3
			fans = -2 * sev
			rep = -2 * sev
			trust = -3 * sev
			followers = int(base_followers * 0.02 * sev)
			sponsor_risk = 0.3 * sev
			parts.append("Redoblas la apuesta: la tendencia explota")
		_:
			choice = "ignore"
			mood = -1
			fans = -sev
			rep = -sev
			sponsor_risk = 0.15 * sev
			parts.append("Ignoras el ruido")
	# Lo que de verdad cambió (con los topes 0-100), para contarlo bien.
	var m0 := player.mood
	var r0 := player.reputation
	var t0 := player.coach_trust
	player.mood = clampi(player.mood + mood, 0, 100)
	player.reputation = clampi(player.reputation + rep, 0, 100)
	player.coach_trust = clampi(player.coach_trust + trust, 0, 100)
	mood = player.mood - m0
	rep = player.reputation - r0
	trust = player.coach_trust - t0
	var fs: int = int(season.get("fan_sentiment", InterviewEngine.FAN_DEFAULT))
	season["fan_sentiment"] = clampi(fs + fans, 0, 100)
	fans = int(season["fan_sentiment"]) - fs
	if fans != 0:
		parts.append("%+d afición" % fans)
	if followers > 0:
		var s: Dictionary = season.get("social", {})
		s["bonus_followers"] = int(s.get("bonus_followers", 0)) + followers
		season["social"] = s
		parts.append("+%s seguidores" % SocialEngine.followers_label(followers))
	if rep != 0:
		parts.append("%+d reputación" % rep)
	if trust != 0:
		parts.append("%+d confianza del míster" % trust)
	if mood != 0:
		parts.append("%+d ánimo" % mood)
	# El patrocinador: con mucho ruido recorta el contrato o se va.
	if not player.sponsor.is_empty() and sponsor_risk > 0.0 and rng.randf() < sponsor_risk:
		var name := String(player.sponsor.get("name", "Tu patrocinador"))
		if sev >= 2 and choice == "double_down":
			player.sponsor = {}
			parts.append("%s rompe el contrato" % name)
		else:
			var weeks: int = int(player.sponsor.get("weeks_remaining", 0))
			player.sponsor["weeks_remaining"] = maxi(1, weeks - 4 * sev)
			parts.append("%s recorta tu contrato (%d semanas menos)" % [name, weeks - int(player.sponsor["weeks_remaining"])])
	var outcome := ". ".join(parts) + "."
	c["choice"] = choice
	c["outcome"] = outcome
	c["resolved_day"] = day
	season["controversy"] = c
	return outcome


## Comentarios de la gente sobre la polémica (deterministas para ese día).
static func reactions(c: Dictionary, player: PlayerData, world_seed: int, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("controversy|%s|%d" % [String(c.get("id", "")), day]) ^ world_seed
	var surname := _surname(player.player_name)
	var tag := "#" + surname.replace(" ", "")
	var against := [
		"Un profesional no puede hacer eso. Que pida perdón ya. %s" % tag,
		"%s se cree más de lo que es. Bajen el humo. %s" % [surname, tag],
		"Si yo fuera su patrocinador, lo pensaría dos veces...",
		"Lamentable. Y luego hablan de valores. %s" % tag,
	]
	var favor := [
		"Dejen en paz a %s, es pasión de fútbol. %s" % [surname, tag],
		"Por fin un jugador con carácter. Banco a %s 🔥" % surname,
		"Lo que hace la gente por un clic... %s no hizo nada grave." % surname,
		"Todos los domingos lo mismo. %s, a lo tuyo. 💪" % surname,
	]
	var out: Array = []
	for i in 3:
		var bad := rng.randf() < 0.55
		var pool: Array = against if bad else favor
		out.append({
			"author": "%s%s" % [["Nico", "Vale", "Santi", "Cami", "Rodri", "Lu"][rng.randi() % 6], ["", "_", ".", "9"][rng.randi() % 4]],
			"handle": "@%s%d" % [["hincha", "tribuna", "futbolero", "datafut"][rng.randi() % 4], rng.randi_range(1, 999)],
			"text": pool[rng.randi() % pool.size()],
			"likes": rng.randi_range(50, 9000),
			"tint": "RED" if bad else "GREEN",
		})
	return out


static func _surname(full_name: String) -> String:
	var parts := full_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else full_name
