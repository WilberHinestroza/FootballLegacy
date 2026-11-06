extends Control
class_name PlayerPresentation

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
		number = Kit.suggested_number(p.position, "%s|%d" % [p.player_name, SaveManager.load_world_seed()])
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

## Flashes de fotógrafos: destellos blancos que aparecen y se apagan al azar.
func _process(delta: float) -> void:
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
