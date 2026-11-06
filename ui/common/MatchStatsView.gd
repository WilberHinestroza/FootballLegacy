extends RefCounted
class_name MatchStatsView

## Render ÚNICO de las estadísticas de un partido (LOCAL | concepto | VISITANTE
## con barra), en su versión EXTENDIDA. Lo usan MatchSummary (final) y el
## entretiempo de Match — así "las estadísticas" se ven igual y completas
## en todos lados (pedido de Wilber).
##
## El motor solo trackea 5 reales (posesión, tiros, a puerta, córners,
## faltas). El resto se DERIVA determinista del propio partido + una
## semilla estable — son de lectura, no cambian nada.

static func render(box: Control, ms: Dictionary, gh: int, ga: int, seed_key: String, hc: Color, ac: Color, at_halftime: bool = false) -> void:
	if ms.is_empty():
		return
	var hs: Dictionary = ms.get("home", {})
	var as_: Dictionary = ms.get("away", {})
	var ph: int = int(ms.get("possession_home", 50))
	var h_shots: int = int(hs.get("shots", 0))
	var a_shots: int = int(as_.get("shots", 0))
	var h_on: int = int(hs.get("on_target", 0))
	var a_on: int = int(as_.get("on_target", 0))
	var h_cor: int = int(hs.get("corners", 0))
	var a_cor: int = int(as_.get("corners", 0))
	var h_foul: int = int(hs.get("fouls", 0))
	var a_foul: int = int(as_.get("fouls", 0))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mstats|%s|%d-%d|%d" % [seed_key, gh, ga, ph])

	box.add_child(_row("Posesión", "%d%%" % ph, "%d%%" % (100 - ph), ph, 100 - ph, hc, ac))
	box.add_child(_row("Tiros", str(h_shots), str(a_shots), h_shots, a_shots, hc, ac))
	box.add_child(_row("Tiros a puerta", str(h_on), str(a_on), h_on, a_on, hc, ac))
	box.add_child(_row("Disparos desviados", str(maxi(0, h_shots - h_on)), str(maxi(0, a_shots - a_on)), maxi(0, h_shots - h_on), maxi(0, a_shots - a_on), hc, ac))
	box.add_child(_row("Atajadas del portero", str(maxi(0, a_on - ga)), str(maxi(0, h_on - gh)), maxi(0, a_on - ga), maxi(0, h_on - gh), hc, ac))
	var h_big: int = maxi(gh, int(round(h_on * 0.55)) + rng.randi_range(0, 1))
	var a_big: int = maxi(ga, int(round(a_on * 0.55)) + rng.randi_range(0, 1))
	box.add_child(_row("Ocasiones claras", str(h_big), str(a_big), h_big, a_big, hc, ac))
	box.add_child(_row("Córners", str(h_cor), str(a_cor), h_cor, a_cor, hc, ac))
	var h_off: int = rng.randi_range(0, 4)
	var a_off: int = rng.randi_range(0, 4)
	box.add_child(_row("Fuera de juego", str(h_off), str(a_off), h_off, a_off, hc, ac))
	box.add_child(_row("Faltas", str(h_foul), str(a_foul), h_foul, a_foul, hc, ac))
	var h_yc: int = clampi(int(round(h_foul * 0.28)), 0, 5)
	var a_yc: int = clampi(int(round(a_foul * 0.28)), 0, 5)
	box.add_child(_row("Amarillas", str(h_yc), str(a_yc), h_yc, a_yc, hc, ac))
	var h_tk: int = a_foul + rng.randi_range(6, 14)
	var a_tk: int = h_foul + rng.randi_range(6, 14)
	box.add_child(_row("Entradas", str(h_tk), str(a_tk), h_tk, a_tk, hc, ac))
	var mult: float = 3.5 if at_halftime else 7.5
	var h_pass: int = int(round(ph * (mult + rng.randf() * 2.0)))
	var a_pass: int = int(round((100 - ph) * (mult + rng.randf() * 2.0)))
	box.add_child(_row("Pases", str(h_pass), str(a_pass), h_pass, a_pass, hc, ac))
	var h_acc: int = clampi(72 + int(round((ph - 50) * 0.4)) + rng.randi_range(-3, 3), 55, 93)
	var a_acc: int = clampi(72 + int(round((50 - ph) * 0.4)) + rng.randi_range(-3, 3), 55, 93)
	box.add_child(_row("Precisión de pase", "%d%%" % h_acc, "%d%%" % a_acc, h_acc, a_acc, hc, ac))
	var h_duel: int = rng.randi_range(8, 22)
	var a_duel: int = rng.randi_range(8, 22)
	box.add_child(_row("Duelos ganados", str(h_duel), str(a_duel), h_duel, a_duel, hc, ac))
	var h_xg: float = h_on * 0.32 + h_big * 0.18 + gh * 0.05
	var a_xg: float = a_on * 0.32 + a_big * 0.18 + ga * 0.05
	box.add_child(_row("xG (goles esperados)", "%.1f" % h_xg, "%.1f" % a_xg, int(h_xg * 10), int(a_xg * 10), hc, ac))

static func _row(label: String, hv: String, av: String, hn: int, an: int, hc: Color, ac: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 8))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)

	var top := HBoxContainer.new()
	var lh := Label.new()
	lh.text = hv
	lh.custom_minimum_size = Vector2(46, 0)
	lh.add_theme_font_override("font", Styles.font_semibold())
	var lc := Label.new()
	lc.text = label
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lc.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lc.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	var la := Label.new()
	la.text = av
	la.custom_minimum_size = Vector2(46, 0)
	la.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	la.add_theme_font_override("font", Styles.font_semibold())
	top.add_child(lh)
	top.add_child(lc)
	top.add_child(la)
	col.add_child(top)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	var bh := ColorRect.new()
	bh.color = hc
	bh.custom_minimum_size = Vector2(0, 4)
	bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.size_flags_stretch_ratio = maxf(float(hn), 0.5)
	var ba := ColorRect.new()
	ba.color = ac
	ba.custom_minimum_size = Vector2(0, 4)
	ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ba.size_flags_stretch_ratio = maxf(float(an), 0.5)
	bar.add_child(bh)
	bar.add_child(ba)
	col.add_child(bar)

	m.add_child(col)
	panel.add_child(m)
	return panel
