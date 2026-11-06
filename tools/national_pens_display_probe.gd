extends Node

## Prueba dirigida: "si algún equipo en los mata mata gana por penales,
## mostralo también en el resultado" — Selections.gd._national_match_row()
## solo mostraba el marcador de los 90' (SeasonEngine.resolve_cup ya deja
## "pens":[ph,pa] en el partido cuando se define así, mismo campo que
## WorldExplorer.gd ya usaba para copas de club — acá nunca se leía).
## Instancia el SCRIPT suelto (Selections.gd no tiene class_name) y llama
## al constructor de fila directo — no toca ningún nodo @onready.
##   godot --headless res://tools/NationalPensDisplayProbe.tscn

func _ready() -> void:
	var script: GDScript = load("res://scenes/Selections/Selections.gd")
	var s = script.new()
	var ok: bool = true

	# Cruce decidido en los 90' (sin penales) — no debería mostrar nada extra.
	var m_normal: Dictionary = {"home_club_id": "Argentina", "away_club_id": "Brasil", "result": [2, 1]}
	var row_normal: Control = s._national_match_row(m_normal)
	var text_normal: String = _score_text(row_normal)
	print("marcador normal: '%s'" % text_normal)
	if text_normal.find("pen") >= 0:
		print("FALLA: un cruce sin penales no debería mencionar 'pen'")
		ok = false

	# Cruce definido por penales.
	var m_pens: Dictionary = {"home_club_id": "Francia", "away_club_id": "España", "result": [1, 1], "pens": [5, 4]}
	var row_pens: Control = s._national_match_row(m_pens)
	var text_pens: String = _score_text(row_pens)
	print("marcador con penales: '%s'" % text_pens)
	if text_pens.find("5-4 pen") < 0:
		print("FALLA: no se muestra el resultado de la tanda de penales")
		ok = false
	if text_pens.find("1-1") < 0:
		print("FALLA: se perdió el marcador de los 90' al agregar los penales")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

func _score_text(row: Control) -> String:
	for c in row.get_children():
		if c is Label and (c as Label).custom_minimum_size.x > 40:
			return (c as Label).text
	return "?NO_ENCONTRADO?"
