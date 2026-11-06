extends RefCounted
class_name SuperCupEngine

## Supercopas (partido único al arrancar la temporada) y Mundial de Clubes
## (cada 4 años: 2025, 2029, 2033...). Todo DERIVADO/determinista del
## world_seed + año — nada se persiste, mismo criterio que el resto del
## mundo vivo. No simula la temporada anterior entera: elige campeones con
## un mini-torneo relámpago sesgado por fuerza, estable por año.
##
## V1: son competiciones para MIRAR en Explorar mundo. Que el usuario las
## JUEGUE (si su club ganó liga/copa/continental) es el siguiente paso.

const CWC_BASE_YEAR := 2025

static func is_cwc_year(season_year: int) -> bool:
	return season_year >= CWC_BASE_YEAR and (season_year - CWC_BASE_YEAR) % 4 == 0

## Campeón determinista de una competición de la temporada PASADA, elegido
## del `pool` (club_ids) con moneda sesgada por fuerza.
static func prev_winner(pool: Array, key: String, world_seed: int, season_year: int, strength_by_club: Dictionary) -> String:
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [key, season_year - 1]) ^ world_seed
	var field: Array = pool.duplicate()
	field.sort_custom(func(a, b): return float(strength_by_club.get(a, 55)) > float(strength_by_club.get(b, 55)))
	var size: int = 16 if field.size() >= 16 else (8 if field.size() >= 8 else 4 if field.size() >= 4 else field.size())
	field = field.slice(0, size)
	while field.size() > 1:
		var nxt: Array = []
		for i in range(0, field.size() - 1, 2):
			nxt.append(_winner(field[i], field[i + 1], rng, strength_by_club))
		if field.size() % 2 == 1:
			nxt.append(field[-1])
		field = nxt
	return String(field[0])

static func _winner(a: String, b: String, rng: RandomNumberGenerator, sbc: Dictionary) -> String:
	var sa: float = float(sbc.get(a, 55))
	var sb: float = float(sbc.get(b, 55))
	var p: float = clampf(0.5 + (sa - sb) * 0.014, 0.14, 0.86)
	return a if rng.randf() < p else b

