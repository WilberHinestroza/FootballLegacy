extends Node

## Prueba dirigida del bug real reportado por Wilber ("se sigue
## replicando la explicación" en la barra de acciones del partido).
## Reproduce el mecanismo EXACTO de Match._tap_hint(): dos llamadas
## seguidas (mismo frame, sin await de por medio — igual que
## _on_aim_zone_picked llamando a _start_power_meter y después a sí
## mismo) que agregan un hijo con el mismo `name` a un mismo padre.
##
## Con queue_free() (borrado DIFERIDO) el primer nodo sigue vivo cuando
## se agrega el segundo con el mismo nombre -> Godot autorenombra el
## nuevo a "MG_Hint2" en vez de reemplazar, y los dos quedan visibles.
## Con remove_child()+free() (borrado INMEDIATO, el fix real) el primero
## ya no existe cuando se agrega el segundo -> queda solo uno, con el
## nombre correcto.
##   godot --headless res://tools/HintReplaceProbe.tscn

func _add_hint(parent: Node, use_queue_free: bool) -> void:
	var old: Node = parent.get_node_or_null("MG_Hint")
	if old != null:
		if use_queue_free:
			old.queue_free()
		else:
			parent.remove_child(old)
			old.free()
	var row := Control.new()
	row.name = "MG_Hint"
	parent.add_child(row)

func _ready() -> void:
	# --- Reproduce el bug (queue_free) ---
	var buggy := Node.new()
	add_child(buggy)
	_add_hint(buggy, true)   # primer hint
	_add_hint(buggy, true)   # segundo hint, MISMO frame, sin esperar el borrado diferido
	var buggy_hints: int = 0
	for c in buggy.get_children():
		if String(c.name).begins_with("MG_Hint"):
			buggy_hints += 1
	print("con queue_free(): hijos MG_Hint* tras 2 llamadas seguidas = %d (bug real: >1)" % buggy_hints)

	# --- Fix real (remove_child + free, inmediato) ---
	var fixed := Node.new()
	add_child(fixed)
	_add_hint(fixed, false)
	_add_hint(fixed, false)
	var fixed_hints: int = 0
	for c in fixed.get_children():
		if String(c.name).begins_with("MG_Hint"):
			fixed_hints += 1
	print("con remove_child()+free(): hijos MG_Hint* tras 2 llamadas seguidas = %d (esperado 1)" % fixed_hints)

	var ok: bool = buggy_hints > 1 and fixed_hints == 1
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
