extends RefCounted
class_name RivalryEngine

## Rivalidades — pedido explícito, 3 tipos:
##  1) Entre CLUBES (clásicos/derbis): cada club de una liga tiene un
##     rival ESTABLE dentro de su propia liga.
##  2) Pujas cruzadas por el mismo fichaje: ya viven en
##     TransferMarketEngine (campo "bidders" de cada fichaje "potente") —
##     no se duplica acá, esto es solo para las otras dos.
##  3) Entre JUGADORES de un mismo plantel, por la titularidad.
##
## Mundo vivo: todo determinista, recalculado desde cero cada vez que se
## pide, nunca persistido.

## Rival de club ESTABLE dentro de su propia liga — emparejamiento por
## sorteo determinista (Fisher-Yates sembrado), cada club queda pareado
## con otro exactamente uno (si la liga tiene un nº impar de equipos, el
## último del sorteo se queda sin rival esa liga). "" si no tiene.
static func club_rival_for(world: Dictionary, club_id: String, world_seed: int) -> String:
	var meta: Dictionary = world.get("club_meta_by_id", {}).get(club_id, {})
	if meta.is_empty():
		return ""
	var league_id: int = int(meta.get("league_id", -1))
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.size() < 2:
		return ""

	var ids: Array = clubs.map(func(c): return c.club_id)
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rivals:%d" % league_id) ^ world_seed
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp

	var idx: int = ids.find(club_id)
	if idx == -1:
		return ""
	var partner_idx: int = idx + 1 if idx % 2 == 0 else idx - 1
	if partner_idx < 0 or partner_idx >= ids.size():
		return ""
	return String(ids[partner_idx])

## Compañero de plantel de la MISMA posición y mejor overall que compite
## por la titularidad de `player` — {} si nadie le hace sombra (es el
## mejor de su puesto, o juega solo). `intensity` (10-95) crece cuanto
## más lo supera en nivel: no es solo "están en la misma posición", es
## "cuánto le cuesta ganarle el puesto".
static func position_rival_for(player: PlayerData, squad: Array) -> Dictionary:
	var best: PlayerData = null
	for p in squad:
		if p == player or p.position != player.position:
			continue
		if String(p.player_name) == String(player.player_name):
			continue
		if best == null or p.overall > best.overall:
			best = p
	if best == null:
		return {}
	var gap: int = best.overall - player.overall
	var intensity: int = clampi(50 + gap * 3, 10, 95)
	return {"name": best.player_name, "overall": best.overall, "intensity": intensity, "reason": "Competencia por la titularidad"}
