extends RefCounted
class_name ImmersionEngine

## Inmersión (10-oct, Wilber: "dime qué falta y agrega"):
##  1) VESTUARIO después del partido: un compañero comenta tu jugada y el
##     DT reacciona según tu nota.
##  2) RIVAL PERSONAL: el jugador del clásico que más te marca (defensor
##     si sos de ataque, delantero si sos de defensa), con su historial
##     contra vos en la temporada y piques en la red social.
##  3) FAMILIA en partidos clave (final, clásico, debut, selección):
##     mensaje de casa en la previa y tus padres en la tribuna.
##  4) HINCHAS: pancartas con tu apodo/apellido de local; silbidos si la
##     afición está crispada o si jugás de visitante en el clásico.
##  5) CARTA ESPECIAL: además del bronce → plata → oro → élite por media,
##     versiones especiales por premio individual, racha o leyenda.
##  6) SEMANA DE CLÁSICO: cuenta regresiva y ruido en la red los días
##     previos.
##
## Motor PURO y DETERMINISTA (nada se persiste salvo el historial del
## rival en season["nemesis_log"], que reinicia con la temporada como el
## resto de `season`). Sin cambio de esquema.

# =====================================================================
#  1) Vestuario
# =====================================================================

## ctx: {rating, goals, assists, won, draw, mate_name, coach_name,
##       derby, key, you}  → {mate_name, mate_line, coach_name,
##       coach_line, coach_expr ("feliz"|"enojado"|""), mood}
static func locker_room(ctx: Dictionary) -> Dictionary:
	var rng := _rng("locker|" + String(ctx.get("key", "")))
	var rating: float = float(ctx.get("rating", 6.0))
	var goals: int = int(ctx.get("goals", 0))
	var assists: int = int(ctx.get("assists", 0))
	var won: bool = bool(ctx.get("won", false))
	var draw: bool = bool(ctx.get("draw", false))
	var derby: bool = bool(ctx.get("derby", false))
	var you: String = String(ctx.get("you", ""))

	var mate: Array
	if goals >= 3:
		mate = ["¡Hat-trick, %s! Esa pelota te la llevás a casa, la firmamos todos." % you,
			"Tres goles... en el micro de vuelta pagás vos, ¿eh?"]
	elif goals >= 1 and won:
		mate = ["¡Qué gol, hermano! Te vi venir y ya sabía que adentro.",
			"Ese gol vale tres puntos. Hoy te ganaste la ducha primero.",
			"Le pegaste como los dioses. Mañana sos portada."]
	elif assists >= 1 and won:
		mate = ["Ese pase me lo dejaste servido, el gol es medio tuyo.",
			"Con pases así, cualquiera la mete. Gracias, crack."]
	elif goals >= 1:
		mate = ["Tu gol no alcanzó, pero dejaste todo. Eso se nota.",
			"Al menos vos la metiste. El resto tenemos que mejorar."]
	elif won:
		mate = ["Partido trabajado. Ganamos, que es lo que importa.",
			"No brillaste, pero corriste por dos. Así se gana."]
	elif draw:
		mate = ["Un punto... se nos escapó al final. La próxima la ganamos.",
			"Empate con sabor a poco. Hay que levantar la cabeza."]
	else:
		mate = ["Duele, pero esto es largo. El martes a entrenar el doble.",
			"No es tu culpa, fue una mala tarde de todos.",
			"Cabeza arriba. Perder así enseña más que una goleada a favor."]
	if derby and won:
		mate.append("¡GANAMOS EL CLÁSICO! Esta semana no pagamos nada en el barrio.")

	var coach: Array
	var expr: String = ""
	var mood: String = "ok"
	if rating >= 8.0:
		coach = ["Esto es lo que quiero ver cada fin de semana. Excelente.",
			"Hoy fuiste diferencial. Sigue así y el puesto es tuyo.",
			"No tengo nada que corregirte. Disfrutalo, te lo ganaste."]
		expr = "feliz"
		mood = "great"
	elif rating >= 7.0:
		coach = ["Buen partido. Ordenado, intenso. Así.",
			"Me gustó tu actitud. Ahora quiero un poco más arriba.",
			"Cumpliste. Ahora a recuperar, que viene otro."]
		expr = "feliz" if won else ""
		mood = "good"
	elif rating >= 6.0:
		coach = ["Correcto, nada más. De vos espero más que correcto.",
			"Te vi apagado por momentos. El martes lo hablamos.",
			"Ni bien ni mal. Y yo no te traje para eso."]
		mood = "ok"
	else:
		coach = ["Así no. Te perdiste en la cancha y lo sabés.",
			"Hoy no estuviste. Mañana quiero verte con otra cara.",
			"Si no estás bien, decímelo. Pero así no podés salir."]
		expr = "enojado"
		mood = "bad"
	return {
		"mate_name": String(ctx.get("mate_name", "Tu compañero")),
		"mate_line": String(mate[rng.randi() % mate.size()]),
		"coach_name": String(ctx.get("coach_name", "El DT")),
		"coach_line": String(coach[rng.randi() % coach.size()]),
		"coach_expr": expr,
		"mood": mood,
	}

