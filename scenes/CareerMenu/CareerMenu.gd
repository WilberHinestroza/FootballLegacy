extends Control

## Pestaña "Carrera" de la barra inferior: agrupa lo que antes vivía como
## botones sueltos en el Hub (entrenamiento, vida y agente, patrocinio, mi
## clasificación, mi copa, noticias) MÁS el resumen de contrato/agente/
## objetivos que también salió del Hub — el Inicio del prototipo es magro
## a propósito, esto es "el resto de tu carrera".
##
## Tarjetas con insignia de color agrupadas por sección, como el
## prototipo de Football Legacy (capturas de Android Studio): ámbar para
## gestión personal, azul para competición.

@onready var vbox: VBoxContainer = $Root/Scroll/Margin/VBox

var _player: PlayerData = null
var _club: ClubData = null
var _world: Dictionary = {}

func _ready() -> void:
	WorldTickEngine.load_runtime()
	# Bug visual real (auditoría ronda 3): faltaba el deadzone táctil.
	UiScroll.make_touch($Root/Scroll)
	_player = SaveManager.load_player()
	_world = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	if _player != null and _player.club_id != "":
		_club = WorldFactory.find_club(_world, _player.club_id)

	_build_summary_card()
	if _player != null and not _player.pending_sponsor_offer.is_empty():
		_build_sponsor_banner()

	var has_season: bool = WorldTickEngine.has_active_season()

	vbox.add_child(Styles.section_label("GESTIÓN"))
	var gestion_grid := _new_grid()
	gestion_grid.add_child(_make_tile("Entrenar", "Atributos, intensidad y habilidades", Icons.PX_TRAINING, Styles.AMBER, "res://scenes/Training/Training.tscn", not has_season))
	gestion_grid.add_child(_make_tile("Vida personal", "Casa, coche y bienestar", Icons.PX_LIFESTYLE, Styles.AMBER, "res://scenes/Lifestyle/Lifestyle.tscn", false))
	gestion_grid.add_child(_make_tile("Mi agente", "Representante y contrato", Icons.PX_AGENT, Styles.AMBER, "res://scenes/Agent/Agent.tscn", _player == null))
	gestion_grid.add_child(_make_tile("Mi perfil", "Stats, vitrina y más", Icons.PX_PROFILE, Styles.AMBER, "res://scenes/PlayerProfile/PlayerProfile.tscn", _player == null))
	gestion_grid.add_child(_make_tile("Tienda", "Botiquines y suplementos", Icons.PX_SHOP, Styles.AMBER, "res://scenes/Shop/Shop.tscn", _player == null))
	gestion_grid.add_child(_make_tile("Redes sociales", "Feed y publicaciones", Icons.PX_SOCIAL, Styles.AMBER, "res://scenes/Social/Social.tscn", _player == null))
	gestion_grid.add_child(_make_tile("Patrocinios", "Marca principal y guayos", Icons.PX_SPONSORS, Styles.AMBER, "res://scenes/Sponsors/Sponsors.tscn", _player == null))
	vbox.add_child(gestion_grid)

	vbox.add_child(Styles.section_label("COMPETICIÓN"))
	var comp_grid := _new_grid()
	comp_grid.add_child(_make_tile("Mi clasificación", "Tabla de tu liga", Icons.PX_STANDINGS, Styles.BLUE, "res://scenes/Standings/Standings.tscn", not has_season))
	comp_grid.add_child(_make_tile("Mi copa", "Cuadro de tu copa", Icons.PX_CUP, Styles.BLUE, "res://scenes/CupBracket/CupBracket.tscn", not has_season))
	comp_grid.add_child(_make_tile("Noticias", "La prensa habla de ti", Icons.PX_NEWS, Styles.BLUE, "res://scenes/News/News.tscn", false))
	comp_grid.add_child(_make_tile("Fichajes", "Ofertas y mercado", Icons.PX_TRANSFERS, Styles.BLUE, "res://scenes/Transfers/Transfers.tscn", _player == null))
	comp_grid.add_child(_make_tile("Premios anuales", "Balón de Oro y más", Icons.PX_AWARDS, Styles.BLUE, "res://scenes/Awards/Awards.tscn", not has_season))
	comp_grid.add_child(_make_tile("Buscar jugador", "Filtrá por liga, puesto, edad y media", Icons.PX_WORLD, Styles.BLUE, "res://scenes/PlayerSearch/PlayerSearch.tscn", not has_season))
	vbox.add_child(comp_grid)

	# Retiro VOLUNTARIO desde los 34, en cualquier momento (no solo al
	# vencer contrato — eso ya existía en ContractDecision). Pedido de
	# Wilber: "si un jugador se quiere retirar por la edad, desde los 34
	# lo puede hacer, ¿lo tenemos implementado?" — faltaba la vía
	# voluntaria a mitad de contrato.
	if _player != null and _player.age >= 34 and _player.club_id != "":
		vbox.add_child(Styles.section_label("RETIRO"))
		var retire_btn := Button.new()
		retire_btn.custom_minimum_size = Vector2(0, 52)
		retire_btn.focus_mode = Control.FOCUS_NONE
		retire_btn.text = "Colgar los botines (retirarme)"
		Styles.styled_button(retire_btn, Styles.pill_outlined(Styles.RED), Styles.RED)
		retire_btn.pressed.connect(_on_voluntary_retire_pressed)
		vbox.add_child(retire_btn)

