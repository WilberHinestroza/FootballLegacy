extends Node

## Prueba dirigida: "en el mercado deben ir pasando fichajes cada día, no
## que al primer día pase de una todo, y hasta puede haber un bombazo el
## último día" — TransferMarketEngine.generate_season_transfers() ahora
## le pone un "day" real a cada fichaje (dentro de la ventana de verano o
## invierno), y Transfers.gd._render_world() oculta los que todavía no
## llegaron a su día. Este probe verifica el motor (día real, repartido,
## no todo en el día 0) y el filtro de la pantalla (día a día).
##   godot --headless res://tools/TransferMarketTrickleProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var season_start: int = 0
	var transfers: Array = TransferMarketEngine.generate_season_transfers(world, world_seed, season_start)
	var ok: bool = true

	print("total de fichajes: %d" % transfers.size())
	if transfers.is_empty():
		print("PROBE FAIL (sin fichajes para probar)")
		get_tree().quit(1)
		return

	var w: int = SeasonCalendar.TRANSFER_WINDOW_DAYS
	var mid: int = SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET
	var day0_count: int = 0
	var distinct_days: Dictionary = {}
	var bombazo_last3_count: int = 0
	var bombazo_total: int = 0
	for t in transfers:
		if not t.has("day"):
			print("FALLA: fichaje sin campo 'day': %s" % t)
			ok = false
			continue
		var d: int = int(t["day"])
		var in_summer: bool = d >= season_start and d < season_start + w
		var in_winter: bool = d >= season_start + mid and d < season_start + mid + w
		if not (in_summer or in_winter):
			print("FALLA: día %d fuera de ambas ventanas de fichajes" % d)
			ok = false
		if d == season_start:
			day0_count += 1
		distinct_days[d] = true
		if String(t.get("tier", "")) == "potente" and String(t.get("kind", "")) != "cesión":
			bombazo_total += 1
			var w_start: int = season_start if in_summer else season_start + mid
			if d >= w_start + w - 3:
				bombazo_last3_count += 1

	print("fichajes en el día exacto de apertura (día 0): %d de %d" % [day0_count, transfers.size()])
	print("días distintos usados: %d" % distinct_days.size())
	print("fichajes 'potente' en los últimos 3 días de su ventana: %d de %d" % [bombazo_last3_count, bombazo_total])

	# No todo el mercado debe caer el mismo día (el bug real reportado).
	if day0_count == transfers.size():
		print("FALLA: TODOS los fichajes cayeron el día 0 — no se repartió nada")
		ok = false
	if distinct_days.size() < 5:
		print("FALLA: muy pocos días distintos (%d) para %d fichajes — no se ve 'ir pasando'" % [distinct_days.size(), transfers.size()])
		ok = false
	# Los "potente" deberían inclinarse fuerte hacia el cierre (bombazo).
	if bombazo_total > 0 and float(bombazo_last3_count) / float(bombazo_total) < 0.6:
		print("FALLA: los fichajes 'potente' no se están concentrando en el cierre de la ventana")
		ok = false

	# --- Pantalla: el filtro por día oculta lo que no llegó todavía ---
	var visible_at_open: int = transfers.filter(func(t): return int(t["day"]) <= season_start).size()
	var visible_at_window_end: int = transfers.filter(func(t): return int(t["day"]) <= season_start + w - 1).size()
	print("visibles el día de apertura: %d" % visible_at_open)
	print("visibles al cerrar la ventana de verano (día %d): %d" % [w - 1, visible_at_window_end])
	if visible_at_open >= visible_at_window_end:
		print("FALLA: no hay más fichajes visibles al cerrar la ventana que al abrirla")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
