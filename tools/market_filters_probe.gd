extends "res://tools/ui_gallery_probe.gd"
## MERCADO con filtros (11-oct). Captura REAL + conteos. slot_3.
##   godot --path . --resolution 432x936 res://tools/MarketFiltersProbe.tscn
func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var ss: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	WorldTickEngine.current_epoch_day = ss + SeasonCalendar.TRANSFER_WINDOW_DAYS   # fin de la ventana: ya paso todo lo del verano
	var all: Array = TransferMarketEngine.season_transfers_cached(WorldTickEngine.world, WorldTickEngine.world_seed, ss)
	var stars: int = 0
	var top_ov: int = 0
	var with_age: int = 0
	for t in all:
		if String(t.get("tier", "")) == "potente":
			stars += 1
		top_ov = maxi(top_ov, int(t.get("overall", 0)))
		if int(t.get("age", 0)) > 0 and int(t.get("value", 0)) > 0:
			with_age += 1
	print("fichajes de la temporada: %d · bombazos (85+): %d · media mas alta que se movio: %d · con edad y valor: %d" % [all.size(), stars, top_ov, with_age])
	var sc: Node = (load("res://scenes/Transfers/Transfers.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(sc)
	for i in range(40):
		await get_tree().process_frame
	sc.call("_on_tab", "market")
	for i in range(30):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/market_filters.png"))
	var fails: int = 0
	# Cada filtro deja solo lo que corresponde.
	sc.set("_f_age", "u21")
	sc.set("_f_fee", "")
	var young: Array = all.filter(func(t): return sc.call("_passes_filters", t))
	for t in young:
		if int(t.get("age", 99)) > 21:
			fails += 1
	sc.set("_f_age", "")
	sc.set("_f_fee", "high")
	var pricey: Array = all.filter(func(t): return sc.call("_passes_filters", t))
	for t in pricey:
		if int(t.get("value", 0)) < 10000 or int(t.get("value", 0)) >= 50000:
			fails += 1
	sc.set("_f_fee", "")
	sc.set("_f_pos", "GK")
	var gks: Array = all.filter(func(t): return sc.call("_passes_filters", t))
	for t in gks:
		if String(t.get("position", "")) != "GK":
			fails += 1
	print("hasta 21: %d · de 10M a 50M: %d · arqueros: %d" % [young.size(), pricey.size(), gks.size()])
	sc.set("_f_pos", "")
	sc.set("_f_age", "u21")
	sc.call("_render")
	for i in range(30):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/market_filters_u21.png"))
	if with_age != all.size():
		fails += 1
		print("FAIL hay fichajes sin edad o valor")
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
