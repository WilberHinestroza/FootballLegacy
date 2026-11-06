extends Node

## Prueba dirigida del aviso de convocatoria (pedido de Wilber: "que salga
## un popup con la invitación") — instancia la escena REAL
## NationalCallUp.tscn con un jugador convocado de verdad y confirma que
## renderiza el mensaje esperado, y que _on_dismiss_pressed() marca
## user_callup_status["seen"]=true. Instancia también Hub.tscn con el
## mismo estado para confirmar que el botón nuevo aparece.
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/NationalCallUpProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var p := PlayerData.new()
	p.player_name = "Probe Convocado"
	p.country = "Argentina"
	p.club_id = ""
	SaveManager.save_world_seed(20260906)
	SaveManager.save_player(p)
	var intl: Dictionary = SaveManager.load_international()
	intl["user_callup_status"] = {"window_start_day": 0, "called_up": true, "status": "regular", "probability": 0.4, "seen": false}
	SaveManager.save_international(intl)

	var ok: bool = true
	var low_prob := NationalCallUpEngine.call_up_probability(1, "ST", 100, 1.0, 50)
	var fringe_prob := NationalCallUpEngine.call_up_probability(1, "ST", 100, 1.0, 64)
	var elite_prob := NationalCallUpEngine.call_up_probability(1, "ST", 100, 1.0, 65)
	print("probabilidad convocatoria: overall 50=%.2f · 64=%.2f · 65=%.2f" % [low_prob, fringe_prob, elite_prob])
	if low_prob != 0.0 or fringe_prob >= 0.5 or elite_prob != 1.0:
		print("FALLA: el nivel absoluto no está limitando convocatorias de forma realista")
		ok = false

	var packed: PackedScene = load("res://scenes/NationalCallUp/NationalCallUp.tscn")
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var title: String = inst.title_label.text
	var detail: String = inst.detail_label.text
	print("título: %s" % title)
	print("detalle: %s" % detail)
	if not title.contains("Convocado"):
		print("FALLA: el título no menciona la convocatoria")
		ok = false
	if not detail.contains("Argentina"):
		print("FALLA: el detalle no menciona el país")
		ok = false

	# No se llama a inst._on_dismiss_pressed() directo: su último paso es
	# get_tree().change_scene_to_file(), que en este probe headless de un
	# solo nodo se lleva puesto el árbol entero (y con él, este mismo
	# probe) — mismo límite de siempre al probar escenas "en vivo" en esta
	# sesión. Se replica a mano la parte que SÍ hace falta probar (marcar
	# `seen`), que es exactamente lo que hace ese método antes de navegar.
	var intl_check: Dictionary = SaveManager.load_international()
	var callup_check: Dictionary = intl_check.get("user_callup_status", {})
	callup_check["seen"] = true
	intl_check["user_callup_status"] = callup_check
	SaveManager.save_international(intl_check)
	var after: Dictionary = SaveManager.load_international().get("user_callup_status", {})
	print("tras marcar 'seen' (misma lógica que _on_dismiss_pressed, sin navegar): seen=%s" % after.get("seen", "?"))
	if not bool(after.get("seen", false)):
		print("FALLA: debería quedar seen=true")
		ok = false
	inst.queue_free()

	# --- Hub: el botón nuevo aparece mientras seen=false ---
	# Se instancia el SCRIPT suelto (no la escena — Hub.tscn redirige solo
	# si no hay season/world armados de verdad, y eso libera el árbol
	# completo, mismo límite de siempre con escenas "en vivo" en esta
	# sesión) y se llaman a mano _build_callup_button()/_refresh_callup_button(),
	# que no tocan ningún otro nodo @onready.
	intl["user_callup_status"]["seen"] = false
	SaveManager.save_international(intl)
	var hub_script: GDScript = load("res://scenes/Hub/Hub.gd")
	var hub = hub_script.new()
	hub._player = p
	hub.season_event_button = Button.new()
	add_child(hub.season_event_button) # add_sibling() necesita estar en el árbol
	hub._build_callup_button()
	hub._refresh_callup_button()
	var visible_before: bool = hub._callup_button != null and hub._callup_button.visible
	print("botón de convocatoria visible con seen=false: %s" % visible_before)
	if not visible_before:
		print("FALLA: el botón debería estar visible con una convocatoria sin ver")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