# =====================================================================
#  2) Rival personal
# =====================================================================

## Club del que sale tu rival personal: el del clásico; si tu club no
## tiene clásico, el más fuerte de tu liga (que no seas vos).
static func nemesis_club_id(world: Dictionary, club_id: String, world_seed: int) -> String:
	if world.is_empty() or club_id == "":
		return ""
	var rid: String = RivalryEngine.club_rival_for(world, club_id, world_seed)
	if rid != "":
		return rid
	var club: ClubData = WorldFactory.find_club(world, club_id)
	if club == null:
		return ""
	var meta: Dictionary = world.get("club_meta_by_id", {})
	var best_id: String = ""
	var best_ov: int = -1
	for c in world.get("clubs_by_league", {}).get(club.league_id, []):
		if c.club_id == club_id:
			continue
		var ov: int = int(meta.get(c.club_id, {}).get("base_overall", 0))
		if ov > best_ov:
			best_ov = ov
			best_id = c.club_id
	return best_id

## Posición de tu rival según la tuya: si atacás te marca un defensor; si
## defendés (o atajás), te enfrentás a su delantero.
static func nemesis_position(user_position: String) -> String:
	return "ST" if user_position in ["DF", "GK"] else "DF"

## Elegir al rival dentro del plantel (la escena arma el plantel): el
## mejor de la posición que te toca. {} si no hay.
static func pick_nemesis(squad: Array, user_position: String) -> Dictionary:
	var want: String = nemesis_position(user_position)
	var best: PlayerData = null
	for p in squad:
		if p == null or p.position != want:
			continue
		if best == null or p.overall > best.overall:
			best = p
	if best == null:
		return {}
	return {"name": best.player_name, "overall": best.overall, "position": best.position,
		"detailed": best.detailed_position, "age": best.age, "country": best.country}

## Historial de TODA la carrera contra tu rival (player.nemesis_log, v34).
## → {played, won, draw, lost, your_goals, best_rating}
static func nemesis_record(log: Array) -> Dictionary:
	var r := {"played": 0, "won": 0, "draw": 0, "lost": 0, "your_goals": 0, "best_rating": 0.0}
	for e in log:
		r["played"] += 1
		match int(e.get("sign", 0)):
			1: r["won"] += 1
			0: r["draw"] += 1
			_: r["lost"] += 1
		r["your_goals"] += int(e.get("goals", 0))
		r["best_rating"] = maxf(float(r["best_rating"]), float(e.get("rating", 0.0)))
	return r

