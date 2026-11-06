extends "res://scenes/MatchSummary/MatchSummary.gd"
## Solo para TrophyTapProbe: la pantalla de resumen sin su _ready (que sin
## partido real cambia de escena).
func _ready() -> void:
	_player = SaveManager.load_player()
