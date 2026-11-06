extends PanelContainer
class_name ProgressPanel

## Panel de PROGRESO animado del post-partido (schema v33, 9-oct — Wilber:
## "que la evolución tenga sentido y sea divertida"). Muestra:
##  - el NIVEL con su barra de XP de carrera llenándose (y "¡NIVEL X!" si
##    subiste, con los puntos ganados),
##  - cada atributo que ganó XP con su barrita llenándose y un "+1" que
##    salta si subió,
##  - la media si cambió, y un botón a las Habilidades si hay puntos.
## Solo presentación: los números ya vienen calculados (ProgressionEngine /
## PlayerDevelopment).

signal open_skills

var _player: PlayerData
var _lv_before: int = 1
var _xp_before: int = 0
var _lv_result: Dictionary = {}
var _attr_result: Dictionary = {}
var _lvup: Label

## `lv_before`/`xp_before` = estado ANTES de sumar; `lv_result` =
## ProgressionEngine.add_xp(); `attr_result` = grant_attribute_xp().
func setup(player: PlayerData, lv_before: int, xp_before: int, lv_result: Dictionary, attr_result: Dictionary) -> ProgressPanel:
	_player = player
	_lv_before = lv_before
	_xp_before = xp_before
	_lv_result = lv_result
	_attr_result = attr_result
	return self

