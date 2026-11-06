extends Control

## "Mi agente" — pantalla dedicada al representante (antes solo era una
## línea en Vida). Muestra el perfil del agente (tier, atributos estilo
## EA FC, experiencia, otro cliente) y sus acciones. Perfil DERIVADO,
## nada nuevo se persiste (ver AgentEngine.profile). La única acción con
## estado es "Pedir aumento", con cooldown en season["agent_raise_cd_day"].

@onready var body: VBoxContainer = $Margin/VBox/Scroll/Body
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var back_button: Button = $Margin/VBox/BackButton

var _player: PlayerData = null
var _world: Dictionary = {}

const _ATTR_COLORS := {
	"Deportivo": Color(0.30, 0.63, 0.98),
	"Económico": Color(0.35, 0.80, 0.45),
	"Comercial": Color(0.96, 0.72, 0.25),
	"Influencia": Color(0.72, 0.45, 0.95),
}

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_player = SaveManager.load_player()
	_world = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/CareerMenu/CareerMenu.tscn"))
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	$Margin/VBox/TitleLabel.visible = false   # lo reemplaza la cabecera héroe
	_render()

func _render() -> void:
	Styles.land_columns_later(body, 1)  # horizontal: 2 columnas
	for c in body.get_children():
		c.queue_free()
	if _player == null:
		body.add_child(_plain("Sin jugador activo."))
		return

	var stars: int = _player.agent_stars
	var prof: Dictionary = AgentEngine.profile(_player.agent_name, stars, _world, WorldTickEngine.world_seed)

	# --- Cabecera héroe del agente (9-oct, rediseño) ---
	var face: Control = null
	if _player.agent_name != "":
		face = Styles.portrait_frame(Avatar.for_npc(_player.agent_name, "agent", WorldTickEngine.world_seed, 72), 72, Styles.GOLD)
	else:
		face = Icons.px_rect(Icons.PX_AGENT, 72)
	var meta: String = "%d cliente%s · %d años de experiencia" % [
		int(prof["clients"]), "" if int(prof["clients"]) == 1 else "s", int(prof["years_exp"])]
	var right := Styles.star_row(stars, 5, 16)
	body.add_child(UiKit.hero(Styles.GOLD.darkened(0.15), face,
		_player.agent_name if _player.agent_name != "" else "Sin representante",
		meta, [[String(prof["tier"]), Styles.GOLD]], right))

	# --- Atributos ---
	body.add_child(Styles.section_label("Atributos"))
	var attrs: Dictionary = prof["attributes"]
	var abox := PanelContainer.new()
	abox.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 10))
	var am := _pad(14, 12)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 10)
	for key in ["Deportivo", "Económico", "Comercial", "Influencia"]:
		av.add_child(_attr_bar(key, int(attrs[key]), _ATTR_COLORS[key]))
	am.add_child(av)
	abox.add_child(am)
	body.add_child(abox)

	# --- Otro cliente ---
	var other: Dictionary = prof.get("other_client", {})
	if not other.is_empty():
		body.add_child(Styles.section_label("También representa a"))
		var ob := PanelContainer.new()
		ob.add_theme_stylebox_override("panel", Styles.card(Styles.CARD_DARK, 10))
		var om := _pad(14, 12)
		var oh := HBoxContainer.new()
		var on_lbl := VBoxContainer.new()
		on_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n1 := Label.new()
		n1.text = String(other["name"])
		n1.add_theme_font_override("font", Styles.font_semibold())
		on_lbl.add_child(n1)
		var n2 := Label.new()
		n2.text = String(other["club_name"])
		n2.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		n2.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		on_lbl.add_child(n2)
		oh.add_child(on_lbl)
		var med := Label.new()
		med.text = "%d media" % int(other["overall"])
		med.add_theme_font_override("font", Styles.font_semibold())
		med.add_theme_color_override("font_color", Styles.GOLD)
		oh.add_child(med)
		om.add_child(oh)
		ob.add_child(om)
		body.add_child(ob)

	# --- Acciones ---
	body.add_child(Styles.section_label("Acciones"))
	var today: int = WorldTickEngine.current_epoch_day
	var blocker: String = AgentEngine.raise_blocker(_player, WorldTickEngine.season, today)
	body.add_child(_action_card(
		"Pedir aumento de sueldo",
		"Tu agente negocia una mejora con el club" if blocker == "" else blocker,
		blocker == "", Styles.GOLD, _on_request_raise))
	var lobby_blocker: String = AgentEngine.lobby_blocker(_player, WorldTickEngine.season, today)
	body.add_child(_action_card(
		"Pedir ser titular",
		"Tu agente presiona al DT de cara a tu próximo partido" if lobby_blocker == "" else lobby_blocker,
		lobby_blocker == "", Styles.GREEN, _on_request_starting))
	body.add_child(_action_card(
		"Buscar nuevos clubes",
		"Ver ofertas por vos, el mercado y las cesiones",
		true, Styles.BLUE, func(): get_tree().change_scene_to_file("res://scenes/Transfers/Transfers.tscn")))
	body.add_child(_action_card(
		"Explorar mercados internacionales",
		"Movimientos de todo el mundo esta temporada",
		true, Styles.PURPLE, func():
			# Bug real de la auditoría: esta tarjeta navegaba al mismo lugar
			# que "Buscar nuevos clubes" (siempre pestaña "Mis ofertas"),
			# pese a prometer "movimientos de todo el mundo" (pestaña
			# Mercado, que sí existe en Transfers.gd).
			Transfers.open_tab = "market"
			get_tree().change_scene_to_file("res://scenes/Transfers/Transfers.tscn")))

	var contract := Label.new()
	var extras: Dictionary = WorldTickEngine.season.get("contract_extras", {})
	var extra_txt := ""
	if not extras.is_empty():
		extra_txt = " · prima gol %s · cláusula %s" % [
			CurrencyFormat.format(int(extras.get("goal_bonus", 0))),
			CurrencyFormat.format(int(extras.get("release_clause", 0))),
		]
	contract.text = "Contrato: %d año%s · sueldo %s/temporada%s" % [
		_player.contract_years_remaining, "" if _player.contract_years_remaining == 1 else "s",
		CurrencyFormat.format(_player.wage), extra_txt,
	]
	contract.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	contract.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	body.add_child(contract)
	UiScroll.pad_bottom(body)

