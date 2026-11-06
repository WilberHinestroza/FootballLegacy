extends RefCounted
class_name WorldPulseEngine

## LA RED SOCIAL "MUNDO" (10-oct, Wilber: "mejorar la sección de red
## social, más inmersivo y mundo vivo de clubes, jugadores y selecciones").
## Publicaciones generadas a partir de lo que REALMENTE pasó en el mundo
## simulado: resultados de la última jornada (cuentas oficiales de los
## clubes), la punta de la tabla (cuenta de la liga), goleadores y
## candidatos al Balón de Oro (medios ficticios de MediaOutlets), rumores
## de mercado sobre las figuras, y selecciones (fecha FIFA / Mundial).
## Determinista por (semilla, día) y SIN persistir nada — mismo criterio de
## mundo vivo que el resto. Puro: la escena junta los datos en `ctx`.
##
## ctx = {
##   league_name: String, league_hashtag: String,
##   table: Array[{club_id, name, pts, pos}],
##   last_round: Array[{home_id, home, away_id, away, gh, ga}],
##   scorers: Array[{name, club_name, count}],
##   ballon: Array[{name, club_name, goals}],
##   rich_clubs: Array[String],         # para rumores
##   user_country: String, intl_days: int (-1 si no hay ventana cerca),
##   wc_year: bool, in_window: bool,
## }
## Cada post: {author, handle, text, likes, rts, replies, tint, verified,
##   av: {kind: club|media|fan|league|nation, ...}, card: {...}?}

