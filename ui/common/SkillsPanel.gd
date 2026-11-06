extends Control
class_name SkillsPanel

## Árbol de HABILIDADES (schema v33). Se abre superpuesto desde el
## post-partido, Entrenar, Carrera o el Inicio. Cada rama es una tarjeta con
## sus 4 escalones conectados; tocar uno muestra qué hace y, si se puede,
## "Desbloquear (N pts)". Las reglas viven en SkillTree.

signal closed

var overlay: bool = true

## Abre el panel en su PROPIA capa (arriba de la barra superior y el menú
## inferior, que viven en CanvasLayers). Se libera solo al cerrar.
static func open(host: Node) -> SkillsPanel:
	var layer := CanvasLayer.new()
	layer.layer = 90
	host.add_child(layer)
	var p := SkillsPanel.new()
	p.closed.connect(layer.queue_free)
	layer.add_child(p)
	return p
var _player: PlayerData
var _list: VBoxContainer
var _detail: PanelContainer
var _points_lbl: Label
var _selected: String = ""
var _cols: HBoxContainer = null
var _close_parent: Control = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("nav_back_handlers")
	_player = SaveManager.load_player()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 18)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	# Cabecera: nivel + puntos.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(ProgressPanel._level_badge(_player.level))
	var hc := VBoxContainer.new()
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new()
	t.text = "HABILIDADES"
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 24)
	hc.add_child(t)
	_points_lbl = Label.new()
	_points_lbl.add_theme_color_override("font_color", Styles.GOLD)
	_points_lbl.add_theme_font_override("font", Styles.font_semibold())
	hc.add_child(_points_lbl)
	var hint := Label.new()
	hint.text = "1 punto por nivel (+1 extra cada 5). Subís jugando y entrenando. La rama CARRERA se abre con los hitos de tu carrera."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hc.add_child(hint)
	head.add_child(hc)
	v.add_child(head)

	var land: bool = get_viewport_rect().size.x > get_viewport_rect().size.y
	if land:
		# HORIZONTAL: árbol de talentos. Ramas en COLUMNAS a la izquierda;
		# detalle + desbloquear fijo a la derecha.
		hint.visible = false
		var body := HBoxContainer.new()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 16)
		v.add_child(body)
		var csc := ScrollContainer.new()
		csc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		csc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UiScroll.make_touch(csc)
		body.add_child(csc)
		_cols = HBoxContainer.new()
		_cols.add_theme_constant_override("separation", 10)
		_cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		csc.add_child(_cols)
		var side := VBoxContainer.new()
		side.custom_minimum_size.x = 330
		side.add_theme_constant_override("separation", 10)
		body.add_child(side)
		_detail = PanelContainer.new()
		_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(_detail)
		_close_parent = side
		_list = VBoxContainer.new()   # no se usa en horizontal
	else:
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(sc)
		UiScroll.make_touch(sc)
		_list = VBoxContainer.new()
		_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_theme_constant_override("separation", 10)
		sc.add_child(_list)

		_detail = PanelContainer.new()
		v.add_child(_detail)
		_close_parent = v

	var close := Button.new()
	close.text = "Listo"
	close.custom_minimum_size = Vector2(0, 50)
	close.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(close, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	close.pressed.connect(_close)
	_close_parent.add_child(close)
	_render()
	Juice.stagger_in(_cols if _cols != null else _list, 0.06)

func nav_back() -> bool:
	_close()
	return true

func _close() -> void:
	closed.emit()
	queue_free()

func _render() -> void:
	_points_lbl.text = "Nivel %d  ·  %d punto%s para gastar" % [_player.level, _player.skill_points, "" if _player.skill_points == 1 else "s"]
	for c in _list.get_children():
		c.queue_free()
	if _cols != null:
		for c in _cols.get_children():
			c.queue_free()
		var branches: Array = SkillTree.branches_for(_player.position)
		if _selected == "":
			_selected = _first_buyable(branches)
		for b in branches:
			_cols.add_child(_branch_column(b))
		_render_detail()
		return
	for b in SkillTree.branches_for(_player.position):
		_list.add_child(_branch_card(b))
	_render_detail()

func _branch_card(b: Dictionary) -> Control:
	var col := Color(String(b["color"]))
	var card := PanelContainer.new()
	var sb := Styles.card_flat(Color(col.darkened(0.7), 0.9), 14)
	sb.border_width_left = 4
	sb.border_color = col
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var owned: int = 0
	for n in b["nodes"]:
		if _player.skills.has(String(n["id"])):
			owned += 1
	var t := Label.new()
	t.text = "%s   %d/%d" % [String(b["name"]).to_upper(), owned, (b["nodes"] as Array).size()]
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", col.lightened(0.2))
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var nodes: Array = b["nodes"]
	for i in range(nodes.size()):
		if i > 0:
			var link := ColorRect.new()
			link.custom_minimum_size = Vector2(0, 4)
			link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			link.color = col if _player.skills.has(String(nodes[i]["id"])) else Color(1, 1, 1, 0.12)
			row.add_child(link)
		row.add_child(_node_button(nodes[i], i, col, nodes.size()))
	v.add_child(row)
	return card

func _node_button(n: Dictionary, _idx: int, col: Color, count: int = 4) -> Button:
	var id: String = String(n["id"])
	var owned: bool = _player.skills.has(id)
	var can: bool = SkillTree.can_unlock(_player, id)
	var b := Button.new()
	# Ramas largas (5-7 escalones): círculos más chicos para que entren.
	var side: float = 64.0 if count <= 4 else (50.0 if count <= 6 else 44.0)
	b.custom_minimum_size = Vector2(side, side)
	b.focus_mode = Control.FOCUS_NONE
	var rq: Array = SkillTree.requirement(_player, id)
	var locked_req: bool = not rq.is_empty() and not bool(rq[0])
	b.text = "★" if owned else ("🔒" if locked_req else str(SkillTree.cost_of(id)))
	b.add_theme_font_override("font", Styles.font_black())
	b.add_theme_font_size_override("font_size", (22 if owned else 18) if count <= 4 else (18 if owned else 15))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(side * 0.5))
	sb.set_border_width_all(3 if id == _selected else 2)
	if owned:
		sb.bg_color = col
		sb.border_color = Color.WHITE if id == _selected else col.lightened(0.4)
	elif can:
		sb.bg_color = Color(0.12, 0.12, 0.16)
		sb.border_color = Styles.GOLD
	else:
		sb.bg_color = Color(0.08, 0.08, 0.1)
		sb.border_color = Color(1, 1, 1, 0.5) if id == _selected else Color(1, 1, 1, 0.15)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.BLACK if owned else (Styles.GOLD if can else Styles.GRAY_TEXT))
	b.add_theme_color_override("font_hover_color", Color.BLACK if owned else (Styles.GOLD if can else Styles.GRAY_TEXT))
	b.pressed.connect(func():
		_selected = id
		_render())
	if can:
		b.ready.connect(func(): Juice.pulse(b, 1.07, 1.1))
	return b

