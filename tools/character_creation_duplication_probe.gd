extends Node

## Prueba dirigida del bug real reportado por Wilber: "cambié la posición
## principal por la que ya tenía de secundaria (no debería poderse) y se
## duplicó la pantalla". Causa raíz: _sync_pos2_disabled() tenía el resto
## de _build_identity_form() (nacionalidad/pie/origen/dificultad/año) mal
## anidado dentro de su cuerpo por un indentado corrido — como se llama
## cada vez que cambia la posición PRINCIPAL, cada cambio volvía a
## construir y agregar esos campos a identity_box sin sacar los viejos.
## Instancia la escena REAL (no el script suelto: necesita @onready
## identity_box) y confirma que llamar _sync_pos2_disabled() varias veces
## NO hace crecer identity_box.
##   godot --headless res://tools/CharacterCreationDuplicationProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var packed: PackedScene = load("res://scenes/CharacterCreation/CharacterCreation.tscn")
	var inst: Control = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var identity_box: VBoxContainer = inst.get_node("Margin/VBox/IdentityScroll/IdentityBox")
	var n0: int = identity_box.get_child_count()
	print("hijos de identity_box tras _ready(): %d" % n0)

	# Simula 3 cambios de posición PRINCIPAL (lo que dispara
	# _sync_pos2_disabled() en el juego real).
	for i in range(3):
		inst._sync_pos2_disabled()
	var n1: int = identity_box.get_child_count()
	print("hijos de identity_box tras 3 llamadas a _sync_pos2_disabled(): %d" % n1)

	var ok: bool = n1 == n0
	if not ok:
		print("FALLA: identity_box creció de %d a %d hijos — la pantalla se está duplicando" % [n0, n1])

	# Confirma también que el escenario exacto de Wilber (primaria ->
	# mismo código que la secundaria) deja la secundaria en "Ninguna",
	# no en un estado duplicado/inconsistente.
	var pos2_option: OptionButton = inst._pos2_option
	var pos_option: OptionButton = inst._pos_option
	# pos2_option tiene "Ninguna" en el índice 0, así que
	# Positions.DETAILED[i] vive en el índice i+1 — mismo offset que usa
	# _sync_pos2_disabled() de verdad, para no probar un desfasaje que el
	# juego real nunca comete.
	pos2_option.select(3) # Positions.DETAILED[2] como secundaria
	pos_option.select(2)  # Positions.DETAILED[2] — la MISMA como principal
	inst._sync_pos2_disabled()
	print("tras elegir la misma posición como principal: secundaria queda en índice %d (0=Ninguna)" % pos2_option.selected)
	if pos2_option.selected != 0:
		print("FALLA: la secundaria debería resetearse a 'Ninguna' cuando la principal la pisa")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