## Un partido único: {home, away, gh, ga, winner}.
static func single_match(home_id: String, away_id: String, key: String, world_seed: int, season_year: int, sbc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|sc|%d" % [key, season_year]) ^ world_seed
	var sa: float = float(sbc.get(home_id, 55))
	var sb: float = float(sbc.get(away_id, 55))
	var gh: int = _goals(sa, sb, rng)
	var ga: int = _goals(sb, sa, rng)
	var w: String
	var pens: Array = []  # [ph, pa] si hubo tanda de penales
	if gh > ga:
		w = home_id
	elif ga > gh:
		w = away_id
	else:
		# Empate en los 90: tanda de penales (a partido único no hay
		# desempate por goles de visitante).
		var home_wins: bool = rng.randf() < clampf(0.5 + (sa - sb) * 0.012, 0.2, 0.8)
		w = home_id if home_wins else away_id
		var loser_pens: int = rng.randi_range(2, 4)
		var winner_pens: int = loser_pens + rng.randi_range(1, 2)
		pens = [winner_pens, loser_pens] if home_wins else [loser_pens, winner_pens]
	return {"home": home_id, "away": away_id, "gh": gh, "ga": ga, "winner": w, "pens": pens}

static func _goals(atk: float, def: float, rng: RandomNumberGenerator) -> int:
	var lam: float = clampf(1.35 + (atk - def) * 0.03, 0.25, 4.0)
	var g: int = 0
	var pr: float = exp(-lam)
	var cum: float = pr
	var r: float = rng.randf()
	while r > cum and g < 7:
		g += 1
		pr *= lam / float(g)
		cum += pr
	return g

# --- Armado de todas las supercopas de un año ---

## `pool_by_conf` = {conf: [club_ids ordenados por fuerza desc]}
## `country_pools` = {country: {"top": [ids liga], "all": [ids liga+copa]}}
## Supercopa continental de UNA confederación (campeón nivel 1 vs campeón
## nivel 2 del año pasado). {} si el pool es muy chico o coinciden.
static func continental_supercup(conf: String, world_seed: int, season_year: int, sbc: Dictionary, pool_by_conf: Dictionary) -> Dictionary:
	var pool: Array = pool_by_conf.get(conf, [])
	if pool.size() < 4:
		return {}
	var t1_pool: Array = pool.slice(0, maxi(8, pool.size() / 2))
	var t2_pool: Array = pool.slice(pool.size() / 3, pool.size())
	var c1: String = prev_winner(t1_pool, "cont1:%s" % conf, world_seed, season_year, sbc)
	var c2: String = prev_winner(t2_pool, "cont2:%s" % conf, world_seed, season_year, sbc)
	if c1 == "" or c2 == "" or c1 == c2:
		return {}
	return {
		"kind": "continental",
		"conf": conf,
		"name": "Supercopa de %s" % Confederations.REGION.get(conf, conf),
		"subtitle": "%s vs %s" % [CompetitionNames.continental(conf, 1), CompetitionNames.continental(conf, 2)],
		"match": single_match(c1, c2, "supercont:%s" % conf, world_seed, season_year, sbc),
	}

## Supercopa doméstica de UN país (campeón de liga vs campeón de copa del
## año pasado). {} si el país no tiene los dos campeones distintos.
static func domestic_supercup(country: String, world_seed: int, season_year: int, sbc: Dictionary, country_pools: Dictionary) -> Dictionary:
	if country == "" or not country_pools.has(country):
		return {}
	var cp: Dictionary = country_pools[country]
	var lg_champ: String = prev_winner(cp.get("top", []), "liga:%s" % country, world_seed, season_year, sbc)
	var cup_champ: String = prev_winner(cp.get("all", []), "copa:%s" % country, world_seed, season_year, sbc)
	if lg_champ == "" or cup_champ == "" or lg_champ == cup_champ:
		return {}
	return {
		"kind": "domestic",
		"country": country,
		"name": "Supercopa de %s" % country,
		"subtitle": "Campeón de liga vs campeón de copa",
		"match": single_match(lg_champ, cup_champ, "superdom:%s" % country, world_seed, season_year, sbc),
	}

static func season_supercups(world_seed: int, season_year: int, sbc: Dictionary, pool_by_conf: Dictionary, user_country: String, country_pools: Dictionary) -> Array:
	var out: Array = []
	for conf in pool_by_conf:
		var cs: Dictionary = continental_supercup(conf, world_seed, season_year, sbc, pool_by_conf)
		if not cs.is_empty():
			out.append(cs)
	var ds: Dictionary = domestic_supercup(user_country, world_seed, season_year, sbc, country_pools)
	if not ds.is_empty():
		out.append(ds)
	return out

## Mundial de Clubes de un año (solo si `is_cwc_year`). Devuelve el cuadro
## resuelto (SeasonEngine.resolve_cup) con `current_epoch_day` para el gate.
static func club_world_cup(world_seed: int, season_year: int, sbc: Dictionary, pool_by_conf: Dictionary, anchor: int, current_epoch_day: int) -> Dictionary:
	if not is_cwc_year(season_year):
		return {}
	# 16 clubes: 4 UEFA, 4 CONMEBOL, 2 CONCACAF, 2 AFC, 2 CAF, 2 comodín UEFA.
	var slots := {"UEFA": 6, "CONMEBOL": 4, "CONCACAF": 2, "AFC": 2, "CAF": 2}
	var field: Array = []
	for conf in slots:
		var pool: Array = pool_by_conf.get(conf, [])
		for i in range(mini(int(slots[conf]), pool.size())):
			# los N más fuertes de cada conf, con un pequeño barajado por año
			field.append(String(pool[i]))
	if field.size() < 8:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cwc|%d" % season_year) ^ world_seed
	for i in range(field.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = field[i]; field[i] = field[j]; field[j] = tmp
	var start: int = anchor + 120
	var bracket: Dictionary = SeasonCalendar.build_continental_bracket(field, "cwc_%d" % season_year, "Mundial de Clubes %d" % season_year, start, 70)
	return SeasonEngine.resolve_cup(bracket, world_seed, sbc, {}, current_epoch_day)