## Anotar un partido contra el club del rival (idempotente por día).
const NEMESIS_LOG_MAX := 60
static func log_nemesis_match(player: PlayerData, day: int, sign: int, goals: int, rating: float, season_year: int = 0, club_id: String = "") -> void:
	for e in player.nemesis_log:
		if int(e.get("day", -1)) == day:
			return
	player.nemesis_log.append({"day": day, "season": season_year, "sign": sign, "goals": goals,
		"rating": snappedf(rating, 0.1), "club_id": club_id})
	while player.nemesis_log.size() > NEMESIS_LOG_MAX:
		player.nemesis_log.pop_front()

# --- Ex clubes (v34) ---------------------------------------------------

## Te fuiste de un club (traspaso o fin de contrato; NO cesión): queda en
## tu historial. Llamar ANTES de cambiar player.club_id.
static func note_club_left(player: PlayerData, world: Dictionary, to_club_id: String, season_year: int) -> void:
	if player == null or player.club_id == "" or player.club_id == to_club_id:
		return
	var old: ClubData = WorldFactory.find_club(world, player.club_id)
	player.former_clubs.append({
		"club_id": player.club_id, "name": old.club_name if old != null else player.club_id,
		"left_season": season_year, "seniority": player.club_seniority, "to_club_id": to_club_id,
	})

## ¿`club_id` es un ex club tuyo? → la entrada más reciente, o {}.
static func former_club_entry(player: PlayerData, club_id: String) -> Dictionary:
	for i in range(player.former_clubs.size() - 1, -1, -1):
		if String(player.former_clubs[i].get("club_id", "")) == club_id:
			return player.former_clubs[i]
	return {}

## Cómo te recibe la hinchada de un ex club cuando volvés de visitante:
##  "traidor"  te fuiste directo a su clásico rival → silbidos fuertes
##  "idolo"    estuviste 4+ temporadas → aplausos
##  "ex"       recibimiento frío (algún silbido)
##  ""         no es un ex club
static func ex_club_reception(player: PlayerData, world: Dictionary, host_club_id: String, world_seed: int) -> String:
	var e: Dictionary = former_club_entry(player, host_club_id)
	if e.is_empty():
		return ""
	var their_rival: String = RivalryEngine.club_rival_for(world, host_club_id, world_seed)
	if their_rival != "" and (String(e.get("to_club_id", "")) == their_rival or player.club_id == their_rival):
		return "traidor"
	if int(e.get("seniority", 0)) >= 4:
		return "idolo"
	return "ex"

## Pique del rival antes de enfrentarte (red social / previa).
static func nemesis_pre_line(nem_name: String, you: String, record: Dictionary, key: String) -> String:
	var rng := _rng("nempre|" + key)
	var pool: Array = [
		"El domingo %s no va a tocar una pelota. Palabra." % you,
		"Me preguntan por %s. Que se preocupe él por mí." % you,
		"Lo estudié toda la semana. Ya sé para qué lado se va %s." % you,
		"Respeto a %s, pero en la cancha no tengo amigos." % you,
	]
	if int(record.get("lost", 0)) > 0:
		pool.append("La última vez se fue llorando. Que no se olvide, %s." % you)
	if int(record.get("won", 0)) > 0:
		pool.append("Esta vez es distinto. Tengo una cuenta pendiente con %s." % you)
	return String(pool[rng.randi() % pool.size()])

## Respuesta tuya que la red le "atribuye" (o un DM del rival).
static func nemesis_dm(nem_name: String, you: String, record: Dictionary, key: String) -> Array:
	var rng := _rng("nemdm|" + key)
	var open: Array = [
		"Nos vemos el domingo, %s. Traé canilleras." % you,
		"Ya leí lo que dijiste. Lo hablamos en la cancha.",
		"Te tengo marcado desde el vestuario, %s." % you,
	]
	var close: Array = [
		"Después del partido te cambio la camiseta. Si te queda aire.",
		"Que gane el mejor. O sea, yo.",
		"Sin rencores afuera. Adentro, guerra.",
	]
	var msgs: Array = [{"from": "them", "text": String(open[rng.randi() % open.size()])}]
	if int(record.get("played", 0)) > 0:
		msgs.append({"from": "them", "text": "Vamos %d-%d-%d en el año. Esto se define ahora." % [int(record["won"]), int(record["draw"]), int(record["lost"])]})
	msgs.append({"from": "them", "text": String(close[rng.randi() % close.size()])})
	return msgs