func _on_voluntary_retire_pressed() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "¿Seguro que querés retirarte ahora, a mitad de contrato? Termina tu carrera de jugador."
	dlg.title = "Retiro"
	dlg.ok_button_text = "Me retiro"
	dlg.confirmed.connect(func():
		var p := SaveManager.load_player()
		if p != null:
			p.club_id = ""
			p.wage = 0
			p.contract_years_remaining = 0
			p.press_feed.push_front({
				"headline": "%s anuncia su retiro" % p.player_name,
				"body": "Tras una carrera con %d títulos, %s cuelga los botines por decisión propia." % [p.trophies_won, p.player_name],
				"source": "DEPORTE TOTAL", "sentiment": "NEUTRAL", "day": WorldTickEngine.current_epoch_day,
			})
			SaveManager.save_player(p)
			# Bug real encontrado en la auditoría (pérdida de datos): a esta
			# vía de retiro VOLUNTARIO le faltaba este archive_retired_career()
			# que sí tiene ContractDecision.gd. Sin esto, slot_summary() (club_id
			# vacío) no la mostraba ni como activa ni como retirada — la
			# carrera desaparecía de Colección, el slot se veía "Nueva
			# carrera" en Start.gd, y jugar ahí la pisaba con un personaje
			# nuevo, borrando la vieja para siempre.
			SaveManager.archive_retired_career(p)
		get_tree().change_scene_to_file("res://scenes/Retirement/Retirement.tscn"))
	add_child(dlg)
	dlg.popup_centered()

func _new_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4 if get_viewport_rect().size.x > get_viewport_rect().size.y else 2  # horizontal: 4 por fila
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


func _go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

