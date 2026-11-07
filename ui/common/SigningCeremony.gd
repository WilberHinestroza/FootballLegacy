extends Control
class_name SigningCeremony

## Ceremonia de firma de contrato: overlay full-rect con la HOJA del contrato en
## papel (franja del club, escudo de agua, cláusulas con tinta), y la firma:
## la dibujas TÚ con el dedo en el recuadro (o, si solo pulsas "Firmar", se firma
## sola). Al confirmar cae el sello "FIRMADO" del club con golpe y vibración, y
## después "¡Bienvenido!" + confeti + "Continuar" (club nuevo -> presentación).
## 7-nov, Wilber: "mejorar la firma de contrato".
##
## Uso:
##   var sc := SigningCeremony.new()
##   sc.setup({club_id, club_name, league_name, stars, wage, years, role,
##            number, is_renewal, player})
##   sc.confirmed.connect(_finalize)
##   add_child(sc)

signal confirmed

const PAPER := Color(0.953, 0.933, 0.882)
const INK := Color(0.12, 0.14, 0.2)
const MUTED := Color(0.44, 0.42, 0.37)
const PEN := Color(0.1, 0.16, 0.52)
const SIG_W := 288.0
const SIG_H := 84.0
const SIG_BASE := 62.0   # altura de la línea de firma dentro del recuadro

var _d: Dictionary = {}
var _card: PanelContainer
var _sig_area: Control
var _strokes: Array[Line2D] = []
var _drawing := false
var _signed := false
var _hint: Label
var _pen: Polygon2D
var _sign_btn: Button
var _clear_btn: Button
var _footer: VBoxContainer
var _club_col := Styles.BLUE