# =====================================================================
#  3) Familia
# =====================================================================

const _MOTHER_NAMES := ["Rosa", "Marta", "Carmen", "Gloria", "Elena", "Lucía", "Beatriz", "Patricia", "Inés", "Teresa"]
const _FATHER_NAMES := ["Jorge", "Ramón", "Luis", "Alberto", "Héctor", "Raúl", "Miguel", "Óscar", "Ernesto", "Hugo"]

static func family(player: PlayerData) -> Dictionary:
	var h: int = absi(hash("family:" + player.player_name))
	var parts: PackedStringArray = player.player_name.split(" ", false)
	var surname: String = parts[parts.size() - 1] if parts.size() > 0 else ""
	var out := {
		"mother": "%s %s" % [_MOTHER_NAMES[h % _MOTHER_NAMES.size()], surname],
		"father": "%s %s" % [_FATHER_NAMES[(h / 7) % _FATHER_NAMES.size()], surname],
		"mother_short": "Mamá",
		"father_short": "Papá",
		"partner": String(player.partner.get("name", "")) if player.partner is Dictionary else "",
	}
	return out

## ¿Partido "de los que la familia no se pierde"? → kind o "".
## kind ∈ final | clasico | debut | seleccion | eliminatoria
static func key_match_kind(fx: Dictionary, player: PlayerData) -> String:
	if fx.is_empty() or player == null:
		return ""
	var round_name: String = String(fx.get("round_name", ""))
	var comp: String = String(fx.get("competition", ""))
	if comp == "friendly":
		return ""
	if round_name == "Final" or round_name.ends_with(" Final") or comp == "supercup":
		return "final"
	if player.career_matches + player.season_matches_played == 0:
		return "debut"
	if bool(fx.get("derby", false)):
		return "clasico"
	if fx.has("opponent") or comp in ["world_cup", "national_cup", "qualifying"]:
		return "seleccion"
	if bool(fx.get("is_knockout", false)) and (round_name.begins_with("Semi") or round_name.begins_with("Cuartos")):
		return "eliminatoria"
	return ""

## Mensaje de casa para la previa: {from, text}.
static func family_message(kind: String, player: PlayerData) -> Dictionary:
	var fam := family(player)
	var rng := _rng("fammsg|%s|%s|%d" % [kind, player.player_name, player.career_matches])
	var you: String = player.player_name.split(" ", false)[0] if player.player_name != "" else ""
	var pool: Array
	var from: String = "Mamá"
	match kind:
		"final":
			pool = ["%s, estamos en la tribuna con la camiseta que usabas de chiquito. Pase lo que pase, ya ganaste." % you,
				"Hijo, tu papá no durmió en toda la noche. Jugá tranquilo, como en el potrero.",
				"Una final, %s. Acordate de dónde saliste. Te amamos." % you]
		"debut":
			pool = ["¡Tu primer partido, %s! Estamos todos acá, hasta la abuela vino." % you,
				"Hijo, disfrutalo. Este día lo soñamos juntos desde que tenías cinco años."]
		"clasico":
			from = "Papá"
			pool = ["El clásico, %s. Lo vi mil veces desde la tribuna; hoy te veo a vos ahí abajo." % you,
				"Hoy no se juega, hoy se gana. Tranquilo y con la cabeza fría, campeón.",
				"Media ciudad va a estar mirando. Yo solo te miro a vos. Dale."]
		"seleccion":
			pool = ["Con la camiseta de la selección... %s, no podemos estar más orgullosos." % you,
				"Hijo, cuando suene el himno acordate de tu abuelo. Él lo hubiera dado todo por verte."]
		_:
			from = "Papá"
			pool = ["Partido grande, %s. Confiá en lo que entrenaste." % you,
				"Estamos con vos. Salí a disfrutar."]
	if fam["partner"] != "" and rng.randf() < 0.35:
		from = String(fam["partner"])
		pool = ["Estoy en la tribuna con tus viejos. Mirá para arriba cuando la metas 💛",
			"Hoy es tu día. Te espero a la salida, pase lo que pase."]
	return {"from": from, "text": String(pool[rng.randi() % pool.size()])}

