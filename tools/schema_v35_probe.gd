extends Node
## ESQUEMA v35 (11-oct): market_v2_from_day. Una carrera vieja conserva su
## temporada en curso EXACTA; los bombazos empiezan en la siguiente.
##   godot --headless --path . res://tools/SchemaV35Probe.tscn
func _ready() -> void:
	var fails: int = 0
	# 1) Migracion: v34 con temporada empezada -> from = inicio + 1.
	var old := {"schema_version": 34, "player": {"player_name": "X"}, "season": {"season_start_epoch_day": 20000}, "market_salt": 0}
	var mig: Dictionary = SaveManager._migrate_v34_to_v35(old.duplicate(true))
	if int(mig.get("schema_version", 0)) != 35 or int(mig.get("market_v2_from_day", -1)) != 20001:
		fails += 1
		print("FAIL migracion: ", mig.get("schema_version"), " ", mig.get("market_v2_from_day"))
	var fresh: Dictionary = SaveManager._migrate_v34_to_v35({"schema_version": 34, "player": {}})
	if int(fresh.get("market_v2_from_day", -1)) != 0:
		fails += 1
		print("FAIL carrera sin temporada debe quedar en 0")
	# 2) El mercado: con la regla apagada para ESTA temporada sale igual que antes; prendida, suma bombazos.
	var world := WorldFactory.build(4242)
	var ss: int = 20000
	TransferMarketEngine.set_salt(0)
	TransferMarketEngine.set_v2_from(ss + 1)
	var before: Array = TransferMarketEngine.season_transfers_cached(world, 4242, ss).duplicate(true)
	TransferMarketEngine.set_v2_from(0)
	var after: Array = TransferMarketEngine.season_transfers_cached(world, 4242, ss).duplicate(true)
	var same_prefix: bool = after.size() >= before.size()
	for i in range(mini(before.size(), after.size())):
		if str(before[i]) != str(after[i]):
			same_prefix = false
	var bombs: Array = after.filter(func(t): return bool(t.get("bombazo", false)))
	var legacy_bombs: int = before.filter(func(t): return bool(t.get("bombazo", false))).size()
	if not same_prefix or legacy_bombs != 0:
		fails += 1
		print("FAIL la temporada en curso de una carrera vieja cambio (%d vs %d, bombazos %d)" % [before.size(), after.size(), legacy_bombs])
	if bombs.size() < TransferMarketEngine.BOMBAZOS_MIN or bombs.size() > TransferMarketEngine.BOMBAZOS_MAX:
		fails += 1
		print("FAIL cantidad de bombazos: ", bombs.size())
	var top_before: int = 0
	for t in before:
		top_before = maxi(top_before, int(t["overall"]))
	print("temporada vieja: %d fichajes, media mas alta %d, 0 bombazos" % [before.size(), top_before])
	for b in bombs:
		var o: ClubData = WorldFactory.find_club(world, String(b["origin_club_id"]))
		var d: ClubData = WorldFactory.find_club(world, String(b["destination_club_id"]))
		print("  BOMBAZO: %s (%s, %d, %d anios) %s -> %s por %s" % [b["player_name"], b["position"], b["overall"], b["age"], o.club_name if o else "?", d.club_name if d else "?", CurrencyFormat.format(int(b["fee"]))])
		if String(b["origin_club_id"]) == String(b["destination_club_id"]):
			fails += 1
	# 3) Varias temporadas: siempre hay, y no son siempre los mismos.
	var names := {}
	var total: int = 0
	for k in range(6):
		var arr: Array = TransferMarketEngine.generate_season_transfers(world, 4242, ss + 365 * (k + 1))
		for t in arr:
			if bool(t.get("bombazo", false)):
				names[String(t["player_name"])] = true
				total += 1
	print("6 temporadas mas: %d bombazos, %d jugadores distintos" % [total, names.size()])
	if total < 12 or names.size() < 8:
		fails += 1
		print("FAIL pocos bombazos o siempre los mismos")
	# 4) Los planteles se arman con los bombazos aplicados (no rompe nada).
	if not bombs.is_empty():
		var sq: Array = WorldFactory.make_squad_with_transfers(world, String(bombs[0]["destination_club_id"]), 4242, ss)
		var found: bool = false
		for p in sq:
			if p.player_name == String(bombs[0]["player_name"]):
				found = true
		if not found:
			fails += 1
			print("FAIL el bombazo no aparece en el plantel de destino")
		else:
			print("OK   la figura aparece en el plantel de su nuevo club")
	TransferMarketEngine.set_v2_from(0)
	print("PROBE ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
