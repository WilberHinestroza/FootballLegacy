extends Control

## Colección — la vitrina de TODAS tus carreras, no solo la activa. Pedido
## explícito de Wilber ("ahora que tenemos todas las competiciones del
## mundo, ahora sí podemos agregar la sección de colecciones que es las
## vitrinas recolectadas en general de todas las partidas"), respondiendo
## a su propia aclaración: junta las 3 (slot_1/2/3) carreras EN CURSO más
## el archivo de carreras RETIRADAS (SaveManager.archive_retired_career,
## que sobrevive aunque un slot se reutilice) — una tarjeta por carrera,
## paginada, cada una con su propia vitrina de trofeos agrupada por tipo
## (mismo criterio de agrupado que PlayerProfile._render_showcase, pero
## copiado acá en vez de compartido: son datos de OTRAS carreras, no de
## `self._player`, y el resto del juego ya tiene 2 copias independientes
## de este mismo renderizado de "celda de trofeo" — PlayerProfile.gd y
## Retirement.gd — así que una tercera acá sigue el mismo criterio).
##
## Se entra desde el menú inicial (Start.gd, botón "Colección"), NUNCA
## desde dentro de una carrera — no toca WorldTickEngine.active state ni
## pisa `active_slot_id` en ningún momento (SaveManager.load_slot() es de
## solo lectura y no depende del slot activo).

@onready var back_button: Button = $Root/VBox/BackButton
@onready var content_box: VBoxContainer = $Root/VBox/Scroll/ContentBox

var _world_cache: Dictionary = {}  # world_seed -> world (evita reconstruir por tarjeta)

func _ready() -> void:
	var bg := Styles.screen_bg()
	add_child(bg)
	move_child(bg, 0)

	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	UiKit.land_back_arrow.call_deferred(back_button)
	UiScroll.make_touch(self)

	_render()

func _on_back_pressed() -> void:
	if Nav.can_go_back():
		Nav.back()
	else:
		get_tree().change_scene_to_file("res://scenes/Start/Start.tscn")

func _world_for(world_seed: int) -> Dictionary:
	if not _world_cache.has(world_seed):
		_world_cache[world_seed] = WorldFactory.build(world_seed)
	return _world_cache[world_seed]

func _render() -> void:
	for c in content_box.get_children():
		c.queue_free()

	var careers: Array = _gather_careers()
	if careers.is_empty():
		var empty := Label.new()
		empty.text = "Todavía no hay ninguna carrera jugada. Empezá una desde el menú inicial."
		UiKit.empty_icon(empty, Icons.PX_COLLECTION)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		content_box.add_child(empty)
		return

	# Récords cross-save (Parte 91, pedido de Wilber): con una sola carrera
	# no hay nada que comparar, así que la sección solo aparece a partir
	# de la segunda.
	var land: bool = get_viewport_rect().size.x > get_viewport_rect().size.y
	var host: Container = content_box
	var side: VBoxContainer = null
	if land:
		# HORIZONTAL: la carrera (carta + datos) a la izquierda, con ◀ ▶ para
		# pasar de carrera; los récords de todas a la derecha.
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 18)
		content_box.add_child(cols)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.4
		cols.add_child(left)
		host = left
		side = VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(side)
	if careers.size() >= 2:
		(side if side != null else content_box).add_child(_records_section(careers))

	var builders: Array = []
	for career in careers:
		builders.append(func(c = career) -> Control: return _career_card(c))
	var pager := Pager.new()
	host.add_child(pager)
	pager.show_items(builders, 1, func(b: Callable) -> Control: return b.call())
	UiScroll.pad_bottom(content_box, 24)

## Récord: [clave en el dict de carrera ("titles" es especial: cuenta
## career_titles.size() en vez de leer una clave), etiqueta, unidad].
const _RECORD_DEFS := [
	["career_goals", "Máximo goleador histórico", "goles"],
	["career_assists", "Máximo asistidor histórico", "asistencias"],
	["titles", "Más títulos en una carrera", "títulos"],
	["caps", "Más partidos con la selección", "partidos"],
	["overall", "Mejor overall alcanzado", "overall"],
]

