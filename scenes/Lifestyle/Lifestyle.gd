extends Control

## Vida personal — bienestar (métricas derivadas + recuperación pagada de
## energía/tensión), patrimonio, vivienda y coche. Compra con
## PlayerData.balance; guarda al momento. El representante tiene su propia
## pantalla (scenes/Agent). "Staff personal" e "Inversiones" quedan para
## cuando se apruebe el cambio de esquema (necesitan estado persistente
## por carrera, no por temporada).

@onready var body: VBoxContainer = $Margin/VBox/Scroll/Body
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var back_button: Button = $Margin/VBox/BackButton

var _player: PlayerData = null
var _inv_picker_open: bool = false
## Héroe; en horizontal encabeza la columna izquierda (info a la izquierda).
var _hero_card: PanelContainer = null

func _ready() -> void:
	WorldTickEngine.load_runtime()
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn"))
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_player = SaveManager.load_player()
	_build_hero()
	_land = get_viewport_rect().size.x > get_viewport_rect().size.y
	if _land:
		_build_land_menu()
	_render()

## HORIZONTAL estilo consola: a la izquierda tu casa y el menú de secciones, a
## la derecha solo la sección elegida (antes era una lista larga en dos columnas).
var _land := false
var _land_page := "social"
var _land_menu: VBoxContainer = null
const _LAND_PAGES := [["social", "Vida social"], ["wellbeing", "Bienestar"], ["home", "Casa y coche"],
	["staff", "Staff personal"], ["money", "Finanzas"]]

func _build_land_menu() -> void:
	var vb: VBoxContainer = $Margin/VBox
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	vb.move_child(row, scroll.get_index())
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 270
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	if _hero_card != null:
		UiKit.hero_to_column(_hero_card)
		_hero_card.reparent(left)
	_land_menu = VBoxContainer.new()
	_land_menu.add_theme_constant_override("separation", 6)
	left.add_child(_land_menu)
	scroll.reparent(row)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.visible = false   # "volver" está en la barra de arriba
	var bd := UiKit.club_backdrop(Styles.PURPLE.darkened(0.2))
	add_child(bd)
	move_child(bd, 0)
	_refresh_land_menu()

func _refresh_land_menu() -> void:
	for c in _land_menu.get_children():
		c.queue_free()
	for p in _LAND_PAGES:
		var b := Button.new()
		b.text = String(p[1])
		b.custom_minimum_size.y = 40
		b.focus_mode = Control.FOCUS_NONE
		Styles.tab(b, p[0] == _land_page)
		var key: String = String(p[0])
		b.pressed.connect(func() -> void:
			if _land_page == key:
				return
			Haptics.hit("tap")
			_land_page = key
			_refresh_land_menu()
			_render()
			scroll.scroll_vertical = 0)
		_land_menu.add_child(b)

## Cabecera héroe (9-oct, rediseño): tu casa en pixel art, dinero, casa y coche.
func _build_hero() -> void:
	$Margin/VBox/TitleLabel.visible = false
	$Margin/VBox/SubLabel.visible = false
	if _player == null:
		return
	var tex := _life_tex(_player.home_type)
	var left: Control = null
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(80, 80)
		left = r
	var hero := UiKit.hero(Styles.PURPLE, left, "Vida personal", "Fuera del campo también vivís · %s" % CurrencyFormat.format(_player.balance),
		[[LifestyleEngine.home_label(_player.home_type), Styles.GOLD], [LifestyleEngine.car_label(_player.car_type), Color(0.6, 0.75, 1.0)]])
	var vb: VBoxContainer = $Margin/VBox
	vb.add_child(hero)
	vb.move_child(hero, 0)
	_hero_card = hero

