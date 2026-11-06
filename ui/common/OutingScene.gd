extends Control
class_name OutingScene

## Escena ANIMADA de una salida (schema v33, vida social — Wilber: "crear
## animaciones para el mundo fuera del fútbol"). Fondo pixel del lugar
## (assets/outings/<tipo>.png), tu jugador de ropa de calle y tu
## acompañante, con animación según el lugar (corazones en una cita,
## luces de fiesta, parpadeo del cine, gol en la tribuna), y abajo la
## tarjeta con lo que cambió. Solo presentación: el resultado ya viene
## calculado por SocialLifeEngine.do_outing().

signal closed

var _res: Dictionary = {}
var _player: PlayerData
var _stage: Control

static func open(host: Node, result: Dictionary) -> OutingScene:
	var layer := CanvasLayer.new()
	layer.layer = 92
	host.add_child(layer)
	var s := OutingScene.new()
	s._res = result
	s.closed.connect(layer.queue_free)
	layer.add_child(s)
	return s

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("nav_back_handlers")
	_player = SaveManager.load_player()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", 18)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var kind: String = String(_res.get("outing", "cine"))
	var o: Dictionary = SocialLifeEngine.OUTINGS.get(kind, {})
	var with_id: String = String(_res.get("with", ""))
	var g: Dictionary = SocialLifeEngine.girl(with_id)
	var title := Label.new()
	title.text = String(o.get("name", "Salida")).to_upper() + ("  con " + String(g["name"]) if not g.is_empty() else ("  con compañeros" if kind == "videojuegos" else ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", Styles.font_black())
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(title)

	# --- Escenario ---
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(0, 430)
	_stage.clip_contents = true
	v.add_child(_stage)
	var pic := TextureRect.new()
	var path: String = "res://assets/outings/%s.png" % kind
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(pic)
	var fx := ColorRect.new()   # capa de luz (fiesta / cine)
	fx.color = Color(1, 1, 1, 0.0)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(fx)

	var cfg: Dictionary = Avatar.config_for_player(_player, SaveManager.load_world_seed())
	if not Avatar.wears_street(cfg):
		cfg["outfit"] = "hoodie"
	var me := Avatar.build_full(cfg, 190)
	_stage.add_child(me)
	var companion: Control = null
	if not g.is_empty():
		companion = _sprite(SocialLifeEngine.sprite_path(with_id), 190)
		_stage.add_child(companion)
	elif kind == "videojuegos":
		companion = Avatar.build_full(Avatar.config_for_npc("compa:%d" % WorldTickEngine.current_epoch_day, "player", SaveManager.load_world_seed()), 190)
		_stage.add_child(companion)
	_stage.resized.connect(func():
		var w: float = _stage.size.x
		var h: float = _stage.size.y
		if companion != null:
			me.position = Vector2(w * 0.5 - 190.0 + 14.0, h - 200.0)
			companion.position = Vector2(w * 0.5 - 14.0, h - 200.0)
		else:
			me.position = Vector2(w * 0.5 - 95.0, h - 200.0))
	_animate_place(kind, fx, me, companion, not g.is_empty())

	# --- Lo que cambió ---
	var card := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.09, 0.10, 0.14), 16)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	cv.add_child(_line("Ánimo  +%d" % int(_res.get("mood", 0)), Styles.GREEN))
	if float(_res.get("mental", 0.0)) > 0.5:
		cv.add_child(_line("Cansancio mental  −%d" % int(round(float(_res["mental"]))), Styles.BLUE))
	if int(_res.get("cost", 0)) > 0:
		cv.add_child(_line("Gasto  %s" % CurrencyFormat.format(int(_res["cost"])), Styles.GRAY_TEXT))
	if not g.is_empty():
		cv.add_child(_line("Afinidad con %s  +%d  (%d/100)" % [String(g["name"]), int(_res.get("aff", 0)), int(_player.affinities.get(with_id, 0))], Color(1, 0.45, 0.6)))
		if String(_res.get("stage_up", "")) != "":
			cv.add_child(_line("¡%s!" % String(SocialLifeEngine.STAGE_NAMES.get(_res["stage_up"], "")), Styles.GOLD, true))
	if kind == "videojuegos":
		cv.add_child(_line("Química con el plantel  +%d  · el DT lo nota (+1 confianza)" % int(_res.get("chem", 0)), Styles.GREEN))
	if bool(_res.get("press", false)):
		cv.add_child(_line("La prensa te vio de fiesta: −2 confianza del DT", Styles.RED))
	var met: String = String(_res.get("met", ""))
	if met != "":
		var mg: Dictionary = SocialLifeEngine.girl(met)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var face := _sprite(SocialLifeEngine.sprite_path(met), 64)
		row.add_child(face)
		var ml := _line("¡Conociste a %s!  %s. Ahora podés invitarla a salir." % [String(mg["name"]), String(mg["job"])], Color(1, 0.55, 0.7), true)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ml)
		cv.add_child(row)
		# Ella aparece en la escena.
		var her := _sprite(SocialLifeEngine.sprite_path(met), 190)
		her.modulate.a = 0.0
		_stage.add_child(her)
		_stage.resized.connect(func(): her.position = Vector2(_stage.size.x - 190.0, _stage.size.y - 200.0))
		var tw := her.create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(her, "modulate:a", 1.0, 0.5)
	v.add_child(card)
	Juice.stagger_in(cv, 0.18)

	var btn := Button.new()
	btn.text = "Continuar"
	btn.custom_minimum_size = Vector2(0, 52)
	btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	btn.pressed.connect(_close)
	v.add_child(btn)
	Audio.play("celebrate")