## Config de avatar para mamá/papá: misma piel que el jugador (parecido
## familiar), mayores (arrugas), sin kit.
static func parent_config(player_cfg: Dictionary, role: String, key: String, world_seed: int) -> Dictionary:
	var cfg: Dictionary = Avatar.config_for_npc(key + ":" + role, "partner", world_seed).duplicate(true)
	var rng := _rng("parent|" + key + role)
	if player_cfg.has("tint_base"):
		cfg["tint_base"] = player_cfg["tint_base"]
	cfg["age"] = "arrugas"
	cfg.erase("acc_eyes")
	if role == "mother":
		cfg["hair"] = ["largo", "mono", "coleta", "rizos_largos", "melena"][rng.randi() % 5]
		cfg["face"] = ""
		cfg["outfit"] = ["lino", "plumifero", "polo", "hoodie"][rng.randi() % 4]
	else:
		cfg["hair"] = ["calvo", "raya", "engominado", "rapado"][rng.randi() % 4]
		cfg["face"] = ["bigote", "barba", "barba3", ""][rng.randi() % 4]
		cfg["outfit"] = ["polo", "camisa_vestir", "abrigo", "vaquera"][rng.randi() % 4]
	var greys: Array = ["#9a9a9a", "#c8c8c8", "#5a4a40"]
	cfg["tint_hair"] = greys[rng.randi() % greys.size()]
	return cfg

# =====================================================================
#  4) Hinchas con memoria
# =====================================================================

