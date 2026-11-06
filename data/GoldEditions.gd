extends RefCounted
class_name GoldEditions

## EDICIONES DORADAS de ropa (P3, 9-oct — "ediciones doradas por logros"):
## no se compran, se GANAN con un título o premio de la carrera
## (player.career_titles). Capas generadas con tools/gold_editions.py.

const RULES := [
	{"id": "traje_oro", "need": "Ganá el Balón de Oro", "prefix": "ballon_dor", "exact": true},
	{"id": "chandal_oro", "need": "Ganá una liga", "prefix": "league_"},
	{"id": "bomber_oro", "need": "Ganá la Bota de Oro de una liga", "prefix": "botaoro_"},
	{"id": "polo_oro", "need": "Ganá una copa continental", "kind": "continental"},
	{"id": "cuero_oro", "need": "Ganá el Mundial o el Mundial de Clubes", "kind": "world"},
]

static func is_gold(id: String) -> bool:
	for r in RULES:
		if String(r["id"]) == id:
			return true
	return false

static func rule(id: String) -> Dictionary:
	for r in RULES:
		if String(r["id"]) == id:
			return r
	return {}

static func earned(player: PlayerData, r: Dictionary) -> bool:
	for t in player.career_titles:
		var tid: String = String(t.get("id", ""))
		if r.has("prefix"):
			if bool(r.get("exact", false)) and tid == String(r["prefix"]):
				return true
			if not bool(r.get("exact", false)) and tid.begins_with(String(r["prefix"])):
				return true
		elif r.has("kind") and String(t.get("kind", "")) == String(r["kind"]):
			return true
	return false

## Agrega a cosmetics_owned las que ya se ganaron y no tenía. Devuelve las
## nuevas (para avisar).
static func sync(player: PlayerData) -> Array:
	var out: Array = []
	if player == null:
		return out
	for r in RULES:
		var id: String = String(r["id"])
		if not player.cosmetics_owned.has(id) and earned(player, r):
			player.cosmetics_owned.append(id)
			out.append(id)
	return out
