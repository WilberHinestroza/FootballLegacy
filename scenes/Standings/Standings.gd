extends Control

## Clasificación completa de la liga del usuario. Lectura pura sobre
## WorldTickEngine (mundo vivo, Fase 5) — no muta nada.
## Paginada con botones ◀ ▶ (ver Pager.gd) en vez de scroll táctil —
## pedido explícito y repetido de Wilber ("el táctil funciona mal").

const COL_WIDTHS := [24, 124, 26, 24, 24, 24, 28, 28, 36, 38]
const CREST_PX := 20
const HEADER := ["#", "Club", "PJ", "G", "E", "P", "GF", "GC", "DG", "Pts"]
const PER_PAGE := 12

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var rows_box: VBoxContainer = $Margin/VBox/Scroll/RowsBox
@onready var back_button: Button = $Margin/VBox/BackButton

var _table_size: int = 0
var _pager: Pager = null
var _league: LeagueData = null

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_render()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _render() -> void:
	var league_id: int = int(WorldTickEngine.season.get("league_id", -1))
	var league: LeagueData = _find_league(league_id)
	title_label.text = league.league_name if league != null else "Clasificación"

	for child in rows_box.get_children():
		child.queue_free()

	var table := WorldTickEngine.user_league_table()
	if table.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Sin temporada activa."
		rows_box.add_child(empty_label)
		return

	_table_size = table.size()
	_league = league
	var items: Array = []
	for i in range(table.size()):
		items.append({"idx": i, "row": table[i]})

	_pager = Pager.new()
	rows_box.add_child(_pager)
	var hspace := Control.new()
	hspace.custom_minimum_size = Vector2(CREST_PX, 1)
	_pager.set_header(DataTable.make_row(HEADER, COL_WIDTHS, true, false, Callable(), Color.TRANSPARENT, -1, hspace))
	var land: bool = get_viewport_rect().size.x > get_viewport_rect().size.y
	# Horizontal: arranca en la hoja donde está TU club.
	var my_idx: int = 0
	for i in range(table.size()):
		if table[i]["club_id"] == WorldTickEngine.user_club_id:
			my_idx = i
	_pager.show_items(items, 7 if land else PER_PAGE, _build_row)
	if land:
		_pager.goto_page(my_idx / 7)
		_land_side(table, my_idx)
	UiScroll.pad_bottom(rows_box)

func _build_row(item: Dictionary) -> Control:
	var row: Dictionary = item["row"]
	var pos: int = int(row["pos"])
	var is_mine: bool = row["club_id"] == WorldTickEngine.user_club_id
	var accent: Color = StandingsColor.accent_for(_league, _table_size, pos)
	return DataTable.make_row([
		str(pos), row["name"], str(row["pj"]), str(row["g"]), str(row["e"]),
		str(row["p"]), str(row["gf"]), str(row["gc"]), "%+d" % row["dg"], str(row["pts"]),
	], COL_WIDTHS, false, is_mine, Callable(), accent, int(item["idx"]), Styles.club_crest(row["club_id"], CREST_PX))

func _find_league(league_id: int) -> LeagueData:
	for lg in WorldTickEngine.world.get("leagues", []):
		if lg.league_id == league_id:
			return lg
	return null


## HORIZONTAL: la tabla a la izquierda; a la derecha TU CLUB en grande
## (posición, puntos, a cuánto del líder y de la zona de abajo) y la
## leyenda de colores.
func _land_side(table: Array, my_idx: int) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	rows_box.add_child(cols)
	_pager.reparent(cols)
	_pager.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pager.size_flags_stretch_ratio = 1.9
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	cols.add_child(side)
	var me: Dictionary = table[my_idx]
	var pos: int = int(me["pos"])
	var zone: Dictionary = StandingsColor.zone_for(_league, table.size(), pos)
	var zc: Color = zone["color"] if zone["color"] != Color.TRANSPARENT else Styles.GRAY_TEXT
	var card := PanelContainer.new()
	var sb := Styles.card_flat(Color(0.09, 0.1, 0.12, 0.95), 16)
	sb.border_width_left = 5
	sb.border_color = zc
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(Styles.club_crest(String(me["club_id"]), 56))
	var pv := VBoxContainer.new()
	var big := Label.new()
	big.text = "%dº" % pos
	big.add_theme_font_override("font", Styles.font_black())
	big.add_theme_font_size_override("font_size", 40)
	var bc: Color = zc if zone["color"] != Color.TRANSPARENT else Color.WHITE
	if bc.get_luminance() < 0.45:
		bc = bc.lightened(0.55)   # zonas oscuras (azul) se leían mal
	big.add_theme_color_override("font_color", bc)
	pv.add_child(big)
	var zl := Label.new()
	zl.text = String(zone["label"]) if String(zone["label"]) != "" else "Mitad de tabla"
	zl.add_theme_font_size_override("font_size", 12)
	zl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	pv.add_child(zl)
	top.add_child(pv)
	v.add_child(top)
	var nm := Label.new()
	nm.text = String(me["name"])
	nm.add_theme_font_override("font", Styles.font_semibold())
	nm.add_theme_font_size_override("font_size", 16)
	v.add_child(nm)
	var pts: int = int(me["pts"])
	var leader: int = int(table[0]["pts"])
	var lines: Array = [["Puntos", str(pts)], ["Récord", "%dG %dE %dP" % [int(me["g"]), int(me["e"]), int(me["p"])]],
		["Goles", "%d a favor · %d en contra" % [int(me["gf"]), int(me["gc"])]]]
	lines.append(["Al líder", "—  sos el líder" if my_idx == 0 else "a %d pts" % (leader - pts)])
	var drop_from: int = -1
	for i in range(table.size()):
		var z: Dictionary = StandingsColor.zone_for(_league, table.size(), i + 1)
		if String(z["label"]).to_lower().contains("desc"):
			drop_from = i
			break
	if drop_from > 0 and my_idx < drop_from:
		lines.append(["Sobre el descenso", "+%d pts" % (pts - int(table[drop_from]["pts"]))])
	for l in lines:
		var h := HBoxContainer.new()
		var k := Label.new()
		k.text = String(l[0])
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		k.add_theme_font_size_override("font_size", 13)
		h.add_child(k)
		var val := Label.new()
		val.text = String(l[1])
		val.add_theme_font_size_override("font_size", 13)
		h.add_child(val)
		v.add_child(h)
	card.add_child(v)
	side.add_child(card)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 12)
	legend.add_theme_constant_override("v_separation", 4)
	for pair in StandingsColor.legend_for(_league, table.size()):
		var lh := HBoxContainer.new()
		lh.add_theme_constant_override("separation", 5)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = pair[0]
		lh.add_child(dot)
		var ll := Label.new()
		ll.text = String(pair[1])
		ll.add_theme_font_size_override("font_size", 11)
		ll.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		lh.add_child(ll)
		legend.add_child(lh)
	side.add_child(legend)