## Pancartas de la tribuna. home = jugás de local.
## → {kind: "love"|"boo"|"", banners: [String], line: String}
const IDOL_SENTIMENT := 72
const IDOL_REPUTATION := 72
const IDOL_SENIORITY := 4
const LOVE_BANNER_SHARE := 0.4
static func crowd_banners(player: PlayerData, world_seed: int, fan_sentiment: int, home: bool, derby: bool, shirt_number: int, ex_reception: String = "") -> Dictionary:
	if player == null:
		return {"kind": "", "banners": [], "line": ""}
	var parts: PackedStringArray = player.player_name.split(" ", false)
	var surname: String = (parts[parts.size() - 1] if parts.size() > 0 else "").to_upper()
	# De visitante en tu EX club (v34): la tribuna se acuerda de vos.
	if not home and ex_reception != "":
		match ex_reception:
			"traidor":
				return {"kind": "boo", "banners": ["%s TRAIDOR" % surname, "ACÁ NO VOLVÉS MÁS"],
					"line": "Tu ex hinchada no te perdona haberte ido al clásico rival: silbatina total."}
			"idolo":
				return {"kind": "love", "banners": ["GRACIAS, %s" % surname, "ESTA SIEMPRE SERÁ TU CASA"],
					"line": "Tu ex hinchada te recibe con aplausos: no se olvidan de vos."}
			_:
				return {"kind": "boo", "banners": ["%s, YA NO SOS DE ACÁ" % surname],
					"line": "Recibimiento frío en tu ex cancha, con algunos silbidos."}
	var nick: String = Nickname.for_player(player, world_seed).to_upper()
	var rng := _rng("banners|%s|%d" % [player.player_name, player.career_matches])
	if not home and derby:
		return {"kind": "boo", "banners": ["%s, ACÁ NO SOS NADIE" % surname, "SILENCIO, %s" % surname],
			"line": "La hinchada local silba cada vez que tocás la pelota."}
	if home and fan_sentiment < 30:
		return {"kind": "boo", "banners": ["%s, ¡DESPERTÁ!" % surname, "QUEREMOS HUEVO"],
			"line": "Silbidos en la tribuna: la afición está crispada contigo."}
	if not home:
		return {"kind": "", "banners": [], "line": ""}
	# 11-oct (Wilber: "que la barra hablando de mí solo salga cuando sea
	# alguien muy importante en el equipo y no siempre"). Antes alcanzaba con
	# tener apodo, así que salía en casi todos los partidos de local. Ahora
	# hay que ser ÍDOLO (afición muy a favor, mucha reputación, o años en el
	# club con la gente contenta) y aun así no en cada partido: en el
	# clásico siempre, el resto de las veces LOVE_BANNER_SHARE.
	var idol: bool = fan_sentiment >= IDOL_SENTIMENT or player.reputation >= IDOL_REPUTATION or (player.club_seniority >= IDOL_SENIORITY and fan_sentiment >= 55)
	if not idol:
		return {"kind": "", "banners": [], "line": ""}
	if not derby and rng.randf() >= LOVE_BANNER_SHARE:
		return {"kind": "", "banners": [], "line": ""}
	var love: Array = []
	if nick != "":
		love.append("¡VAMOS %s!" % nick)
		love.append("%s %s ♥" % [nick, surname])
	if fan_sentiment >= 65 or nick != "" or player.reputation >= 60:
		love.append("%s ES DE LOS NUESTROS" % surname)
		love.append("EL %d ES SAGRADO" % shirt_number if shirt_number > 0 else "%s ETERNO" % surname)
		if player.club_seniority >= 4:
			love.append("%d AÑOS CONTIGO, %s" % [player.club_seniority, surname])
	if love.is_empty():
		return {"kind": "", "banners": [], "line": ""}
	# 2 pancartas por partido, distintas.
	var picked: Array = []
	while picked.size() < mini(2, love.size()):
		var b: String = String(love[rng.randi() % love.size()])
		if not picked.has(b):
			picked.append(b)
	return {"kind": "love", "banners": picked, "line": "La tribuna te banca: pancartas con tu nombre."}

# =====================================================================
#  5) Carta especial
# =====================================================================

## Versión especial de la carta, o {} si va la normal (por media).
## → {id, label, top, bot, ink, edge}
static func special_card(player: PlayerData, season_year: int) -> Dictionary:
	if player == null:
		return {}
	if LegacyEngine.tier(player) >= 3:
		return {"id": "icono", "label": "ÍCONO", "top": Color("#fff6d8"), "bot": Color("#c9a24a"),
			"ink": Color("#2a1d05"), "edge": Color("#fffbe8")}
	for t in player.career_titles:
		if String(t.get("kind", "")) == "individual" and int(t.get("season", -99)) >= season_year - 1 and int(t.get("metal", 1)) == 1:
			return {"id": "premio", "label": "PREMIO", "top": Color("#2a2a2e"), "bot": Color("#0b0b0d"),
				"ink": Color("#f3d36b"), "edge": Color("#f3d36b")}
	var rr: Array = player.recent_ratings
	if rr.size() >= 4:
		var s: float = 0.0
		for v in rr:
			s += float(v)
		if s / float(rr.size()) >= 7.8:
			return {"id": "racha", "label": "EN RACHA", "top": Color("#1fd1f9"), "bot": Color("#0b2a6b"),
				"ink": Color("#eafaff"), "edge": Color("#8ff0ff")}
	return {}

## Nombre del escalón por media (bronce → plata → oro → élite).
static func card_tier_name(overall: int) -> String:
	if overall > 85:
		return "ÉLITE"
	if overall >= 80:
		return "ORO"
	if overall >= 61:
		return "PLATA"
	return "BRONCE"