func _render_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var sb := Styles.card_flat(Color(0.1, 0.11, 0.15), 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_detail.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_detail.add_child(v)
	if _selected == "":
		var l := Label.new()
		l.text = "Tocá un círculo para ver qué hace. Los dorados ya los podés comprar."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		v.add_child(l)
		return
	var f: Array = SkillTree.find(_selected)
	var n: Dictionary = f[0]["nodes"][f[1]]
	if _cols != null:
		# Rama y escalón, con su color, arriba del nombre.
		var bc := Color(String(f[0]["color"]))
		sb.border_width_top = 5
		sb.border_color = bc
		var bl := Label.new()
		bl.text = "%s  ·  escalón %d de %d" % [String(f[0]["name"]).to_upper(), int(f[1]) + 1, (f[0]["nodes"] as Array).size()]
		bl.add_theme_font_override("font", Styles.font_semibold())
		bl.add_theme_font_size_override("font_size", 12)
		bl.add_theme_color_override("font_color", bc.lightened(0.3))
		v.add_child(bl)
	var name_l := Label.new()
	name_l.text = String(n["name"])
	name_l.add_theme_font_override("font", Styles.font_black())
	name_l.add_theme_font_size_override("font_size", 18)
	v.add_child(name_l)
	var d := Label.new()
	d.text = String(n["desc"])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var rq2: Array = SkillTree.requirement(_player, _selected)
	if not rq2.is_empty():
		var rl := Label.new()
		rl.text = "Hito de carrera: %s  (%d / %d)%s" % [String(rq2[3]), mini(int(rq2[1]), int(rq2[2])), int(rq2[2]), "  ✓" if bool(rq2[0]) else ""]
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		rl.add_theme_color_override("font_color", Styles.GREEN if bool(rq2[0]) else Styles.GOLD)
		v.add_child(rl)
	if _player.skills.has(_selected):
		var ok := Label.new()
		ok.text = "★ Desbloqueada"
		ok.add_theme_color_override("font_color", Styles.GREEN)
		v.add_child(ok)
		_detail_next(v, f)
		return
	var cost: int = SkillTree.cost_of(_selected)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 46)
	btn.focus_mode = Control.FOCUS_NONE
	var can: bool = SkillTree.can_unlock(_player, _selected)
	btn.disabled = not can
	if can:
		btn.text = "Desbloquear  ·  %d punto%s" % [cost, "" if cost == 1 else "s"]
	elif int(f[1]) > 0 and not _player.skills.has(String(f[0]["nodes"][int(f[1]) - 1]["id"])):
		btn.text = "Primero desbloqueá la anterior de la rama"
	elif not rq2.is_empty() and not bool(rq2[0]):
		btn.text = "Todavía no llegaste a ese hito"
	else:
		btn.text = "Necesitás %d punto%s" % [cost, "" if cost == 1 else "s"]
	Styles.styled_button(btn, Styles.pill_filled(Styles.GOLD) if can else Styles.pill_outlined(Styles.GRAY_TEXT), Color.BLACK if can else Styles.GRAY_TEXT)
	btn.pressed.connect(_unlock)
	v.add_child(btn)
	_detail_next(v, f)

