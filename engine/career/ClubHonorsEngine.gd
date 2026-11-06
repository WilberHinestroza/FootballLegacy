extends RefCounted
class_name ClubHonorsEngine

## Palmarés HISTÓRICO de un club — derivado de su prestigio (fuerza +
## reputación de liga) y el world_seed. NADA se persiste: mismo principio
## que el resto del "mundo vivo". Dos clubes iguales en dos partidas con
## distinto seed tienen vitrinas distintas, pero siempre coherentes con su
## tamaño (un grande tiene decenas de ligas, un chico ninguna).
##
## Devuelve Array de { id, name, count, icon, tier, last_year } ordenado de
## más prestigioso a menos, saltando las categorías con count 0.

const _CATS := [
	# id,                nombre,                    icono Trophy,      peso, umbral_prestigio
	["league",           "Liga",                    "mvp_liga",        1.00, 0],
	["domestic_cup",     "Copa nacional",           "supercopa",       0.85, 0],
	["domestic_supercup","Supercopa nacional",      "supercopa",       0.55, 30],
	["continental_2",    "Copa continental (2ª)",   "continental_cup", 0.40, 52],
	["continental_1",    "Copa continental (1ª)",   "continental_cup", 0.30, 72],
	["club_world_cup",   "Mundial de Clubes",       "mundial_clubes",  0.16, 86],
]

## `prestige` 0..100. `strength` es _strength_by_club (30..99), `league_rep`
## la reputación de la liga (0..100).
static func prestige_of(strength: int, league_rep: int) -> int:
	return clampi(int(round(strength * 0.62 + league_rep * 0.38)), 0, 100)

static func for_club(club_id: String, world_seed: int, strength: int, league_rep: int, current_year: int) -> Array:
	var prestige: int = prestige_of(strength, league_rep)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("palmares:" + club_id) ^ world_seed
	var founded: int = current_year - rng.randi_range(40, 128)

	var out: Array = []
	for cat in _CATS:
		var cid: String = cat[0]
		var threshold: int = int(cat[4])
		if prestige < threshold:
			continue
		var head: float = float(prestige - threshold) / float(maxi(100 - threshold, 1))  # 0..1
		var scale: float = float(cat[3])
		# curva: los muy grandes acumulan muchísimo, los medianos poco.
		var base: float = pow(head, 2.15) * 46.0 * scale
		var jitter: float = rng.randf_range(0.68, 1.32)
		var count: int = int(round(base * jitter))
		if cid == "league" and prestige >= 55:
			count = maxi(count, 1)
		if count <= 0:
			continue
		var last_year: int = clampi(current_year - rng.randi_range(0, maxi(3, int(28 - head * 26))), founded, current_year)
		out.append({
			"id": cid,
			"name": String(cat[1]),
			"count": count,
			"icon": String(cat[2]),
			"tier": _tier_for(cid),
			"last_year": last_year,
		})
	out.sort_custom(func(a, b): return _cat_rank(a["id"]) < _cat_rank(b["id"]))
	return out

## Total de títulos mayores — para una línea resumen.
static func total_count(entries: Array) -> int:
	var t: int = 0
	for e in entries:
		t += int(e["count"])
	return t

static func _tier_for(cid: String) -> String:
	match cid:
		"club_world_cup", "continental_1": return "gold"
		"continental_2", "domestic_supercup": return "silver"
		_: return "bronze"

static func _cat_rank(cid: String) -> int:
	for i in range(_CATS.size()):
		if _CATS[i][0] == cid:
			return i
	return 99
