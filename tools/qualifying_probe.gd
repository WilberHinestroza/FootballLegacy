extends Node

## Diagnóstico de Fase 1 (selecciones nacionales): construye un par de
## mundos de prueba (NUNCA toca un save real) y corre QualifyingEngine
## para las 5 confederaciones en 3 puntos del ciclo (arranque / mitad /
## final), verificando que cada una produce un campo de clasificados de
## tamaño creíble, sin crashear, y sin duplicar/perder países.
##   godot --headless res://tools/QualifyingProbe.tscn

const SEEDS := [20260906, 777, 4242]

func _ready() -> void:
	var bad: int = 0
	for seed_i in SEEDS:
		bad += _probe_seed(seed_i)
	print("PROBE ", "OK" if bad == 0 else "FAIL (%d)" % bad)
	get_tree().quit(1 if bad > 0 else 0)

func _probe_seed(world_seed: int) -> int:
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))
	var strength_by_country: Dictionary = NationalTeamFactory.strength_by_country(world, strength_by_club)

	var problems: int = 0
	for confederation in Confederations.ALL:
		var pool_size: int = 0
		for country in Confederations.COUNTRY_TO_CONFEDERATION:
			if Confederations.confederation_of(country) == confederation:
				pool_size += 1

		var windows: Array = SeasonCalendar.international_windows_in_range(0, QualifyingEngine.CYCLE_QUALIFYING_DAYS, 0)

		# 3 puntos del ciclo: recién arrancado, a mitad, y ya resuelto.
		for frac in [0.0, 0.5, 1.05]:
			var day: int = int(round(float(QualifyingEngine.CYCLE_QUALIFYING_DAYS) * frac))
			var res: Dictionary = QualifyingEngine.resolve(confederation, strength_by_country, world_seed, day, 0, {}, windows)
			if res.is_empty():
				print("  [%d] %s día %d: VACÍO (pool=%d)" % [world_seed, confederation, day, pool_size])
				problems += 1
				continue
			var direct: Array = res.get("direct", [])
			var playoff: Array = res.get("playoff_pool", [])
			var eliminated: Array = res.get("eliminated", [])
			var total: int = direct.size() + playoff.size() + eliminated.size()
			var all_ids: Array = direct + playoff + eliminated
			var seen: Dictionary = {}
			var dupes: int = 0
			for cid in all_ids:
				if seen.has(cid):
					dupes += 1
				seen[cid] = true
			if total != pool_size or dupes > 0:
				print("  [%d] %s día %d formato=%s: total=%d pool=%d dupes=%d direct=%d playoff=%d elim=%d" % [
					world_seed, confederation, day, res.get("format", "?"), total, pool_size, dupes,
					direct.size(), playoff.size(), eliminated.size()])
				problems += 1
			else:
				print("  [%d] %s día %d formato=%s OK: direct=%d playoff=%d elim=%d" % [
					world_seed, confederation, day, res.get("format", "?"), direct.size(), playoff.size(), eliminated.size()])

			# Verifica que TODOS los fixtures caigan dentro de alguna ventana
			# FIFA — el hallazgo real de la Parte 81 era exactamente que no
			# pasaba esto.
			var all_fixtures: Array = []
			if String(res.get("format", "")) == "table":
				all_fixtures = res.get("fixtures", [])
			else:
				for g in res.get("groups", []):
					all_fixtures.append_array(g.get("fixtures", []))
			var out_of_window: int = 0
			for fx in all_fixtures:
				var d: int = int(fx.get("epoch_day", -1))
				var inside: bool = false
				for w in windows:
					if d >= int(w[0]) and d <= int(w[1]):
						inside = true
						break
				if not inside:
					out_of_window += 1
			if out_of_window > 0:
				print("    !! %d/%d fixtures FUERA de ventana FIFA" % [out_of_window, all_fixtures.size()])
				problems += 1

			# Repechaje (Item 3, "hazlo todo"): al final del ciclo (frac=1.05,
			# bien pasado el día del repechaje) ya no debe quedar NADIE en
			# "zona de repechaje" para formato "groups" — o quedó clasificado
			# (direct) o quedó eliminado, nunca los dos, nunca en limbo.
			if frac > 1.0 and String(res.get("format", "")) == "groups" and not playoff.is_empty():
				print("  [%d] %s día %d: repechaje SIN RESOLVER (%d países en limbo)" % [world_seed, confederation, day, playoff.size()])
				problems += 1
	return problems