func nav_back() -> bool:
	_close()
	return true

func _close() -> void:
	closed.emit()
	queue_free()

func _sprite(path: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	if ResourceLoader.exists(path):
		r.texture = load(path)
	r.custom_minimum_size = Vector2(px, px)
	r.size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _line(text: String, col: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", Styles.font_black())
	return l

## Animación del lugar.
func _animate_place(kind: String, fx: ColorRect, me: Control, companion: Control, date: bool) -> void:
	# Respiración / balanceo suave de los personajes.
	for n in [me, companion]:
		if n == null:
			continue
		var tw := (n as Control).create_tween().set_loops()
		tw.tween_property(n, "scale", Vector2(1.0, 1.03), 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
		(n as Control).pivot_offset = Vector2(95, 190)
	match kind:
		"fiesta":
			var cols := [Color(1, 0.2, 0.6, 0.18), Color(0.2, 0.6, 1, 0.18), Color(0.6, 1, 0.3, 0.16), Color(1, 0.8, 0.2, 0.16)]
			var tw2 := fx.create_tween().set_loops()
			for c in cols:
				tw2.tween_property(fx, "color", c, 0.35)
			# Saltitos al ritmo.
			for n in [me, companion]:
				if n != null:
					var j := (n as Control).create_tween().set_loops()
					j.tween_property(n, "position:y", -8.0, 0.18).as_relative().set_trans(Tween.TRANS_QUAD)
					j.tween_property(n, "position:y", 8.0, 0.18).as_relative().set_trans(Tween.TRANS_QUAD)
		"cine":
			var tw3 := fx.create_tween().set_loops()
			tw3.tween_property(fx, "color", Color(0.6, 0.7, 1.0, 0.10), 0.5)
			tw3.tween_property(fx, "color", Color(0, 0, 0, 0.22), 0.7)
		"partido":
			var t := Timer.new()
			t.wait_time = 1.6
			t.autostart = true
			add_child(t)
			t.timeout.connect(func():
				Juice.float_text(_stage, "¡GOOOL!", Vector2(_stage.size.x * 0.5 - 60, 40), Styles.GOLD, 26)
				for n in [me, companion]:
					if n != null:
						var jj := (n as Control).create_tween()
						jj.tween_property(n, "position:y", -22.0, 0.15).as_relative()
						jj.tween_property(n, "position:y", 22.0, 0.2).as_relative())
		"videojuegos":
			var tw4 := fx.create_tween().set_loops()
			tw4.tween_property(fx, "color", Color(0.3, 0.5, 1.0, 0.10), 0.25)
			tw4.tween_property(fx, "color", Color(0, 0, 0, 0.05), 0.25)
	if date:
		# Corazones que suben entre los dos.
		var ht := Timer.new()
		ht.wait_time = 0.45
		ht.autostart = true
		add_child(ht)
		ht.timeout.connect(func():
			var x: float = _stage.size.x * 0.5 + randf_range(-40.0, 30.0)
			Juice.float_text(_stage, "♥", Vector2(x, _stage.size.y - 210.0), Color(1, 0.35, 0.55), randi_range(18, 30)))
