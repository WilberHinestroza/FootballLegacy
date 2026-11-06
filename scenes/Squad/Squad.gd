extends Control

## Pestaña "Plantilla" de la barra inferior — dos vistas, como el
## prototipo de Football Legacy: "Formación" (la cancha con el once
## titular, reutilizando MatchTeam._build_lineup — la MISMA lógica que
## arma el equipo real de partido, nunca duplicada) y "Plantilla" (la
## lista completa del club, generada determinista vía WorldFactory).
##
## Orden GK → DF → MF → ST en toda la lista, regla no negociable del
## proyecto (ver CLAUDE.md).

const ORDER := ["GK", "DF", "MF", "ST"]
const ROW_Y_FRACTION := {"ST": 0.14, "MF": 0.42, "DF": 0.68, "GK": 0.90}
## Horizontal: la cancha es más baja; las líneas se juntan un poco al centro.
const ROW_Y_LAND := {"ST": 0.19, "MF": 0.44, "DF": 0.67, "GK": 0.86}

## Banda de la cancha (0=izquierda, 1=centro, 2=derecha) por posición
## detallada — sin esto, la fila se ordena por overall nomás y un lateral
## derecho puede terminar dibujado del lado izquierdo, cosa que en una
## cancha de verdad nunca pasa.
const _LATERAL_BAND := {
	"LI": 0, "CAI": 0, "EI": 0, "MI": 0,
	"DFC": 1, "MCD": 1, "MC": 1, "MCO": 1, "MP": 1, "POR": 1, "DC": 1, "SD": 1,
	"LD": 2, "CAD": 2, "ED": 2, "MD": 2,
}

@onready var club_name_label: Label = $Root/Margin/VBox/ClubNameLabel
@onready var formation_label: Label = $Root/Margin/VBox/FormationLabel
@onready var tabs_row: HBoxContainer = $Root/Margin/VBox/TabsRow
@onready var formation_tab_button: Button = $Root/Margin/VBox/TabsRow/FormationTabButton
@onready var squad_tab_button: Button = $Root/Margin/VBox/TabsRow/SquadTabButton
@onready var formation_panel: PanelContainer = $Root/Margin/VBox/FormationPanel
@onready var pitch: Control = $Root/Margin/VBox/FormationPanel/Pitch
@onready var bench_title_label: Label = $Root/Margin/VBox/BenchTitleLabel
@onready var bench_scroll: ScrollContainer = $Root/Margin/VBox/BenchScroll
@onready var bench_row: HBoxContainer = $Root/Margin/VBox/BenchScroll/BenchRow
@onready var squad_scroll: ScrollContainer = $Root/Margin/VBox/Scroll
@onready var list_box: VBoxContainer = $Root/Margin/VBox/Scroll/ListBox
@onready var player_card_overlay: ColorRect = $PlayerCardOverlay
@onready var player_card_box: VBoxContainer = $PlayerCardOverlay/Margin/VBox/Scroll/PlayerCardBox
@onready var player_card_back_button: Button = $PlayerCardOverlay/Margin/VBox/PlayerCardBackButton

var _showing_formation: bool = true
var _wseed: int = 0
var _kit_col: Color = Styles.BLUE