static func feed(ctx: Dictionary, world_seed: int, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("worldpulse|%d" % day) ^ world_seed
	var out: Array = []

	# 1) Resultados de la última jornada, publicados por el club GANADOR (o
	#    el local si empató). Primero las goleadas y las sorpresas.
	var rounds: Array = (ctx.get("last_round", []) as Array).duplicate()
	var pos_of: Dictionary = {}
	for r in ctx.get("table", []):
		pos_of[String(r["club_id"])] = int(r.get("pos", 99))
	rounds.sort_custom(func(a, b): return _interest(a, pos_of) > _interest(b, pos_of))
	for m in rounds.slice(0, 4):
		var gh: int = int(m["gh"])
		var ga: int = int(m["ga"])
		var home_wins: bool = gh >= ga
		var poster_id: String = String(m["home_id"] if home_wins else m["away_id"])
		var poster: String = String(m["home"] if home_wins else m["away"])
		var other: String = String(m["away"] if home_wins else m["home"])
		var text: String
		if gh == ga:
			text = "FINAL | Reparto de puntos ante %s. Seguimos sumando. 🤝" % other
		elif absi(gh - ga) >= 3:
			text = "FINAL | ¡GOLEADA! %d-%d ante %s. Noche perfecta. 🔥" % [maxi(gh, ga), mini(gh, ga), other]
		elif int(pos_of.get(poster_id, 99)) > int(pos_of.get(String(m["away_id"] if home_wins else m["home_id"]), 99)) + 6:
			text = "FINAL | ¡Golpe en la liga! Le ganamos %d-%d a %s. Este equipo cree. 💪" % [maxi(gh, ga), mini(gh, ga), other]
		else:
			text = "FINAL | Tres puntos de oro: %d-%d ante %s. ¡Vamos! ⚽" % [maxi(gh, ga), mini(gh, ga), other]
		var p := _post(poster, "@" + _tag(poster), text, rng.randi_range(800, 24000), rng, "BLUE", true, {"kind": "club", "id": poster_id})
		p["card"] = {"kind": "score", "home_id": m["home_id"], "home": m["home"], "away_id": m["away_id"], "away": m["away"], "gh": gh, "ga": ga}
		out.append(p)

	# 2) La cuenta de la liga: quién manda.
	var table: Array = ctx.get("table", [])
	var league: String = String(ctx.get("league_name", ""))
	if table.size() >= 3 and int(table[0].get("pj", 1)) > 0:
		var a: Dictionary = table[0]
		var b: Dictionary = table[1]
		var gap: int = int(a["pts"]) - int(b["pts"])
		var t2: String = ("%s es líder con %d pts y le saca %d a %s. ¿Alguien lo frena? 👀" % [a["name"], a["pts"], gap, b["name"]]) if gap > 0 \
			else ("Empate en la cima: %s y %s, los dos con %d pts. ¡Qué liga! 🔥" % [a["name"], b["name"], a["pts"]])
		var p2 := _post(league, "@" + _tag(league), t2, rng.randi_range(2000, 40000), rng, "GOLD", true, {"kind": "league"})
		p2["card"] = {"kind": "table", "rows": table.slice(0, 3)}
		out.append(p2)

	# 3) Medios: goleadores y Balón de Oro.
	var outlets: Array = MediaOutlets.names()
	var scorers: Array = ctx.get("scorers", [])
	if not scorers.is_empty() and int(scorers[0].get("count", 0)) > 0:
		var s: Dictionary = scorers[0]
		var o: String = outlets[rng.randi() % outlets.size()]
		out.append(_post(o, "@" + _tag(o), "📊 %s (%s) es el pichichi de %s con %d goles. Imparable." % [s["name"], s["club_name"], league, s["count"]],
			rng.randi_range(1500, 30000), rng, "PURPLE", true, {"kind": "media", "name": o}))
	var ballon: Array = ctx.get("ballon", [])
	if ballon.size() >= 3:
		var o2: String = outlets[rng.randi() % outlets.size()]
		out.append(_post(o2, "@" + _tag(o2), "🏆 Carrera por el Balón de Oro: 1. %s · 2. %s · 3. %s. ¿Quién se lo lleva?" % [ballon[0]["name"], ballon[1]["name"], ballon[2]["name"]],
			rng.randi_range(5000, 80000), rng, "GOLD", true, {"kind": "media", "name": o2}))
		# Rumor de mercado sobre una figura (no siempre).
		var rich: Array = ctx.get("rich_clubs", [])
		if not rich.is_empty() and rng.randf() < 0.6:
			var star: Dictionary = ballon[rng.randi_range(0, mini(5, ballon.size()) - 1)]
			var dest: String = String(rich[rng.randi() % rich.size()])
			if dest != String(star["club_name"]):
				out.append(_post("Mercado en Vivo", "@mercadoenvivo", "🔴 EXCLUSIVA | %s pregunta por %s (%s). Primeros contactos con su entorno." % [dest, star["name"], star["club_name"]],
					rng.randi_range(3000, 60000), rng, "AMBER", true, {"kind": "media", "name": "Mercado en Vivo"}))

	# 4) Selecciones.
	var country: String = String(ctx.get("user_country", ""))
	if bool(ctx.get("in_window", false)) and country != "":
		out.append(_post("Selección de %s" % country, "@sel" + _tag(country), "Semana de selecciones. Todos con la camiseta. #Vamos%s" % _tag(country).capitalize(),
			rng.randi_range(4000, 70000), rng, "GREEN", true, {"kind": "nation", "country": country}))
	elif int(ctx.get("intl_days", -1)) > 0 and country != "":
		out.append(_post("Selección de %s" % country, "@sel" + _tag(country), "En %d días se viene la fecha FIFA. El cuerpo técnico ya sigue a los candidatos de cerca. 👀" % int(ctx["intl_days"]),
			rng.randi_range(2000, 40000), rng, "GREEN", true, {"kind": "nation", "country": country}))
	if bool(ctx.get("wc_year", false)):
		var o3: String = outlets[rng.randi() % outlets.size()]
		out.append(_post(o3, "@" + _tag(o3), "🌍 Año de Mundial. Cada partido de liga es una vidriera para la convocatoria.",
			rng.randi_range(5000, 90000), rng, "GREEN", true, {"kind": "media", "name": o3}))

	# Orden "timeline": mezclado pero estable.
	for i in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out

## Tendencias del día: hashtags de lo que está pasando.
static func trends(ctx: Dictionary, world_seed: int, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("trends|%d" % day) ^ world_seed
	var out: Array = []
	var table: Array = ctx.get("table", [])
	if not table.is_empty():
		out.append("#" + _tag(String(table[0]["name"])).capitalize())
	var league: String = String(ctx.get("league_hashtag", ""))
	if league != "":
		out.append("#" + league)
	var ballon: Array = ctx.get("ballon", [])
	if not ballon.is_empty():
		out.append("#BalónDeOro")
	if bool(ctx.get("wc_year", false)):
		out.append("#Mundial")
	if bool(ctx.get("in_window", false)):
		out.append("#FechaFIFA")
	var rounds: Array = ctx.get("last_round", [])
	if not rounds.is_empty():
		var m: Dictionary = rounds[rng.randi() % rounds.size()]
		out.append("#%sVs%s" % [_tag(String(m["home"])).capitalize(), _tag(String(m["away"])).capitalize()])
	out.append(["#MercadoDePases", "#VARpolémico", "#GolDeLaFecha", "#Clásico"][rng.randi() % 4])
	return out

## Qué tan "noticia" es un resultado: goleada o que el de abajo le gane al
## de arriba.
static func _interest(m: Dictionary, pos_of: Dictionary) -> int:
	var gh: int = int(m["gh"])
	var ga: int = int(m["ga"])
	var diff: int = absi(gh - ga)
	var score: int = diff * 3 + gh + ga
	var ph: int = int(pos_of.get(String(m["home_id"]), 10))
	var pa: int = int(pos_of.get(String(m["away_id"]), 10))
	if (gh > ga and ph > pa + 6) or (ga > gh and pa > ph + 6):
		score += 10
	return score

static func _post(author: String, handle: String, text: String, likes: int, rng: RandomNumberGenerator, tint: String, verified: bool, av: Dictionary) -> Dictionary:
	return {"author": author, "handle": handle, "text": text, "likes": likes,
		"rts": int(likes * rng.randf_range(0.08, 0.25)), "replies": int(likes * rng.randf_range(0.02, 0.08)),
		"tint": tint, "verified": verified, "av": av, "mine": false}

static func _tag(name: String) -> String:
	var s: String = name.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"], ["ü", "u"], [" ", ""], [".", ""], ["-", ""], ["'", ""]]:
		s = s.replace(pair[0], pair[1])
	return s
