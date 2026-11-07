extends RefCounted
class_name UiKit

## Piezas de interfaz compartidas del rediseño (9-oct, Wilber: "mejorá la
## GUI, todo muy apretado y desordenado"). Un solo lugar para que Club,
## Entrenar, Agente, Vida personal y Perfil se vean de la misma familia.

## Tarjeta "héroe" de cabecera: franja del color de acento con degradado,
## algo grande a la izquierda (escudo, avatar, ícono), título + subtítulo +
## chips al medio y, opcional, algo a la derecha (camisetas, media...).
static func hero(accent: Color, left: Control, title: String, subtitle: String, chips: Array = [], right: Control = null) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent.darkened(0.55)
	sb.set_corner_radius_all(18)
	sb.border_width_bottom = 4
	sb.border_color = accent
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	# Brillo del color de acento arriba (degradado horizontal tenue).
	var glow := TextureRect.new()
	glow.texture = Styles.gradient_texture(Color(accent, 0.38), Color(accent, 0.0))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	card.add_child(glow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	if left != null:
		left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(left)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = title
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("outline_size", 4)
	col.add_child(t)
	if subtitle != "":
		var st := Label.new()
		st.text = subtitle
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
		st.add_theme_font_size_override("font_size", 13)
		col.add_child(st)
	if not chips.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for c in chips:
			flow.add_child(chip(String(c[0]), c[1] if c.size() > 1 else Styles.GOLD))
		col.add_child(flow)
	row.add_child(col)
	if right != null:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right)
	card.add_child(row)
	card.set_meta("ui_hero", true)
	return card

## Versión columna del héroe (pantallas horizontales): retrato arriba,
## título/subtítulo/chips debajo, extra (estrellas, escudos) al final.
## La usa Styles.land_columns() cuando el héroe pasa a la barra izquierda.
static func hero_to_column(card: PanelContainer) -> void:
	if card == null or card.has_meta("ui_hero_col"):
		return
	var row: HBoxContainer = null
	for k in card.get_children():
		if k is HBoxContainer:
			row = k
	if row == null:
		return
	card.set_meta("ui_hero_col", true)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var kids := row.get_children()
	for k in kids:
		row.remove_child(k)
		v.add_child(k)
		if k is Control:
			var c := k as Control
			if c is VBoxContainer:
				c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				for l in c.get_children():
					if l is Label:
						(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					elif l is HFlowContainer:
						(l as HFlowContainer).alignment = FlowContainer.ALIGNMENT_CENTER
			else:
				c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.remove_child(row)
	row.queue_free()
	card.add_child(v)

## Pantallas horizontales cuyo héroe vive fuera de land_columns (Fichajes,
## Vida personal): el héroe pasa a una barra izquierda de ancho fijo y todo
## lo que venía debajo (pestañas, scroll, botón volver) queda a la derecha.
static func hero_sidebar(hero: Control, width: float = 300.0) -> void:
	if hero == null or not hero.is_inside_tree():
		return
	var vp: Vector2 = hero.get_viewport().get_visible_rect().size
	if vp.x <= vp.y:
		return
	var vb := hero.get_parent() as VBoxContainer
	if vb == null:
		return
	var at: int = hero.get_index()
	var after: Array = []
	for k in vb.get_children():
		if k.get_index() > at and not k.is_queued_for_deletion():
			after.append(k)
	var row := HBoxContainer.new()
	row.name = "HeroSidebar"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	vb.move_child(row, at)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = width
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	if hero is PanelContainer:
		hero_to_column(hero as PanelContainer)
	hero.reparent(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", vb.get_theme_constant("separation"))
	row.add_child(right)
	for k in after:
		(k as Node).reparent(right)

## Chip redondeado con borde del color (texto chico).
static func chip(text: String, col: Color) -> PanelContainer:
	var c := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.16)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(col, 0.7)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	c.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Styles.font_semibold())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col.lightened(0.25))
	c.add_child(l)
	return c

## Franja de números grandes (stat strip): [[valor, etiqueta, color], ...].
static func stat_strip(stats: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Styles.CARD_DARK
	sb.set_corner_radius_all(14)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	for i in range(stats.size()):
		var s: Array = stats[i]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		var v := Label.new()
		v.text = String(s[0])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_theme_font_override("font", Styles.font_black())
		v.add_theme_font_size_override("font_size", 24)
		v.add_theme_color_override("font_color", s[2] if s.size() > 2 else Color.WHITE)
		col.add_child(v)
		var cap := Label.new()
		cap.text = String(s[1])
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 12)
		cap.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		col.add_child(cap)
		row.add_child(col)
		if i < stats.size() - 1:
			var sep := VSeparator.new()
			sep.add_theme_constant_override("separation", 1)
			row.add_child(sep)
	card.add_child(row)
	return card

