extends Control
class_name FarewellCeremony
const _M3D = preload("res://engine/match/m3d/Match3DBridge.gd")  # retrato 3D

## CEREMONIA DE DESPEDIDA (10-oct, Wilber: "sería solo ceremonia de
## despedida y si fui muy bueno, retirada de camiseta"). Láminas a pantalla
## completa que se pasan tocando (mismo patrón que SeasonWrapped): la
## tribuna con el tifo y tu nombre, los números de la carrera, las palabras
## del DT y — si LegacyEngine.jersey_retired() — el club colgando tu número.
## Solo lectura: las reglas viven en LegacyEngine.

signal closed

var _p: PlayerData
var _club: ClubData
var _slides: Array = []
var _i: int = 0
var _holder: Control

static func open(host: Node, player: PlayerData, club: ClubData) -> FarewellCeremony:
	var layer := CanvasLayer.new()
	layer.layer = 96
	host.add_child(layer)
	var f := FarewellCeremony.new()
	f._p = player
	f._club = club
	f.closed.connect(layer.queue_free)
	layer.add_child(f)
	return f

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("nav_back_handlers")
	_slides = ["tifo", "numbers", "coach"]
	if LegacyEngine.jersey_retired(_p):
		_slides.append("jersey")
	_holder = Control.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_show(0)

func _gui_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if pressed:
		accept_event()
		if _i + 1 >= _slides.size():
			_close()
		else:
			_show(_i + 1)

func nav_back() -> bool:
	_close()
	return true

func _close() -> void:
	closed.emit()
	queue_free()

func _club_col() -> Color:
	var c: Color = Color(_club.primary_color_hex) if _club != null and _club.primary_color_hex != "" else Styles.BLUE
	return c

func _number() -> int:
	return ShirtNumberEngine.number_for(_p, SaveManager.load_world_seed())

func _show(i: int) -> void:
	_i = i
	for c in _holder.get_children():
		c.queue_free()
	match String(_slides[i]):
		"tifo": _slide_tifo()
		"numbers": _slide_numbers()
		"coach": _slide_coach()
		"jersey": _slide_jersey()
	var hint := _lbl("tocá para seguir  ›" if i + 1 < _slides.size() else "tocá para ver tu Salón de la Fama", 14, Color(1, 1, 1, 0.65))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -48
	hint.offset_bottom = -20
	_holder.add_child(hint)
	Audio.play("click")

func _bg(path: String, veil: float) -> void:
	var bg := TextureRect.new()
	if ResourceLoader.exists(path):
		bg.texture = load(path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(bg)
	var v := ColorRect.new()
	v.color = Color(0, 0, 0, veil)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(v)

func _col() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	_holder.add_child(v)
	v.modulate.a = 0.0
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.35)
	return v

## 1 · La tribuna con el tifo: "GRACIAS, <NOMBRE>" + vos saludando.
func _slide_tifo() -> void:
	_bg("res://assets/scenes/tifo.png", 0.30)
	var v := _col()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.offset_top = 70
	var banner := PanelContainer.new()
	var sb := Styles.card_flat(_club_col(), 6)
	sb.set_border_width_all(3)
	sb.border_color = Color.WHITE
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", sb)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bl := _lbl("GRACIAS, %s" % _p.player_name.to_upper(), 24, Styles.contrasting_text_color(_club_col()))
	# Sin autowrap: dentro de un panel que se encoge, el ajuste por palabra
	# lo dejaba en una columna de UNA letra (visto en captura real).
	bl.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner.add_child(bl)
	v.add_child(banner)
	banner.rotation = -0.03
	Juice.pop(banner, 1.12, 0.5)
	v.add_child(_lbl("EL ÚLTIMO ADIÓS", 18, Styles.GOLD))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var av: Control = _M3D.portrait(_p, null, 260, true)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(av)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 70)
	v.add_child(gap)
	av.ready.connect(func(): Juice.bob(av, 5.0, 1.2))
	# Cánticos de la tribuna.
	var nick: String = Nickname.for_player(_p, SaveManager.load_world_seed())
	var chant: String = "¡Olé, olé, %s!" % (nick if nick != "" else _p.player_name.split(" ")[0])
	var t := create_tween().set_loops(3)
	t.tween_callback(func():
		if is_instance_valid(_holder) and _i == 0:
			Juice.float_text(_holder, chant, Vector2(randf_range(60, 380), randf_range(380, 520)), Color(1, 1, 1, 0.95), 20))
	t.tween_interval(1.1)
	var cf := Confetti.new()
	cf.position = Vector2(288, -10)
	_holder.add_child(cf)
	cf.burst(3.0)