## Tarjeta-botón con insignia de color arriba, título y subtítulo debajo
## — el contenido va SOBRE un Button transparente (mouse_filter=IGNORE en
## todo lo decorativo) para que toda la tarjeta sea tocable, no solo el
## texto.
func _make_tile(title: String, subtitle: String, icon_path: String, badge_color: Color, target: String, disabled: bool) -> Control:
	var btn := Button.new()
	# Altura FIJA (mín = máx efectivo con clip): todas las tarjetas del grid
	# quedan iguales y el subtítulo largo nunca se derrama fuera de la
	# tarjeta (bug reportado: el texto salía por debajo del recuadro).
	btn.custom_minimum_size = Vector2(0, 152)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = disabled
	Styles.styled_button(btn, Styles.card_accent(badge_color))
	if not disabled:
		btn.pressed.connect(_go.bind(target))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 5)

	if Icons.is_pixel(icon_path):
		# Ícono pixel art a color: va suelto (sin insignia teñida), a 48 px
		# = escala 1:1 del arte, nítido.
		# Placa suave del color de la sección: los íconos oscuros (el
		# maletín) se perdían contra CARD_DARK sin ella.
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var psb := Styles.card(Color(badge_color, 0.22), 12)
		psb.content_margin_left = 4
		psb.content_margin_right = 4
		psb.content_margin_top = 4
		psb.content_margin_bottom = 4
		plate.add_theme_stylebox_override("panel", psb)
		plate.add_child(Icons.px_rect(icon_path, 48))
		content.add_child(plate)
	var badge := PanelContainer.new()
	badge.visible = not Icons.is_pixel(icon_path)
	badge.custom_minimum_size = Vector2(40, 40)
	# Sin esto, el VBoxContainer padre estira la insignia a todo el ancho
	# de la tarjeta (el bug que reportó Wilber: el icono tapaba el botón
	# entero en vez de quedarse chico arriba-izquierda).
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", Styles.card(badge_color, 10))
	var badge_center := CenterContainer.new()
	badge_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_center.add_child(Icons.make_rect(icon_path, 20))
	badge.add_child(badge_center)
	content.add_child(badge)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = subtitle
	subtitle_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	subtitle_lbl.add_theme_font_size_override("font_size", 12)
	subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(subtitle_lbl)

	margin.add_child(content)
	btn.add_child(margin)
	return btn

