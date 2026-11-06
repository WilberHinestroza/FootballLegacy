extends Node
## Cobertura del arte NUEVO (Trophy.V3_ART): toda liga, copa doméstica,
## copa continental, copa de selecciones y premio debe resolver a un PNG
## de assets/trophies/v3 — sin caer a ningún arte viejo. Solo lectura.
##   godot --headless --path . res://tools/TrophyV3Probe.tscn
func _ready() -> void:
	var miss: Array = []
	var n: int = 0
	var world: Dictionary = WorldFactory.build(20260906)
	print("mundo importado: ", WorldFactory.has_imported_world(), " · ligas: ", world.get("leagues", []).size())
	var ids: Array = []
	for l in world.get("leagues", []):
		ids.append("league_%d" % l.league_id)
		ids.append("dcup_%s" % l.country)
	for id in ids:
		n += 1
		if Trophy._v3_node(id, 32) == null:
			miss.append(id)
	var honors: Array = Trophy.HONOR_IDS.duplicate()
	honors.append_array(["supercopa", "supercopa_cont", "mundial_clubes", "mundial_seleccion", "continental_cup", "copa_continental_seleccion", "mvp_match", "mvp_temporada"])
	for conf in ["UEFA", "CONMEBOL", "CONCACAF", "CAF", "AFC", "OFC"]:
		honors.append("natcup_%s" % conf)
		for tier in range(1, Confederations.tier_count(conf) + 1):
			honors.append("cont_%s_%d" % [conf, tier])
	for h in honors:
		n += 1
		if Trophy._v3_node(h, 32) == null and Trophy._v3_node(Trophy._family_fallback(h), 32) == null:
			miss.append(h)
	print("ids revisados: %d · sin arte v3: %d" % [n, miss.size()])
	for m in miss:
		print("  ", m)
	print("PROBE ", "OK" if miss.is_empty() else "FAIL")
	get_tree().quit(0 if miss.is_empty() else 1)