func _ready() -> void:
	WorldTickEngine.load_runtime()
	# Bug visual real (auditoría ronda 3): el scroll de la ficha de jugador
	# (overlay compartido con PlayerSearch/WorldExplorer) y el del banco
	# no tenían el deadzone táctil — pad_bottom(list_box) más abajo solo
	# alcanza al scroll principal del plantel, no a estos otros dos.
	UiScroll.make_touch($PlayerCardOverlay/Margin/VBox/Scroll)
	UiScroll.make_touch(bench_scroll)
	player_card_back_button.pressed.connect(_on_player_card_back_pressed)
	Styles.styled_button(player_card_back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	var player: PlayerData = SaveManager.load_player()
	if player == null or player.club_id == "":
		club_name_label.text = "Sin club"
		tabs_row.visible = false
		return

	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var club := WorldFactory.find_club(world, player.club_id)
	club_name_label.text = club.club_name if club != null else "Plantilla"
	_wseed = SaveManager.load_world_seed()
	if club != null and club.primary_color_hex != "":
		_kit_col = Color(club.primary_color_hex)
	if club != null:
		_place_club_header(club)

	var meta: Dictionary = world.get("club_meta_by_id", {})
	if not meta.has(player.club_id):
		tabs_row.visible = false
		return
	var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(
		world, player.club_id, WorldTickEngine.world_seed, int(WorldTickEngine.season.get("season_start_epoch_day", 0)),
	)

	formation_tab_button.pressed.connect(_show_formation)
	squad_tab_button.pressed.connect(_show_squad_list)

	var coach := WorldFactory.find_coach(world, player.club_id)
	var form: String = coach.formation if coach != null else ""
	# Bug real de la auditoría: acá se pasaba 0.0 fijo en vez de la chance
	# real de titularidad (mismo criterio que MatchLauncher.gd, la fuente
	# real que arma el partido) — con 0.0 el usuario SIEMPRE aparecía en el
	# banco en esta vista, sin importar overall real ni confianza del DT.
	var team := MatchTeam.from_club(club, squad, player, CoachRelations.start_chance(player.coach_trust), form)
	_coach_formation = form
	_render_formation(team, player)
	_render_coach_card(coach, club)
	_render_squad_list(squad, player)
	_landscape_squad(player)
	_show_formation()

## Escudo + camiseta del club junto al nombre (envuelve el Label una vez).
func _place_club_header(club: ClubData) -> void:
	var parent := club_name_label.get_parent()
	if parent.has_node("ClubHeaderRow"):
		return
	var idx := club_name_label.get_index()
	var row := HBoxContainer.new()
	row.name = "ClubHeaderRow"
	row.add_theme_constant_override("separation", 10)
	parent.remove_child(club_name_label)
	var crest := Styles.club_crest(club.club_id, 46)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	club_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	club_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(club_name_label)
	var kit := Kit.build_for_club_kit(club, WorldTickEngine.get_season_start_year(), false, 44)
	kit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(kit)
	parent.add_child(row)
	parent.move_child(row, idx)

## Tarjeta con la IA del DT: formación, filosofía, estilo de juego + la
## identidad de juego del club (ver Formations.gd). Solo lectura — el DT
## decide, no el usuario.
func _render_coach_card(coach: CoachData, club: ClubData) -> void:
	var box: VBoxContainer = formation_label.get_parent()
	if box.has_node("CoachCard"):
		box.get_node("CoachCard").queue_free()
	var card := PanelContainer.new()
	card.name = "CoachCard"
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	# Compacta (9-oct): antes eran 5 renglones clave/valor que ocupaban
	# media pantalla encima de la cancha. Ahora: cara + nombre + estilo en
	# una línea y el resto como chips.
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	if coach != null:
		var face := Avatar.for_npc(coach.coach_name, "coach", _wseed, 36)
		head_row.add_child(Styles.portrait_frame(face, 36, Styles.BLUE))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := Label.new()
	h.text = coach.coach_name if coach != null else "Sin entrenador"
	h.add_theme_font_override("font", Styles.font_semibold())
	names.add_child(h)
	if coach != null:
		var st := Label.new()
		st.text = "DT · %s" % coach.style
		st.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		st.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		names.add_child(st)
	head_row.add_child(names)
	v.add_child(head_row)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	if coach != null:
		chips.add_child(_chip("⚽ Prefiere " + coach.formation, Styles.BLUE))
		chips.add_child(_chip(coach.philosophy, Styles.GRAY_TEXT))
		chips.add_child(_chip(coach.play_style, Styles.GRAY_TEXT))
	if club != null:
		chips.add_child(_chip("Club: " + Formations.club_style(club, WorldTickEngine.world_seed), Styles.GOLD))
	v.add_child(chips)
	m.add_child(v)
	card.add_child(m)
	box.add_child(card)
	box.move_child(card, formation_label.get_index() + 1)

func _chip(text: String, col: Color) -> PanelContainer:
	var c := PanelContainer.new()
	var sb := Styles.card_flat(Color(col, 0.16), 8)
	sb.border_width_left = 2
	sb.border_color = col
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	c.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	c.add_child(l)
	return c

func _kv(k: String, val: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var a := Label.new()
	a.text = k
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	a.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	var b := Label.new()
	b.text = val
	b.add_theme_font_override("font", Styles.font_semibold())
	b.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	hb.add_child(a)
	hb.add_child(b)
	return hb

func _show_formation() -> void:
	_showing_formation = true
	if _land_cols != null:
		_land_cols.visible = true
	formation_panel.visible = true
	bench_title_label.visible = true
	bench_scroll.visible = not bench_scroll.has_meta("land_hidden")
	squad_scroll.visible = false
	Styles.tab(formation_tab_button, true)
	Styles.tab(squad_tab_button, false)

func _show_squad_list() -> void:
	_showing_formation = false
	if _land_cols != null:
		_land_cols.visible = false
	formation_panel.visible = false
	bench_title_label.visible = false
	bench_scroll.visible = false
	squad_scroll.visible = true
	Styles.tab(squad_tab_button, true)
	Styles.tab(formation_tab_button, false)

# --- Formación: cancha con el once titular ---

var _coach_formation: String = ""

## "4-2-3-1" → "4-5-1" (defensa, todo el medio sumado, delantera).
static func _broad_formation(f: String) -> String:
	var parts: PackedStringArray = f.split("-")
	if parts.size() < 3:
		return f
	var mid: int = 0
	for i in range(1, parts.size() - 1):
		mid += int(parts[i])
	return "%d-%d-%d" % [int(parts[0]), mid, int(parts[parts.size() - 1])]

func _render_formation(team: MatchTeam, user: PlayerData) -> void:
	# Agrupa por el PUESTO DESPLEGADO (deployed_code), no por la posición de
	# oficio del jugador — bug real encontrado en la auditoría: con squads
	# flacos en cierta banda, MatchTeam._build_lineup() (pase 4) puede poner
	# a un defensor de oficio en un hueco de mediocampo; agrupar por
	# p.position mostraba "4-4-2" mientras la tarjeta del DT decía "3-5-2"
	# (la formación REAL que se armó) — dos fuentes de verdad distintas.
	var by_line: Dictionary = {"GK": [], "DF": [], "MF": [], "ST": []}
	for p in team.starting_xi:
		var broad: String = Positions.broad_of(team.deployed_code(p))
		by_line[broad].append(p)

	# P0 (9-oct): antes decía "4-5-1" acá y "4-2-3-1" en la tarjeta del DT,
	# que es la MISMA forma contada por líneas. Si las líneas coinciden se
	# muestra el nombre del DT; si no, se aclara que hoy forman distinto.
	var today: String = "%d-%d-%d" % [by_line["DF"].size(), by_line["MF"].size(), by_line["ST"].size()]
	if _coach_formation != "" and _broad_formation(_coach_formation) == today:
		formation_label.text = "Formación: %s" % _coach_formation
	elif _coach_formation != "":
		formation_label.text = "Hoy forman %s · el DT prefiere %s (faltan piezas)" % [today, _coach_formation]
	else:
		formation_label.text = "Formación: %s" % today

	for child in pitch.get_children():
		child.queue_free()

	var pitch_bg := MiniPitch.new()
	pitch_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pitch.add_child(pitch_bg)
	pitch.move_child(pitch_bg, 0)

	for line in ["GK", "DF", "MF", "ST"]:
		var players: Array = by_line[line]
		players.sort_custom(func(a, b):
			var band_a: int = _LATERAL_BAND.get(a.detailed_position, 1)
			var band_b: int = _LATERAL_BAND.get(b.detailed_position, 1)
			if band_a != band_b:
				return band_a < band_b
			return a.overall > b.overall
		)
		var land: bool = get_viewport_rect().size.x > get_viewport_rect().size.y
		var y: float = (ROW_Y_LAND if land else ROW_Y_FRACTION)[line]
		for i in range(players.size()):
			var x: float = float(i + 1) / float(players.size() + 1)
			pitch.add_child(_make_token(players[i], players[i] == user, x, y))

	for child in bench_row.get_children():
		child.queue_free()
	for p in team.bench:
		bench_row.add_child(_make_bench_token(p, p == user))

## Sprite pixel art del jugador con la camiseta del club (9-oct, pedido de
## Wilber: "mejorá la sección de plantilla") — misma pieza que la cancha
## del partido (Avatar.anim_frames + tools/pitch_sprites.py), con su piel y
## pelo propios. Arquero con buzo de arquero.
func _sprite(p: PlayerData) -> TextureRect:
	var cfg: Dictionary = Avatar.config_for_player(p, _wseed).duplicate()
	var keeper: bool = p.position == "GK"
	var shirt: Color = PitchPlays.GK_US if keeper else _kit_col
	cfg["tint_clothing"] = shirt.to_html(false)
	cfg["tint_shorts"] = "#1f2026" if shirt.get_luminance() > 0.42 else "#e9e9ec"
	cfg.erase("tint_socks")
	var anim: String = "gk_idle_south" if keeper else "pitch_idle_south"
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(68, 68)
	r.size = Vector2(68, 68)
	if Avatar.fill_3d(r, cfg, 68):
		return r
	var frames: Array = Avatar.anim_frames(cfg, anim)
	if not frames.is_empty():
		r.texture = frames[0]
	return r

## Chapita con la media, del color del nivel (mismo criterio que PlayerCard).
func _ovr_chip(ovr: int, px: int = 13) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Styles.card_flat(PlayerCard.tier_color(ovr), 6)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.35)
	chip.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = str(ovr)
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(l)
	return chip

func _name_label(p: PlayerData, is_user: bool, px: int) -> Label:
	var l := Label.new()
	var parts: PackedStringArray = p.player_name.split(" ")
	l.text = "TÚ" if is_user else (parts[parts.size() - 1] if parts.size() > 1 else p.player_name)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_override("font", Styles.font_semibold())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Styles.GOLD if is_user else Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Ficha sobre la cancha, anclada a un PUNTO por fracción del panel: el
## jugador en pixel art, su media arriba a la derecha, apellido y puesto
## abajo. Vos: aro dorado bajo los pies.
func _make_token(p: PlayerData, is_user: bool, x_fraction: float, y_fraction: float) -> Control:
	const TOKEN_W := 84.0
	const TOKEN_H := 98.0
	var wrap := Control.new()
	wrap.anchor_left = x_fraction
	wrap.anchor_right = x_fraction
	wrap.anchor_top = y_fraction
	wrap.anchor_bottom = y_fraction
	wrap.offset_left = -TOKEN_W / 2.0
	wrap.offset_right = TOKEN_W / 2.0
	wrap.offset_top = -TOKEN_H / 2.0 - 8.0
	wrap.offset_bottom = TOKEN_H / 2.0 - 8.0

	if is_user:
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(1.0, 0.85, 0.25, 0.25)
		rs.border_color = Styles.GOLD
		rs.set_border_width_all(2)
		rs.set_corner_radius_all(20)
		ring.add_theme_stylebox_override("panel", rs)
		ring.position = Vector2(TOKEN_W / 2.0 - 22, 52)
		ring.size = Vector2(44, 14)
		wrap.add_child(ring)
	var spr := _sprite(p)
	spr.position = Vector2((TOKEN_W - 68.0) / 2.0, 0)
	wrap.add_child(spr)
	var chip := _ovr_chip(p.overall)
	chip.position = Vector2(TOKEN_W / 2.0 + 10, 4)
	wrap.add_child(chip)
	var nm := _name_label(p, is_user, 12)
	nm.position = Vector2(-6, 62)
	nm.size = Vector2(TOKEN_W + 12, 18)
	wrap.add_child(nm)
	var pos := Label.new()
	pos.text = p.detailed_position
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos.add_theme_font_size_override("font_size", 10)
	pos.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	pos.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	pos.add_theme_constant_override("outline_size", 3)
	pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos.position = Vector2(0, 79)
	pos.size = Vector2(TOKEN_W, 14)
	wrap.add_child(pos)

	PlayerCard.make_clickable(wrap, p, _open_player_card)
	return wrap

## Suplente: tarjetita con el jugador, su media, apellido y puesto.
func _make_bench_token(p: PlayerData, is_user: bool) -> Control:
	var card := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.3, 0.24, 0.05) if is_user else Styles.CARD_DARK_2, 10)
	sb.border_width_bottom = 3
	sb.border_color = PlayerCard.tier_color(p.overall)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(80, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := Control.new()
	top.custom_minimum_size = Vector2(72, 60)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spr := _sprite(p)
	spr.position = Vector2(2, -6)
	top.add_child(spr)
	var chip := _ovr_chip(p.overall, 12)
	chip.position = Vector2(46, 2)
	top.add_child(chip)
	v.add_child(top)
	v.add_child(_name_label(p, is_user, 11))
	var pos := Label.new()
	pos.text = p.detailed_position
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos.add_theme_font_size_override("font_size", 10)
	pos.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pos)
	card.add_child(v)
	PlayerCard.make_clickable(card, p, _open_player_card)
	return card

