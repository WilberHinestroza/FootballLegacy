extends Node
## Capturas de las viviendas y coches 3D (LifeStage): una hoja con todos.
const LifeStage = preload("res://ui/common/LifeStage.gd")
func _ready() -> void:
	var cv := CanvasLayer.new()
	add_child(cv)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(4, 4)
	cv.add_child(grid)
	var cfg := Avatar.random_config(7)
	var items := [["shared_apartment", "none", "home"], ["small_apartment", "none", "home"], ["apartment", "none", "home"],
		["house", "none", "home"], ["mansion", "none", "home"], ["house", "none", "car"], ["house", "economy", "car"],
		["house", "sedan", "car"], ["house", "sports_car", "car"], ["house", "luxury_car", "car"], ["mansion", "luxury_car", "both"],
		["shared_apartment", "economy", "both"]]
	for it in items:
		var st = LifeStage.make(cfg, it[0], it[1], it[2], 170)
		st.custom_minimum_size = Vector2(316, 170)
		grid.add_child(st)
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png("res://build/life_sheet.png")
	print("LIFE OK")
	get_tree().quit()