func _build_sponsor_banner() -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	var so: Dictionary = _player.pending_sponsor_offer
	var wk: int = int(so.get("weekly_income", 0))
	var wks: int = int(so.get("weeks_remaining", 0))
	btn.text = "%s te ofrece %s/semana (%d sem.)" % [
		String(so.get("name", "Un patrocinador")), CurrencyFormat.format(wk), wks,
	] if wk > 0 else "Oferta de patrocinio disponible"
	btn.icon = Icons.load_icon(Icons.SPONSOR)
	btn.add_theme_constant_override("icon_max_width", 26)
	Styles.styled_button(btn, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	btn.pressed.connect(_go.bind("res://scenes/SponsorOffer/SponsorOffer.tscn"))
	vbox.add_child(btn)

## Contrato, patrocinio activo, agente/vida y objetivos — vivían como
## texto en el Hub; se movieron aquí para que el Inicio quedara magro
## (mismo criterio de IA que el prototipo).
func _build_summary_card() -> void:
	if _player == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var margin := MarginContainer.new()
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	for s in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)

	# --- Encabezado: club + chip de capitán ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	if _player.club_id != "":
		head.add_child(Styles.club_crest(_player.club_id, 30))
	var club_lbl := Label.new()
	club_lbl.text = (_club.club_name if _club != null else "Sin club")
	club_lbl.add_theme_font_override("font", Styles.font_black())
	club_lbl.add_theme_font_size_override("font_size", 16)
	club_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	club_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(club_lbl)
	if bool(WorldTickEngine.season.get("is_captain", false)):
		var cap := Label.new()
		cap.text = "🎖 CAPITÁN"
		cap.add_theme_font_size_override("font_size", 11)
		cap.add_theme_color_override("font_color", Styles.GOLD)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(cap)
	v.add_child(head)

	# --- Filas clave: valor / etiqueta gris ---
	if _player.club_id != "":
		var coach := WorldFactory.find_coach(_world, _player.club_id)
		if coach != null:
			v.add_child(_kv_row("Entrenador", "%s · %s" % [coach.coach_name, coach.style],
				"Confianza %d%%" % _player.coach_trust, _trust_color(_player.coach_trust)))
		v.add_child(_kv_row("Contrato", "%d año%s · %s/temp." % [
			_player.contract_years_remaining, "" if _player.contract_years_remaining == 1 else "s",
			CurrencyFormat.format(_player.wage)], "Ahorros %s" % CurrencyFormat.format(_player.balance), Styles.GREEN))

	if not _player.sponsor.is_empty():
		var sp_row := _kv_row("Patrocinio", String(_player.sponsor.get("name", "?")),
			"%s/sem · %d sem." % [CurrencyFormat.format(int(_player.sponsor.get("weekly_income", 0))),
			int(_player.sponsor.get("weeks_remaining", 0))], Styles.GOLD)
		var sp_logo := BrandMark.build(String(_player.sponsor.get("name", "")), 28)
		sp_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sp_row.add_child(sp_logo)
		sp_row.move_child(sp_logo, 1)
		v.add_child(sp_row)
	# Marca de guayos (schema v32) con su logo.
	if not _player.boot_deal.is_empty():
		var bb: Dictionary = BootBrands.by_id(String(_player.boot_deal.get("brand", "")))
		if not bb.is_empty():
			var bt_row := _kv_row("Guayos", String(bb["name"]),
				"%s/sem · %d sem." % [CurrencyFormat.format(int(_player.boot_deal.get("weekly_income", 0))),
				int(_player.boot_deal.get("weeks_remaining", 0))], Styles.GOLD)
			var bt_logo := BootBrands.logo_rect(bb, 28)
			bt_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bt_row.add_child(bt_logo)
			bt_row.move_child(bt_logo, 1)
			v.add_child(bt_row)

	var stars: String = "★".repeat(_player.agent_stars) + "☆".repeat(5 - _player.agent_stars)
	v.add_child(_kv_row("Agente", "%s  %s" % [_player.agent_name, stars],
		"%s · %s" % [LifestyleEngine.home_label(_player.home_type), LifestyleEngine.car_label(_player.car_type)], Styles.GRAY_TEXT))

	# --- Objetivos (con barra de progreso el del jugador) ---
	var objective: Dictionary = WorldTickEngine.season.get("player_objective", {})
	if not objective.is_empty() or _club != null:
		v.add_child(_thin_divider())
	if _club != null:
		v.add_child(_kv_row("Objetivo del club", ObjectivesEngine.club_league_objective(_club),
			ObjectivesEngine.club_cup_objective(_club), Styles.BLUE))
	if not objective.is_empty():
		var progress: Dictionary = ObjectivesEngine.player_objective_progress(_player, objective)
		var cur: int = int(progress["current"])
		var tgt: int = maxi(int(progress["target"]), 1)
		var met: bool = bool(progress["met"])
		var ov := VBoxContainer.new()
		ov.add_theme_constant_override("separation", 4)
		var ot := HBoxContainer.new()
		ot.add_theme_constant_override("separation", 6)
		var okey := Label.new()
		okey.text = "Tu objetivo"
		okey.add_theme_font_size_override("font_size", 11)
		okey.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		ot.add_child(okey)
		var oval := Label.new()
		oval.text = "%s  %d/%d%s" % [String(objective.get("text", "")), cur, tgt, "  ✓" if met else ""]
		oval.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		oval.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		oval.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		oval.add_theme_color_override("font_color", Styles.GREEN if met else Color(0.9, 0.9, 0.93))
		ot.add_child(oval)
		ov.add_child(ot)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, 0.08)
		track.custom_minimum_size = Vector2(0, 6)
		var fill := ColorRect.new()
		fill.color = Styles.GREEN if met else Styles.GOLD
		fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
		fill.anchor_right = clampf(float(cur) / float(tgt), 0.0, 1.0)
		fill.anchor_bottom = 1.0
		track.add_child(fill)
		ov.add_child(track)
		v.add_child(ov)

	margin.add_child(v)
	panel.add_child(margin)
	vbox.add_child(panel)

## Fila "etiqueta gris → valor" con un dato secundario a la derecha.
func _kv_row(key: String, value: String, right: String = "", right_col: Color = Color.TRANSPARENT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(96, 0)
	k.add_theme_font_size_override("font_size", 11)
	k.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(k)
	var val := Label.new()
	val.text = value
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	row.add_child(val)
	if right != "":
		var r := Label.new()
		r.text = right
		r.add_theme_font_size_override("font_size", 11)
		r.add_theme_color_override("font_color", right_col if right_col.a > 0.0 else Styles.GRAY_TEXT)
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(r)
	return row

func _thin_divider() -> Control:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, 0.09)
	d.custom_minimum_size = Vector2(0, 1)
	return d

func _trust_color(t: int) -> Color:
	if t >= 66:
		return Styles.GREEN
	if t >= 40:
		return Styles.AMBER
	return Styles.RED