func _render() -> void:
	if not _land and _hero_card != null and is_instance_valid(_hero_card) and _hero_card.get_parent() != $Margin/VBox:
		_hero_card.reparent($Margin/VBox)
		$Margin/VBox.move_child(_hero_card, 0)
	for c in body.get_children():
		c.queue_free()
	if _player == null:
		body.add_child(_plain("Sin jugador activo."))
		return

	var sections: Array[Callable] = [
		_build_money,
		_build_social,
		_build_wellbeing,
		_build_physical,
		_build_adaptation,
		_build_wellness_actions,
		func(): _build_tier_section("Residencia", LifestyleEngine.HOME_TIERS, "home"),
		func(): _build_tier_section("Garaje", LifestyleEngine.CAR_TIERS, "car"),
		_build_staff,
		_build_investments,
	]
	var land: bool = _land
	if land:
		match _land_page:
			"social": sections = [_build_social]
			"wellbeing": sections = [_build_wellbeing, _build_physical, _build_adaptation, _build_wellness_actions]
			"home": sections = [func(): _build_tier_section("Residencia", LifestyleEngine.HOME_TIERS, "home"),
				func(): _build_tier_section("Garaje", LifestyleEngine.CAR_TIERS, "car")]
			"staff": sections = [_build_staff]
			_: sections = [_build_money, _build_investments]
	var groups: Array = []
	for i in range(sections.size()):
		if i > 0 and not land:
			body.add_child(_bullet_divider())
		var before: int = body.get_child_count()
		sections[i].call()
		var g: Array = []
		for k in range(before, body.get_child_count()):
			g.append(body.get_child(k))
		groups.append(g)
	if land and groups.size() > 1 and _land_page != "money":
		_two_columns(groups)
		var sc := body.get_parent() as ScrollContainer
		if sc != null:
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiScroll.pad_bottom(body)

## HORIZONTAL (FootballLegacy H): las secciones en DOS columnas, cada una a
## la columna más baja en ese momento (queda pareja y se scrollea la mitad).
func _two_columns(groups: Array) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	var col_v: Array = []
	var col_h: Array = [0.0, 0.0]
	for i in 2:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", body.get_theme_constant("separation"))
		cols.add_child(v)
		col_v.append(v)
	body.add_child(cols)
	if not _land and _hero_card != null and is_instance_valid(_hero_card):
		UiKit.hero_to_column(_hero_card)
		_hero_card.reparent(col_v[0])
		col_h[0] = _hero_card.get_combined_minimum_size().y + 16.0
	for g in groups:
		var h: float = 0.0
		for n in g:
			if n is Control:
				h += (n as Control).get_combined_minimum_size().y + 8.0
		var tgt: int = 0 if col_h[0] <= col_h[1] else 1
		for n in g:
			(n as Node).reparent(col_v[tgt])
		col_h[tgt] += h + 16.0

## Viñeta separadora entre secciones de Vida personal (pedido de Wilber):
## línea tenue con un rombo centrado.
func _bullet_divider() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 18)
	var ll := ColorRect.new()
	ll.color = Color(1, 1, 1, 0.10)
	ll.custom_minimum_size = Vector2(0, 2)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot := Label.new()
	dot.text = "◆"
	dot.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
	dot.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	var rl := ColorRect.new()
	rl.color = Color(1, 1, 1, 0.10)
	rl.custom_minimum_size = Vector2(0, 2)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ll)
	row.add_child(dot)
	row.add_child(rl)
	return row

# --- Dinero ---

func _build_money() -> void:
	var card := _card(Styles.GOLD)
	var v := _card_body(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_money_col("Dinero líquido", _player.balance))
	var sep := VSeparator.new()
	row.add_child(sep)
	row.add_child(_money_col("Patrimonio total", LifestyleEngine.net_worth(_player)))
	v.add_child(row)
	body.add_child(card)

func _money_col(label: String, amount: int) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	l.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	var n := Label.new()
	n.text = CurrencyFormat.format(amount)
	n.add_theme_font_override("font", Styles.font_black())
	n.add_theme_font_size_override("font_size", 20)
	n.add_theme_color_override("font_color", Styles.GOLD)
	c.add_child(l)
	c.add_child(n)
	return c

# --- Bienestar personal (derivado) ---

func _build_wellbeing() -> void:
	var wb: Dictionary = LifestyleEngine.wellbeing(_player)
	body.add_child(Styles.section_label("Bienestar personal"))
	var card := _card(Styles.CARD_DARK)
	var v := _card_body(card)
	v.add_child(_bar("Felicidad", int(wb["felicidad"]), false))
	v.add_child(_bar("Estrés", int(wb["estres"]), true))
	v.add_child(_bar("Motivación", int(wb["motivacion"]), false))
	body.add_child(card)

# --- Estado físico y mental (fatiga real) ---