func setup(data: Dictionary) -> SigningCeremony:
	_d = data
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	_club_col = _club_color()

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(328, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(6)
	sb.border_width_top = 7
	sb.border_color = _club_col
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)

	# Escudo de agua: el del club, grande y casi transparente, detrás del texto
	var cid: String = String(_d.get("club_id", ""))
	if cid != "":
		var wm_box := CenterContainer.new()
		wm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wm := Styles.club_crest(cid, 200)
		wm.modulate = Color(1, 1, 1, 0.07)
		wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wm_box.add_child(wm)
		_card.add_child(wm_box)

	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 16)
	_card.add_child(m)

	# En horizontal (el juego va apaisado) la hoja no cabe en alto: dos columnas,
	# cláusulas a la izquierda y jugador + firma + botones a la derecha.
	var vs := get_viewport_rect().size
	var land: bool = vs.x > vs.y
	var cols: BoxContainer = HBoxContainer.new() if land else VBoxContainer.new()
	cols.add_theme_constant_override("separation", 22 if land else 8)
	m.add_child(cols)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7 if land else 8)
	cols.add_child(v)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	cols.add_child(v2)
	if land:
		_card.custom_minimum_size = Vector2(0, 0)
		v.custom_minimum_size = Vector2(300, 0)
		v2.custom_minimum_size = Vector2(SIG_W, 0)
		v2.alignment = BoxContainer.ALIGNMENT_END

	var kind_col: Color = _club_col if _club_col.get_luminance() < 0.6 else _club_col.darkened(0.45)
	var kind := _lbl("CONTRATO DE RENOVACIÓN" if bool(_d.get("is_renewal", false)) else "CONTRATO PROFESIONAL", 12, kind_col, Styles.font_black())
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kind)

	# --- Cabecera del club ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	if cid != "":
		var cr := Styles.club_crest(cid, 46)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(cr)
	var hcol := VBoxContainer.new()
	hcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hcol.add_theme_constant_override("separation", 1)
	hcol.add_child(_lbl(String(_d.get("club_name", "Club")), 17, INK, Styles.font_black()))
	hcol.add_child(_lbl(String(_d.get("league_name", "")), 10, MUTED))
	var stars: int = clampi(int(_d.get("stars", 3)), 0, 5)
	hcol.add_child(Styles.star_row(stars, 5, 12, Color(0.8, 0.58, 0.1)))
	head.add_child(hcol)
	v.add_child(head)

	var p: PlayerData = _d.get("player", null)
	var intro := _lbl("Entre %s y el jugador %s se acuerda:" % [String(_d.get("club_name", "el club")), p.player_name if p != null else ""], 10, MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	v.add_child(_rule(0.35))

	# --- Cláusulas ---
	var wage: int = int(_d.get("wage", 0))
	var years: int = int(_d.get("years", 3))
	var rows := [
		["Duración", "%d temporada%s" % [years, "" if years == 1 else "s"]],
		["Sueldo", "%s / temporada" % CurrencyFormat.format(wage)],
		["Rol", String(_d.get("role", "Rotación"))],
		["Prima por gol", CurrencyFormat.format(maxi(5000, int(wage * 0.006)))],
		["Cláusula", CurrencyFormat.format(maxi(1000000, wage * 25))],
		["Dorsal", str(int(_d.get("number", 0))) if int(_d.get("number", 0)) > 0 else "por asignar"],
	]
	var n := 1
	for r in rows:
		var hr := HBoxContainer.new()
		var k := _lbl("%d. %s" % [n, String(r[0])], 12, MUTED)
		k.custom_minimum_size = Vector2(126, 0)
		hr.add_child(k)
		var val := _lbl(String(r[1]), 12, INK, Styles.font_semibold())
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hr.add_child(val)
		v.add_child(hr)
		v.add_child(_rule(0.1))
		n += 1

	# --- Jugador ---
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	if p != null:
		prow.add_child(Styles.portrait_frame(Avatar.for_player(p, SaveManager.load_world_seed(), 40), 40, _club_col))
	var pcol := VBoxContainer.new()
	pcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pcol.add_theme_constant_override("separation", 1)
	pcol.add_child(_lbl(p.player_name if p != null else "Jugador", 14, INK, Styles.font_semibold()))
	pcol.add_child(_lbl("%s · %d años" % [Positions.label_of(p.detailed_position), p.age] if p != null else "", 10, MUTED))
	prow.add_child(pcol)
	v2.add_child(prow)

	# --- Recuadro de firma (se dibuja con el dedo) ---
	_sig_area = Control.new()
	_sig_area.custom_minimum_size = Vector2(SIG_W, SIG_H)
	_sig_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_sig_area.clip_contents = true
	_sig_area.gui_input.connect(_on_sig_input)
	v2.add_child(_sig_area)
	var pad := ColorRect.new()
	pad.color = Color(1, 1, 1, 0.45)
	pad.size = Vector2(SIG_W, SIG_H)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sig_area.add_child(pad)
	var x_mark := _lbl("X", 14, MUTED, Styles.font_semibold())
	x_mark.position = Vector2(10, SIG_BASE - 20)
	_sig_area.add_child(x_mark)
	var base_line := Line2D.new()
	base_line.width = 1.2
	base_line.default_color = Color(INK, 0.45)
	base_line.points = PackedVector2Array([Vector2(8, SIG_BASE), Vector2(SIG_W - 8, SIG_BASE)])
	_sig_area.add_child(base_line)
	var under := _lbl("Firma del jugador", 9, MUTED)
	under.position = Vector2(10, SIG_BASE + 3)
	_sig_area.add_child(under)
	_hint = _lbl("Firma aquí con el dedo", 13, Color(PEN, 0.75), Styles.font_semibold())
	_hint.size = Vector2(SIG_W, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, SIG_BASE - 34)
	_sig_area.add_child(_hint)
	if not Preferences.reduce_motion:
		var pulse := _hint.create_tween().set_loops()
		pulse.tween_property(_hint, "modulate:a", 0.4, 0.8)
		pulse.tween_property(_hint, "modulate:a", 1.0, 0.8)
	_pen = Polygon2D.new()
	_pen.polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, -20), Vector2(15, -16), Vector2(5, 3)])
	_pen.color = Color(0.15, 0.15, 0.18)
	_pen.visible = false
	_sig_area.add_child(_pen)

	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 6)
	v2.add_child(_footer)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	_footer.add_child(btns)
	_clear_btn = Button.new()
	_clear_btn.text = "Borrar"
	_clear_btn.custom_minimum_size = Vector2(86, 48)
	_clear_btn.focus_mode = Control.FOCUS_NONE
	_clear_btn.visible = false
	Styles.styled_button(_clear_btn, Styles.pill_filled(Color(INK, 0.12)), INK)
	_clear_btn.pressed.connect(_clear_signature)
	btns.add_child(_clear_btn)
	_sign_btn = Button.new()
	_sign_btn.text = "Firmar contrato"
	_sign_btn.custom_minimum_size = Vector2(0, 48)
	_sign_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign_btn.focus_mode = Control.FOCUS_NONE
	_sign_btn.icon = Icons.load_icon(Icons.CARD)
	_sign_btn.add_theme_constant_override("icon_max_width", 20)
	Styles.styled_button(_sign_btn, Styles.pill_filled(INK), PAPER)
	_sign_btn.pressed.connect(_do_signature)
	btns.add_child(_sign_btn)

	# Aparición: la hoja llega un poco girada y se endereza
	_card.modulate = Color(1, 1, 1, 0)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_card.pivot_offset = _card.size / 2.0
	_card.rotation = -0.05
	_card.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate", Color(1, 1, 1, 1), 0.2)
	tw.tween_property(_card, "rotation", 0.0, 0.32)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.32)