## El mejor de TODAS las carreras (en curso + retiradas) en cada métrica
## — un pequeño "libro de récords" del jugador entre sus propias partidas
## (pedido de Wilber: "qué más podemos agregar" a Colección). Solo
## muestra las métricas con algún valor > 0 (una carrera recién empezada
## no "gana" el récord de partidos con la selección con 0 caps).
func _records_section(careers: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Styles.section_label("RÉCORDS DE TODAS TUS CARRERAS"))
	var panel := _card(Styles.GOLD)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	var any: bool = false
	for def in _RECORD_DEFS:
		var key: String = def[0]
		var best: Dictionary = {}
		var best_val: int = 0
		for c in careers:
			var v: int = (c.get("career_titles", []) as Array).size() if key == "titles" else int(c.get(key, 0))
			if v > best_val:
				best_val = v
				best = c
		if best.is_empty():
			continue
		any = true
		content.add_child(_record_row(String(def[1]), best, best_val, String(def[2])))
	if not any:
		content.add_child(_row_label("Récords", "Todavía nada que destacar"))
	box.add_child(panel)
	return box

func _record_row(label: String, holder: Dictionary, value: int, unit: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var country: String = String(holder.get("country", ""))
	if country != "":
		row.add_child(CountryFlags.flag_rect(country, 16))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(lbl)
	var nm := Label.new()
	nm.text = String(holder.get("player_name", "?"))
	nm.add_theme_font_size_override("font_size", 14)
	vb.add_child(nm)
	row.add_child(vb)
	var val := Label.new()
	val.text = "%d %s" % [value, unit]
	val.add_theme_font_override("font", Styles.font_semibold())
	row.add_child(val)
	return row

## Junta las carreras EN CURSO (slot_1/2/3, leídas de solo-lectura vía
## load_slot — nunca toca active_slot_id) con el archivo de RETIRADAS.
## Si una entrada retirada corresponde al mismo world_seed que lo que HOY
## vive en ese slot, es la MISMA carrera todavía sin pisar — se muestra
## una sola vez (la retirada, más completa) en vez de duplicarla.
func _gather_careers() -> Array:
	var out: Array = []
	var archived: Array = SaveManager.load_retired_careers()
	var archived_by_slot: Dictionary = {}
	for a in archived:
		var sid: String = String((a as Dictionary).get("slot_id", ""))
		if not archived_by_slot.has(sid):
			archived_by_slot[sid] = []
		archived_by_slot[sid].append(a)

	for slot_id in SaveManager.SLOT_IDS:
		var live_data: Dictionary = SaveManager.load_slot(slot_id)
		var live_player: Dictionary = live_data.get("player", {})
		var live_seed: int = int(live_data.get("world_seed", -1))
		var slot_archives: Array = archived_by_slot.get(slot_id, [])
		var matched_live: bool = false
		for a in slot_archives:
			out.append(_from_archive(a))
			if int((a as Dictionary).get("world_seed", -2)) == live_seed:
				matched_live = true
		if not live_player.is_empty() and String(live_player.get("club_id", "")) != "" and not matched_live:
			out.append(_from_live(slot_id, live_player, live_seed))
	return out

func _from_archive(a: Dictionary) -> Dictionary:
	return {
		"player_name": String(a.get("player_name", "Jugador")),
		"country": String(a.get("country", "")),
		"club_id": "", "world_seed": -1, "status": "retirada",
		"career_titles": a.get("career_titles", []),
		"career_goals": int(a.get("career_goals", 0)),
		"career_assists": int(a.get("career_assists", 0)),
		"trophies_won": int(a.get("trophies_won", 0)),
		"overall": int(a.get("overall", 0)),
		"caps": int(a.get("caps", 0)),
		"international_goals": int(a.get("international_goals", 0)),
	}

func _from_live(slot_id: String, p: Dictionary, world_seed: int) -> Dictionary:
	return {
		"player_name": String(p.get("player_name", "Jugador")),
		"country": String(p.get("country", "")),
		"club_id": String(p.get("club_id", "")), "world_seed": world_seed, "status": "activa",
		"career_titles": p.get("career_titles", []),
		"career_goals": int(p.get("career_goals", 0)),
		"career_assists": int(p.get("career_assists", 0)),
		"trophies_won": int(p.get("trophies_won", 0)),
		"overall": int(p.get("overall", 0)),
		"caps": int(p.get("caps", 0)),
		"international_goals": int(p.get("international_goals", 0)),
		"avatar": p.get("avatar", {}),
	}

## Tarjeta completa de UNA carrera: encabezado (nombre, país, club/estado)
## + resumen (goles/asistencias/trofeos) + vitrina agrupada por tipo.
func _career_card(career: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var cc := CenterContainer.new()
	cc.add_child(_cromo(career))
	var summary_panel := _card(Styles.GOLD)
	var summary_content: VBoxContainer = summary_panel.get_child(0).get_child(0)
	summary_content.add_child(_row_label("Títulos", str((career.get("career_titles", []) as Array).size())))
	summary_content.add_child(_row_label("Goles en la carrera", str(int(career.get("career_goals", 0)))))
	summary_content.add_child(_row_label("Asistencias en la carrera", str(int(career.get("career_assists", 0)))))
	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		# HORIZONTAL: el cromo a la izquierda; nombre, números y vitrina al lado.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.add_child(cc)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 10)
		info.add_child(_career_header(career))
		info.add_child(summary_panel)
		info.add_child(_showcase(career.get("career_titles", [])))
		row.add_child(info)
		box.add_child(row)
		return box
	box.add_child(_career_header(career))
	box.add_child(cc)
	box.add_child(summary_panel)
	box.add_child(_showcase(career.get("career_titles", [])))
	return box

## CROMO de la carrera (P6, 10-oct): marco por nivel — bronce, plata,
## oro o leyenda — con el jugador de cuerpo entero y su media.
const _CROMO_TIERS := [[88, "LEYENDA", "#a855f7", "#ffd54f"], [80, "ORO", "#e9b73a", "#fff2b3"],
	[70, "PLATA", "#b8c2cc", "#ffffff"], [0, "BRONCE", "#b87333", "#f3c9a0"]]
func _cromo(career: Dictionary) -> Control:
	var ovr: int = int(career.get("overall", 0))
	var tier: Array = _CROMO_TIERS[_CROMO_TIERS.size() - 1]
	for t in _CROMO_TIERS:
		if ovr >= int(t[0]):
			tier = t
			break
	var edge := Color(String(tier[2]))
	var shine := Color(String(tier[3]))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = edge.darkened(0.65)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(5)
	sb.border_color = edge
	sb.shadow_color = Color(edge, 0.45)
	sb.shadow_size = 10
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var top := HBoxContainer.new()
	var o := Label.new()
	o.text = "  %d" % ovr
	o.add_theme_font_override("font", Styles.font_black())
	o.add_theme_font_size_override("font_size", 28)
	o.add_theme_color_override("font_color", shine)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(o)
	var tl := Label.new()
	tl.text = String(tier[1]) + "  "
	tl.add_theme_font_override("font", Styles.font_black())
	tl.add_theme_font_size_override("font_size", 11)
	tl.add_theme_color_override("font_color", shine)
	top.add_child(tl)
	v.add_child(top)
	var av_cfg: Dictionary = career.get("avatar", {}) if career.get("avatar", {}) is Dictionary and not (career.get("avatar", {}) as Dictionary).is_empty() else Avatar.config_for_npc(String(career.get("player_name", "")), "player", 1)
	var av := Avatar.build_full(av_cfg, 130)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(av)
	var n := Label.new()
	n.text = String(career.get("player_name", "Jugador")).to_upper()
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.add_theme_font_override("font", Styles.font_black())
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(n)
	if int(tier[0]) >= 80:
		# Oro/leyenda: el borde late suave (un brillo dentro de un
		# PanelContainer se estiraría a todo el cromo).
		card.ready.connect(func(): Juice.pulse(card, 1.02, 1.8))
	return card

func _career_header(career: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var country: String = String(career.get("country", ""))
	if country != "":
		row.add_child(CountryFlags.flag_rect(country, 22))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = String(career.get("player_name", "Jugador"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(name_lbl)
	var sub_lbl := Label.new()
	var status: String = String(career.get("status", "activa"))
	if status == "retirada":
		sub_lbl.text = "%s — Retirado/a" % country if country != "" else "Retirado/a"
	else:
		var world: Dictionary = _world_for(int(career.get("world_seed", 0)))
		var club := WorldFactory.find_club(world, String(career.get("club_id", "")))
		var club_name: String = club.club_name if club != null else "?"
		sub_lbl.text = "%s — %s (en curso)" % [country, club_name] if country != "" else "%s (en curso)" % club_name
	sub_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sub_lbl.add_theme_font_size_override("font_size", 12)
	vb.add_child(sub_lbl)
	row.add_child(vb)
	return row

## Vitrina agrupada por tipo (team/continental/world/individual) — mismo
## agrupado que PlayerProfile._render_showcase, sin la tarjeta "legacy" ni
## el Balón de Oro EN VIVO (no tienen sentido para una carrera que no es
## la activa: acá solo mostramos lo YA ganado).
func _showcase(titles: Array) -> Control:
	var groups := {"team": [], "continental": [], "world": [], "individual": []}
	for t in titles:
		var k: String = String((t as Dictionary).get("kind", "team"))
		if not groups.has(k):
			k = "team"
		groups[k].append(t)

	var group_meta := [
		["team", "TÍTULOS DE EQUIPO", Styles.GOLD],
		["continental", "COPAS CONTINENTALES", Styles.BLUE],
		["world", "MUNDIALES", Styles.PURPLE],
		["individual", "HONORES INDIVIDUALES", Styles.GREEN],
	]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var any: bool = false
	for gm in group_meta:
		var arr: Array = (groups[gm[0]] as Array)
		if arr.is_empty():
			continue
		any = true
		arr = arr.duplicate()
		arr.sort_custom(func(a, b): return int(a.get("season", 0)) > int(b.get("season", 0)))
		box.add_child(_group_card(String(gm[1]), gm[2], arr))
	if not any:
		var e_panel := _card(Styles.GOLD)
		(e_panel.get_child(0).get_child(0) as VBoxContainer).add_child(_row_label("Palmarés", "Todavía sin títulos"))
		box.add_child(e_panel)
	return box

func _group_card(title: String, accent: Color, arr: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Styles.section_label("%s (%d)" % [title, arr.size()]))
	var panel := _card(accent)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	for e in arr:
		grid.add_child(_title_cell(e))
	content.add_child(grid)
	box.add_child(panel)
	return box

## Celda de un título: trofeo + nombre + temporada — misma lógica que
## PlayerProfile._title_cell (usa HonorsEngine.trophy_key_for para el
## arte correcto, incluidos los trofeos de selección de la Parte 82).
func _title_cell(entry: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	var node: Control = Trophy.for_entry(entry, 52)
	node.custom_minimum_size = Vector2(52, 58)
	var wrap := CenterContainer.new()
	wrap.add_child(node)
	col.add_child(wrap)
	var nm := Label.new()
	nm.text = String(entry.get("name", "Título"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", 11)
	col.add_child(nm)
	var yr := Label.new()
	yr.text = "%d/%02d" % [int(entry.get("season", 0)), (int(entry.get("season", 0)) + 1) % 100]
	yr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yr.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	yr.add_theme_font_size_override("font_size", 9)
	col.add_child(yr)
	return col

func _card(accent: Color = Color.TRANSPARENT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card() if accent.a <= 0 else Styles.card_accent(accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	panel.add_child(margin)
	return panel

func _row_label(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)
	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)
	return row