func _build_physical() -> void:
	var energy: int = clampi(100 - int(round(_player.fatigue_physical)), 0, 100)
	var calm: int = clampi(100 - int(round(_player.fatigue_mental)), 0, 100)
	body.add_child(Styles.section_label("Estado físico y mental"))
	var card := _card(Styles.CARD_DARK)
	var v := _card_body(card)

	var forma := HBoxContainer.new()
	var fl := Label.new()
	fl.text = "Forma actual"
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	var fv := Label.new()
	fv.text = _form_label(energy)
	fv.add_theme_font_override("font", Styles.font_semibold())
	fv.add_theme_color_override("font_color", _bar_color(energy, false))
	forma.add_child(fl)
	forma.add_child(fv)
	v.add_child(forma)

	v.add_child(_bar("Energía física", energy, false))
	v.add_child(_bar("Calma mental", calm, false))
	if _player.injury_days_remaining > 0:
		var inj := Label.new()
		inj.text = "Lesión: %d días de baja" % _player.injury_days_remaining
		inj.add_theme_color_override("font_color", Styles.RED)
		inj.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(inj)
	body.add_child(card)

func _form_label(energy: int) -> String:
	if energy >= 85:
		return "Excelente"
	if energy >= 65:
		return "Normal"
	if energy >= 45:
		return "Justa"
	return "Baja"

# --- Adaptación al club ---

func _build_adaptation() -> void:
	var wb: Dictionary = LifestyleEngine.wellbeing(_player)
	var adap: int = int(wb["adaptacion"])
	body.add_child(Styles.section_label("Adaptación al club"))
	var card := _card(Styles.BLUE)
	var v := _card_body(card)
	var head := HBoxContainer.new()
	var hl := Label.new()
	hl.text = "Adaptación"
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	var hv := Label.new()
	var state: String = "Asentado" if adap >= 80 else ("En proceso" if adap >= 35 else "Recién llegado")
	hv.text = "%d%% · %s" % [adap, state]
	hv.add_theme_font_override("font", Styles.font_semibold())
	hv.add_theme_color_override("font_color", Styles.BLUE if adap >= 35 else Styles.AMBER)
	head.add_child(hl)
	head.add_child(hv)
	v.add_child(head)
	v.add_child(_bar("", adap, false))
	var hint := Label.new()
	hint.text = "Mejora con el tiempo en el club y los partidos jugados."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hint.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(hint)
	body.add_child(card)

# --- Vida social (SocialLifeEngine, schema v33) ---
# Salidas semanales animadas (OutingScene), chicas para conocer, afinidad,
# noviazgo y ánimo. Reemplaza el "salir a conocer gente" instantáneo de v18.

var _companion: String = ""