## 2 · La carrera en números (contando).
func _slide_numbers() -> void:
	_bg("res://assets/scenes/locker.png", 0.62)
	var v := _col()
	v.add_child(_lbl("TU CARRERA", 24, Color.WHITE))
	var rows := [[_p.career_matches, "partidos"], [_p.career_goals, "goles"], [_p.career_assists, "asistencias"], [_p.career_titles.size(), "títulos y premios"]]
	for r in rows:
		var big := _lbl("0", 58, Styles.GOLD)
		v.add_child(big)
		Juice.count_up(big, 0, int(r[0]), 1.0)
		var cap := _lbl(String(r[1]), 18, Color(1, 1, 1, 0.85))
		v.add_child(cap)
	var lt: int = LegacyEngine.tier(_p)
	var chip_row := CenterContainer.new()
	chip_row.add_child(UiKit.chip("Legado: %s" % LegacyEngine.TIER_NAMES[lt], [Styles.GRAY_TEXT, Styles.BLUE, Styles.GOLD, Styles.PURPLE][lt]))
	v.add_child(chip_row)

## 3 · Las palabras del DT.
func _slide_coach() -> void:
	_bg("res://assets/scenes/office.png", 0.55)
	var v := _col()
	var seed_i: int = SaveManager.load_world_seed()
	var face := Avatar.with_expression(Avatar.config_for_npc("coach:%s" % _p.club_id, "coach", seed_i), "feliz")
	var cc := CenterContainer.new()
	cc.add_child(Styles.portrait_frame(Avatar.build(face, 110), 110, Styles.GOLD))
	v.add_child(cc)
	v.add_child(_lbl("Tu entrenador", 16, Styles.GRAY_TEXT))
	var q := _lbl(LegacyEngine.coach_words(_p), 22, Color.WHITE)
	v.add_child(q)

## 4 · El club retira tu camiseta.
func _slide_jersey() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(bg)
	var spot := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.75, 0.35))
	g.set_color(1, Color(1, 0.95, 0.75, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	spot.texture = gt
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(spot)
	var v := _col()
	v.add_child(_lbl("CAMISETA RETIRADA", 28, Styles.GOLD))
	var frame := PanelContainer.new()
	var fsb := Styles.card_flat(Color(0.10, 0.09, 0.06), 10)
	fsb.set_border_width_all(4)
	fsb.border_color = Styles.GOLD
	fsb.content_margin_left = 18
	fsb.content_margin_right = 18
	fsb.content_margin_top = 18
	fsb.content_margin_bottom = 18
	frame.add_theme_stylebox_override("panel", fsb)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _club != null:
		frame.add_child(Kit.build_for_club_kit(_club, WorldTickEngine.get_season_start_year(), false, 190, _number()))
	v.add_child(frame)
	frame.ready.connect(func():
		frame.pivot_offset = frame.size * 0.5
		Juice.pop(frame, 1.15, 0.6))
	var club_name: String = _club.club_name if _club != null else "Tu club"
	v.add_child(_lbl("%s retira el N.º %d en tu honor." % [club_name, _number()], 20, Color.WHITE))
	v.add_child(_lbl("Nadie más la va a usar.", 16, Color(1, 1, 1, 0.7)))
	var cf := Confetti.new()
	cf.position = Vector2(288, -10)
	_holder.add_child(cf)
	cf.burst(4.0)

func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 6)
	return l