# =====================================================================
#  6) Semana de clásico
# =====================================================================

const DERBY_WEEK_DAYS := 6

## {days_left, rival_id} si el próximo partido es el clásico dentro de la
## semana; {} si no.
static func derby_week(next_fx: Dictionary, user_club_id: String, rival_id: String, today: int) -> Dictionary:
	if next_fx.is_empty() or rival_id == "" or String(next_fx.get("competition", "")) == "friendly":
		return {}
	var h: String = String(next_fx.get("home_club_id", ""))
	var a: String = String(next_fx.get("away_club_id", ""))
	if not ((h == user_club_id and a == rival_id) or (a == user_club_id and h == rival_id)):
		return {}
	var dl: int = int(next_fx.get("epoch_day", today)) - today
	if dl < 0 or dl > DERBY_WEEK_DAYS:
		return {}
	return {"days_left": dl, "rival_id": rival_id, "home": h == user_club_id}

## Posts de la semana de clásico para "Tu feed". ctx: {you, club, rival,
## nemesis, nem_line, days_left, home}
static func derby_week_posts(ctx: Dictionary, world_seed: int, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("derbyweek|%d" % day) ^ world_seed
	var club: String = String(ctx.get("club", ""))
	var rival: String = String(ctx.get("rival", ""))
	var you: String = String(ctx.get("you", ""))
	var dl: int = int(ctx.get("days_left", 0))
	var when: String = "HOY" if dl == 0 else ("MAÑANA" if dl == 1 else "en %d días" % dl)
	var out: Array = []
	out.append({"author": club, "handle": "@" + _tag(club), "verified": true,
		"text": "🔥 SEMANA DE CLÁSICO. %s vs %s, %s. Que se escuche la ciudad entera. #%s" % [club, rival, when, _tag("Clásico " + club)],
		"likes": rng.randi_range(8000, 60000), "tint": "GOLD", "mine": false, "rts": rng.randi_range(900, 9000),
		"av": {"kind": "club", "id": String(ctx.get("club_id", ""))}})
	var nem: String = String(ctx.get("nemesis", ""))
	if nem != "":
		out.append({"author": nem, "handle": "@" + _tag(nem).to_lower(), "verified": true,
			"text": String(ctx.get("nem_line", "")), "likes": rng.randi_range(3000, 30000), "tint": "RED", "mine": false,
			"rts": rng.randi_range(400, 5000), "nemesis": true})
	var press: Array = [
		"Todo listo para el clásico: %s llega como la gran amenaza de %s." % [you, club],
		"Clima caliente en la previa del clásico. Entradas agotadas en horas.",
		"¿Quién gana el duelo de la semana? %s contra la defensa de %s." % [you, rival],
	]
	out.append({"author": "DEPORTE TOTAL", "handle": "@deportetotal", "verified": true,
		"text": String(press[rng.randi() % press.size()]), "likes": rng.randi_range(1500, 12000), "tint": "PURPLE",
		"mine": false, "av": {"kind": "media", "name": "DEPORTE TOTAL"}})
	var fan_rival: Array = [
		"Este año les bailamos el clásico. %s no pasa de mitad de cancha 😂" % you,
		"Que vengan. Nuestra cancha, nuestras reglas. #%s" % _tag(rival),
	]
	out.append({"author": "Hincha de " + rival, "handle": "@" + _tag(rival).to_lower() + "_siempre",
		"text": String(fan_rival[rng.randi() % fan_rival.size()]), "likes": rng.randi_range(200, 4000), "tint": "RED", "mine": false})
	return out

# =====================================================================

static func _rng(salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("immersion|" + salt)
	return r

static func _tag(name: String) -> String:
	var out := ""
	for ch in name:
		if ch != " " and ch != "." and ch != "'" and ch != "-":
			out += ch
	return out
