extends Control
class_name SigningCeremony

## Ceremonia de firma de contrato: overlay full-rect con la "hoja" del
## contrato (escudo del club, nivel, cláusulas), tu avatar, y una línea de
## firma que se DIBUJA con animación al pulsar "Firmar". Después:
## "¡Bienvenido!" + confeti + "Continuar".
##
## Uso:
##   var sc := SigningCeremony.new()
##   sc.setup({club_id, club_name, league_name, stars, wage, years, role,
##            number, is_renewal, player})
##   sc.confirmed.connect(_finalize)
##   add_child(sc)

signal confirmed

var _d: Dictionary = {}
var _sig_area: Control
var _sig_line: Line2D
var _pen: Polygon2D
var _sign_btn: Button
var _footer: VBoxContainer

func setup(data: Dictionary) -> SigningCeremony:
	_d = data
	return self

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.74)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	var club_col: Color = _club_color()
	card.add_theme_stylebox_override("panel", Styles.card_accent(club_col))
	center.add_child(card)

	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 16)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 16)
	card.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	var kind := Label.new()
	kind.text = "RENOVACIÓN DE CONTRATO" if bool(_d.get("is_renewal", false)) else "FICHAJE"
	kind.add_theme_font_override("font", Styles.font_black())
	kind.add_theme_color_override("font_color", Styles.GOLD)
	kind.add_theme_font_size_override("font_size", 13)
	v.add_child(kind)

	# --- Cabecera del club ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var cid: String = String(_d.get("club_id", ""))
	if cid != "":
		var cr := Styles.club_crest(cid, 44)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(cr)
	var hcol := VBoxContainer.new()
	hcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hcol.add_theme_constant_override("separation", 1)
	var cn := Label.new()
	cn.text = String(_d.get("club_name", "Club"))
	cn.add_theme_font_override("font", Styles.font_semibold())
	cn.add_theme_font_size_override("font_size", 16)
	hcol.add_child(cn)
	var ln := Label.new()
	ln.text = String(_d.get("league_name", ""))
	ln.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	ln.add_theme_font_size_override("font_size", 10)
	hcol.add_child(ln)
	var stars: int = clampi(int(_d.get("stars", 3)), 0, 5)
	hcol.add_child(Styles.star_row(stars, 5, 12))
	head.add_child(hcol)
	v.add_child(head)
	v.add_child(HSeparator.new())

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
	for r in rows:
		var hr := HBoxContainer.new()
		var k := Label.new()
		k.text = String(r[0])
		k.custom_minimum_size = Vector2(120, 0)
		k.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		k.add_theme_font_size_override("font_size", 12)
		hr.add_child(k)
		var val := Label.new()
		val.text = String(r[1])
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.add_theme_font_size_override("font_size", 12)
		hr.add_child(val)
		v.add_child(hr)

	v.add_child(HSeparator.new())

	# --- Firma ---
	var p: PlayerData = _d.get("player", null)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	if p != null:
		prow.add_child(Styles.portrait_frame(Avatar.for_player(p, SaveManager.load_world_seed(), 40), 40, club_col))
	var pcol := VBoxContainer.new()
	pcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pcol.add_theme_constant_override("separation", 1)
	var pn := Label.new()
	pn.text = p.player_name if p != null else "Jugador"
	pn.add_theme_font_override("font", Styles.font_semibold())
	pcol.add_child(pn)
	var pinfo := Label.new()
	pinfo.text = "%s · %d años" % [Positions.label_of(p.detailed_position), p.age] if p != null else ""
	pinfo.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	pinfo.add_theme_font_size_override("font_size", 10)
	pcol.add_child(pinfo)
	prow.add_child(pcol)
	v.add_child(prow)

	_sig_area = Control.new()
	_sig_area.custom_minimum_size = Vector2(280, 54)
	v.add_child(_sig_area)
	var base_line := Line2D.new()
	base_line.width = 1.0
	base_line.default_color = Color(1, 1, 1, 0.25)
	base_line.points = PackedVector2Array([Vector2(8, 46), Vector2(272, 46)])
	_sig_area.add_child(base_line)
	_sig_line = Line2D.new()
	_sig_line.width = 3.0
	_sig_line.default_color = Color(0.15, 0.22, 0.7)
	_sig_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_sig_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_sig_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_sig_area.add_child(_sig_line)
	_pen = Polygon2D.new()
	_pen.polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, -20), Vector2(15, -16), Vector2(5, 3)])
	_pen.color = Styles.GOLD
	_pen.visible = false
	_sig_area.add_child(_pen)
	var sig_hint := Label.new()
	sig_hint.text = "Firma del jugador"
	sig_hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sig_hint.add_theme_font_size_override("font_size", 8)
	sig_hint.position = Vector2(8, 46)
	_sig_area.add_child(sig_hint)

	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 6)
	v.add_child(_footer)

	_sign_btn = Button.new()
	_sign_btn.text = "Firmar contrato"
	_sign_btn.custom_minimum_size = Vector2(0, 48)
	_sign_btn.focus_mode = Control.FOCUS_NONE
	_sign_btn.icon = Icons.load_icon(Icons.CARD)
	_sign_btn.add_theme_constant_override("icon_max_width", 20)
	Styles.styled_button(_sign_btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	_sign_btn.pressed.connect(_do_signature)
	_footer.add_child(_sign_btn)

	# aparición
	card.modulate = Color(1, 1, 1, 0)
	card.scale = Vector2(0.92, 0.92)
	card.pivot_offset = card.size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.18)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18)

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

func _do_signature() -> void:
	_sign_btn.disabled = true
	_pen.visible = true
	var pts := _signature_points()
	_sig_line.clear_points()
	for i in range(pts.size()):
		_sig_line.add_point(pts[i])
		_pen.position = pts[i] + Vector2(-3, 2)
		await get_tree().create_timer(0.018).timeout
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.25).timeout
	_pen.visible = false
	_show_welcome()

func _signature_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := 46
	for i in range(n):
		var t := float(i) / float(n - 1)
		var x := 12.0 + t * 250.0
		var y := 34.0 + sin(t * 11.0) * 11.0 * exp(-t * 1.1) - t * 6.0
		if t > 0.82:
			y = 34.0 - (t - 0.82) * 40.0
		out.append(Vector2(x, y))
	return out

func _show_welcome() -> void:
	for c in _footer.get_children():
		c.queue_free()
	var ok := PanelContainer.new()
	ok.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GREEN))
	var mm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		mm.add_theme_constant_override("margin_" + s, 10)
	var okv := VBoxContainer.new()
	okv.add_theme_constant_override("separation", 2)
	var big := Label.new()
	big.text = "¡BIENVENIDO A %s!" % String(_d.get("club_name", "TU NUEVO CLUB")).to_upper()
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big.add_theme_font_override("font", Styles.font_black())
	big.add_theme_color_override("font_color", Styles.GREEN)
	big.add_theme_font_size_override("font_size", 15)
	okv.add_child(big)
	var sub := Label.new()
	sub.text = "Contrato firmado"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sub.add_theme_font_size_override("font_size", 10)
	okv.add_child(sub)
	mm.add_child(okv)
	ok.add_child(mm)
	_footer.add_child(ok)

	var cont := Button.new()
	cont.text = "Continuar"
	cont.custom_minimum_size = Vector2(0, 46)
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

	var confetti := Confetti.new()
	confetti.position = Vector2(size.x * 0.5, 40)
	confetti.z_index = 210
	add_child(confetti)
	confetti.burst(2.2)
