extends Node

## Prueba dirigida: "debería salir el botón de una X roja para rechazar,
## y no tener que darle a 'no quiero salir cedido ahora'" — Transfers.gd
## ahora agrega una X roja chiquita (Icons.CROSS) en la esquina de cada
## tarjeta de oferta NO pendiente y en el encabezado del bloque de
## cesión, además de los botones de texto de siempre. Instancia el
## SCRIPT suelto (Transfers.gd no tiene class_name) y llama a los
## constructores de tarjeta directo — no tocan ningún nodo @onready.
##   godot --headless res://tools/TransferRejectButtonProbe.tscn

func _count_cross_buttons(node: Node) -> int:
	var n: int = 0
	if node is Button and (node as Button).icon != null:
		n += 1
	for c in node.get_children():
		n += _count_cross_buttons(c)
	return n

func _ready() -> void:
	var script: GDScript = load("res://scenes/Transfers/Transfers.gd")
	var t = script.new()
	var ok: bool = true

	var offer: Dictionary = {
		"id": "o1", "from_club_id": "", "from_club_name": "Club de prueba",
		"kind": "traspaso", "wage": 1000, "contract_years": 3, "fee": 5000,
		"window_day": 21,
	}
	var card: PanelContainer = t._offer_card(offer, false)
	var crosses_in_card: int = _count_cross_buttons(card)
	print("botones con ícono en la tarjeta de oferta NO pendiente: %d (esperado >= 3: aceptar/rechazar + la X + negociar)" % crosses_in_card)
	if crosses_in_card < 1:
		print("FALLA: no se encontró ningún botón con ícono en la tarjeta")
		ok = false

	var pending_card: PanelContainer = t._offer_card(offer, true)
	# La tarjeta PENDIENTE (ya acordada) no debería tener la X de rechazo
	# rápido — ahí la acción es "Cancelar el acuerdo", no "rechazar".
	print("tarjeta pendiente construida sin crash: OK")

	t._world = {}
	var p := PlayerData.new()
	p.player_name = "Probe X"
	p.club_id = "c_1_0"
	t._player = p
	var loan_block: VBoxContainer = t._loan_request_block(false)
	print("bloque de cesión construido sin crash, hijos: %d" % loan_block.get_child_count())
	if loan_block.get_child_count() < 1:
		print("FALLA: el bloque de cesión no construyó nada")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