## PANTALLA VACÍA (P2, 9-oct): convierte un Label de "no hay nada" en un
## bloque centrado con un ícono pixel tenue arriba que flota suave. Se
## llama justo después de crear el label (antes o después de agregarlo):
## el envoltorio se arma cuando el label ya está en el árbol.
static func empty_icon(label: Label, icon_path: String) -> void:
	if label == null:
		return
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	var wrap := func():
		var parent: Node = label.get_parent()
		if parent == null or label.has_meta("empty_wrapped"):
			return
		label.set_meta("empty_wrapped", true)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = label.get_index()
		parent.add_child(box)
		parent.move_child(box, idx)
		var top := Control.new()
		top.custom_minimum_size = Vector2(0, 16)
		box.add_child(top)
		var cc := CenterContainer.new()
		var ic := Icons.make_rect(icon_path, 56)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.modulate = Color(1, 1, 1, 0.55)
		cc.add_child(ic)
		box.add_child(cc)
		label.reparent(box)
		var bottom := Control.new()
		bottom.custom_minimum_size = Vector2(0, 12)
		box.add_child(bottom)
		var tw := ic.create_tween().set_loops()
		tw.tween_property(ic, "modulate:a", 0.85, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ic, "modulate:a", 0.45, 1.2).set_trans(Tween.TRANS_SINE)
	if label.is_inside_tree():
		wrap.call_deferred()
	else:
		label.tree_entered.connect(func(): wrap.call_deferred(), CONNECT_ONE_SHOT)

## Tu jugador haciendo una animación de SITUACIÓN (10-oct, Wilber: "agrega
## animaciones a las situaciones inesperadas, convocatorias y así"):
## "llamada", "pensar", "sorpresa", "himno", "lamento", "firma", "puno"...
## Con el kit del club. Si falta el arte, el cuerpo quieto.
static func player_anim(player: PlayerData, anim: String, px: int, loop: bool = true, fps: float = 7.0) -> Control:
	var seed_i: int = SaveManager.load_world_seed()
	var cfg: Dictionary = Avatar.celebration_config_for_player(player, seed_i)
	var node: Control
	if Avatar.has_anim(anim):
		node = Avatar.build_anim(cfg, anim, px, loop, fps)
	else:
		node = Avatar.build_full(cfg, px)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## Tarjeta "escena": la animación centrada sobre un fondo suave del color
## dado, para encabezar una pantalla de decisión.
static func anim_stage(player: PlayerData, anim: String, accent: Color, px: int = 150) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent, 0.12)
	sb.border_color = Color(accent, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, px + 8)
	var a := player_anim(player, anim, px)
	a.custom_minimum_size = Vector2(px, px)
	cc.add_child(a)
	panel.add_child(cc)
	return panel

## Pone (o reemplaza) la escena animada justo ARRIBA de `anchor` dentro de
## su contenedor. Para las pantallas de decisión que comparten estructura
## (evento de temporada, convocatoria, ofertas).
static func put_anim_above(anchor: Control, player: PlayerData, anim: String, accent: Color, px: int = 120) -> void:
	if anchor == null or player == null:
		return
	var parent := anchor.get_parent()
	var old := parent.get_node_or_null("AnimStage")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	var stage := anim_stage(player, anim, accent, px)
	stage.name = "AnimStage"
	parent.add_child(stage)
	parent.move_child(stage, anchor.get_index())