func _build_social() -> void:
	var today: int = WorldTickEngine.current_epoch_day
	body.add_child(Styles.section_label("Vida social"))
	var pink := Color(0.92, 0.42, 0.6)

	# Ánimo.
	var mood_card := _card(pink)
	var mv := _card_body(mood_card)
	var mrow := HBoxContainer.new()
	var ml := Label.new()
	ml.text = "Ánimo: %s" % SocialLifeEngine.mood_label(_player.mood)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.add_theme_font_override("font", Styles.font_semibold())
	mrow.add_child(ml)
	var mval := Label.new()
	mval.text = "%d/100" % _player.mood
	mrow.add_child(mval)
	mv.add_child(mrow)
	var mbar := ProgressBar.new()
	mbar.show_percentage = false
	mbar.custom_minimum_size = Vector2(0, 10)
	mbar.max_value = 100
	var fg := StyleBoxFlat.new()
	fg.bg_color = pink
	fg.set_corner_radius_all(5)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.08)
	bgs.set_corner_radius_all(5)
	mbar.add_theme_stylebox_override("fill", fg)
	mbar.add_theme_stylebox_override("background", bgs)
	mv.add_child(mbar)
	mbar.create_tween().tween_property(mbar, "value", float(_player.mood), 0.6)
	var mh := Label.new()
	mh.text = "Con el ánimo alto jugás un poco mejor (zona verde más ancha); bajoneado, peor."
	mh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mh.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	mh.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	mv.add_child(mh)
	body.add_child(mood_card)

	# Pareja (si hay).
	if RelationshipEngine.has_partner(_player):
		var pc := _card(pink)
		var pv := _card_body(pc)
		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 12)
		var pid: String = String(_player.partner.get("npc_id", ""))
		if pid != "":
			prow.add_child(_person_sprite(pid, 72))
		else:
			prow.add_child(Styles.portrait_frame(Avatar.for_npc(String(_player.partner.get("name", "?")), "partner", SaveManager.load_world_seed(), 56), 56, pink))
		var pcol := VBoxContainer.new()
		pcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pn := Label.new()
		pn.text = "♥ " + String(_player.partner.get("name", "?"))
		pn.add_theme_font_override("font", Styles.font_black())
		pn.add_theme_font_size_override("font_size", 18)
		pn.add_theme_color_override("font_color", pink)
		pcol.add_child(pn)
		var ps := Label.new()
		ps.text = RelationshipEngine.status_line(_player, today)
		ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ps.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		pcol.add_child(ps)
		prow.add_child(pcol)
		pv.add_child(prow)
		var end := Button.new()
		end.custom_minimum_size = Vector2(0, 40)
		end.focus_mode = Control.FOCUS_NONE
		end.text = "Terminar la relación"
		Styles.styled_button(end, Styles.pill_outlined(Styles.RED), Styles.RED)
		end.pressed.connect(func():
			SocialLifeEngine.break_up(_player)
			SaveManager.save_player(_player)
			_render())
		pv.add_child(end)
		body.add_child(pc)

	# Chicas que conociste.
	var known: Array = SocialLifeEngine.known(_player)
	if not known.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for g in known:
			flow.add_child(_girl_card(g))
		body.add_child(flow)

	# Salidas.
	var used: bool = SocialLifeEngine.outing_used(WorldTickEngine.season, today)
	var oc := _card(Styles.CARD_DARK)
	var ov := _card_body(oc)
	var oh := Label.new()
	if used:
		oh.text = "Ya saliste esta semana. La próxima salida, en %d día(s)." % (7 - today % 7)
	elif _companion != "":
		oh.text = "Elegí a dónde ir con %s:" % String(SocialLifeEngine.girl(_companion).get("name", ""))
	else:
		oh.text = "Una salida por semana. Solo podés conocer a alguien; acompañado, suma afinidad."
	oh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oh.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	ov.add_child(oh)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for kind in ["cine", "cena", "partido", "fiesta", "videojuegos"]:
		var o: Dictionary = SocialLifeEngine.OUTINGS[kind]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var price: String = CurrencyFormat.format(int(o["cost"])) if int(o["cost"]) > 0 else "gratis"
		b.text = String(o["name"]) + "\n" + price
		b.disabled = used or _player.balance < int(o["cost"]) or (kind == "videojuegos" and _companion != "")
		var thumb: String = "res://assets/outings/%s.png" % kind
		if ResourceLoader.exists(thumb):
			b.icon = _thumb(thumb)
			b.expand_icon = false
		Styles.styled_button(b, Styles.card_accent(pink) if not b.disabled else Styles.pill_outlined(Color(1, 1, 1, 0.15)), Color.WHITE if not b.disabled else Styles.GRAY_TEXT)
		b.pressed.connect(_on_outing.bind(kind))
		grid.add_child(b)
	ov.add_child(grid)
	if _companion != "":
		var solo := Button.new()
		solo.text = "Ir solo"
		solo.custom_minimum_size = Vector2(0, 38)
		solo.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(solo, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		solo.pressed.connect(func():
			_companion = ""
			_render())
		ov.add_child(solo)
	body.add_child(oc)

func _girl_card(g: Dictionary) -> Control:
	var id: String = String(g["id"])
	var aff: int = int(_player.affinities.get(id, 0))
	var stage: String = SocialLifeEngine.stage_of(_player, id)
	var pink := Color(0.92, 0.42, 0.6)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 0)
	var sb := Styles.card_flat(Color(0.12, 0.08, 0.11), 14)
	sb.set_border_width_all(2)
	sb.border_color = Styles.GOLD if id == _companion else Color(pink, 0.5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var cc := CenterContainer.new()
	cc.add_child(_person_sprite(id, 80))
	v.add_child(cc)
	var n := Label.new()
	n.text = String(g["name"])
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_override("font", Styles.font_black())
	v.add_child(n)
	var j := Label.new()
	j.text = "%s · %s" % [String(g["job"]), String(SocialLifeEngine.STAGE_NAMES[stage])]
	j.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	j.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	j.add_theme_font_size_override("font_size", 11)
	j.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(j)
	var full: int = clampi(int(ceil(aff / 20.0)), 0, 5)
	var hearts := Label.new()
	hearts.text = "♥".repeat(full) + "♡".repeat(5 - full)
	hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hearts.add_theme_color_override("font_color", pink)
	v.add_child(hearts)
	if stage != "novia" and SocialLifeEngine.can_ask_out(_player, id):
		var ask := Button.new()
		ask.focus_mode = Control.FOCUS_NONE
		ask.custom_minimum_size = Vector2(0, 34)
		ask.text = "Pedirle ser novios"
		Styles.styled_button(ask, Styles.pill_filled(pink), Color.BLACK)
		ask.pressed.connect(func():
			var yes: bool = SocialLifeEngine.ask_out(_player, id, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed())
			SaveManager.save_player(_player)
			_render()
			if yes:
				Nav.toast("¡%s dijo que sí! ♥" % String(g["name"]))
			else:
				Nav.toast("%s todavía no está lista. Seguí invitándola." % String(g["name"])))
		v.add_child(ask)
	var inv := Button.new()
	inv.focus_mode = Control.FOCUS_NONE
	inv.custom_minimum_size = Vector2(0, 34)
	inv.text = "Invitada ✓" if id == _companion else "Invitar a salir"
	Styles.styled_button(inv, Styles.pill_outlined(pink), pink)
	inv.pressed.connect(func():
		_companion = "" if _companion == id else id
		_render())
	v.add_child(inv)
	return card

func _person_sprite(id: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	var path: String = SocialLifeEngine.sprite_path(id)
	if ResourceLoader.exists(path):
		r.texture = load(path)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _thumb(path: String) -> Texture2D:
	var img: Image = (load(path) as Texture2D).get_image()
	img.resize(64, 36, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func _on_outing(kind: String) -> void:
	var res: Dictionary = SocialLifeEngine.do_outing(_player, WorldTickEngine.season, kind, _companion, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed())
	if not bool(res.get("ok", false)):
		return
	if bool(res.get("press", false)):
		PressGenerator.append_to_feed(_player, {
			"headline": "%s, de fiesta en plena temporada" % _player.player_name,
			"body": "Lo vieron saliendo tarde de un boliche. En el club no cayó bien.",
			"source": "TRIBUNA", "sentiment": "CRITICAL",
		}, WorldTickEngine.current_epoch_day)
	WeeklyGoalsEngine.bump(WorldTickEngine.season, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed(), "outing")
	SaveManager.save_player(_player)
	SaveManager.save_season(WorldTickEngine.season)
	_companion = ""
	OutingScene.open(self, res).closed.connect(_render)

func _toast(text: String) -> void:
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_color_override("font_color", Styles.AMBER)
	body.add_child(t)
	body.move_child(t, 0)

# --- Recuperación pagada (fisio / psicólogo) ---

func _build_wellness_actions() -> void:
	body.add_child(Styles.section_label("Recuperación express"))
	var day: int = WorldTickEngine.current_epoch_day
	body.add_child(_wl_action(
		"Fisioterapeuta", LifestyleEngine.PHYSIO_COST,
		_player.fatigue_physical > 0.0 and not LifestyleEngine.wellness_used(WorldTickEngine.season, "physio", day),
		LifestyleEngine.wellness_used(WorldTickEngine.season, "physio", day), "physio"))
	body.add_child(_wl_action(
		"Psicólogo deportivo", LifestyleEngine.PSYCH_COST,
		_player.fatigue_mental > 0.0 and not LifestyleEngine.wellness_used(WorldTickEngine.season, "psych", day),
		LifestyleEngine.wellness_used(WorldTickEngine.season, "psych", day), "psych"))

func _wl_action(label: String, cost: int, enabled: bool, used: bool, key: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 50)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	if used:
		btn.text = "  %s  ·  usado esta semana" % label
		btn.disabled = true
		Styles.styled_button(btn, Styles.card(), Styles.GRAY_TEXT)
	elif not enabled:
		btn.text = "  %s  —  %s" % [label, CurrencyFormat.format(cost)]
		btn.disabled = true
		Styles.styled_button(btn, Styles.card(), Styles.GRAY_TEXT)
	else:
		btn.text = "  %s  —  %s" % [label, CurrencyFormat.format(cost)]
		Styles.styled_button(btn, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
		btn.pressed.connect(_on_wellness_pressed.bind(key))
	return btn

func _on_wellness_pressed(key: String) -> void:
	var day: int = WorldTickEngine.current_epoch_day
	var res: Dictionary = LifestyleEngine.use_physio(_player, WorldTickEngine.season, day) if key == "physio" \
		else LifestyleEngine.use_psych(_player, WorldTickEngine.season, day)
	if res.get("ok", false):
		SaveManager.save_player(_player)
		SaveManager.save_season(WorldTickEngine.season)
	_render()

# --- Vivienda / Coche ---

func _build_tier_section(title: String, tiers: Array, kind: String) -> void:
	body.add_child(Styles.section_label(title))
	var current_key: String = _player.home_type if kind == "home" else _player.car_type
	var current_idx: int = LifestyleEngine.home_index(current_key) if kind == "home" else LifestyleEngine.car_index(current_key)
	body.add_child(_tier_showcase(String(tiers[current_idx]["key"]), kind))
	for i in range(tiers.size()):
		body.add_child(_make_tier_button(tiers[i], i, current_idx, kind))

## Arte pixel (PixelLab, 9-oct) de cada vivienda / coche.
const _LIFE_ART := {
	"shared_apartment": "home_shared", "small_apartment": "home_small", "apartment": "home_apartment",
	"house": "home_house", "mansion": "home_mansion",
	"none": "car_none", "economy": "car_economy", "sedan": "car_sedan",
	"sports_car": "car_sports", "luxury_car": "car_luxury",
}

static func _life_tex(key: String) -> Texture2D:
	var p := "res://assets/life/%s.png" % String(_LIFE_ART.get(key, ""))
	return load(p) as Texture2D if _LIFE_ART.has(key) and ResourceLoader.exists(p) else null

## Lo que tenés HOY, grande (escala ×2 entera) sobre una placa clara — el
## coche de lujo es negro y se perdía contra la tarjeta oscura.
const LifeStage = preload("res://ui/common/LifeStage.gd")

func _tier_showcase(key: String, kind: String) -> Control:
	# 3D (8-nov): tu vivienda o tu coche de verdad, con tu jugador al lado
	var home_key: String = key if kind == "home" else _player.home_type
	var car_key: String = key if kind == "car" else _player.car_type
	var st: Control = LifeStage.make(Avatar.config_for_player(_player, SaveManager.load_world_seed()),
			home_key, car_key, kind, 230)
	if st != null:
		return st
	var center := CenterContainer.new()
	var tex := _life_tex(key)
	if tex == null:
		return center
	var plate := PanelContainer.new()
	var sb := Styles.card(Color(0.22, 0.25, 0.30), 14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	plate.add_theme_stylebox_override("panel", sb)
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = tex.get_size() * 2.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(r)
	center.add_child(plate)
	return center

func _make_tier_button(tier: Dictionary, i: int, current_idx: int, kind: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 60)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var thumb := _life_tex(String(tier["key"]))
	if thumb != null:
		btn.icon = thumb
		btn.expand_icon = false
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.add_theme_constant_override("icon_max_width", 56)
	btn.focus_mode = Control.FOCUS_NONE
	if i == current_idx:
		btn.text = "  %s  ·  actual" % tier["label"]
		btn.disabled = true
		Styles.styled_button(btn, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	elif i < current_idx:
		btn.text = "  %s" % tier["label"]
		btn.disabled = true
		Styles.styled_button(btn, Styles.card(), Styles.GRAY_TEXT)
	else:
		var cost: int = int(tier["cost"])
		var affordable: bool = _player.balance >= cost
		btn.text = "  %s  —  %s" % [tier["label"], CurrencyFormat.format(cost)]
		btn.disabled = not affordable
		if affordable:
			Styles.styled_button(btn, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
			btn.pressed.connect(_on_tier_chosen.bind(kind, tier["key"]))
		else:
			Styles.styled_button(btn, Styles.card(), Styles.GRAY_TEXT)
	return btn

func _on_tier_chosen(kind: String, key: String) -> void:
	var ok: bool = LifestyleEngine.buy_home(_player, key) if kind == "home" else LifestyleEngine.buy_car(_player, key)
	if ok:
		SaveManager.save_player(_player)
	_render()

# --- Staff personal (StaffEngine, schema v16) ---

func _build_staff() -> void:
	var total_sal: int = StaffEngine.total_season_salaries(_player)
	body.add_child(Styles.section_label("Staff personal · sueldos %s/temporada" % CurrencyFormat.format(total_sal)))
	for role in StaffEngine.ROLES:
		body.add_child(_staff_card(role))

func _staff_card(role: String) -> PanelContainer:
	var meta: Dictionary = StaffEngine.META[role]
	var lvl: int = StaffEngine.level_of(_player, role)
	var hired: bool = lvl > 0
	var card := _card(Styles.PURPLE if hired else Styles.CARD_DARK)
	var v := _card_body(card)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", Styles.circle(Color(0.72, 0.45, 0.95, 0.22) if hired else Color(1, 1, 1, 0.08), 36))
	var bc := CenterContainer.new()
	bc.add_child(Icons.make_rect(String(meta["icon"]), 18, Styles.PURPLE if hired else Styles.GRAY_TEXT))
	badge.add_child(bc)
	top.add_child(badge)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)
	var n1 := Label.new()
	n1.text = String(meta["name"])
	n1.add_theme_font_override("font", Styles.font_semibold())
	names.add_child(n1)
	var n2 := Label.new()
	n2.text = ("Nivel %d/%d · sueldo %s/temp" % [lvl, StaffEngine.MAX_LEVEL, CurrencyFormat.format(StaffEngine.season_salary(role, lvl))]) if hired else String(meta["effect"])
	n2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n2.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	n2.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	names.add_child(n2)
	top.add_child(names)
	v.add_child(top)

	if hired:
		var lbar := _bar("", lvl * 20, false)
		v.add_child(lbar)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	if not hired:
		var cost: int = StaffEngine.hire_cost(role)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.text = "Contratar · %s" % CurrencyFormat.format(cost)
		if _player.balance >= cost:
			Styles.styled_button(b, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
			b.pressed.connect(func(): _staff_do(StaffEngine.hire(_player, role)))
		else:
			b.disabled = true
			Styles.styled_button(b, Styles.card(), Styles.GRAY_TEXT)
		actions.add_child(b)
	else:
		if lvl < StaffEngine.MAX_LEVEL:
			var ucost: int = StaffEngine.upgrade_cost(role, lvl)
			var u := Button.new()
			u.custom_minimum_size = Vector2(0, 44)
			u.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			u.focus_mode = Control.FOCUS_NONE
			u.text = "Subir a nivel %d · %s" % [lvl + 1, CurrencyFormat.format(ucost)]
			if _player.balance >= ucost:
				Styles.styled_button(u, Styles.pill_outlined(Styles.GREEN), Styles.GREEN)
				u.pressed.connect(func(): _staff_do(StaffEngine.upgrade(_player, role)))
			else:
				u.disabled = true
				Styles.styled_button(u, Styles.card(), Styles.GRAY_TEXT)
			actions.add_child(u)
		var d := Button.new()
		d.custom_minimum_size = Vector2(96, 44)
		d.focus_mode = Control.FOCUS_NONE
		d.text = "Despedir"
		Styles.styled_button(d, Styles.pill_outlined(Styles.RED), Styles.RED)
		d.pressed.connect(func(): _staff_do(StaffEngine.dismiss(_player, role)))
		actions.add_child(d)
	v.add_child(actions)
	return card

func _staff_do(changed: bool) -> void:
	if changed:
		SaveManager.save_player(_player)
	_render()

# --- Inversiones (InvestmentEngine, schema v17) ---

func _build_investments() -> void:
	var today: int = WorldTickEngine.current_epoch_day
	body.add_child(Styles.section_label("Inversiones · %d activa%s" % [
		_player.investments.size(), "" if _player.investments.size() == 1 else "s",
	]))

	for inv in _player.investments:
		var card := _card(Styles.GREEN)
		var v := _card_body(card)
		var top := HBoxContainer.new()
		var n := Label.new()
		n.text = String(inv["name"])
		n.add_theme_font_override("font", Styles.font_semibold())
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var days_left: int = maxi(0, int(inv["matures_day"]) - today)
		var d := Label.new()
		d.text = "vence en %d días" % days_left
		d.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		d.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		top.add_child(n)
		top.add_child(d)
		v.add_child(top)
		var amt := Label.new()
		amt.text = "Invertido: %s" % CurrencyFormat.format(int(inv["amount"]))
		amt.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		amt.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(amt)
		v.add_child(_bar("", int(round(InvestmentEngine.progress(inv, today) * 100.0)), false))
		body.add_child(card)

	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(0, 46)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.text = "Cerrar" if _inv_picker_open else "Nueva inversión"
	Styles.styled_button(toggle, Styles.pill_outlined(Styles.GOLD if not _inv_picker_open else Styles.GRAY_TEXT), Styles.GOLD if not _inv_picker_open else Styles.GRAY_TEXT)
	toggle.pressed.connect(func():
		_inv_picker_open = not _inv_picker_open
		_render())
	body.add_child(toggle)

	if not _inv_picker_open:
		return

	for t in InvestmentEngine.TYPES:
		var card := _card(Styles.CARD_DARK)
		var v := _card_body(card)
		var head := HBoxContainer.new()
		var tn := Label.new()
		tn.text = String(t["name"])
		tn.add_theme_font_override("font", Styles.font_semibold())
		tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var risk := Label.new()
		risk.text = String(t["risk"])
		risk.add_theme_color_override("font_color", Styles.AMBER)
		risk.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		head.add_child(tn)
		head.add_child(risk)
		v.add_child(head)
		var desc := Label.new()
		desc.text = "%s Vence a los %d días." % [String(t["desc"]), int(t["days"])]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		desc.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(desc)
		var amounts := HBoxContainer.new()
		amounts.add_theme_constant_override("separation", 6)
		var any: bool = false
		for a in InvestmentEngine.AMOUNTS:
			if _player.balance < a:
				continue
			any = true
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.focus_mode = Control.FOCUS_NONE
			b.text = CurrencyFormat.format(a)
			b.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
			Styles.styled_button(b, Styles.pill_outlined(Styles.GREEN), Styles.GREEN)
			b.pressed.connect(_on_invest.bind(String(t["id"]), a))
			amounts.add_child(b)
		if any:
			v.add_child(amounts)
		else:
			var nope := Label.new()
			nope.text = "No te alcanza para el monto mínimo (%s)." % CurrencyFormat.format(InvestmentEngine.min_amount())
			nope.add_theme_color_override("font_color", Styles.RED)
			nope.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
			v.add_child(nope)
		body.add_child(card)

func _on_invest(type_id: String, amount: int) -> void:
	var res: Dictionary = InvestmentEngine.open(_player, type_id, amount, WorldTickEngine.current_epoch_day)
	if bool(res.get("ok", false)):
		SaveManager.save_player(_player)
		_inv_picker_open = false
	_render()

# --- helpers ---

func _card(accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	if accent == Styles.CARD_DARK:
		p.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 12))
	else:
		p.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	return p

func _card_body(card: PanelContainer) -> VBoxContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	card.add_child(m)
	return v

func _plain(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	return l

## Barra 0-100 estilo EA FC. `invert`: para métricas donde MENOS es mejor
## (estrés) — el color se calcula al revés, el largo sigue siendo el valor.
func _bar(label: String, value: int, invert: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	if label != "":
		var head := HBoxContainer.new()
		var l := Label.new()
		l.text = label
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		head.add_child(l)
		var n := Label.new()
		n.text = str(value)
		n.add_theme_font_override("font", Styles.font_semibold())
		n.add_theme_color_override("font_color", _bar_color(value, invert))
		head.add_child(n)
		v.add_child(head)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.08)
	track.custom_minimum_size = Vector2(0, 8)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = _bar_color(value, invert)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(value / 100.0, 0.02, 1.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	v.add_child(track)
	return v

func _bar_color(value: int, invert: bool) -> Color:
	var good: bool = value <= 40 if invert else value >= 65
	var mid: bool = value <= 65 if invert else value >= 45
	if good:
		return Styles.GREEN
	if mid:
		return Styles.AMBER
	return Styles.RED
