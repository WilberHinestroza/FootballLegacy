extends Node

## Prueba dirigida de la Colección (SaveManager.archive_retired_career +
## Coleccion.gd._gather_careers): usa SOLO slot_3 (desechable) y
## user://retired_careers.json (se limpia antes y después). Verifica:
##  1) retirar una carrera la archiva y Coleccion la muestra.
##  2) re-retirar la MISMA carrera (mismo world_seed) actualiza, no duplica.
##  3) una carrera NUEVA en el mismo slot (world_seed distinto) se suma
##     como card aparte — no pisa el archivo de la anterior (el bug real
##     que encontré y corregí: upsert por slot_id+world_seed, no solo
##     slot_id).
##  4) si el slot sigue con la MISMA carrera ya retirada sin pisar, no se
##     duplica como "activa" además de "retirada".
##   godot --headless res://tools/ColeccionProbe.tscn

const RETIRED_PATH := "user://retired_careers.json"

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	# Estado limpio: sin esto, una corrida previa de este mismo probe (u
	# otra prueba) podría dejar entradas viejas y ensuciar los conteos.
	if FileAccess.file_exists(RETIRED_PATH):
		DirAccess.remove_absolute(RETIRED_PATH)

	var problems: int = 0

	# --- 1) Retirar la carrera A (seed 111) y archivarla ---
	var seed_a: int = 111
	SaveManager.save_world_seed(seed_a)
	var pa := PlayerData.new()
	pa.player_name = "Carrera A"
	pa.country = "Argentina"
	pa.club_id = "algún_club"
	pa.career_goals = 120
	pa.overall = 91
	pa.caps = 12
	pa.career_titles = [{"id": "league_1", "name": "Liga A", "kind": "team", "season": 2030, "metal": 1}]
	SaveManager.save_player(pa)
	pa.club_id = ""  # como hace ContractDecision al retirar
	SaveManager.save_player(pa)
	SaveManager.archive_retired_career(pa)

	var archived1: Array = SaveManager.load_retired_careers()
	if archived1.size() != 1:
		print("FALLA 1: esperaba 1 archivada, hay %d" % archived1.size())
		problems += 1

	# --- 2) Re-archivar la MISMA carrera (mismo seed) con más títulos: debe
	#     ACTUALIZAR, no sumar una segunda entrada ---
	pa.career_goals = 130
	pa.career_titles.append({"id": "league_1", "name": "Liga A", "kind": "team", "season": 2031, "metal": 1})
	SaveManager.archive_retired_career(pa)
	var archived2: Array = SaveManager.load_retired_careers()
	if archived2.size() != 1:
		print("FALLA 2: re-retirar la misma carrera debería seguir siendo 1, hay %d" % archived2.size())
		problems += 1
	elif int(archived2[0].get("career_goals", 0)) != 130:
		print("FALLA 2b: no actualizó los goles (quedó en %d)" % int(archived2[0].get("career_goals", 0)))
		problems += 1

	# --- 3) Carrera NUEVA en el MISMO slot (seed distinto) también se
	#     retira: debe sumar una SEGUNDA entrada, sin tocar la de A ---
	var seed_b: int = 222
	SaveManager.save_world_seed(seed_b)
	var pb := PlayerData.new()
	pb.player_name = "Carrera B"
	pb.country = "Brasil"
	pb.club_id = "otro_club"
	pb.career_goals = 40
	pb.overall = 78
	pb.caps = 30
	SaveManager.save_player(pb)
	pb.club_id = ""
	SaveManager.save_player(pb)
	SaveManager.archive_retired_career(pb)
	var archived3: Array = SaveManager.load_retired_careers()
	if archived3.size() != 2:
		print("FALLA 3: esperaba 2 archivadas (A y B), hay %d" % archived3.size())
		problems += 1
	var a_still_130: bool = false
	for c in archived3:
		if String(c.get("player_name", "")) == "Carrera A" and int(c.get("career_goals", 0)) == 130:
			a_still_130 = true
	if not a_still_130:
		print("FALLA 3b: archivar la carrera B pisó/perdió el registro de la carrera A")
		problems += 1

	# --- 4) Coleccion._gather_careers(): el slot_3 vive HOY con la carrera
	#     B todavía sin pisar (mismo seed_b) — no debe duplicarse como
	#     "activa" además de la archivada "retirada". La carrera A (seed
	#     distinto al que hoy vive el slot) debe aparecer una sola vez,
	#     como retirada. ---
	var packed: PackedScene = load("res://scenes/Coleccion/Coleccion.tscn")
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var careers: Array = inst._gather_careers()
	var slot3_cards: Array = []
	for c in careers:
		if String(c.get("player_name", "")) in ["Carrera A", "Carrera B"]:
			slot3_cards.append(c)
	print("cards de slot_3 en Colección: %d" % slot3_cards.size())
	for c in slot3_cards:
		print("  - %s status=%s goles=%d" % [c.get("player_name"), c.get("status"), int(c.get("career_goals", 0))])
	if slot3_cards.size() != 2:
		print("FALLA 4: esperaba exactamente 2 cards (A retirada + B retirada, sin duplicar B como activa), hay %d" % slot3_cards.size())
		problems += 1
	else:
		var b_row = slot3_cards.filter(func(c): return String(c.get("player_name")) == "Carrera B")[0]
		if String(b_row.get("status", "")) != "retirada":
			print("FALLA 4b: Carrera B debería figurar como 'retirada' (coincide con lo archivado), no '%s'" % b_row.get("status"))
			problems += 1

	# --- 5) _records_section() (Parte 91): Carrera A tiene más goles (130
	#     vs 40) Y más overall (91 vs 78); Carrera B tiene más caps (30 vs
	#     12) — las dos deberían aparecer como titulares de ALGÚN récord.
	var records: Control = inst._records_section(careers)
	var texts: Array = []
	_collect_label_texts(records, texts)
	var has_a: bool = texts.has("Carrera A")
	var has_b: bool = texts.has("Carrera B")
	print("récords: aparece Carrera A=%s, Carrera B=%s" % [has_a, has_b])
	if not has_a or not has_b:
		print("FALLA 5: se esperaba que ambas carreras encabecen al menos un récord cada una")
		problems += 1

	# Limpieza: no dejar rastro de esta prueba en el archivo real.
	if FileAccess.file_exists(RETIRED_PATH):
		DirAccess.remove_absolute(RETIRED_PATH)

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)

func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_label_texts(c, out)