# --- Plantilla: lista completa ---

## Lista paginada con ◀ ▶ (Pager) en vez de scroll táctil — pedido de Wilber.
func _render_squad_list(squad: Array[PlayerData], player: PlayerData) -> void:
	var rows: Array = []
	for p in squad:
		rows.append({"player": p, "is_user": false})
	rows.append({"player": player, "is_user": true})

	rows.sort_custom(func(a, b):
		var oa: int = ORDER.find(a["player"].position)
		var ob: int = ORDER.find(b["player"].position)
		if oa != ob:
			return oa < ob
		return a["player"].overall > b["player"].overall
	)

	# Encabezado por línea (Porteros / Defensas / ...) antes del primero de
	# cada una — la lista se lee por bloques en vez de una tira pareja.
	var grouped: Array = []
	var last_line: String = ""
	for r in rows:
		var line: String = r["player"].position
		if line != last_line:
			grouped.append({"header": line})
			last_line = line
		grouped.append(r)
	rows = grouped

	squad_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	squad_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var pager := Pager.new()
	list_box.add_child(pager)
	pager.show_items(rows, 12, _build_squad_row)
	UiScroll.pad_bottom(list_box, 76)  # BottomNav fijo abajo

const _LINE_TITLES := {"GK": "PORTEROS", "DF": "DEFENSAS", "MF": "MEDIOCAMPISTAS", "ST": "DELANTEROS"}

