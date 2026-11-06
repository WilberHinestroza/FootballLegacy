extends RefCounted
class_name LoanEngine

## Cesiones (préstamos) — el JUGADOR pide salir cedido cuando es joven y no
## juega, y ELIGE el club de una lista. Se ejecuta en la próxima ventana
## (mismo canal que TransferOfferEngine: season["pending_transfer"] con
## kind "cesión"). Al terminar la temporada, WorldTickEngine lo devuelve
## al club padre (season["loan_return"]).
##
## Estado en el dict `season` (aditivo, sin cambio de esquema):
##   pending_transfer.kind == "cesión" + parent_club_id/parent_wage/
##     parent_contract_years  -> préstamo pactado, se concreta en la ventana
##   season["loan_return"]  -> {parent_club_id, parent_club_name, parent_wage,
##     parent_contract_years}  -> el rollover lo usa para devolverte

const MAX_AGE := 21
const CANDIDATES := 3

static func can_request(player: PlayerData, season: Dictionary, day: int) -> bool:
	if player == null or player.club_id == "":
		return false
	if player.age > MAX_AGE:
		return false
	if not season.get("pending_transfer", {}).is_empty():
		return false
	if season.get("loan_return", null) != null:
		return false # ya estás cedido
	# Solo si NO estás jugando: poca titularidad y/o poca confianza del DT.
	var barely_playing: bool = player.season_appearances <= 3
	return barely_playing or player.coach_trust < 52

## 3 clubes que te darían minutos: de reputación algo menor a la de tu
## club (o similar), nunca tu propio club. Determinista por día+seed.
static func candidates(player: PlayerData, world: Dictionary, world_seed: int, day: int) -> Array:
	var by_league: Dictionary = world.get("clubs_by_league", {})
	var meta: Dictionary = world.get("club_meta_by_id", {})
	var my_ovr: int = int(meta.get(player.club_id, {}).get("base_overall", 60))
	var pool: Array = []
	for arr in by_league.values():
		for c in arr:
			if c.club_id == player.club_id:
				continue
			var ovr: int = int(meta.get(c.club_id, {}).get("base_overall", 55))
			# clubes entre 12 por debajo y 4 por encima de tu club: sitios
			# donde un joven promesa sí sería titular.
			if ovr >= my_ovr - 12 and ovr <= my_ovr + 4:
				pool.append(c)
	if pool.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("loan_cands:%d:%s" % [day, player.club_id]) ^ world_seed
	# barajado determinista
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var t = pool[i]; pool[i] = pool[j]; pool[j] = t

	# De ese pool, priorizar los clubes donde el jugador REALMENTE jugaría
	# su puesto — no sirve una cesión a un club que ya tiene la posición
	# tapada (pedido de Wilber: "las cesiones también, por posición").
	# Se limita a los primeros ~14 del barajado para no reconstruir
	# decenas de planteles (esto solo corre al abrir el selector).
	var short_pool: Array = pool.slice(0, mini(pool.size(), 14))
	var squad_cache: Dictionary = {}
	var scored: Array = []
	for c in short_pool:
		var csquad: Array = _need_squad(c.club_id, meta, squad_cache)
		var same_detail: int = 0
		var same_broad: int = 0
		for sp in csquad:
			if String(sp.detailed_position) == player.detailed_position:
				same_detail += 1
			if String(sp.position) == player.position:
				same_broad += 1
		# Peso: puesto exacto libre pesa mucho; línea entera fina, algo.
		var w: float = 1.0
		if same_detail == 0:
			w *= 2.4
		elif same_detail == 1:
			w *= 1.5
		elif same_detail >= 3:
			w *= 0.55
		if same_broad <= 2:
			w *= 1.3
		# Efraimidis-Spirakis: clave = rand^(1/peso), mayor gana.
		scored.append({"club": c, "k": pow(rng.randf(), 1.0 / maxf(w, 0.05))})
	scored.sort_custom(func(a, b): return float(a["k"]) > float(b["k"]))

	var out: Array = []
	for entry in scored.slice(0, CANDIDATES):
		var c: ClubData = entry["club"]
		out.append({
			"club_id": c.club_id, "club_name": c.club_name,
			"league_id": c.league_id,
			"ovr": int(meta.get(c.club_id, {}).get("base_overall", 55)),
		})
	return out

## Plantel de un club (cacheado local) para medir necesidad de puesto.
static func _need_squad(club_id: String, meta: Dictionary, cache: Dictionary) -> Array:
	if not cache.has(club_id):
		cache[club_id] = WorldFactory.make_squad(meta.get(club_id, {}))
	return cache[club_id]

## Pacta la cesión al club elegido. Se concreta en `next_window_day`.
static func request(player: PlayerData, season: Dictionary, club_id: String, club_name: String, day: int, next_window_day: int) -> Dictionary:
	if not can_request(player, season, day):
		return {"ok": false, "message": "Ahora no podés pedir salir cedido."}
	var pending := {
		"id": "loan_%d" % day,
		"from_club_id": club_id,
		"from_club_name": club_name,
		"kind": "cesión",
		"fee": 0,
		"wage": player.wage,
		"contract_years": 1,
		"window_day": next_window_day,
		"created_day": day,
		"parent_club_id": player.club_id,
		"parent_wage": player.wage,
		"parent_contract_years": player.contract_years_remaining,
	}
	season["pending_transfer"] = pending
	season["transfer_inbox"] = []
	return {"ok": true, "message": "Pediste salir cedido a %s. Se concreta en la próxima ventana." % club_name}

## Devuelve el club padre al que hay que volver, o {} si no hay cesión activa.
static func return_target(season: Dictionary) -> Dictionary:
	var lr = season.get("loan_return", null)
	return lr if lr is Dictionary else {}