func _on_request_raise() -> void:
	var res: Dictionary = AgentEngine.request_raise(
		_player, WorldTickEngine.season, WorldTickEngine.current_epoch_day,
		WorldTickEngine.user_league_position_ratio())
	SaveManager.save_season(WorldTickEngine.season)
	if bool(res.get("ok", false)):
		SaveManager.save_player(_player)
		get_tree().change_scene_to_file("res://scenes/WageOffer/WageOffer.tscn")
	else:
		# Bug real encontrado en la auditoría: _toast() agregaba el label y
		# ACTO SEGUIDO _render() limpiaba TODOS los hijos de `body` (incluido
		# el toast recién agregado) antes de que se llegara a pintar un solo
		# frame — el mensaje nunca se veía. _render() va PRIMERO ahora.
		_render()
		_toast(String(res.get("reason", "No se pudo.")))

func _on_request_starting() -> void:
	var res: Dictionary = AgentEngine.request_starting(
		_player, WorldTickEngine.season, WorldTickEngine.current_epoch_day)
	SaveManager.save_season(WorldTickEngine.season)
	if bool(res.get("ok", false)):
		SaveManager.save_player(_player)
	_render()
	if bool(res.get("ok", false)):
		_toast("Tu agente habló con el DT. Vas con más chance de arrancar el próximo partido.")
	else:
		_toast(String(res.get("reason", "No se pudo.")))

func _toast(text: String) -> void:
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_color_override("font_color", Styles.AMBER)
	body.add_child(t)
	body.move_child(t, 0)

# --- helpers de UI ---

func _pad(h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	return m

func _plain(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	return l

func _attr_bar(name: String, value: int, col: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	var l := Label.new()
	l.text = name
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	head.add_child(l)
	var n := Label.new()
	n.text = str(value)
	n.add_theme_font_override("font", Styles.font_semibold())
	n.add_theme_color_override("font_color", col)
	head.add_child(n)
	v.add_child(head)

	# track = ColorRect (Control, NO contenedor) para que las anclas del
	# fill se respeten — un PanelContainer estiraría el fill a todo el ancho.
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.08)
	track.custom_minimum_size = Vector2(0, 8)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = col
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(value / 100.0, 0.02, 1.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	v.add_child(track)
	return v

func _action_card(title: String, sub: String, enabled: bool, accent: Color, cb: Callable) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 66)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not enabled
	btn.clip_contents = true
	Styles.styled_button(btn, Styles.card_accent(accent if enabled else Styles.GRAY_TEXT))
	if enabled:
		btn.pressed.connect(cb)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = title
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not enabled:
		t.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(t)
	var s := Label.new()
	s.text = sub
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_theme_color_override("font_color", Styles.RED if not enabled else Styles.GRAY_TEXT)
	s.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(s)
	m.add_child(v)
	btn.add_child(m)
	return btn