func _ready() -> void:
	var sb := Styles.card_flat(Color(0.09, 0.10, 0.14, 0.96), 16)
	sb.set_border_width_all(2)
	sb.border_color = Color(Styles.BLUE, 0.6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	# --- Nivel ---
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var badge := _level_badge(_lv_before)
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	var head := Label.new()
	head.text = "EXPERIENCIA  +%d" % int(_lv_result.get("xp", 0))
	head.add_theme_font_override("font", Styles.font_black())
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", Styles.BLUE)
	col.add_child(head)
	var bar := _bar(Styles.BLUE)
	col.add_child(bar)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	col.add_child(sub)
	_lvup = Label.new()
	_lvup.visible = false
	_lvup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lvup.add_theme_font_override("font", Styles.font_black())
	_lvup.add_theme_font_size_override("font_size", 15)
	_lvup.add_theme_color_override("font_color", Styles.GOLD)
	col.add_child(_lvup)
	row.add_child(col)
	v.add_child(row)

	# --- Atributos ---
	var xp_added: Dictionary = _attr_result.get("xp_added", {})
	var leveled: Dictionary = _attr_result.get("leveled", {})
	var attr_rows: Array = []
	var keys: Array = xp_added.keys()
	keys.sort_custom(func(a, b): return float(xp_added[a]) > float(xp_added[b]))
	for k in keys.slice(0, 5):
		var ar := HBoxContainer.new()
		ar.add_theme_constant_override("separation", 8)
		var nl := Label.new()
		nl.text = PlayerDevelopment.attr_es(String(k))
		nl.custom_minimum_size = Vector2(118, 0)
		nl.add_theme_font_size_override("font_size", 13)
		ar.add_child(nl)
		var b := _bar(Styles.GREEN, 10)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ar.add_child(b)
		var val := Label.new()
		val.text = str(int(_player.get(String(k))))
		val.custom_minimum_size = Vector2(54, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_override("font", Styles.font_black())
		ar.add_child(val)
		v.add_child(ar)
		attr_rows.append([String(k), b, val, int(leveled.get(k, 0))])

	var od: int = int(_attr_result.get("overall_delta", 0))
	var ol := Label.new()
	ol.visible = false
	ol.text = "MEDIA  +%d  →  %d" % [od, _player.overall]
	ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ol.add_theme_font_override("font", Styles.font_black())
	ol.add_theme_font_size_override("font_size", 18)
	ol.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(ol)

	var skills_btn := Button.new()
	skills_btn.visible = false
	skills_btn.custom_minimum_size = Vector2(0, 46)
	skills_btn.focus_mode = Control.FOCUS_NONE
	skills_btn.pressed.connect(func(): open_skills.emit())
	Styles.styled_button(skills_btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	v.add_child(skills_btn)

	_animate(bar, sub, badge, attr_rows, ol, od, skills_btn)

func _animate(bar: ProgressBar, sub: Label, badge: PanelContainer, attr_rows: Array, ol: Label, od: int, skills_btn: Button) -> void:
	# Barra de nivel: del XP de antes al de ahora, dando la vuelta por cada
	# nivel subido (con pop del escudito).
	var lv: int = _lv_before
	var levels: int = int(_lv_result.get("levels", 0))
	bar.value = float(_xp_before) / float(ProgressionEngine.xp_to_next(lv)) * 100.0
	sub.text = "Nivel %d  ·  %d / %d" % [lv, _xp_before, ProgressionEngine.xp_to_next(lv)]
	await get_tree().create_timer(0.35).timeout
	for i in range(levels):
		var tw := create_tween()
		tw.tween_property(bar, "value", 100.0, 0.45).set_trans(Tween.TRANS_QUAD)
		await tw.finished
		lv += 1
		_set_badge(badge, lv)
		Juice.pop(badge, 1.35)
		bar.value = 0.0
	var target: float = float(_player.career_xp) / float(ProgressionEngine.xp_to_next(_player.level)) * 100.0
	var tw2 := create_tween()
	tw2.tween_property(bar, "value", target, 0.5).set_trans(Tween.TRANS_QUAD)
	await tw2.finished
	sub.text = "Nivel %d  ·  %d / %d" % [_player.level, _player.career_xp, ProgressionEngine.xp_to_next(_player.level)]
	if levels > 0:
		_lvup.text = "¡SUBISTE A NIVEL %d!  +%d punto%s de habilidad" % [_player.level, int(_lv_result.get("points", 0)), "" if int(_lv_result.get("points", 0)) == 1 else "s"]
		_lvup.visible = true
		Juice.pop(_lvup, 1.2)
		Audio.play("celebrate")

	# Atributos: cada barrita se llena; si subió, salta el "+N".
	for r in attr_rows:
		var attr: String = r[0]
		var b: ProgressBar = r[1]
		var val: Label = r[2]
		var gained: int = int(r[3])
		var cur: int = int(_player.get(attr))
		var need: float = float(PlayerDevelopment.xp_needed(cur, _player.growth_difficulty))
		var after: float = float(_player.attribute_xp.get(attr, 0.0)) / maxf(need, 1.0) * 100.0
		var added: float = float((_attr_result.get("xp_added", {}) as Dictionary).get(attr, 0.0)) / maxf(need, 1.0) * 100.0
		b.value = clampf(after - added, 0.0, 100.0) if gained == 0 else clampf(100.0 - added, 0.0, 100.0)
		var t := create_tween()
		if gained > 0:
			t.tween_property(b, "value", 100.0, 0.3)
			t.tween_callback(func():
				b.value = 0.0
				val.text = "%d  +%d" % [cur, gained]
				val.add_theme_color_override("font_color", Styles.GREEN)
				Juice.pop(val, 1.5))
		t.tween_property(b, "value", after, 0.35)
		await t.finished
	if od != 0:
		ol.visible = true
		Juice.pop(ol, 1.4)
	if _player.skill_points > 0:
		skills_btn.text = "Gastar %d punto%s de habilidad  ›" % [_player.skill_points, "" if _player.skill_points == 1 else "s"]
		skills_btn.visible = true
		Juice.pop(skills_btn, 1.12)

func _bar(col: Color, h: int = 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(h >> 1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(h >> 1)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

static func _level_badge(lv: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(56, 56)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.pivot_offset = Vector2(28, 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.2, 0.45)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Styles.GOLD
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.name = "Lv"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", 22)
	p.add_child(l)
	_set_badge(p, lv)
	return p

static func _set_badge(p: PanelContainer, lv: int) -> void:
	(p.get_node("Lv") as Label).text = str(lv)
