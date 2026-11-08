extends RefCounted
class_name ShirtNumberEngine

## Tu dorsal: FUENTE ÚNICA del número que llevas (perfil, camiseta del RPG,
## partido 3D, presentación, despedida, pancartas). Si nunca eliges, es el que
## te asigna el club (Kit.suggested_number, estable por puesto). Puedes pedir
## otro con la ventana de fichajes abierta, una vez por temporada:
##
## - Los compañeros ya llevan la mayoría del 2 al 23 y algunos más altos
##   (deterministas por club): esos no están libres.
## - El 1 es del portero: solo lo puede pedir un portero.
## - El 10, el 7 y el 9 son de los referentes: los consigues si eres de los
##   mejores del equipo (media muy por encima del club), el capitán o una
##   estrella (reputación). Si lo pides y te lo dan, la prensa lo cuenta.
## - Al fichar por otro club intentas llevar el mismo número; si allí está
##   ocupado, te dan el de siempre hasta que elijas.
##
## Estado: player.active_effects["shirt_number"] = {club_id, number}
## (diccionario ya existente) y season["shirt_number_changed"] (una vez por
## temporada). Sin cambio de esquema.

const KEY := "shirt_number"
const ICONIC := [10, 7, 9]
const ICONIC_OVR_MARGIN := 3     # media sobre el nivel del club para pedir el 10/7/9
const ICONIC_REPUTATION := 80
const FREE_LOW := 4              # huecos libres entre el 2 y el 23 en cada club
const HIGH_TAKEN := 6            # números del 24 al 40 que ya lleva alguien

## Número que llevas hoy.
static func number_for(player: PlayerData, world_seed: int) -> int:
	if player == null:
		return 0
	var suggested: int = Kit.suggested_number(player.position, "%s|%d" % [player.player_name, world_seed])
	var d = player.active_effects.get(KEY, {})
	if not (d is Dictionary) or int(d.get("number", 0)) <= 0:
		return suggested
	var n: int = int(d["number"])
	if String(d.get("club_id", "")) == player.club_id:
		return n
	# Club nuevo: te quedas tu número si allí está libre (o te lo ganas).
	if not is_taken(player.club_id, n, suggested) and (n != 1 or player.position == "GK") and (not (n in ICONIC) or iconic_ok(player, -1, false)):
		return n
	return suggested

## ¿Lo lleva ya un compañero en este club? (`mine` = el tuyo de oficio, nunca ocupado)
static func is_taken(club_id: String, n: int, mine: int) -> bool:
	if n == mine:
		return false
	if n == 1:
		return true # el portero titular
	if n >= 2 and n <= 23:
		return not (n in _free_low(club_id))
	if n >= 24 and n <= 40:
		return n in _high_taken(club_id)
	return false

static func _free_low(club_id: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shirt_free:" + club_id)
	var pool: Array = []
	for n in range(2, 24):
		if not (n in ICONIC):
			pool.append(n)
	var out: Array = []
	for i in FREE_LOW:
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out

static func _high_taken(club_id: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shirt_high:" + club_id)
	var out: Array = []
	while out.size() < HIGH_TAKEN:
		var n: int = rng.randi_range(24, 40)
		if not (n in out):
			out.append(n)
	return out

## ¿Te dan un número de referente (10/7/9)? club_base_overall < 0 = sin dato.
static func iconic_ok(player: PlayerData, club_base_overall: int, is_captain: bool) -> bool:
	if is_captain or player.reputation >= ICONIC_REPUTATION:
		return true
	return club_base_overall >= 0 and player.overall >= club_base_overall + ICONIC_OVR_MARGIN

## Estado de un número para la pantalla de elegir:
## "mine" | "free" | "taken" | "gk_only" | "iconic_locked" | "iconic_free"
static func status(player: PlayerData, world_seed: int, n: int, club_base_overall: int, is_captain: bool) -> String:
	var current: int = number_for(player, world_seed)
	if n == current:
		return "mine"
	var suggested: int = Kit.suggested_number(player.position, "%s|%d" % [player.player_name, world_seed])
	if n == 1 and player.position != "GK":
		return "gk_only"
	if n in ICONIC:
		return "iconic_free" if iconic_ok(player, club_base_overall, is_captain) else "iconic_locked"
	return "taken" if is_taken(player.club_id, n, suggested) else "free"

## "" si hoy puedes cambiar de dorsal; si no, el motivo.
static func blocker(player: PlayerData, season: Dictionary, window_open: bool) -> String:
	if player == null or player.club_id == "":
		return "Sin club."
	if bool(season.get("shirt_number_changed", false)):
		return "Ya cambiaste de dorsal esta temporada."
	if not window_open:
		return "El dorsal solo se cambia con el mercado de fichajes abierto."
	return ""

## Cambia el dorsal. Devuelve {ok, message, iconic}.
static func choose(player: PlayerData, season: Dictionary, world_seed: int, n: int, club_base_overall: int, is_captain: bool, window_open: bool) -> Dictionary:
	var b: String = blocker(player, season, window_open)
	if b != "":
		return {"ok": false, "message": b}
	if n < 1 or n > 99:
		return {"ok": false, "message": "Número no válido."}
	var st: String = status(player, world_seed, n, club_base_overall, is_captain)
	match st:
		"mine":
			return {"ok": false, "message": "Ya llevas el %d." % n}
		"taken":
			return {"ok": false, "message": "El %d lo lleva un compañero." % n}
		"gk_only":
			return {"ok": false, "message": "El 1 es del portero."}
		"iconic_locked":
			return {"ok": false, "message": "El %d es del referente del equipo. Gánatelo: más media que el resto, la capitanía o más reputación." % n}
	player.active_effects[KEY] = {"club_id": player.club_id, "number": n}
	season["shirt_number_changed"] = true
	return {"ok": true, "message": "Desde hoy llevas el %d." % n, "iconic": n in ICONIC}
