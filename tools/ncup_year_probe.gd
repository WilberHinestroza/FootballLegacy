extends Node
func _ready() -> void:
	var sel_script: GDScript = load("res://scenes/Selections/Selections.gd")
	var sel = sel_script.new()
	for conf in ["UEFA", "CONMEBOL", "CONCACAF", "AFC", "CAF"]:
		print("%s próxima copa: %d" % [conf, sel._next_national_cup_year(conf)])
	get_tree().quit()
