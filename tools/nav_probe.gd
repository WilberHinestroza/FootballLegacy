extends Node
## Navegación: pila de "Volver", editor de apariencia, overlays, cajón.
##   godot --headless --path . res://tools/NavProbe.tscn
var _fails: int = 0

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)
	for i in range(4):
		await get_tree().process_frame

func _here() -> String:
	var cs := get_tree().current_scene
	return cs.scene_file_path.get_file().get_basename() if cs != null else "?"

func _back() -> void:
	Nav.back()
	for i in range(4):
		await get_tree().process_frame

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var p := PlayerData.new()
	p.player_name = "Probe Nav"
	SaveManager.save_player(p)
	# Sobrevivir a los cambios de escena: la "escena actual" pasa a ser un
	# nodo vacío (lo que libera change_scene es ESE, no el probe).
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy

	# 1) El bug: Perfil → editar apariencia → Cancelar → Volver.
	await _go("res://scenes/Hub/Hub.tscn")
	await _go("res://scenes/CareerMenu/CareerMenu.tscn")
	await _go("res://scenes/PlayerProfile/PlayerProfile.tscn")
	CharacterDraft.edit_mode = true
	await _go("res://scenes/AvatarCreator/AvatarCreator.tscn")
	get_tree().current_scene.call("_on_back")
	for i in range(4):
		await get_tree().process_frame
	_check(_here() == "PlayerProfile", "cancelar el editor vuelve al perfil (%s)" % _here())
	await _back()
	_check(_here() == "CareerMenu", "Volver desde el perfil va a Carrera, NO reabre el editor (%s)" % _here())
	await _back()
	_check(_here() == "Hub", "y después a Inicio (%s)" % _here())

	# 2) Ida y vuelta con change_scene directo (A→B→A) no deja un bucle.
	await _go("res://scenes/CareerMenu/CareerMenu.tscn")
	await _go("res://scenes/Shop/Shop.tscn")
	await _go("res://scenes/CareerMenu/CareerMenu.tscn")
	await _back()
	_check(_here() == "Hub", "A→B→A y Volver = Inicio, no B otra vez (%s)" % _here())

	# 3) Overlay: Volver cierra primero la ficha abierta.
	await _go("res://scenes/PlayerSearch/PlayerSearch.tscn")
	var ps := get_tree().current_scene
	ps.player_card_overlay.visible = true
	await _back()
	_check(_here() == "PlayerSearch" and not ps.player_card_overlay.visible, "Volver cierra la ficha antes de salir")
	await _back()
	_check(_here() == "Hub", "segundo Volver sale (%s)" % _here())

	# 4) Cajón abierto: Volver lo cierra; la hamburguesa queda a la derecha.
	await _go("res://scenes/News/News.tscn")
	var tb: Node = get_tree().get_first_node_in_group("nav_back_handlers")
	_check(tb != null, "TopBar registrado para el atrás")
	if tb != null:
		var hb: HBoxContainer = tb._menu_btn.get_parent()
		_check(hb.get_child(hb.get_child_count() - 1) == tb._menu_btn, "hamburguesa a la derecha")
		_check(hb.get_child(0).name == "TopBackButton", "atrás a la izquierda")
		tb._set_drawer_open(true)
		await _back()
		_check(_here() == "News" and not tb._drawer_open, "Volver con el cajón abierto lo cierra")

	print("PROBE %s (%d fallos)" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