func _lbl(text: String, fs: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rule(alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(INK, alpha)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _club_color() -> Color:
	var cid: String = String(_d.get("club_id", ""))
	if cid != "":
		var world: Dictionary = WorldTickEngine.world
		if world.is_empty():
			world = WorldFactory.build(SaveManager.load_world_seed())
		var club: ClubData = WorldFactory.find_club(world, cid)
		if club != null and not club.primary_color_hex.is_empty():
			return Color(club.primary_color_hex)
	return Styles.BLUE


# ---------------------------------------------------------------- firma a mano

## Ratón (el toque del móvil llega emulado como ratón): pulsar abre un trazo,
## arrastrar lo alarga.
func _on_sig_input(e: InputEvent) -> void:
	if _signed:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drawing = (e as InputEventMouseButton).pressed
		if _drawing:
			_new_stroke((e as InputEventMouseButton).position)
		_sig_area.accept_event()
	elif e is InputEventMouseMotion and _drawing:
		_add_point((e as InputEventMouseMotion).position)
		_sig_area.accept_event()


func _new_stroke(at: Vector2) -> void:
	var l := Line2D.new()
	l.width = 2.6
	l.default_color = PEN
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = true
	_sig_area.add_child(l)
	_sig_area.move_child(l, _pen.get_index())
	_strokes.append(l)
	l.add_point(_clamp(at))
	_hint.visible = false
	if not _signed:
		_clear_btn.visible = true
		_sign_btn.text = "Confirmar firma"


func _add_point(at: Vector2) -> void:
	if _strokes.is_empty():
		return
	var l: Line2D = _strokes[-1]
	var q := _clamp(at)
	if l.get_point_count() > 0 and l.get_point_position(l.get_point_count() - 1).distance_to(q) < 2.0:
		return
	if l.get_point_count() < 400:
		l.add_point(q)


func _clamp(at: Vector2) -> Vector2:
	return Vector2(clampf(at.x, 4.0, SIG_W - 4.0), clampf(at.y, 4.0, SIG_H - 4.0))


func _ink_points() -> int:
	var t := 0
	for l in _strokes:
		t += l.get_point_count()
	return t


func _clear_signature() -> void:
	if _signed:
		return
	_clear_strokes_now()
	_hint.visible = true
	_clear_btn.visible = false
	_sign_btn.text = "Firmar contrato"


func _clear_strokes_now() -> void:
	for l in _strokes:
		l.queue_free()
	_strokes.clear()


func _do_signature() -> void:
	if _signed:
		return
	_signed = true
	_drawing = false
	_sign_btn.disabled = true
	_clear_btn.visible = false
	# Sin firma a mano (o un simple toque): firma sola con la pluma
	if _ink_points() < 8:
		_clear_strokes_now()
		_pen.visible = true
		var pts := _signature_points()
		_new_stroke(pts[0])
		var l: Line2D = _strokes[-1]
		for i in range(1, pts.size()):
			l.add_point(pts[i])
			_pen.position = pts[i] + Vector2(-3, 2)
			await get_tree().create_timer(0.016).timeout
			if not is_inside_tree():
				return
		_pen.visible = false
	await get_tree().create_timer(0.2).timeout
	if not is_inside_tree():
		return
	await _stamp()
	_show_welcome()


## Firma de pluma: un nombre "corrido" con lazos y un subrayado de vuelta.
func _signature_points() -> PackedVector2Array:
	# Trazo de cursiva: avance + giro circular (bucles) con altura que varía, y
	# un subrayado de vuelta. Queda a la izquierda: el sello cae a la derecha.
	var out := PackedVector2Array()
	var n := 90
	for i in range(n):
		var t := float(i) / float(n - 1)
		var w := t * TAU * 6.0
		var amp := 11.0 * (0.65 + 0.35 * sin(t * 9.0)) * (1.0 - t * 0.35)
		var x := 22.0 + t * 140.0 + sin(w) * 8.0
		var y := SIG_BASE - 20.0 - cos(w) * amp - t * 4.0
		if t < 0.1:
			y -= (0.1 - t) * 120.0   # mayúscula alta al empezar
		out.append(Vector2(x, y))
	for i in range(1, 16):
		var u := float(i) / 15.0
		out.append(Vector2(lerpf(165.0, 30.0, u), SIG_BASE - 8.0 + sin(u * PI) * 3.0))
	return out


## Sello "FIRMADO" del club: cae grande, golpea y se queda torcido sobre la firma.
func _stamp() -> void:
	var col: Color = _club_col if _club_col.get_luminance() < 0.6 else Color(0.72, 0.1, 0.12)
	var st := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.08)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	st.add_theme_stylebox_override("panel", sb)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", -3)
	st.add_child(sv)
	var big := _lbl("FIRMADO", 22, col, Styles.font_black())
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(big)
	var small := _lbl(String(_d.get("club_name", "")).to_upper(), 8, col, Styles.font_semibold())
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.clip_text = true
	small.custom_minimum_size = Vector2(104, 0)
	sv.add_child(small)
	_sig_area.add_child(st)
	st.reset_size()
	st.position = Vector2(SIG_W - st.size.x - 12, 8)
	st.pivot_offset = st.size / 2.0
	st.rotation = -0.21
	st.scale = Vector2(2.6, 2.6)
	st.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(st, "scale", Vector2.ONE, 0.16)
	tw.tween_property(st, "modulate:a", 0.92, 0.12)
	await tw.finished
	if not is_inside_tree():
		return
	# Golpe: la hoja se hunde un instante
	Haptics.hit("big")
	var sh := create_tween()
	sh.tween_property(_card, "scale", Vector2(0.985, 0.985), 0.04)
	sh.tween_property(_card, "scale", Vector2(1.005, 1.005), 0.06)
	sh.tween_property(_card, "scale", Vector2.ONE, 0.06)
	await get_tree().create_timer(0.45).timeout


func _show_welcome() -> void:
	if not is_inside_tree():
		return
	for c in _footer.get_children():
		c.queue_free()
	var big := _lbl("¡BIENVENIDO A %s!" % String(_d.get("club_name", "TU NUEVO CLUB")).to_upper(), 16,
			Color(0.08, 0.5, 0.25), Styles.font_black())
	if bool(_d.get("is_renewal", false)):
		big.text = "¡SEGUIMOS JUNTOS!"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_child(big)

	var cont := Button.new()
	cont.text = "Continuar"
	cont.custom_minimum_size = Vector2(0, 48)
	cont.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(cont, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	cont.pressed.connect(func():
		# Club NUEVO (no renovación): presentación oficial en el estadio
		# antes de seguir (9-oct, pedido de Wilber).
		if not bool(_d.get("is_renewal", false)) and String(_d.get("club_id", "")) != "" and _d.get("player", null) != null:
			var pp := PlayerPresentation.new()
			pp.setup({"club_id": _d["club_id"], "player": _d["player"], "years": int(_d.get("years", 3)),
				"number": int(_d.get("number", 0)), "loan": false})
			pp.finished.connect(func():
				confirmed.emit()
				queue_free())
			get_parent().add_child(pp)
			visible = false
			return
		confirmed.emit()
		queue_free())
	_footer.add_child(cont)
	Audio.match_sfx("trophy")

	var confetti := Confetti.new()
	confetti.position = Vector2(size.x * 0.5, 40)
	confetti.z_index = 210
	add_child(confetti)
	confetti.burst(2.2)
