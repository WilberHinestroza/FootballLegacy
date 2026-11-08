extends RefCounted
class_name SocialEngine

## "Redes sociales" (clon de Twitter) — porte conceptual de Football
## Legacy. El feed se GENERA determinista a partir del estado de carrera y
## una semilla; NO se persiste, igual criterio "mundo vivo" que
## WorldExplorer / table_for_league. Lo único que persiste al publicar es
## un ajuste chico de reputación (campo ya existente en PlayerData) y un
## contador de posts por semana guardado en el dict de temporada — aditivo,
## SIN cambio de esquema (SaveManager no versiona `season`).

const MAX_POSTS_PER_WEEK := 2
const FEED_SIZE := 14

# --- Seguir cuentas (jugadores / clubes / DTs) ---
# Se guarda la lista de "claves" seguidas en season["following"] (Array de
# String). No es cambio de esquema: `season` no se versiona.

static func is_following(season: Dictionary, key: String) -> bool:
	return (season.get("following", []) as Array).has(key)

## Alterna seguir/dejar de seguir. Devuelve el estado NUEVO (true = ahora
## lo seguís). El llamador guarda la temporada.
static func toggle_follow(season: Dictionary, key: String) -> bool:
	var lst: Array = season.get("following", [])
	if lst.has(key):
		lst.erase(key)
		season["following"] = lst
		return false
	lst.append(key)
	season["following"] = lst
	return true