## HORIZONTAL (FootballLegacy H): ventanas de decisión (ofertas, eventos).
## `col` (la columna centrada de siempre) pasa a la mitad DERECHA; lo que
## haya llamado "AnimStage" (tu jugador animado) y `extra` (logo de marca…)
## van grandes a la IZQUIERDA. Se puede llamar en cada _render().
static func land_modal(col: Control, extra: Control = null) -> void:
	var root: Control = col.get_parent() as Control
	if root == null:
		return
	var vp: Vector2 = root.get_viewport_rect().size
	if vp.x <= vp.y:
		return
	col.anchor_left = 0.5
	col.anchor_right = 0.96
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_left = 0
	col.offset_right = 0
	col.offset_top = 0
	col.offset_bottom = 0
	if col is BoxContainer:
		(col as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	var tl := col.get_node_or_null("TitleLabel") as Label
	if tl != null:
		tl.add_theme_font_override("font", Styles.font_black())
		tl.add_theme_font_size_override("font_size", 26)
	var left: VBoxContainer = root.get_node_or_null("LandLeft")
	if left == null:
		left = VBoxContainer.new()
		left.name = "LandLeft"
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_theme_constant_override("separation", 16)
		left.anchor_left = 0.04
		left.anchor_right = 0.46
		left.anchor_bottom = 1.0
		root.add_child(left)
	var stage: Node = col.get_node_or_null("AnimStage")
	if stage != null:
		var old: Node = left.get_node_or_null("AnimStage")
		if old != null:
			left.remove_child(old)
			old.queue_free()
		stage.reparent(left)
		left.move_child(stage, 0)
	if extra != null and extra.get_parent() != left:
		extra.reparent(left)

## HORIZONTAL: el "Volver" gigante de abajo pasa a ser la flecha chica
## arriba a la izquierda (como en el resto del juego).
static func land_back_arrow(btn: Button) -> void:
	if btn == null or btn.get_viewport() == null:
		return
	var vp: Vector2 = btn.get_viewport().get_visible_rect().size
	if vp.x <= vp.y:
		return
	var root: Node = btn.owner if btn.owner != null else btn.get_tree().current_scene
	btn.reparent(root, false)
	btn.text = ""
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn.position = Vector2(14, 12)
	btn.custom_minimum_size = Vector2(46, 42)
	btn.size = Vector2(46, 42)
	btn.z_index = 50
	# El contenido baja un poco para que la flecha no tape el título.
	for c in root.get_children():
		if c is MarginContainer:
			var mc := c as MarginContainer
			mc.add_theme_constant_override("margin_top", maxi(mc.get_theme_constant("margin_top"), 0) + 46)
			break


# ---------------------------------------------------------------- mosaico (8-nov)
# Rediseño de menús estilo consola pero táctil (Wilber: "un menú mejor como los
# del PES o FIFA pero en táctil"): tarjetas grandes en mosaico con el color del
# club, que se hunden al tocarlas, y un fondo con franjas diagonales.

## Tarjeta del mosaico: título arriba, `body` dentro y `on_tap` al tocarla (sin
## disparar si el dedo estaba desplazando). Se hunde un poco al pulsarla.
static func tile(title: String, accent: Color, body: Control, on_tap: Callable = Callable(), min_h: float = 80.0) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, min_h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.88)
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 3
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_color = Color(accent, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", sb)
	# El brillo ocupa toda la tarjeta, recortado a sus esquinas redondeadas
	# (antes quedaba un recuadro más claro adentro, con esquinas rectas)
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var glow := TextureRect.new()
	glow.texture = Styles.gradient_texture(Color(accent, 0.26), Color(accent, 0.0))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(glow)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	if title != "":
		var t := Label.new()
		t.text = title.to_upper()
		t.add_theme_font_override("font", Styles.font_semibold())
		t.add_theme_font_size_override("font_size", 11)
		t.add_theme_color_override("font_color", accent.lightened(0.35))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
	if body != null:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(body)
		_ignore_mouse(body)
	if on_tap.is_valid():
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		UiScroll.on_tap(card, func() -> void:
			Haptics.hit("tap")
			on_tap.call())
		card.gui_input.connect(func(ev: InputEvent) -> void:
			var down: bool = (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed
			var up: bool = (ev is InputEventScreenTouch or ev is InputEventMouseButton) and not ev.pressed
			if not (down or up):
				return
			card.pivot_offset = card.size * 0.5
			var tw := card.create_tween()
			tw.tween_property(card, "scale", Vector2.ONE * (0.97 if down else 1.0), 0.08)
			sb.border_color = accent if down else Color(accent, 0.55))
	return card


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## Texto de tarjeta (una línea grande o el detalle pequeño).
static func tile_text(text: String, size: int = 15, color: Color = Color.WHITE, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if bold:
		l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static var _backdrop_cache := {}

## Fondo de pantalla con el color del club: degradado oscuro con franjas
## diagonales suaves (como las pantallas de alineaciones de los juegos de fútbol).
static func club_backdrop(primary: Color) -> TextureRect:
	var key := primary.to_html(false)
	var tex: Texture2D = _backdrop_cache.get(key)
	if tex == null:
		var w := 480
		var h := 270
		var img := Image.create(w, h, false, Image.FORMAT_RGB8)
		var base := Color(0.035, 0.045, 0.07)
		var tint := base.lerp(primary, 0.32)
		for y in h:
			for x in w:
				var u := float(x) / w
				var v := float(y) / h
				var c := tint.lerp(base, clampf(u * 0.9 + v * 0.35, 0.0, 1.0))
				# Franjas diagonales finas, más visibles a la derecha
				var d := fmod(float(x + y) * 0.5, 22.0)
				if d < 1.2:
					c = c.lightened(0.05 + 0.06 * u)
				c = c.lerp(Color.BLACK, clampf((v - 0.75) * 0.8, 0.0, 0.2)) # algo más oscuro abajo
				img.set_pixel(x, y, c)
		tex = ImageTexture.create_from_image(img)
		_backdrop_cache[key] = tex
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r