func _unlock() -> void:
	if SkillTree.unlock(_player, _selected):
		SaveManager.save_player(_player)
		WeeklyGoalsEngine.bump(WorldTickEngine.season, WorldTickEngine.current_epoch_day, SaveManager.load_world_seed(), "skill")
		SaveManager.save_season(WorldTickEngine.season)
		Audio.play("celebrate")
		Haptics.hit("success")
		_render()
		Juice.float_text(self, "¡Habilidad desbloqueada!", Vector2(size.x * 0.5 - 130, size.y * 0.55), Styles.GOLD, 22)


# ---------------------------------------------------------------- horizontal
## Arranca mostrando la primera habilidad que podés comprar (si hay).
func _first_buyable(branches: Array) -> String:
	for b in branches:
		for n in b["nodes"]:
			if SkillTree.can_unlock(_player, String(n["id"])):
				return String(n["id"])
	return ""

## Rama como COLUMNA: título con su progreso y las habilidades apiladas,
## cada una con su NOMBRE (antes eran círculos con un número).
func _branch_column(b: Dictionary) -> Control:
	var col := Color(String(b["color"]))
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 150
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := Styles.card_flat(Color(col.darkened(0.75), 0.92), 14)
	sb.border_width_top = 4
	sb.border_color = col
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var nodes: Array = b["nodes"]
	var owned: int = 0
	for n in nodes:
		if _player.skills.has(String(n["id"])):
			owned += 1
	var t := Label.new()
	t.text = String(b["name"]).to_upper()
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", col.lightened(0.3))
	v.add_child(t)
	var pr := Label.new()
	pr.text = "%d / %d" % [owned, nodes.size()]
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pr.add_theme_font_size_override("font_size", 12)
	pr.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(pr)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	v.add_child(gap)
	for i in range(nodes.size()):
		if i > 0:
			var lc := CenterContainer.new()
			var link := ColorRect.new()
			link.custom_minimum_size = Vector2(4, 8)
			link.color = col if _player.skills.has(String(nodes[i]["id"])) else Color(1, 1, 1, 0.15)
			lc.add_child(link)
			v.add_child(lc)
		v.add_child(_skill_tile(nodes[i], col))
	return card