## Un tweet de una cuenta seguida para la semana dada, o {} si esa semana
## no publicó. `kind` ∈ player | club | coach.
static func account_tweet(display_name: String, kind: String, world_seed: int, week: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("acct|%s|%d" % [display_name, week]) ^ world_seed
	if rng.randf() > 0.55:
		return {}   # esa semana no tuiteó
	var lines: Array
	match kind:
		"club":
			lines = [
				"Entrenamiento a doble turno. Se viene una semana clave. 💪",
				"Gracias a la gente que llenó el estadio. Sois el jugador número 12.",
				"Trabajo, humildad y a seguir. Vamos con todo.",
				"Bienvenida a la afición visitante. El fútbol se disfruta en paz.",
			]
		"coach":
			lines = [
				"Contento con la actitud del grupo. Hay margen de mejora.",
				"El resultado no fue el buscado. Autocrítica y a levantarse.",
				"Los chicos del filial vienen empujando fuerte.",
			]
		_:
			lines = [
				"Día de recuperación. El cuerpo pide descanso.",
				"Gracias por todos los mensajes. Esto es de todos. 🙏",
				"A veces se gana, a veces se aprende. Seguimos.",
				"Nada como volver a pisar el césped. ⚽",
				"Focus. El resto es ruido.",
				"Buen entrenamiento hoy. Sensaciones positivas de cara al finde.",
			]
	var h: String = _hashtag(display_name)
	if not h.begins_with("@"):
		h = "@" + h
	return _post(display_name, h, lines[rng.randi() % lines.size()],
		rng.randi_range(40, 5000), "BLUE" if kind == "club" else "GREEN")

## Tweets recientes de todo lo que el usuario sigue, para mezclar en "Para ti".
static func followed_tweets(season: Dictionary, world: Dictionary, world_seed: int, day: int) -> Array:
	var following: Array = season.get("following", [])
	if following.is_empty():
		return []
	var week: int = CalendarUtils.week_index(day)
	var out: Array = []
	for key in following:
		var k: String = String(key)
		var kind: String = "club" if k.begins_with("club:") else ("coach" if k.begins_with("coach:") else "player")
		var name: String = k.split(":", true, 1)[-1] if ":" in k else k
		if k.begins_with("club:"):
			var c: ClubData = WorldFactory.find_club(world, name)
			if c != null:
				name = c.club_name
		var tw: Dictionary = account_tweet(name, kind, world_seed, week)
		if not tw.is_empty():
			out.append(tw)
	return out

## Publicaciones que el jugador puede lanzar. `rep` = delta de reputación;
## `fans_pct` = fracción de tus seguidores actuales que ganás por el
## engagement. "Picante" cambia reputación por alcance a propósito.
const POST_OPTIONS := [
	{
		"id": "humble", "label": "Humilde", "tint": "BLUE",
		"text": "Solo pienso en ayudar al equipo. A por el próximo partido.",
		"rep": 1, "fans_pct": 0.010,
	},
	{
		"id": "confident", "label": "Confiado", "tint": "GOLD",
		"text": "Estamos para cosas grandes esta temporada. Vamos con todo.",
		"rep": 2, "fans_pct": 0.020,
	},
	{
		"id": "fans", "label": "Agradecer a la afición", "tint": "GREEN",
		"text": "El apoyo de ustedes lo es todo. Gracias por bancar siempre.",
		"rep": 1, "fans_pct": 0.030,
	},
	{
		"id": "fiery", "label": "Picante", "tint": "RED",
		"text": "Los que hablan de más, que se preparen. En la cancha se ve todo.",
		"rep": -1, "fans_pct": 0.045,
	},
]

## Seguidores: derivado, nunca guardado. Reputación es el grueso (cuadrática
## para premiar a las estrellas); goles/asistencias/títulos de carrera lo
## empujan y los partidos dan una base. `bonus` viene del engagement
## acumulado de tus propios posts esta temporada (season["social"]).
static func followers(player: PlayerData, bonus: int = 0) -> int:
	if player == null:
		return 0
	var rep: float = float(player.reputation)
	var total: float = 2000.0
	total += rep * rep * 12.0
	total += float(player.career_goals) * 1800.0
	total += float(player.career_assists) * 700.0
	total += float(player.trophies_won) * 40000.0
	total += float(player.career_matches) * 250.0
	total += float(FoundationEngine.followers_bonus(player))   # tu fundación también suma
	return maxi(int(total) + maxi(bonus, 0), 0)

## Empujón de seguidores DESPUÉS de un partido notable — la gente de las
## redes reacciona a lo que hacés en la cancha, no solo a que publiques
## (pedido de Wilber: "IAs más inmersivas y realistas"). Devuelve el
## bump (0 si el partido no dio para tanto); la escena lo suma a
## season["social"]["bonus_followers"]. `ctx`: {goals, rating, won,
## is_rival, is_final}.
static func match_follower_bump(player: PlayerData, ctx: Dictionary) -> int:
	if player == null:
		return 0
	var goals: int = int(ctx.get("goals", 0))
	var rating: float = float(ctx.get("rating", 6.0))
	var base: float = followers(player)   # escala con tu tamaño de cuenta
	var pct: float = 0.0
	pct += goals * 0.010                    # +1% por gol
	if goals >= 3:
		pct += 0.03                         # hat-trick, extra
	if rating >= 8.5:
		pct += 0.012
	elif rating >= 7.5:
		pct += 0.005
	if bool(ctx.get("is_rival", false)) and (goals >= 1 or float(rating) >= 7.5):
		pct += 0.02
	if bool(ctx.get("is_final", false)) and bool(ctx.get("won", false)):
		pct += 0.04
	if pct <= 0.0:
		return 0
	# tope: un partido no te multiplica la cuenta.
	pct = minf(pct, 0.12)
	# piso absoluto para que un jugador chico igual note el envión.
	return maxi(int(round(base * pct)), 150 if goals >= 1 else 0)

static func followers_label(n: int) -> String:
	if n >= 1_000_000:
		return "%.1f M" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.1f k" % (n / 1_000.0)
	return str(n)

static func handle_for(player: PlayerData) -> String:
	if player == null:
		return "@jugador"
	var parts: PackedStringArray = player.player_name.to_lower().split(" ", false)
	var h: String = "".join(parts) if parts.size() > 0 else "jugador"
	h = h.replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n")
	return "@" + h

## --- Publicar ---

static func week_of(day: int) -> int:
	return CalendarUtils.week_index(day)

static func posts_left_this_week(season: Dictionary, day: int) -> int:
	var s: Dictionary = season.get("social", {})
	if int(s.get("week", -1)) != week_of(day):
		return MAX_POSTS_PER_WEEK
	return maxi(MAX_POSTS_PER_WEEK - int(s.get("posts", 0)), 0)

## Aplica el efecto de una publicación: mueve reputación, suma seguidores
## por engagement y deja registrado el post (para mostrarlo arriba del
## feed). Devuelve {ok, message, followers_gained}. La escena guarda
## player + season.
static func publish(player: PlayerData, season: Dictionary, option_id: String, day: int, rng: RandomNumberGenerator) -> Dictionary:
	if posts_left_this_week(season, day) <= 0:
		return {"ok": false, "message": "Ya publicaste demasiado esta semana.", "followers_gained": 0}
	var opt: Dictionary = {}
	for o in POST_OPTIONS:
		if o["id"] == option_id:
			opt = o
			break
	if opt.is_empty():
		return {"ok": false, "message": "Publicación desconocida.", "followers_gained": 0}

	player.reputation = clampi(player.reputation + int(opt["rep"]), 0, 100)

	var s: Dictionary = season.get("social", {})
	if int(s.get("week", -1)) != week_of(day):
		s = {"week": week_of(day), "posts": 0, "bonus_followers": int(s.get("bonus_followers", 0))}
	var base_gain: int = int(followers(player) * float(opt["fans_pct"]))
	# Community manager del staff personal (StaffEngine): amplifica lo que
	# gana cada publicación.
	base_gain = int(base_gain * StaffEngine.follower_factor(player))
	var gain: int = maxi(base_gain + rng.randi_range(-150, 400), 0)
	s["posts"] = int(s.get("posts", 0)) + 1
	s["bonus_followers"] = int(s.get("bonus_followers", 0)) + gain
	s["last_post"] = {"text": opt["text"], "day": day, "tint": opt["tint"]}
	season["social"] = s

	return {"ok": true, "message": "Publicado. +%s seguidores." % followers_label(gain), "followers_gained": gain}

## --- Feed generado (determinista) ---

## Devuelve una lista de {author, handle, text, likes, tint} — la mezcla
## depende del estado de carrera. `world` se usa para el nombre del club y
## de un rival. Reproducible para (seed, day) dados.
static func generate_feed(player: PlayerData, world: Dictionary, world_seed: int, day: int, season: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("social_feed|%d" % day) ^ world_seed
	var out: Array = []
	var surname: String = _surname(player.player_name)

	# El feed NO es siempre igual de lleno: la mayoría de los días la red
	# está tranquila (pedido de Wilber: "los mensajes en twitter son muy
	# comunes"). Se llena de verdad cerca de partido / titular fuerte.
	var recent_headline: bool = not player.press_feed.is_empty() and (day - int(player.press_feed[0].get("day", 0))) <= 2
	var quiet: bool = not recent_headline and rng.randf() < 0.5
	var feed_cap: int = (rng.randi_range(3, 5) if quiet else rng.randi_range(8, 12))

	# Tu propia última publicación arriba de todo.
	var last_post: Dictionary = season.get("social", {}).get("last_post", {})
	if not last_post.is_empty():
		out.append({
			"author": player.player_name, "handle": handle_for(player),
			"text": last_post.get("text", ""), "likes": rng.randi_range(200, 9000),
			"tint": String(last_post.get("tint", "GOLD")), "mine": true,
		})

	# Lo que se dijo en redes de tu último partido (season.social.match_posts):
	# visible hasta 2 días después.
	var mp: Dictionary = season.get("social", {}).get("match_posts", {})
	if not mp.is_empty() and day - int(mp.get("day", -99)) <= 2:
		for mpost in mp.get("posts", []):
			feed_cap += 1   # no las recorta el tope de un día "tranquilo"
			out.append(_post(String(mpost.get("author", "")), String(mpost.get("handle", "")),
				String(mpost.get("text", "")), rng.randi_range(150, 9000), String(mpost.get("tint", "PURPLE"))))

	var club_name: String = ""
	if player.club_id != "":
		var club: ClubData = WorldFactory.find_club(world, player.club_id)
		if club != null:
			club_name = club.club_name

	# Reacciones de hinchas a los últimos titulares de prensa.
	for entry in player.press_feed.slice(0, 2):
		var sentiment: String = String(entry.get("sentiment", ""))
		var headline: String = String(entry.get("headline", ""))
		if sentiment == "CRITICAL":
			out.append(_post(_fan_name(rng), _fan_handle(rng),
				"%s otra vez irregular... el nivel no alcanza. #%s" % [surname, _hashtag(club_name)],
				rng.randi_range(30, 800), "RED"))
		else:
			out.append(_post(_fan_name(rng), _fan_handle(rng),
				"QUÉ JUGADOR %s 🔥🔥 titular: \"%s\"" % [surname.to_upper(), headline],
				rng.randi_range(120, 6000), "GREEN"))

	# Cuenta oficial del club (no todos los días).
	if club_name != "" and rng.randf() < 0.45:
		out.append(_post(club_name, "@" + _hashtag(club_name),
			"Sesión completada. El domingo se juega en casa. ¡Los esperamos! 💙",
			rng.randi_range(300, 12000), "BLUE"))

	# Analista / prensa.
	var pundit_lines: Array = [
		"%s está en un momento de forma serio. Ojo con su proyección." % surname,
		"Para mí %s todavía tiene que dar el salto en partidos grandes." % surname,
		"Los números de %s esta temporada no mienten: %d goles ya." % [surname, player.season_goals],
		"Se habla de interés de varios clubes por %s. Fuentes cercanas lo confirman." % surname,
	]
	if rng.randf() < 0.55:
		var pundit: String = _pundit_name(rng)
		out.append(_post(pundit, _pundit_handle(pundit),
			pundit_lines[rng.randi() % pundit_lines.size()], rng.randi_range(80, 3500), "PURPLE"))

	# Reacción de hincha propio al jugador (siempre hay, no depende de prensa).
	var hype_lines: Array = [
		"%s es de los nuestros. Banco a muerte. 💚" % surname,
		"Necesitamos más minutos de %s, cambia el equipo cuando entra." % surname,
		"%s este año va a explotar, se los digo yo." % surname,
		"Ojalá %s se quede muchos años. De los que valen la pena." % surname,
	]
	if rng.randf() < 0.6:
		out.append(_post(_fan_name(rng), _fan_handle(rng),
			hype_lines[rng.randi() % hype_lines.size()], rng.randi_range(15, 900), "GREEN"))

	# Rumor de mercado si el contrato está por vencer.
	if player.contract_years_remaining <= 1:
		out.append(_post("Mercado en Vivo", "@mercadoenvivo",
			"🔴 %s termina contrato. Su entorno ya escucha ofertas. Se viene movida." % surname,
			rng.randi_range(500, 20000), "AMBER"))

	# Patrocinador.
	if not player.sponsor.is_empty():
		out.append(_post(String(player.sponsor.get("name", "Sponsor")), "@" + _hashtag(String(player.sponsor.get("name", "sponsor"))),
			"Orgullosos de acompañar a %s esta temporada. #Vamos%s" % [surname, surname],
			rng.randi_range(200, 5000), "GOLD"))

	# Hincha rival (a veces).
	var rival_name: String = _rival_club_name(world, player.club_id, rng)
	if rival_name != "" and rng.randf() < 0.35:
		out.append(_post(_fan_name(rng), _fan_handle(rng),
			"%s no le ganaría ni a nuestro juvenil. Sobrevalorado. 😂 #%s" % [surname, _hashtag(rival_name)],
			rng.randi_range(20, 1200), "RED"))

	# Relleno de chchara futbolera genérica.
	var filler: Array = [
		"El fútbol moderno es todo presión y transición, ya no hay 10 clásicos.",
		"VAR arruinó la celebración del gol y nadie lo va a admitir.",
		"Domingo de fútbol y asado, no se pide más.",
		"Cada año el calendario está más cargado. Los jugadores no son máquinas.",
		"Los relatos de ahora hablan más de apuestas que del partido.",
		"Un buen lateral vale oro y nadie lo valora hasta que se lesiona.",
		"Extraño cuando los clubes formaban jugadores en vez de comprarlos.",
		"La camiseta nueva es un golazo, la de visitante un desastre.",
		"Partido chivo hoy y aún así lo voy a ver entero. Enfermo del fútbol.",
		"Se viene fecha FIFA y con eso, dos semanas sin liga. Un bajón.",
	]
	# Tweets de las cuentas que seguís (jugadores / clubes / DTs) — van
	# arriba y suben el cupo del día para que no los recorte el slice.
	var mine_offset: int = 1 if not last_post.is_empty() else 0
	var ft: Array = followed_tweets(season, world, world_seed, day)
	for i in range(ft.size()):
		out.insert(mini(mine_offset + i, out.size()), ft[i])
	feed_cap += ft.size()

	# Relleno solo hasta el cupo del día (no siempre 14).
	var guard: int = 0
	while out.size() < feed_cap and guard < 30:
		guard += 1
		out.append(_post(_fan_name(rng), _fan_handle(rng),
			filler[rng.randi() % filler.size()], rng.randi_range(5, 400), "BLUE"))

	return out.slice(0, feed_cap)

static func _post(author: String, handle: String, text: String, likes: int, tint: String) -> Dictionary:
	return {"author": author, "handle": handle, "text": text, "likes": likes, "tint": tint, "mine": false}

static func _surname(full_name: String) -> String:
	var parts: PackedStringArray = full_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else full_name

static func _hashtag(name: String) -> String:
	var s: String = name.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"], [" ", ""], [".", ""], ["-", ""]]:
		s = s.replace(pair[0], pair[1])
	return s

const _FIRST := ["Nico", "Juli", "Fer", "Rodri", "Santi", "Tomi", "Agus", "Manu", "Lea", "Fran", "Cami", "Vale"]
const _LAST := ["Fútbol", "10", "Hincha", "CF", "Tribuna", "Aguante", "DT", "Data", "Gol"]
## Ficticios (10-oct: había nombres de periodistas/exjugadores REALES —
## contra la regla de "nada de nombres reales" de CLAUDE.md).
const _PUNDITS := ["Darío Lastra", "Mónica Arrieta", "Matías Soler", "Clara Bravo", "Rubén Iturbe"]

static func _fan_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [_FIRST[rng.randi() % _FIRST.size()], _LAST[rng.randi() % _LAST.size()]]

static func _fan_handle(rng: RandomNumberGenerator) -> String:
	return "@%s%d" % [_FIRST[rng.randi() % _FIRST.size()].to_lower(), rng.randi_range(2, 99)]

static func _pundit_name(rng: RandomNumberGenerator) -> String:
	return _PUNDITS[rng.randi() % _PUNDITS.size()]

static func _pundit_handle(name: String) -> String:
	return "@" + name.to_lower().replace(" ", "_").replace("ó", "o").replace("é", "e").replace("í", "i")

static func _rival_club_name(world: Dictionary, club_id: String, rng: RandomNumberGenerator) -> String:
	if club_id == "" or world.is_empty():
		return ""
	var club: ClubData = WorldFactory.find_club(world, club_id)
	if club == null:
		return ""
	var peers: Array = world.get("clubs_by_league", {}).get(club.league_id, [])
	var others: Array = peers.filter(func(c): return c.club_id != club_id)
	if others.is_empty():
		return ""
	return others[rng.randi() % others.size()].club_name

# =====================================================================
#  Mensajes directos (DMs) + eventos con coste de energía
# =====================================================================
#
# El jugador chatea con su representante, compañeros y el entrenador.
# Algunos hilos traen una INVITACIÓN a un evento: consume energía física
# (sube PlayerData.fatigue_physical, que se recupera unos puntos por día
# en WorldTickEngine._tick_fatigue_and_development) a cambio de dinero,
# reputación, confianza del entrenador, seguidores o alguna mejora. Sin
# cambio de esquema: fatigue_physical / balance / reputation / coach_trust
# / consumables ya existen; lo aceptado se anota en season["social"].

## Nombres ficticios para compañeros/rivales — nunca futbolistas reales
## sin licencia (misma regla que el resto del juego).
const _DM_PEERS := [
	"Bruno Sánchez", "Iker Montoya", "Leandro Farías", "Adam Novak",
	"Théo Rael", "Kwame Osei", "Dani Prieto", "Marco Belli",
]

## Frecuencia de invitación en los DMs (pedido explícito de Wilber):
##   70% conversación normal, sin invitación
##   20% invitación SOCIAL — salir con un contacto, construye vínculo
##       (DM_SOCIAL_INVITES): energía baja, recompensa blanda
##   10% ACTIVIDAD con beneficio real (DM_BENEFIT_EVENTS): dinero, mejora,
##       seguidores, a veces riesgo de lesión
const DM_INVITE_NONE_CHANCE := 0.82 # ~1 invitación cada 5-6 semanas (antes 0.70 = muy seguido)
const DM_INVITE_BENEFIT_CHANCE := 0.14 # el 14% superior del rango

## `stamina` = energía física que consume. `effects` se aplican al aceptar
## (rangos [lo, hi] se sortean). `kind` solo etiqueta la UI.
const DM_SOCIAL_INVITES := [
	{
		"id": "coffee_agent", "role": "agent", "kind": "social", "title": "Un café con tu representante",
		"desc": "Ponerse al día sin apuro, hablar de la vida más que del fútbol.",
		"stamina": 4, "effects": {"reputation": [0, 1]},
	},
	{
		"id": "dinner_teammates", "role": "teammate", "kind": "social", "title": "Cena con el grupo",
		"desc": "Los compañeros arman una cena. Se hace grupo fuera de la cancha.",
		"stamina": 6, "effects": {"reputation": [1, 2]},
	},
	{
		"id": "coach_walk", "role": "coach", "kind": "social", "title": "Charla con el entrenador",
		"desc": "El míster quiere conocerte mejor como persona, no solo como jugador.",
		"stamina": 3, "effects": {"coach_trust": [1, 3]},
	},
	{
		"id": "fan_meetup", "role": "agent", "kind": "social", "title": "Encuentro con la peña de hinchas",
		"desc": "Un rato con la peña más fiel. Volvés cargado de energía… anímica.",
		"stamina": 6, "effects": {"reputation": [1, 3]},
	},
	{
		"id": "teammate_hangout", "role": "teammate", "kind": "social", "title": "Tarde con un compañero",
		"desc": "Un compañero te invita a su casa a no hacer nada. Necesario.",
		"stamina": 3, "effects": {"reputation": [0, 1]},
	},
]

const DM_BENEFIT_EVENTS := [
	{
		"id": "charity_gala", "role": "agent", "kind": "benefit", "title": "Gala benéfica",
		"desc": "Una noche de gala con prensa y patrocinadores. Buen escaparate para tu imagen.",
		"stamina": 12, "effects": {"money": [45, 160], "reputation": [2, 4], "consumable": "medkit"},
	},
	{
		"id": "extra_session", "role": "teammate", "kind": "benefit", "title": "Entrenamiento extra",
		"desc": "Un compañero te invita a una sesión privada con su preparador de confianza.",
		"stamina": 18, "effects": {"attr_bump": 1, "coach_trust": [1, 2], "consumable": "prematch_supp"},
	},
	{
		"id": "podcast", "role": "agent", "kind": "benefit", "title": "Podcast de fútbol",
		"desc": "Tu representante te consiguió un lugar en el podcast del momento.",
		"stamina": 8, "effects": {"reputation": [2, 3], "followers": [4000, 12000], "consumable": "focus_supp"},
	},
	{
		"id": "legends_match", "role": "teammate", "kind": "benefit", "title": "Partido de figuras",
		"desc": "Exhibición benéfica con cracks de varias ligas. Se juega en serio, ojo.",
		"stamina": 24, "effects": {"money": [120, 420], "reputation": [3, 5], "injury_risk": 0.12},
	},
	{
		"id": "brand_shoot", "role": "agent", "kind": "benefit", "title": "Sesión de fotos de marca",
		"desc": "Campaña de una marca deportiva. Un día largo de estudio.",
		"stamina": 10, "effects": {"money": [25, 95], "reputation": [1, 2], "consumable": "energy_drink"},
	},
]

static func _all_invites() -> Array:
	return DM_SOCIAL_INVITES + DM_BENEFIT_EVENTS

static func energy(player: PlayerData) -> int:
	if player == null:
		return 100
	return clampi(100 - int(round(player.fatigue_physical)), 0, 100)

static func _event_key(event_id: String, week: int) -> String:
	return "%s@%d" % [event_id, week]

static func event_done(season: Dictionary, event_id: String, day: int) -> bool:
	var done: Array = season.get("social", {}).get("events_done", [])
	return _event_key(event_id, week_of(day)) in done

static func can_accept(player: PlayerData, event: Dictionary) -> bool:
	return player != null and player.fatigue_physical + float(event.get("stamina", 0)) <= 100.0

static func event_by_id(event_id: String) -> Dictionary:
	for e in _all_invites():
		if e["id"] == event_id:
			return e
	return {}

## Genera los hilos de DM de la semana (deterministas por semana, así la
## invitación no cambia hasta el lunes). Devuelve
## [{contact_name, role, messages:[{from,text}], invite:{} | evento}].
static func generate_threads(player: PlayerData, world: Dictionary, world_seed: int, day: int, season: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("dm|%d" % week_of(day)) ^ world_seed
	var surname: String = _surname(player.player_name)
	var out: Array = []

	var coach_name: String = "el entrenador"
	if player.club_id != "" and not world.is_empty():
		var coach = WorldFactory.find_coach(world, player.club_id)
		if coach != null:
			coach_name = coach.coach_name

	var agent_name: String = player.agent_name if player.agent_name != "" else "Tu representante"
	var peer_name: String = _DM_PEERS[rng.randi() % _DM_PEERS.size()]

	# Una sola tirada por semana decide si hay invitación y de qué tipo
	# (70% nada / 20% social / 10% con beneficio). Se engancha al hilo cuyo
	# rol coincide.
	var week_invite: Dictionary = _weekly_invite(rng, season, day)
	var invite_role: String = String(week_invite.get("role", ""))

	# --- Hilo del representante (siempre) ---
	var agent_msgs: Array = _pick_chat(rng, [
		"%s, ¿cómo va todo? Te sigo por acá también jaja." % surname,
		"Tranqui con la prensa de esta semana, ya la manejo yo.",
		"Buen partido el último. Lo hablaban bien en la radio.",
		"Acordate de descansar, que venís con muchos minutos.",
	])
	out.append(_thread(agent_name, "agent", agent_msgs, week_invite if invite_role == "agent" else {}))

	# --- Hilo de un compañero (a veces) ---
	if rng.randf() < 0.7:
		var peer_msgs: Array = _pick_chat(rng, [
			"Buen laburo en el último partido, eh.",
			"¿Viste el gol del finde? Una locura.",
			"Mañana el entreno es a las 10, avisó el profe.",
			"Bancame en la próxima que yo te banco a vos jaja.",
		])
		out.append(_thread(peer_name, "teammate", peer_msgs, week_invite if invite_role == "teammate" else {}))

	# --- Hilo del entrenador (a veces) ---
	if rng.randf() < 0.45:
		var coach_msgs: Array = _pick_chat(rng, [
			"Quiero que sigas con esa actitud. Hablamos.",
			"Te vi bien en los entrenamientos. Seguí así.",
			"Necesito más comunicación tuya en el campo.",
		])
		out.append(_thread(coach_name, "coach", coach_msgs, week_invite if invite_role == "coach" else {}))

	# Si la invitación era de un rol cuyo hilo no salió esta semana, la
	# colgamos del representante para que no se pierda.
	if not week_invite.is_empty():
		var placed: bool = out.any(func(t): return not t["invite"].is_empty())
		if not placed and out.size() > 0:
			out[0]["invite"] = week_invite

	return out

static func _pick_chat(rng: RandomNumberGenerator, lines: Array) -> Array:
	var a: String = lines[rng.randi() % lines.size()]
	var b: String = lines[rng.randi() % lines.size()]
	var msgs: Array = [{"from": "them", "text": a}]
	if b != a:
		msgs.append({"from": "them", "text": b})
	return msgs

static func _thread(name: String, role: String, messages: Array, invite: Dictionary) -> Dictionary:
	return {"contact_name": name, "role": role, "messages": messages, "invite": invite}

## Tirada semanal única: 70% sin invitación, 20% social, 10% con beneficio.
static func _weekly_invite(rng: RandomNumberGenerator, season: Dictionary, day: int) -> Dictionary:
	var roll: float = rng.randf()
	if roll < DM_INVITE_NONE_CHANCE:
		return {}
	var pool: Array = DM_BENEFIT_EVENTS if roll >= (1.0 - DM_INVITE_BENEFIT_CHANCE) else DM_SOCIAL_INVITES
	# El índice se elige SIEMPRE contra el pool COMPLETO, nunca contra una
	# versión ya filtrada por "no hecho todavía" -- generate_threads() se
	# recalcula desde cero cada vez que se abre la pantalla (misma semilla
	# determinista por semana), así que si se filtraba ANTES de elegir, el
	# tamaño del pool cambiaba apenas se aceptaba/rechazaba un evento y la
	# MISMA tirada terminaba apuntando a un índice distinto -- aparecía un
	# "regalo" nuevo en OTRO hilo cada vez que se respondía uno, en bucle
	# infinito. Reportado por Wilber jugando de verdad. Ahora: el evento
	# elegido para la semana es SIEMPRE el mismo; si ya se respondió, la
	# semana simplemente se queda sin invitación (no salta a otra).
	var chosen: Dictionary = pool[rng.randi() % pool.size()]
	if event_done(season, String(chosen["id"]), day):
		return {}
	return chosen

## ¿Hay una invitación de DM sin aceptar esta semana? (para el aviso del Hub)
static func has_pending_invite(player: PlayerData, world: Dictionary, world_seed: int, day: int, season: Dictionary) -> bool:
	if player == null:
		return false
	for t in generate_threads(player, world, world_seed, day, season):
		var inv: Dictionary = t.get("invite", {})
		if not inv.is_empty() and not event_done(season, String(inv["id"]), day):
			return true
	return false

static func dm_seen_this_week(season: Dictionary, day: int) -> bool:
	return int(season.get("social", {}).get("dm_seen_week", -1)) == week_of(day)

static func mark_dm_seen(season: Dictionary, day: int) -> void:
	var s: Dictionary = season.get("social", {})
	s["dm_seen_week"] = week_of(day)
	season["social"] = s

## Aceptar un evento: descuenta energía, aplica efectos, lo marca como
## hecho esta semana. Devuelve {ok, message}. La escena guarda player +
## season.
static func accept_event(player: PlayerData, season: Dictionary, event_id: String, day: int, rng: RandomNumberGenerator) -> Dictionary:
	var ev: Dictionary = event_by_id(event_id)
	if ev.is_empty():
		return {"ok": false, "message": "Evento desconocido."}
	if event_done(season, event_id, day):
		return {"ok": false, "message": "Ya fuiste a un evento parecido esta semana."}
	if not can_accept(player, ev):
		return {"ok": false, "message": "Estás demasiado cansado para eso ahora."}

	player.fatigue_physical = clampf(player.fatigue_physical + float(ev["stamina"]) * Traits.fatigue_factor(player), 0.0, 100.0)

	var fx: Dictionary = ev.get("effects", {})
	var parts: Array = []
	if fx.has("money"):
		var m: int = rng.randi_range(int(fx["money"][0]), int(fx["money"][1]))
		player.balance += m
		parts.append("+" + CurrencyFormat.format(m))
	if fx.has("reputation"):
		var r: int = int(round(rng.randi_range(int(fx["reputation"][0]), int(fx["reputation"][1])) * Traits.rep_factor(player)))
		player.reputation = clampi(player.reputation + r, 0, 100)
		parts.append("+%d reputación" % r)
	if fx.has("coach_trust"):
		var ct: int = rng.randi_range(int(fx["coach_trust"][0]), int(fx["coach_trust"][1]))
		player.coach_trust = clampi(player.coach_trust + ct, 0, 100)
		parts.append("+%d confianza" % ct)
	if fx.has("followers"):
		var s: Dictionary = season.get("social", {})
		var f: int = int(round(rng.randi_range(int(fx["followers"][0]), int(fx["followers"][1])) * StaffEngine.follower_factor(player)))
		s["bonus_followers"] = int(s.get("bonus_followers", 0)) + f
		season["social"] = s
		parts.append("+%s seguidores" % followers_label(f))
	if fx.has("attr_bump"):
		var attr: String = PlayerDevelopment.ALL_TRAINABLE[rng.randi() % PlayerDevelopment.ALL_TRAINABLE.size()]
		var bump: int = int(fx["attr_bump"])
		player.set(attr, clampi(int(player.get(attr)) + bump, 20, 99))
		PlayerDevelopment.bank_overall_progress(player, bump)
		parts.append("%s +%d" % [attr, bump])
	if fx.has("consumable"):
		var cid: String = String(fx["consumable"])
		player.consumables[cid] = int(player.consumables.get(cid, 0)) + 1
		var cname: String = String(ShopEngine.item_by_id(cid).get("name", cid))
		parts.append("🎁 +1 %s" % cname)
	var hurt: bool = false
	# Bug real de la auditoría (ronda 4): este era el ÚNICO camino de
	# lesión que no pasaba por PlayerDevelopment.apply_match_injury() —
	# ni respetaba al fisioterapeuta (StaffEngine.injury_factor, el
	# beneficio ENTERO de subirlo de nivel) ni el guard de "no pisar una
	# baja ya en curso con otra encima" que esa función sí tiene.
	if fx.has("injury_risk") and player.injury_days_remaining <= 0 and rng.randf() < float(fx["injury_risk"]):
		var raw_days: int = PlayerDevelopment.roll_injury_days(rng)
		player.injury_days_remaining = maxi(1, int(round(raw_days * StaffEngine.injury_factor(player))))
		hurt = true

	var s2: Dictionary = season.get("social", {})
	var done: Array = s2.get("events_done", [])
	done.append(_event_key(event_id, week_of(day)))
	s2["events_done"] = done
	season["social"] = s2

	var msg: String = "%s: %s." % [ev["title"], ", ".join(parts)] if not parts.is_empty() else "%s: hecho." % ev["title"]
	if hurt:
		msg += " Pero saliste tocado — unos días de baja."
	msg += "  (-%d energía)" % int(ev["stamina"])
	return {"ok": true, "message": msg}

## Rechazar la invitación: solo la marca como respondida esta semana (no
## aplica efectos, no cuesta energía). Sin castigo — es tu tiempo.
static func reject_event(season: Dictionary, event_id: String, day: int) -> void:
	var s: Dictionary = season.get("social", {})
	var done: Array = s.get("events_done", [])
	var k: String = _event_key(event_id, week_of(day))
	if not (k in done):
		done.append(k)
	s["events_done"] = done
	season["social"] = s
