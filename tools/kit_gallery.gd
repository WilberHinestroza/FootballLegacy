extends Control
## Galería de camisetas para captura REAL (ScreenshotProbe): 8 clubes ×
## local/visitante × 2 temporadas. Solo herramienta de verificación.
const CLUBS := [["#c8102e", "#ffffff"], ["#0b2a6b", "#f2c200"], ["#111111", "#ffffff"], ["#1b7a3a", "#ffffff"],
	["#6a1b9a", "#ffd54f"], ["#f5f5f5", "#d32f2f"], ["#ff8f00", "#1a1a1a"], ["#4fc3f7", "#0d47a1"]]

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(16, 16)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for i in range(CLUBS.size()):
		var c := ClubData.new()
		c.club_id = "gal_%d" % i
		c.primary_color_hex = CLUBS[i][0]
		c.secondary_color_hex = CLUBS[i][1]
		for yr in [2026, 2027]:
			for away in [false, true]:
				grid.add_child(Kit.build_for_club_kit(c, yr, away, 120, 10 if not away else 0))