func _skill_tile(n: Dictionary, col: Color) -> Control:
	var id: String = String(n["id"])
	var owned: bool = _player.skills.has(id)
	var can: bool = SkillTree.can_unlock(_player, id)
	var rq: Array = SkillTree.requirement(_player, id)
	var locked_req: bool = not rq.is_empty() and not bool(rq[0])
	var sel: bool = id == _selected
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var mark: String = "★" if owned else ("🔒" if locked_req else "%d" % SkillTree.cost_of(id))
	b.text = "  %s   %s" % [mark, String(n["name"])]
	b.add_theme_font_override("font", Styles.font_semibold())
	b.add_theme_font_size_override("font_size", 13)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if sel else 2)
	if owned:
		sb.bg_color = col.darkened(0.15)
		sb.border_color = Color.WHITE if sel else col.lightened(0.35)
	elif can:
		sb.bg_color = Color(0.17, 0.14, 0.05)
		sb.border_color = Color.WHITE if sel else Styles.GOLD
	else:
		sb.bg_color = Color(0.08, 0.08, 0.1)
		sb.border_color = Color.WHITE if sel else Color(1, 1, 1, 0.12)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var fc: Color = Color.WHITE if owned else (Styles.GOLD if can else Color(0.6, 0.62, 0.68))
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.pressed.connect(func():
		_selected = id
		_render())
	if can and not sel:
		b.ready.connect(func(): Juice.pulse(b, 1.04, 1.1))
	return b


## Debajo del detalle (horizontal): qué viene después en la rama y tus
## puntos, así el panel no queda vacío.
func _detail_next(v: VBoxContainer, f: Array) -> void:
	if _cols == null:
		return
	var nodes: Array = f[0]["nodes"]
	var i: int = int(f[1])
	var sep := HSeparator.new()
	v.add_child(sep)
	if i + 1 < nodes.size():
		var nx: Dictionary = nodes[i + 1]
		var h := Label.new()
		h.text = "DESPUÉS EN ESTA RAMA"
		h.add_theme_font_size_override("font_size", 12)
		h.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		v.add_child(h)
		var nn := Label.new()
		nn.text = "%s  (%d pto%s)" % [String(nx["name"]), SkillTree.cost_of(String(nx["id"])), "" if SkillTree.cost_of(String(nx["id"])) == 1 else "s"]
		nn.add_theme_font_override("font", Styles.font_semibold())
		v.add_child(nn)
		var nd := Label.new()
		nd.text = String(nx["desc"])
		nd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nd.add_theme_font_size_override("font_size", 13)
		nd.add_theme_color_override("font_color", Color(0.75, 0.77, 0.82))
		v.add_child(nd)
	else:
		var top := Label.new()
		top.text = "Es la habilidad máxima de esta rama."
		top.add_theme_color_override("font_color", Styles.GOLD)
		v.add_child(top)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var how := Label.new()
	how.text = "1 punto por nivel (+1 extra cada 5). Subís de nivel jugando y entrenando."
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_theme_font_size_override("font_size", 12)
	how.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(how)
