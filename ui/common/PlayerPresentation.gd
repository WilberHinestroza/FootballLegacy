extends Control
class_name PlayerPresentation
const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

## Presentación oficial del jugador en su NUEVO club (9-oct, pedido de
## Wilber: "diseña una presentación de jugador cuando firme con un nuevo
## club"). Overlay a pantalla completa:
##   estadio de noche + reflectores → "PRESENTACIÓN OFICIAL" + escudo →
##   tu jugador CON LA CAMISETA NUEVA (colores y diseño del club) besando
##   el escudo, al lado de la camiseta con tu dorsal → flashes de
##   fotógrafos + confeti en los colores del club → nombre, puesto, edad,
##   contrato → Continuar.
##
## Uso:
##   var pp := PlayerPresentation.new()
##   pp.setup({"club_id": id, "player": p, "years": 3, "number": 0, "loan": false})
##   pp.finished.connect(...)
##   add_child(pp)

signal finished

var _d: Dictionary = {}
var _club: ClubData = null
var _flash_layer: Control
var _rng := RandomNumberGenerator.new()
var _flash_t: float = 0.0
var _stage: PresentationStage = null   # presentación 3D (con el 3D activado)
var _bottom: Control = null

func setup(data: Dictionary) -> PlayerPresentation:
	_d = data
	return self

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 220
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	_club = WorldFactory.find_club(world, String(_d.get("club_id", "")))
	var p: PlayerData = _d.get("player", null)
	var cols: Array = Kit._club_colors(_club)
	var prim: Color = cols[0]
	var sec: Color = cols[1]

	# 7-nov: con el 3D, presentación de verdad en el estadio (PresentationStage)
	if Preferences.match_3d and _club != null and p != null and DisplayServer.get_name() != "headless":
		_build_3d(p, prim, sec)
		return
	# --- Estadio de noche, oscurecido ---
	var bg := StadiumBg.build(prim, sec, 7, "night")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.06, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	_flash_layer = Control.new()
	_flash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_layer)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var kind := _label("CESIÓN · PRESENTACIÓN OFICIAL" if bool(_d.get("loan", false)) else "PRESENTACIÓN OFICIAL", 15, Styles.GOLD, true)
	col.add_child(kind)
	if _club != null:
		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_theme_constant_override("separation", 10)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var crest := Styles.club_crest(_club.club_id, 60)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(crest)
		var cn := _label(_club.club_name, 24, Color.WHITE, true)
		# Sin autowrap: dentro de una fila sin ancho propio, el ajuste de
		# línea lo dejaba de UNA letra por renglón (bug de Godot conocido).
		cn.autowrap_mode = TextServer.AUTOWRAP_OFF
		cn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(cn)
		col.add_child(head)

	# --- Jugador con la camiseta nueva + camiseta con el dorsal ---
	var number: int = int(_d.get("number", 0))
	if number <= 0 and p != null:
		# Mismo dorsal que muestra el Perfil (Kit.suggested_number).
		number = ShirtNumberEngine.number_for(p, SaveManager.load_world_seed())
	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", -6)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Halo de luz detrás del jugador (en vez de un rectángulo de reflector).
	var halo_holder := Control.new()
	halo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p != null:
		var cfg: Dictionary = Avatar.config_for_player(p, SaveManager.load_world_seed()).duplicate()
		Avatar.strip_street(cfg)
		cfg["tint_clothing"] = prim.to_html(false)
		cfg["tint_shorts"] = sec.to_html(false)
		var kcfg: Dictionary = Kit.for_club_kit(_club, WorldTickEngine.get_season_start_year(), false) if _club != null else {}
		if int(kcfg.get("w", -1)) >= 0:
			cfg["kit_w"] = int(kcfg["w"])
			cfg["tint_kit2"] = sec.to_html(false)
		else:
			cfg.erase("kit_w")
		var anim: String = "celeb_escudo" if Avatar.has_anim("celeb_escudo") else "celeb_salto"
		halo_holder.custom_minimum_size = Vector2(240, 240)
		var halo := Panel.new()
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(prim.lightened(0.3), 0.20)
		hs.set_corner_radius_all(110)
		hs.shadow_color = Color(1, 0.95, 0.8, 0.30)
		hs.shadow_size = 40
		halo.add_theme_stylebox_override("panel", hs)
		halo.position = Vector2(30, 30)
		halo.size = Vector2(180, 180)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo_holder.add_child(halo)
		var body: Control = Avatar.build_anim(cfg, anim, 272, true, 7.0)
		body.position = Vector2(-16, -24)
		body.size = Vector2(272, 272)
		halo_holder.add_child(body)
		stage.add_child(halo_holder)
	if _club != null:
		var shirt := Kit.build_for_club_kit(_club, WorldTickEngine.get_season_start_year(), false, 140, number)
		shirt.custom_minimum_size = Vector2(140, 140)
		shirt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		shirt.rotation_degrees = 6.0
		shirt.pivot_offset = Vector2(75, 75)
		stage.add_child(shirt)
	col.add_child(stage)

	# --- Ficha ---
	if p != null:
		col.add_child(_label(p.player_name.to_upper(), 28, Color.WHITE, true))
		var yrs: int = int(_d.get("years", p.contract_years_remaining))
		var start_y: int = WorldTickEngine.get_season_start_year()
		var info := "%s · %d años · Dorsal %d" % [Positions.label_of(p.detailed_position), p.age, number]
		col.add_child(_label(info, 15, Color(0.85, 0.87, 0.92), false))
		var contract := ("Cedido por una temporada" if bool(_d.get("loan", false)) else "Contrato hasta %d" % (start_y + maxi(1, yrs)))
		col.add_child(_label(contract, 14, Styles.GOLD, false))

	var cont := Button.new()
	cont.text = "Continuar"
	cont.custom_minimum_size = Vector2(260, 52)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(cont, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	cont.pressed.connect(func():
		finished.emit()
		queue_free())
	col.add_child(cont)

	# --- Entrada + confeti en los colores del club ---
	col.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(col, "modulate:a", 1.0, 0.45)
	tw.tween_callback(func():
		var cf := Confetti.new()
		cf.position = Vector2(size.x * 0.5, -10)
		cf.z_index = 5
		add_child(cf)
		cf.burst(3.0)
		Audio.match_sfx("trophy"))
	Haptics.hit("big")

## Presentación 3D: el estadio a pantalla completa con la ceremonia, arriba el rótulo
## del club y, cuando posa ante la grada, la ficha y "Continuar". Tocar la salta.
func _build_3d(p: PlayerData, prim: Color, sec: Color) -> void:
	var wseed: int = SaveManager.load_world_seed()
	var year: int = WorldTickEngine.get_season_start_year()
	var number: int = int(_d.get("number", 0))
	if number <= 0:
		number = ShirtNumberEngine.number_for(p, wseed)
	var words: PackedStringArray = p.player_name.split(" ", false)
	var cid: String = _club.club_id
	var club: ClubData = _club
	var view := PresentationStage.make_view({
		"profile": Match3DBridge.profile_for(p, wseed, prim, sec, prim),
		"shirt": prim, "shirt2": sec,
		"pattern": Match3DBridge._pattern(_club, year, false),
		"crest_center": Kit.crest_centered(cid, year),
		"crest": func() -> Control: return Styles.club_crest(cid, 256),
		"held_shirt": func() -> Control: return Kit.build_for_club_kit(club, year, false, 256, number),
		"club_name": _club.club_name,
		"sponsor": KitDecals.sponsor_for(_club.club_name),
		"surname": words[words.size() - 1] if words.size() > 0 else "",
		"number": number,
		"stars": Venue.stars(_club),
	}, get_viewport_rect().size)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	_stage = view.get_node("SubViewport/Stage") if view.has_node("SubViewport/Stage") else null
	if _stage == null:
		for c in view.get_children():
			if c is SubViewport and c.get_child_count() > 0:
				_stage = c.get_child(0) as PresentationStage
	# Viñeta para que se lea el texto encima
	var top_shade := _gradient(true)
	add_child(top_shade)
	var bot_shade := _gradient(false)
	add_child(bot_shade)
	# Rótulo de arriba: tipo de presentación y club
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 14
	top.add_theme_constant_override("separation", 2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	top.add_child(_label("CESIÓN · PRESENTACIÓN OFICIAL" if bool(_d.get("loan", false)) else "PRESENTACIÓN OFICIAL", 14, Styles.GOLD, true))
	top.add_child(_label(_club.club_name.to_upper(), 22, Color.WHITE, true))
	# Ficha de abajo (aparece al final)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -16
	bottom.add_theme_constant_override("separation", 4)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.modulate.a = 0.0
	add_child(bottom)
	_bottom = bottom
	bottom.add_child(_label(p.player_name.to_upper(), 30, Color.WHITE, true))
	var yrs: int = int(_d.get("years", p.contract_years_remaining))
	bottom.add_child(_label("%s · %d años · Dorsal %d" % [Positions.label_of(p.detailed_position), p.age, number], 15, Color(0.88, 0.9, 0.95), false))
	bottom.add_child(_label("Cedido por una temporada" if bool(_d.get("loan", false)) else "Contrato hasta %d" % (year + maxi(1, yrs)), 14, Styles.GOLD, false))
	var cont := Button.new()
	cont.text = "Continuar"
	cont.custom_minimum_size = Vector2(260, 52)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(cont, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	cont.pressed.connect(func():
		finished.emit()
		queue_free())
	bottom.add_child(cont)
	var hint := _label("Toca para saltar", 11, Color(1, 1, 1, 0.6), false)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -30
	hint.offset_bottom = -10
	hint.name = "SkipHint"
	add_child(hint)
	if _stage != null:
		_stage.finale.connect(_show_card)
	else:
		_show_card()
	Haptics.hit("big")


func _show_card() -> void:
	if _bottom == null or _bottom.modulate.a > 0.5:
		return
	if has_node("SkipHint"):
		get_node("SkipHint").queue_free()
	var tw := create_tween()
	tw.tween_property(_bottom, "modulate:a", 1.0, 0.5).set_delay(0.6)
	Audio.match_sfx("trophy")


func _gui_input(event: InputEvent) -> void:
	if _stage == null:
		return
	var tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) 			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap and _bottom != null and _bottom.modulate.a < 0.5:
		_stage.skip_to_end()


func _gradient(top: bool) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0) if top else Vector2(0, 1)
	gt.fill_to = Vector2(0, 1) if top else Vector2(0, 0)
	gt.width = 8
	gt.height = 64
	var r := TextureRect.new()
	r.texture = gt
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		r.offset_bottom = 110
	else:
		r.offset_top = -230
	return r


## Flashes de fotógrafos: destellos blancos que aparecen y se apagan al azar.
func _process(delta: float) -> void:
	if _stage != null:
		return
	_flash_t -= delta
	if _flash_t > 0.0 or Preferences.reduce_motion:
		return
	_flash_t = _rng.randf_range(0.12, 0.45)
	var f := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.9)
	sb.set_corner_radius_all(40)
	sb.shadow_color = Color(1, 1, 1, 0.7)
	sb.shadow_size = 26
	f.add_theme_stylebox_override("panel", sb)
	var s: float = _rng.randf_range(8, 18)
	f.size = Vector2(s, s)
	# Los fotógrafos están abajo y a los costados (zona de prensa).
	var x: float = _rng.randf_range(0.02, 0.98) * size.x
	var y: float = _rng.randf_range(0.70, 0.98) * size.y if _rng.randf() < 0.7 else _rng.randf_range(0.2, 0.7) * size.y
	if y < size.y * 0.7 and x > size.x * 0.2 and x < size.x * 0.8:
		x = size.x * (0.05 if _rng.randf() < 0.5 else 0.95)
	f.position = Vector2(x, y)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "modulate:a", 0.0, 0.22).set_delay(0.04)
	tw.tween_callback(f.queue_free)

func _label(text: String, px: int, col: Color, black: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Styles.font_black() if black else Styles.font_semibold())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