func _build_squad_row(item: Dictionary) -> Control:
	if item.has("header"):
		var l := Label.new()
		l.text = String(_LINE_TITLES.get(item["header"], item["header"]))
		l.add_theme_font_override("font", Styles.font_black())
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Styles.GOLD)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 8)
		m.add_child(l)
		return m
	return _make_row(item["player"], bool(item["is_user"]))

func _make_row(p: PlayerData, is_user: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	# Franja de color = tier del jugador (mismo criterio que PlayerCard/Hub,
	# "que se vea como EA FC"), sobre el fondo dorado tenue si sos vos.
	var bg: Color = Color(0.3, 0.24, 0.05) if is_user else Styles.CARD_DARK
	var style := Styles.card_flat(bg, 8)
	style.border_width_left = 4
	style.border_color = PlayerCard.tier_color(p.overall)
	style.content_margin_left = 8
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	var face := Avatar.for_player(p, _wseed, 40)
	face.custom_minimum_size = Vector2(40, 40)
	hbox.add_child(face)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_lbl := Label.new()
	name_lbl.text = "%s%s" % [p.player_name, "  (tú)" if is_user else ""]
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", Styles.font_semibold())
	if is_user:
		name_lbl.add_theme_color_override("font_color", Styles.GOLD)
	col.add_child(name_lbl)
	var sub := Label.new()
	sub.text = "%s · %d años" % [p.detailed_position, p.age]
	sub.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	col.add_child(sub)
	hbox.add_child(col)

	var chip := _ovr_chip(p.overall, 16)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(chip)

	panel.add_child(hbox)
	PlayerCard.make_clickable(panel, p, _open_player_card)
	return panel

func _open_player_card(p: PlayerData) -> void:
	# Horizontal con la cancha a la vista: tocar un jugador muestra su ficha
	# a la derecha (como WSC); la ficha completa queda a un botón.
	if _land_detail != null and _showing_formation:
		_land_show(p)
		return
	_open_full_card(p)

func _open_full_card(p: PlayerData) -> void:
	PlayerCard.render(player_card_box, p)
	player_card_overlay.visible = true

func nav_back() -> bool:
	if player_card_overlay.visible:
		_on_player_card_back_pressed()
		return true
	return false

func _on_player_card_back_pressed() -> void:
	player_card_overlay.visible = false


# --- HORIZONTAL (FootballLegacy H): estilo "Team Management" de WSC ---
# Izquierda: la cancha con el once a todo el alto. Derecha: la ficha del
# jugador que tocás y la grilla de SUPLENTES. Arriba: club + formación +
# pestañas en una sola franja.

var _land_cols: HBoxContainer = null
var _land_detail: PanelContainer = null

func _landscape_squad(player: PlayerData) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	var vbox := formation_label.get_parent() as VBoxContainer
	vbox.add_theme_constant_override("separation", 8)
	# Franja superior: [escudo + club] [formación] [pestañas].
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var club_node: Control = club_name_label
	while club_node.get_parent() != vbox:
		club_node = club_node.get_parent() as Control
	vbox.add_child(head)
	vbox.move_child(head, club_node.get_index())
	club_node.reparent(head)
	formation_label.reparent(head)
	formation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tabs_row.reparent(head)
	tabs_row.custom_minimum_size.x = 320
	# Columnas.
	_land_cols = HBoxContainer.new()
	_land_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_land_cols.add_theme_constant_override("separation", 14)
	vbox.add_child(_land_cols)
	vbox.move_child(_land_cols, formation_panel.get_index())
	formation_panel.reparent(_land_cols)
	formation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formation_panel.size_flags_stretch_ratio = 1.5
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	_land_cols.add_child(right)
	_land_detail = PanelContainer.new()
	_land_detail.add_theme_stylebox_override("panel", Styles.card_flat(Styles.CARD_DARK_2, 12))
	right.add_child(_land_detail)
	bench_title_label.reparent(right)
	# Suplentes en grilla de 4 (en vez de una fila con scroll de costado).
	var bsc := ScrollContainer.new()
	bsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiScroll.make_touch(bsc)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	bsc.add_child(grid)
	right.add_child(bsc)
	for t in bench_row.get_children():
		(t as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.reparent(grid)
	bench_scroll.visible = false
	bench_scroll.set_meta("land_hidden", true)
	# La tarjeta del DT, compacta, al pie de la columna derecha.
	if vbox.has_node("CoachCard"):
		vbox.get_node("CoachCard").visible = false
	_land_show(player)

func _land_show(p: PlayerData) -> void:
	for c in _land_detail.get_children():
		c.queue_free()
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var spr := _sprite(p)
	# Proporción fija: sin esto el HBox lo estiraba al alto de la tarjeta.
	spr.custom_minimum_size = Vector2(96, 96)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(spr)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var nm := Label.new()
	nm.text = p.player_name
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_override("font", Styles.font_semibold())
	nm.add_theme_font_size_override("font_size", 17)
	top.add_child(nm)
	top.add_child(_ovr_chip(p.overall, 15))
	v.add_child(top)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	sub.add_child(CountryFlags.flag_rect(p.country, 14))
	var info := Label.new()
	info.text = "%s · %d años" % [Positions.label_of(p.detailed_position), p.age]
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sub.add_child(info)
	v.add_child(sub)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 2)
	for pair in [["VEL", p.speed], ["TIR", p.shooting], ["PAS", p.passing], ["REG", p.dribbling], ["FÍS", p.strength], ["RES", p.stamina]]:
		var l := Label.new()
		l.text = "%s  %d" % [pair[0], pair[1]]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", PlayerCard.tier_color(int(pair[1])) if int(pair[1]) >= 70 else Color(0.9, 0.91, 0.95))
		g.add_child(l)
	v.add_child(g)
	var more := Button.new()
	more.text = "Ver ficha completa"
	more.focus_mode = Control.FOCUS_NONE
	more.custom_minimum_size = Vector2(0, 30)
	more.add_theme_font_size_override("font_size", 12)
	Styles.styled_button(more, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	more.pressed.connect(_open_full_card.bind(p))
	v.add_child(more)
	h.add_child(v)
	m.add_child(h)
	_land_detail.add_child(m)
