extends Node

## Prueba dirigida del bug real reportado por Wilber (Parte 88): "con 1
## millón me compro 4 campamentos de alto rendimiento y se rompería el
## juego". Causa raíz: ShopEngine.buy() ya topeaba la COMPRA a 2/temporada
## (TRAINING_CAMP_SEASON_LIMIT), pero use() no topeaba nada — comprar 2 en
## una temporada + 2 en la siguiente sin usarlos dejaba 4 en el
## inventario, y se podían ACTIVAR los 4 de una sentada (8 atributos +1
## garantizados de golpe). Verifica que ahora, con 4 campamentos ya en el
## inventario (simulando exactamente ese escenario de 2 temporadas), solo
## se puede usar 2 en la temporada actual — el 3° y 4° quedan rechazados
## y NO tocan los atributos del jugador.
##   godot --headless res://tools/TrainingCampCapProbe.tscn

func _ready() -> void:
	var problems: int = 0

	var p := PlayerData.new()
	p.player_name = "Probe Campamento"
	p.overall = 60
	p.potential = 99
	p.shooting = 60
	p.passing = 60
	p.dribbling = 60
	p.balance = 10_000_000
	# Simula el escenario reportado: 4 campamentos ya comprados (de 2
	# temporadas distintas, algo que ShopEngine.buy() nunca prohibió por
	# sí solo — el inventario no se resetea entre temporadas).
	p.consumables["training_camp"] = 4

	var season: Dictionary = {}  # temporada NUEVA: 0 usos todavía
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var used_ok: int = 0
	var used_blocked: int = 0
	for i in range(4):
		var res: Dictionary = ShopEngine.use(p, "training_camp", rng, season)
		if bool(res.get("ok", false)):
			used_ok += 1
		else:
			used_blocked += 1
			print("uso #%d rechazado: %s" % [i + 1, res.get("message", "")])

	print("usados=%d bloqueados=%d (esperado 2/2) inventario restante=%d" % [
		used_ok, used_blocked, int(p.consumables.get("training_camp", 0))])
	if used_ok != ShopEngine.TRAINING_CAMP_SEASON_LIMIT:
		print("FALLA 1: se usaron %d, se esperaban %d" % [used_ok, ShopEngine.TRAINING_CAMP_SEASON_LIMIT])
		problems += 1
	if used_blocked != 2:
		print("FALLA 2: se bloquearon %d, se esperaban 2" % used_blocked)
		problems += 1
	# El inventario SOLO baja con usos exitosos (2), no con los rechazados.
	if int(p.consumables.get("training_camp", 0)) != 2:
		print("FALLA 3: inventario quedó en %d, se esperaban 2 (4 - 2 usados)" % int(p.consumables.get("training_camp", 0)))
		problems += 1

	# Nueva temporada (dict fresco, como hace SeasonCalendar.build_season
	# de verdad en cada rollover): el cupo de USO vuelve a 2, aunque el
	# inventario siga teniendo los 2 que sobraron.
	var season2: Dictionary = {}
	var uses_left_new_season: int = ShopEngine.training_camp_uses_left(season2)
	print("cupo de uso en temporada nueva: %d (esperado %d)" % [uses_left_new_season, ShopEngine.TRAINING_CAMP_SEASON_LIMIT])
	if uses_left_new_season != ShopEngine.TRAINING_CAMP_SEASON_LIMIT:
		print("FALLA 4: el cupo de uso no se resetea en una temporada nueva")
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
