extends Control

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

## Previa del partido, reorganizada: panel por equipo con escudo, camiseta
## (con selector Titular / Visitante), estrellas de nivel y barras
## ATA / MED / DEF; selector de balón; y el once titular de cada lado.
## Las elecciones (camisetas + balón) son COSMÉTICAS — van a MatchState y
## solo cambian cómo se dibuja el partido, nunca el resultado.

@onready var compare_label: Label = $Scroll/Margin/VBox/CompareLabel
## Referencia fija (evaluada UNA vez, antes de que _render() la reubique
## dentro de la viñeta "Táctica") — usar SIEMPRE esta variable en vez de
## $Scroll/Margin/VBox/TeamsRow, que deja de resolver apenas el nodo se mueve.
@onready var teams_row: HBoxContainer = $Scroll/Margin/VBox/TeamsRow
@onready var home_name_label: Label = $Scroll/Margin/VBox/TeamsRow/HomeColumn/HomeNameLabel
@onready var home_strength_label: Label = $Scroll/Margin/VBox/TeamsRow/HomeColumn/HomeStrengthLabel
@onready var home_lineup_box: VBoxContainer = $Scroll/Margin/VBox/TeamsRow/HomeColumn/HomeScroll/HomeLineupBox
@onready var away_name_label: Label = $Scroll/Margin/VBox/TeamsRow/AwayColumn/AwayNameLabel
@onready var away_strength_label: Label = $Scroll/Margin/VBox/TeamsRow/AwayColumn/AwayStrengthLabel
@onready var away_lineup_box: VBoxContainer = $Scroll/Margin/VBox/TeamsRow/AwayColumn/AwayScroll/AwayLineupBox
@onready var start_button: Button = $Scroll/Margin/VBox/StartMatchButton

var _home_club: ClubData = null
var _away_club: ClubData = null
var _home_away_kit := false
var _away_away_kit := true
var _ball_idx := -1          # -1 = todavía sin resolver (se fija UNA vez)
var _kit_slot := {}          # side -> CenterContainer que contiene la camiseta
var _ball_slot: CenterContainer = null
var _season_year := 0

## Viñetas (pedido de Wilber: "divide la sección de iniciar partido en
## varias viñetas, una de uniformes y balones, otra de táctica") — 0 =
## Uniformes y balón, 1 = Táctica. Se preserva entre _render() (cada toque
## de camiseta/balón vuelve a llamar _render(), no debe resetear la pestaña).
var _active_tab: int = 1
var _tab_kits: VBoxContainer = null
var _tab_tactics: VBoxContainer = null
var _tab_btn_kits: Button = null
var _tab_btn_tactics: Button = null

## Selección nacional: MatchState.fixture trae home_country/away_country
## en vez de home_club_id/away_club_id (ver NationalTeamMatchLauncher.gd)
## — mismo discriminador que ya usa Match.gd.
func _is_national_fixture(fx: Dictionary) -> bool:
	return fx.has("home_country")

## "Club" de mentira SOLO para reusar Kit.build_for_club_kit() (pide un
## ClubData) con un color/patrón propio del país en vez del celeste
## genérico fijo — NUNCA se usa para el escudo (ahí va la bandera real).
func _country_kit_stub(country: String) -> ClubData:
	var c := ClubData.new()
	c.club_id = country
	c.club_name = country
	c.primary_color_hex = "#" + CountryFlags.team_color(country).to_html(false)
	return c

func _ready() -> void:
	start_button.pressed.connect(_on_start_match_pressed)
	start_button.icon = Icons.load_icon(Icons.FOOTBALL)
	start_button.add_theme_constant_override("icon_max_width", 30)
	Styles.styled_button(start_button, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	_build_back_button()
	UiScroll.make_touch(home_lineup_box.get_parent())
	_landscape_tweaks.call_deferred()
	UiScroll.make_touch(away_lineup_box.get_parent())
	_render()

## Botón de volver (pedido de Wilber: va ACÁ, en la previa — no en el
## partido en sí, que ya arrancó de verdad). Nada se compromete todavía en
## esta pantalla (ni siquiera MatchLauncher tocó season/player), así que
## sin confirmación: vuelve directo a MatchState.return_scene.
func _build_back_button() -> void:
	var btn := Button.new()
	btn.name = "PreMatchBackButton"
	btn.custom_minimum_size = Vector2(38, 38)
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = Icons.load_icon(Icons.BACK)
	btn.add_theme_constant_override("icon_max_width", 18)
	Styles.styled_button(btn, Styles.pill_filled(Color(0.12, 0.13, 0.16, 0.85)), Color(0.92, 0.93, 0.97))
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn.position = Vector2(12, 12)
	btn.z_index = 100
	btn.pressed.connect(func(): get_tree().change_scene_to_file(MatchState.return_scene))
	add_child(btn)

func _render() -> void:
	var home: MatchTeam = MatchState.home_team
	var away: MatchTeam = MatchState.away_team
	if home == null or away == null:
		push_error("PreMatch.gd: MatchState no tiene equipos listos.")
		return

	_season_year = WorldTickEngine.get_season_start_year()
	var fx: Dictionary = MatchState.fixture
	var world: Dictionary = WorldTickEngine.world
	if world.is_empty():
		world = WorldFactory.build(SaveManager.load_world_seed())
	# Selección nacional (Parte 91g, "nada distinto"): el fixture usa
	# home_country/away_country — sin esto _home_club/_away_club quedaban
	# SIEMPRE null (WorldFactory.find_club con id vacío), y todo lo que
	# dependía de un ClubData real cascadeaba a un genérico fijo (nunca
	# crasheaba — Kit/Venue ya toleran club=null — pero se veía genérico:
	# mismo celeste para cualquier país, sin bandera, competencia mal
	# etiquetada). Acá van null a propósito (discriminan "esto es
	# selección" en _team_panel/_competition_header de abajo); Venue ya
	# maneja bien club=null (estadio/asistencia con defaults razonables).
	if _is_national_fixture(fx):
		_home_club = null
		_away_club = null
	else:
		_home_club = WorldFactory.find_club(world, fx.get("home_club_id", ""))
		_away_club = WorldFactory.find_club(world, fx.get("away_club_id", ""))

	# El balón se resuelve UNA sola vez (si no, cada _render lo pisaba con
	# el valor guardado y el selector no cambiaba nada — bug que reportó Wilber).
	if _ball_idx < 0:
		_ball_idx = MatchState.ball_design
		if _ball_idx < 0:
			if Preferences.ball_mode == "random":
				# Uno nuevo por partido de verdad — ni el último elegido a
				# mano (Preferences.last_ball) ni el determinista de
				# siempre por fixture, o "aleatorio" terminaría siendo
				# "siempre el mismo" (pedido explícito de Wilber).
				_ball_idx = randi() % BallDesign.count()
			else:
				_ball_idx = Preferences.last_ball if Preferences.last_ball >= 0 else BallDesign.default_for(
					"%s|%s" % [String(fx.get("home_club_id", "")), String(fx.get("away_club_id", ""))])
		_ball_idx = clampi(_ball_idx, 0, BallDesign.count() - 1)

	# La franja de arriba (escudo/bandera + camiseta + estrellas) reemplaza
	# a HomeStrengthLabel, pero el NOMBRE del equipo se muestra acá arriba
	# de cada lista de titulares/suplentes — sin esto, en la viñeta
	# Táctica las dos columnas no dicen de qué equipo es cada una (pedido
	# de Wilber: "arriba colocales el nombre del equipo").
	home_name_label.visible = true
	away_name_label.visible = true
	home_name_label.text = home.team_name
	away_name_label.text = away.team_name
	home_name_label.add_theme_font_override("font", Styles.font_semibold())
	away_name_label.add_theme_font_override("font", Styles.font_semibold())
	home_strength_label.visible = false
	away_strength_label.visible = false
	compare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var vbox := $Scroll/Margin/VBox as VBoxContainer
	_land_undo(vbox)

	# TeamsRow (listas de titulares/suplentes) es un nodo ESTÁTICO del
	# .tscn que un render anterior puede haber reubicado dentro de la
	# pestaña "Táctica" (PM_Tabs, dinámico) — hay que sacarlo de ahí ANTES
	# de limpiar los PM_* de abajo, o quedaría colgando de un nodo que se
	# va a borrar (crashearía el segundo _render()).
	if teams_row.get_parent() != vbox:
		teams_row.get_parent().remove_child(teams_row)
		vbox.add_child(teams_row)
		vbox.move_child(teams_row, start_button.get_index())

	# Limpia lo que hayamos insertado en un render previo. queue_free() es
	# DIFERIDO: hay que sacarlos del árbol YA o al re-agregar se duplican
	# (bug que reportó Wilber: cada toque de camiseta/balón apilaba otra copia).
	for n in vbox.get_children():
		if n.name.begins_with("PM_"):
			vbox.remove_child(n)
			n.queue_free()

	var comp_row := _competition_header(fx, world)
	if comp_row != null:
		comp_row.name = "PM_Comp"
		vbox.add_child(comp_row)
		vbox.move_child(comp_row, compare_label.get_index())

	var venue_row := _venue_row(fx, world)
	venue_row.name = "PM_Venue"
	vbox.add_child(venue_row)
	vbox.move_child(venue_row, compare_label.get_index())

	var starter_card := _starter_status_card(home, away)
	if starter_card != null:
		starter_card.name = "PM_Starter"
		vbox.add_child(starter_card)
		vbox.move_child(starter_card, venue_row.get_index() + 1)

	# MENSAJE DE CASA (10-oct): en partidos clave escribe la familia.
	var me: PlayerData = SaveManager.load_player()
	var kind: String = ImmersionEngine.key_match_kind(fx, me)
	if kind != "":
		var fam_card := _family_card(ImmersionEngine.family_message(kind, me), me)
		fam_card.name = "PM_Family"
		vbox.add_child(fam_card)
		vbox.move_child(fam_card, (starter_card.get_index() if starter_card != null else venue_row.get_index()) + 1)

	var tabs := _build_tab_switcher()
	tabs.name = "PM_Tabs"
	vbox.add_child(tabs)
	vbox.move_child(tabs, compare_label.get_index() + 1)

	# --- Viñeta "Uniformes y balón" ---
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation", 8)
	panels.alignment = BoxContainer.ALIGNMENT_CENTER
	panels.add_child(_team_panel("home", home, _home_club, _home_away_kit, fx))
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_override("font", Styles.font_black())
	vs.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panels.add_child(vs)
	panels.add_child(_team_panel("away", away, _away_club, _away_away_kit, fx))
	_tab_kits.add_child(panels)
	_tab_kits.add_child(_ball_selector())

	# --- Viñeta "Táctica" ---
	var user_home: bool
	if _is_national_fixture(fx):
		var pl: PlayerData = SaveManager.load_player()
		user_home = pl != null and String(fx.get("home_country", "")) == pl.country
	else:
		user_home = String(fx.get("home_club_id", "")) == WorldTickEngine.user_club_id
	var scout_card := _scout_card(fx, user_home)
	if scout_card != null:
		_tab_tactics.add_child(scout_card)

	# Guerra psicológica: frase del DT rival antes del partido.
	var mind := RivalMindGamesEngine.pre_match(WorldTickEngine, fx, SaveManager.load_player())
	if not mind.is_empty():
		_tab_tactics.add_child(_mindgames_card(mind))

	# RETO DEL DT (10-oct): lo que te pide el entrenador para este partido.
	var challenge: Dictionary = CoachChallengeEngine.for_fixture(me, fx)
	if not challenge.is_empty():
		var my_coach: CoachData = WorldFactory.find_coach(world, me.club_id) if not _is_national_fixture(fx) else null
		_tab_tactics.add_child(_challenge_card(challenge, my_coach))

	# RIVAL PERSONAL (10-oct): si enfrentás a su club, el duelo con historial.
	if not _is_national_fixture(fx) and me != null:
		var duel := _nemesis_card(fx, me, world)
		if duel != null:
			_tab_tactics.add_child(duel)

	# TeamsRow (titulares/suplentes) vive DENTRO de esta viñeta.
	if teams_row.get_parent() != _tab_tactics:
		teams_row.get_parent().remove_child(teams_row)
		_tab_tactics.add_child(teams_row)

	compare_label.text = _compare_text(_xi_strength(home), _xi_strength(away))

	_fill_lineup(home_lineup_box, home)
	_fill_lineup(away_lineup_box, away)
	_land_columns(vbox)

## Switcher simple de 2 viñetas (mismo criterio visual que el resto de la
## pantalla: botones estilo pill, sin usar el TabContainer de Godot).
func _build_tab_switcher() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_tab_btn_kits = _tab_button("👕 Uniformes y balón", 0)
	_tab_btn_tactics = _tab_button("📋 Táctica", 1)
	row.add_child(_tab_btn_kits)
	row.add_child(_tab_btn_tactics)
	wrap.add_child(row)

	_tab_kits = VBoxContainer.new()
	_tab_kits.add_theme_constant_override("separation", 12)
	_tab_tactics = VBoxContainer.new()
	_tab_tactics.add_theme_constant_override("separation", 12)
	_tab_tactics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(_tab_kits)
	wrap.add_child(_tab_tactics)

	_refresh_tab_visibility()
	return wrap

func _tab_button(text: String, idx: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		_active_tab = idx
		_refresh_tab_visibility())
	return b

func _refresh_tab_visibility() -> void:
	if _tab_kits == null:
		return
	_tab_kits.visible = _active_tab == 0
	_tab_tactics.visible = _active_tab == 1
	_style_tab_button(_tab_btn_kits, _active_tab == 0)
	_style_tab_button(_tab_btn_tactics, _active_tab == 1)

func _style_tab_button(b: Button, active: bool) -> void:
	if active:
		Styles.tab(b, true)
	else:
		Styles.tab(b, false)

# --- Panel de equipo ---

func _team_panel(side: String, team: MatchTeam, club: ClubData, away_kit: bool, fx: Dictionary) -> Control:
	var is_nat: bool = _is_national_fixture(fx)
	var country: String = team.team_name if is_nat else ""

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: Color
	if is_nat:
		col = CountryFlags.team_color(country)
	else:
		col = Color(club.primary_color_hex) if club != null and not club.primary_color_hex.is_empty() else Styles.BLUE
	panel.add_theme_stylebox_override("panel", Styles.card_accent(col))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 10)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.alignment = BoxContainer.ALIGNMENT_CENTER

	# insignia + nombre: BANDERA si es selección (pedido de Wilber: "no
	# necesitan escudos, con la bandera basta"), escudo si es club.
	if is_nat:
		var flag: Control = CountryFlags.flag_rect(country, 40)
		if flag != null:
			var ccf := CenterContainer.new()
			ccf.add_child(flag)
			v.add_child(ccf)
	elif club != null:
		var cc := CenterContainer.new()
		cc.add_child(Styles.club_crest(club.club_id, 40))
		v.add_child(cc)
	var nm := Label.new()
	nm.text = team.team_name
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_override("font", Styles.font_semibold())
	v.add_child(nm)

	# camiseta + selector Titular / Visitante — en selección, un "club" de
	# mentira (_country_kit_stub) le da color/patrón propio del país en
	# vez de que las 199 selecciones usen la misma camiseta genérica.
	var kit_club: ClubData = _country_kit_stub(country) if is_nat else club
	var kit_holder := CenterContainer.new()
	kit_holder.custom_minimum_size = Vector2(0, 66)
	_kit_slot[side] = kit_holder
	kit_holder.add_child(Kit.build_for_club_kit(kit_club, _season_year, away_kit, 60))
	v.add_child(kit_holder)

	var toggle := HBoxContainer.new()
	toggle.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle.add_theme_constant_override("separation", 4)
	var b_home := _mini_btn("Titular", not away_kit, func(): _set_kit(side, false))
	var b_away := _mini_btn("Visitante", away_kit, func(): _set_kit(side, true))
	toggle.add_child(b_home)
	toggle.add_child(b_away)
	v.add_child(toggle)

	# estrellas de nivel
	var xi := _xi_strength(team)
	var stars: int = clampi(int(round((xi - 42) / 9.6)), 0, 5)
	var sc := CenterContainer.new()
	sc.add_child(Styles.star_row(stars, 5, 14))
	v.add_child(sc)

	# ATA / MED / DEF
	var lines := _line_ratings(team)
	v.add_child(_stat_bar("ATA", lines[0]))
	v.add_child(_stat_bar("MED", lines[1]))
	v.add_child(_stat_bar("DEF", lines[2]))

	m.add_child(v)
	panel.add_child(m)
	return panel

func _mini_btn(text: String, active: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	if active:
		Styles.tab(b, true, true)
	else:
		Styles.tab(b, false, true)
	b.pressed.connect(cb)
	return b

func _set_kit(side: String, away: bool) -> void:
	if side == "home":
		_home_away_kit = away
	else:
		_away_away_kit = away
	_render()

func _line_ratings(team: MatchTeam) -> Array:
	var buckets := {"ST": [], "MF": [], "DF": [], "GK": []}
	for p in team.starting_xi:
		if buckets.has(p.position):
			buckets[p.position].append(p.overall)
	var avg := func(a: Array, fallback: int) -> int:
		if a.is_empty():
			return fallback
		var t := 0
		for x in a:
			t += x
		return int(round(float(t) / a.size()))
	var base := _xi_strength(team)
	var ata: int = avg.call(buckets["ST"], base)
	var med: int = avg.call(buckets["MF"], base)
	var def_line: Array = buckets["DF"] + buckets["GK"]
	var dfr: int = avg.call(def_line, base)
	return [ata, med, dfr]

func _stat_bar(label: String, value: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(34, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	row.add_child(l)
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(70, 8)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override("panel", Styles.card_flat(Color(1, 1, 1, 0.10), 4))
	var fill := ColorRect.new()
	var c: Color = Styles.GREEN if value >= 80 else (Styles.AMBER if value >= 65 else Styles.RED)
	fill.color = c
	fill.custom_minimum_size = Vector2(70.0 * clampf(value / 99.0, 0.05, 1.0), 8)
	track.add_child(fill)
	row.add_child(track)
	var n := Label.new()
	n.text = str(value)
	n.custom_minimum_size = Vector2(24, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.add_theme_font_size_override("font_size", 11)
	n.add_theme_color_override("font_color", c)
	row.add_child(n)
	return row

# --- Selector de balón ---

func _ball_selector() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := Label.new()
	head.text = "BALÓN DEL PARTIDO"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	box.add_child(head)

	# Toggle "aleatorio cada partido" (pedido explícito de Wilber) — tocar
	# un balón de la fila de abajo mientras está activado lo desactiva (si
	# elegiste uno a mano, es porque QUERÉS ese, no que siga al azar).
	var is_random: bool = Preferences.ball_mode == "random"
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(0, 34)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.text = "🎲 Aleatorio cada partido: %s" % ("Sí" if is_random else "No")
	Styles.styled_button(toggle, Styles.pill_filled(Styles.GOLD) if is_random else Styles.pill_outlined(Styles.GRAY_TEXT), Color.BLACK if is_random else Styles.GRAY_TEXT)
	toggle.pressed.connect(func():
		if Preferences.ball_mode == "random":
			Preferences.set_ball_mode("fixed")
			Preferences.set_last_ball(_ball_idx)
		else:
			Preferences.set_ball_mode("random")
			_ball_idx = randi() % BallDesign.count()
		_render())
	box.add_child(toggle)

	# Grilla de 8 por fila (9-oct, Wilber: "la pantalla de pre partido está
	# desajustada"): con 16 balones en UNA fila (~800 px) la fila era más
	# ancha que la pantalla y ensanchaba toda la pestaña → tarjetas de
	# equipos, pestañas y balones cortados a los costados.
	var row := GridContainer.new()
	row.columns = 8
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(BallDesign.count()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.focus_mode = Control.FOCUS_NONE
		var sel := i == _ball_idx
		var sb := Styles.card_flat(Color(1, 0.85, 0.3, 0.22) if sel else Color(1, 1, 1, 0.05), 8)
		sb.set_border_width_all(2)
		sb.border_color = Styles.GOLD if sel else Color(1, 1, 1, 0.10)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(BallDesign.build(i, 40))
		b.add_child(cc)
		var idx := i
		b.pressed.connect(func():
			_ball_idx = idx
			if Preferences.ball_mode == "random":
				Preferences.set_ball_mode("fixed")
			_render())
		row.add_child(b)
	box.add_child(row)
	var name_lbl := Label.new()
	name_lbl.text = BallDesign.name_of(_ball_idx)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", Styles.font_semibold())
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Styles.GOLD)
	box.add_child(name_lbl)
	return box

# --- Competición / clima ---

func _competition_header(fx: Dictionary, world: Dictionary) -> Control:
	var comp: String = String(fx.get("competition", "league"))
	var logo: Control = null
	var text: String = ""
	if _is_national_fixture(fx):
		match comp:
			"world_cup": text = "Mundial"
			"national_cup": text = "Copa continental"
			_: text = "Eliminatoria"
		var pl: PlayerData = SaveManager.load_player()
		var player_country: String = pl.country if pl != null else ""
		var user_home: bool = String(fx.get("home_country", "")) == player_country
		var opponent: String = String(fx.get("away_country", "")) if user_home else String(fx.get("home_country", ""))
		logo = CountryFlags.flag_rect(opponent, 26)
		return _competition_header_row(text, logo, fx)
	var user_club := WorldFactory.find_club(world, WorldTickEngine.user_club_id)
	var league: LeagueData = null
	if user_club != null:
		for lg in world.get("leagues", []):
			if lg.league_id == user_club.league_id:
				league = lg
				break
	match comp:
		"cup":
			var country: String = league.country if league != null else ""
			logo = Competition.domestic_cup_node(country, 26) if country != "" else null
			text = "%s — %s" % [CompetitionNames.domestic_cup(country), fx.get("round_name", "")] if country != "" else String(fx.get("round_name", "Copa"))
		"friendly":
			text = "Amistoso — pretemporada"
		"supercup":
			# Bug real de la auditoría: caía al caso por defecto y mostraba
			# el nombre/escudo de la liga doméstica en vez de la Supercopa.
			text = String(fx.get("name", "Supercopa"))
			logo = Competition.league_node(league.league_id, 26) if league != null else null
		"continental":
			# Mismo bug: la copa continental de CLUB mostraba la liga
			# doméstica en vez de su propio nombre/escudo de confederación.
			var conf: String = String(fx.get("cont_conf", ""))
			var tier: int = int(fx.get("cont_tier", 1))
			text = "%s — %s" % [Confederations.tier_name(conf, tier), fx.get("round_name", "")] if conf != "" and fx.has("round_name") else Confederations.tier_name(conf, tier)
			logo = Competition.continental_node(conf, tier, 26) if conf != "" else null
		_:
			if league != null:
				logo = Competition.league_node(league.league_id, 26)
				text = league.league_name
			else:
				text = "Liga"
			if int(fx.get("matchday", 0)) > 0:
				text += " — Jornada %d" % int(fx["matchday"])
	return _competition_header_row(text, logo, fx)

## Cabecera de la competición (9-oct, Wilber: "que muestre el nombre de la
## competición que se va a jugar o si es amistoso"): es el TITULAR de la
## pantalla — logo grande + nombre en negrita (y la ronda/jornada debajo);
## el clima va en una línea chica aparte.
func _competition_header_row(text: String, logo: Control, fx: Dictionary) -> Control:
	if text == "":
		return null
	if has_node("Scroll/Margin/VBox/TitleLabel"):
		$Scroll/Margin/VBox/TitleLabel.visible = false
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	if logo != null:
		logo.custom_minimum_size = Vector2(44, 44)
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(logo)
	var parts: PackedStringArray = text.split(" — ", false, 1)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := Label.new()
	lbl.text = parts[0].to_upper()
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Styles.GOLD if String(fx.get("competition", "")) != "friendly" else Color(0.75, 0.9, 1.0))
	tcol.add_child(lbl)
	if parts.size() > 1:
		var sub := Label.new()
		sub.text = parts[1]
		sub.add_theme_font_override("font", Styles.font_semibold())
		sub.add_theme_font_size_override("font_size", 14)
		sub.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
		tcol.add_child(sub)
	row.add_child(tcol)
	outer.add_child(row)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 6)
	outer.add_child(row2)
	row = row2

	var wx: String = MatchIcons.weather_for(fx, SaveManager.load_world_seed())
	row.add_child(MatchIcons.weather(wx, 18, Styles.GRAY_TEXT))
	var wxl := Label.new()
	wxl.text = MatchIcons.weather_label(wx)
	wxl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	wxl.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	row.add_child(wxl)
	return outer

## Estadio · público · árbitro · (DERBI si aplica). Todo determinista, sabor.
func _venue_row(fx: Dictionary, world: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var ws: int = SaveManager.load_world_seed()
	var is_derby: bool = false
	if _home_club != null:
		var rival: String = RivalryEngine.club_rival_for(world, _home_club.club_id, ws)
		is_derby = rival != "" and rival == String(fx.get("away_club_id", ""))
	if is_derby:
		# CLÁSICO (P5): cartel con el emblema + qué cambia.
		var em := Icons.make_rect("res://assets/ui/derby.png", 56)
		em.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var dh := UiKit.hero(Styles.RED, em, "¡CLÁSICO!", "Más presión (con temple alto te agranda) y más premio: XP ×1.5 y prima si ganás.", [])
		box.add_child(dh)
		dh.ready.connect(func(): Juice.pulse(dh, 1.02, 1.6))
	var att: int = Venue.attendance(_home_club, _away_club, is_derby, "%s|%d" % [String(fx.get("home_club_id", "")), int(fx.get("epoch_day", 0))], ws)
	var info := Label.new()
	info.text = "🏟 %s  ·  %s espectadores  ·  Árbitro: %s" % [
		Venue.stadium_name(_home_club), _thousands(att), "%s (%s)" % [Venue.referee(fx, ws), String(DecisionResolver.referee_profile(Venue.referee(fx, ws))["label"]).to_lower()],
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	info.add_theme_font_size_override("font_size", 11)
	box.add_child(info)
	return box

## Aviso destacado ANTES del partido: titular o banco (pedido de Wilber,
## "poder darme cuenta antes del partido si soy titular o suplente"). La
## decisión ya está tomada acá (MatchTeam._build_lineup corrió dentro de
## MatchLauncher.prepare(), antes de llegar a esta pantalla) — solo la
## mostramos, no se vuelve a tirar el dado.
func _starter_status_card(home: MatchTeam, away: MatchTeam) -> Control:
	var user: PlayerData = MatchState.user_player
	if user == null:
		return null
	var team: MatchTeam
	if home.starting_xi.has(user) or home.bench.has(user):
		team = home
	elif away.starting_xi.has(user) or away.bench.has(user):
		team = away
	else:
		return null
	var is_starter: bool = team.starting_xi.has(user)
	var col: Color = Styles.GREEN if is_starter else Styles.AMBER
	if team.user_not_called:
		col = Styles.RED

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(col))
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 10)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var icon := Label.new()
	icon.text = "✅" if is_starter else ("⛔" if team.user_not_called else "🪑")
	icon.add_theme_font_size_override("font_size", 18)
	h.add_child(icon)
	var lbl := Label.new()
	if is_starter:
		lbl.text = "SOS TITULAR (%s)" % team.deployed_code(user)
	elif team.user_not_called:
		lbl.text = "NO CONVOCADO · el DT no cuenta con vos hoy"
	else:
		lbl.text = "EMPEZÁS EN EL BANCO"
	lbl.add_theme_font_override("font", Styles.font_black())
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", col)
	h.add_child(lbl)
	m.add_child(h)
	panel.add_child(m)
	return panel

## Frase del DT rival antes del partido (RivalMindGamesEngine, derivada).
func _mindgames_card(mind: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.PURPLE))
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = "🎙 EL TÉCNICO RIVAL — %s" % String(mind.get("coach_name", ""))
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", Styles.PURPLE)
	v.add_child(t)
	var q := Label.new()
	q.text = "\"%s\"" % String(mind.get("quote", ""))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(q)
	m.add_child(v)
	panel.add_child(m)
	return panel

## Reto del DT para este partido (CoachChallengeEngine).
func _challenge_card(ch: Dictionary, coach: CoachData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if coach != null:
		var frame: Control = Styles.portrait_frame(Avatar.build(Avatar.config_for_npc(coach.coach_name, "coach", SaveManager.load_world_seed()), 46), 46, Styles.GOLD)
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(frame)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = "🎯 RETO DEL DT"
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", Styles.GOLD)
	v.add_child(t)
	var q := Label.new()
	q.text = "«%s»" % String(ch.get("text", ""))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(q)
	var r := Label.new()
	r.text = "Si lo cumplís: +%d confianza del DT y +%d XP de carrera." % [CoachChallengeEngine.REWARD_TRUST, CoachChallengeEngine.REWARD_XP]
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("font_size", 10)
	r.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(r)
	row.add_child(v)
	m.add_child(row)
	panel.add_child(m)
	return panel

## Mensaje de la familia antes de un partido clave.
func _family_card(msg: Dictionary, me: PlayerData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Color("#ff8fb1")))
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var seed_i: int = SaveManager.load_world_seed()
	var pcfg: Dictionary = Avatar.config_for_player(me, seed_i)
	var from: String = String(msg.get("from", "Mamá"))
	var face_cfg: Dictionary
	if from == "Mamá":
		face_cfg = ImmersionEngine.parent_config(pcfg, "mother", me.player_name, seed_i)
	elif from == "Papá":
		face_cfg = ImmersionEngine.parent_config(pcfg, "father", me.player_name, seed_i)
	else:
		face_cfg = Avatar.config_for_npc(from, "partner", seed_i)
	var frame: Control = Styles.portrait_frame(Avatar.build(face_cfg, 50), 50, Color("#ff8fb1"))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = "💬 MENSAJE DE CASA — %s" % from
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", Color("#ff8fb1"))
	v.add_child(t)
	var q := Label.new()
	q.text = String(msg.get("text", ""))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(q)
	var hint := Label.new()
	hint.text = "Tu familia va a estar en la tribuna."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(hint)
	row.add_child(v)
	m.add_child(row)
	panel.add_child(m)
	return panel

## DUELO PERSONAL: tu rival (del club del clásico) con su historial contra
## vos esta temporada. null si este partido no es contra su club.
func _nemesis_card(fx: Dictionary, me: PlayerData, world: Dictionary) -> Control:
	var seed_i: int = SaveManager.load_world_seed()
	var nem_club: String = ImmersionEngine.nemesis_club_id(world, me.club_id, seed_i)
	if nem_club == "" or not (nem_club == String(fx.get("home_club_id", "")) or nem_club == String(fx.get("away_club_id", ""))):
		return null
	var squad: Array = WorldFactory.make_squad_with_transfers(world, nem_club, WorldTickEngine.world_seed, int(WorldTickEngine.season.get("season_start_epoch_day", 0)))
	var nem: Dictionary = ImmersionEngine.pick_nemesis(squad, me.position)
	if nem.is_empty():
		return null
	var rec: Dictionary = ImmersionEngine.nemesis_record(me.nemesis_log)
	var you: String = Nickname.press_name(me, seed_i)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.RED))
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var t := Label.new()
	t.text = "⚔ DUELO PERSONAL"
	t.add_theme_font_override("font", Styles.font_black())
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", Styles.RED)
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(Styles.portrait_frame(Avatar.build(Avatar.with_expression(Avatar.config_for_npc(String(nem["name"]), "player", seed_i), "enojado"), 54), 54, Styles.RED))
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 1)
	var n := Label.new()
	n.text = String(nem["name"])
	n.add_theme_font_override("font", Styles.font_black())
	c.add_child(n)
	var club: ClubData = WorldFactory.find_club(world, nem_club)
	var sub := Label.new()
	sub.text = "%s · %s · OVR %d" % [String(nem["detailed"]), club.short_name if club != null else "", int(nem["overall"])]
	sub.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	c.add_child(sub)
	var h2h := Label.new()
	if int(rec["played"]) == 0:
		h2h.text = "Primer cruce entre ustedes."
	else:
		h2h.text = "Historial: %dG %dE %dP · tus goles: %d" % [int(rec["won"]), int(rec["draw"]), int(rec["lost"]), int(rec["your_goals"])]
	h2h.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	h2h.add_theme_color_override("font_color", Styles.GOLD)
	c.add_child(h2h)
	row.add_child(c)
	v.add_child(row)
	var q := Label.new()
	q.text = "\"%s\"" % ImmersionEngine.nemesis_pre_line(String(nem["name"]), you, rec, "%s|%d" % [me.player_name, int(fx.get("epoch_day", 0))])
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(q)
	m.add_child(v)
	panel.add_child(m)
	return panel

## Informe de ojeadores del rival (ScoutingEngine — derivado del mundo
## vivo, no persiste). Hombre a vigilar, forma reciente, posición en su
## liga y nota táctica según el DT rival.
func _scout_card(fx: Dictionary, user_home: bool) -> Control:
	var rep: Dictionary = ScoutingEngine.report(WorldTickEngine, fx, user_home)
	if rep.is_empty():
		return null

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.BLUE))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "🔍 INFORME DE OJEADORES"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", Styles.font_black())
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Styles.BLUE)
	head.add_child(title)
	var threat := Label.new()
	threat.text = String(rep.get("threat", ""))
	threat.add_theme_font_override("font", Styles.font_semibold())
	threat.add_theme_font_size_override("font_size", 11)
	threat.add_theme_color_override("font_color", Styles.AMBER)
	head.add_child(threat)
	v.add_child(head)

	# Hombre a vigilar.
	var danger := HBoxContainer.new()
	danger.add_theme_constant_override("separation", 6)
	var dc: String = String(rep.get("danger_country", ""))
	if dc != "":
		var fr := CountryFlags.flag_rect(dc, 16)
		fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		danger.add_child(fr)
	var dlbl := Label.new()
	dlbl.text = "A vigilar: %s  ·  %s  ·  OVR %d" % [
		String(rep.get("danger_name", "?")), String(rep.get("danger_pos", "")), int(rep.get("danger_ovr", 0)),
	]
	dlbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	danger.add_child(dlbl)
	v.add_child(danger)

	# La profundidad del informe depende de la red de tu agente: con
	# agente flojo (≤1★) solo te llega el hombre a vigilar y la amenaza.
	var _pm_player := SaveManager.load_player()
	var agent_stars: int = _pm_player.agent_stars if _pm_player != null else 3
	if agent_stars >= 2:
		# Forma + posición.
		var line2 := Label.new()
		var pos_txt: String = "%dº en su liga" % int(rep.get("position", 0)) if int(rep.get("position", 0)) > 0 else "sin datos de liga"
		line2.text = "Forma: %s    ·    %s" % [String(rep.get("form", "")), pos_txt]
		line2.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		line2.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(line2)

		# Nota táctica.
		var tac := Label.new()
		tac.text = String(rep.get("tactic", ""))
		tac.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tac.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(tac)
	else:
		var poor := Label.new()
		poor.text = "Tu agente no tiene más datos de este rival. Un mejor representante trae informes más completos."
		poor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		poor.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		poor.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(poor)

	var src := Label.new()
	src.text = "Informe cortesía de tu agente  %s" % ("★".repeat(agent_stars) + "☆".repeat(5 - agent_stars))
	src.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	src.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	v.add_child(src)

	m.add_child(v)
	panel.add_child(m)
	return panel

func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out

func _xi_strength(team: MatchTeam) -> int:
	if team.starting_xi.is_empty():
		return 0
	var total: int = 0
	for p in team.starting_xi:
		total += p.overall
	return int(round(float(total) / team.starting_xi.size()))

func _compare_text(home_strength: int, away_strength: int) -> String:
	var diff: int = home_strength - away_strength
	if absi(diff) <= 2:
		return "Equipos muy parejos."
	if diff > 0:
		return "El local parte como favorito (+%d)." % diff
	return "El visitante parte como favorito (+%d)." % -diff

func _fill_lineup(box: VBoxContainer, team: MatchTeam) -> void:
	for child in box.get_children():
		child.queue_free()
	var user: PlayerData = MatchState.user_player

	var starters_head := Label.new()
	starters_head.text = "TITULARES"
	starters_head.add_theme_font_size_override("font_size", 11)
	starters_head.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	box.add_child(starters_head)
	for p in team.starting_xi:
		box.add_child(_lineup_row(p, team, user))

	# Suplentes — antes solo se mostraba "En el banco: TÚ" si el usuario
	# estaba ahí, el resto del banco no aparecía en NINGÚN lado (pedido de
	# Wilber: "estás mostrando la titular pero no la suplencia").
	if not team.bench.is_empty():
		var bench_head := Label.new()
		bench_head.text = "SUPLENTES"
		bench_head.add_theme_font_size_override("font_size", 11)
		bench_head.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		box.add_child(bench_head)
		for p in team.bench:
			if p == user and team.user_not_called:
				continue
			box.add_child(_lineup_row(p, team, user))

func _lineup_row(p: PlayerData, team: MatchTeam, user: PlayerData) -> Label:
	var lbl := Label.new()
	var mark: String = "  ★ TÚ" if p == user else ""
	# Puesto en el que lo alinea el DT (puede no ser su posición de
	# oficio); si difiere, se marca con un asterisco. Un suplente no tiene
	# puesto desplegado (deployed_code cae a su posición de oficio) — ahí
	# nunca se marca con "*", no hay "fuera de puesto" posible en el banco.
	var slot: String = team.deployed_code(p)
	var oop: String = "*" if team.starting_xi.has(p) and slot != p.detailed_position else ""
	lbl.text = "%s%s  %s (%d)%s" % [slot, oop, p.player_name, p.overall, mark]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if p == user:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	elif not team.starting_xi.has(p):
		lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	return lbl

func _on_start_match_pressed() -> void:
	MatchState.kit_home_away = _home_away_kit
	MatchState.kit_away_away = _away_away_kit
	MatchState.ball_design = _ball_idx
	# Solo en modo fijo: en "random" no queremos que el sorteo de ESTE
	# partido quede como el "último elegido" para cuando se vuelva a modo
	# fijo (eso sería un pick al azar disfrazado de elección a mano).
	if Preferences.ball_mode != "random":
		Preferences.set_last_ball(_ball_idx)
	# Si el partido 3D no está disponible o está desactivado, usa el clásico.
	if Match3DBridge.supported():
		get_tree().change_scene_to_file("res://scenes/Match3D/Match3D.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/Match/Match.tscn")


## HORIZONTAL (FootballLegacy H): todo scrollea (nada se corta), las
## alineaciones tienen altura para verse, y "Empezar partido" flota abajo
## a la derecha, siempre a mano.
func _landscape_tweaks() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return
	($Scroll/Margin as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiScroll.make_touch($Scroll)
	teams_row.custom_minimum_size.y = 300
	# Barra de fondo arriba: el contenido que scrollea pasa POR DEBAJO de
	# Volver/Simular/Jugar sin mezclarse con ellos.
	var band := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.045, 0.047, 0.055, 0.96)
	bsb.border_width_bottom = 1
	bsb.border_color = Color(1, 1, 1, 0.08)
	band.add_theme_stylebox_override("panel", bsb)
	band.anchor_right = 1.0
	band.offset_bottom = 64
	band.z_index = 99
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var mrg := $Scroll/Margin as MarginContainer
	mrg.add_theme_constant_override("margin_top", maxi(mrg.get_theme_constant("margin_top"), 72))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	# Arriba a la derecha, a la altura del botón de volver.
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.offset_left = -372
	row.offset_top = 12
	row.offset_right = -12
	row.offset_bottom = 52
	row.z_index = 100
	add_child(row)
	var sim := Button.new()
	sim.text = "Simular"
	Styles.styled_button(sim, Styles.pill_filled(Color(0.22, 0.24, 0.3)), Color.WHITE)
	sim.custom_minimum_size = Vector2(130, 40)
	sim.pressed.connect(_on_simulate_pressed.bind(sim))
	row.add_child(sim)
	var fb := Button.new()
	fb.text = "Jugar"
	fb.icon = start_button.icon
	fb.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(fb, Styles.pill_filled(Styles.GOLD), Color.BLACK)
	fb.custom_minimum_size = Vector2(210, 40)
	fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fb.pressed.connect(_on_start_match_pressed)
	row.add_child(fb)
	start_button.visible = false


## "Simular" (como en WSC): el mismo MatchEngine resuelve el partido al
## instante, sin jugar los momentos, y va directo al resumen.
func _on_simulate_pressed(btn: Button) -> void:
	if MatchState.engine == null:
		return
	btn.disabled = true
	MatchState.kit_home_away = _home_away_kit
	MatchState.kit_away_away = _away_away_kit
	MatchState.ball_design = _ball_idx
	MatchState.engine.instant_mode = true
	MatchState.apply_tie_aggregate()
	var result: Dictionary = await MatchState.engine.run_match()
	MatchState.match_result = result
	var national: bool = MatchState.fixture.has("home_country") or MatchState.fixture.has("opponent")
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/NationalMatchSummary/NationalMatchSummary.tscn" if national else "res://scenes/MatchSummary/MatchSummary.tscn")


## HORIZONTAL: dos columnas. Izquierda: competición, estadio, titularidad,
## favorito y las pestañas (uniformes / táctica). Derecha: las dos
## alineaciones, siempre a la vista. Se rehace en cada _render() (tocar
## camiseta o balón vuelve a dibujar todo).
func _land_columns(vbox: VBoxContainer) -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y:
		return
	var cols := HBoxContainer.new()
	cols.name = "LandCols"
	cols.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.name = "LandLeft"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", vbox.get_theme_constant("separation"))
	var right := VBoxContainer.new()
	right.name = "LandRight"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.9
	cols.add_child(left)
	cols.add_child(right)
	var kids: Array = []
	for k in vbox.get_children():
		if k != start_button:
			kids.append(k)
	vbox.add_child(cols)
	vbox.move_child(cols, 0)
	for k in kids:
		(k as Node).reparent(left)
	teams_row.reparent(right)
	teams_row.visible = false   # en horizontal: mini cancha en su lugar
	var me: PlayerData = MatchState.user_player
	var home: MatchTeam = MatchState.home_team
	var away: MatchTeam = MatchState.away_team
	var mine_home: bool = home.starting_xi.has(me) or home.bench.has(me)
	if _land_side == "":
		_land_side = "home" if mine_home else "away"
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 6)
	right.add_child(sw)
	for key in ["home", "away"]:
		var t: MatchTeam = home if key == "home" else away
		var b := Button.new()
		b.text = t.team_name + ("  ★" if (key == "home") == mine_home else "")
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 36
		b.focus_mode = Control.FOCUS_NONE
		Styles.tab(b, key == _land_side)
		b.pressed.connect(func():
			_land_side = key
			_render())
		sw.add_child(b)
	var team: MatchTeam = home if _land_side == "home" else away
	var club: ClubData = _home_club if _land_side == "home" else _away_club
	var col: Color = Color(club.primary_color_hex) if club != null and club.primary_color_hex != "" else (Styles.BLUE if _land_side == "home" else Styles.RED)
	right.add_child(_land_pitch(team, col, me))

func _land_undo(vbox: VBoxContainer) -> void:
	var cols := vbox.get_node_or_null("LandCols")
	if cols == null:
		return
	var idx: int = cols.get_index()
	var left: Node = cols.get_node("LandLeft")
	for k in left.get_children():
		k.reparent(vbox)
		vbox.move_child(k, idx)
		idx += 1
	if teams_row.get_parent() != vbox:
		teams_row.reparent(vbox)
	vbox.remove_child(cols)
	cols.queue_free()


# ---------------------------------------------------------------- mini cancha
var _land_side: String = ""
const _LAND_ROWS := {"ST": 0.16, "MF": 0.44, "DF": 0.70, "GK": 0.90}

## El once en una mini cancha (como Plantilla): jugador, media y apellido.
func _land_pitch(team: MatchTeam, kit: Color, me: PlayerData) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 400)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bg := MiniPitch.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var by_line: Dictionary = {"GK": [], "DF": [], "MF": [], "ST": []}
	for p in team.starting_xi:
		by_line[Positions.broad_of(team.deployed_code(p))].append(p)
	var seed_w: int = SaveManager.load_world_seed()
	for line in ["GK", "DF", "MF", "ST"]:
		var arr: Array = by_line[line]
		for i in arr.size():
			var p: PlayerData = arr[i]
			var x: float = float(i + 1) / float(arr.size() + 1)
			holder.add_child(_land_token(p, team.deployed_code(p), kit, p == me, x, _LAND_ROWS[line], seed_w))
	return holder

func _land_token(p: PlayerData, code: String, kit: Color, mine: bool, x: float, y: float, seed_w: int) -> Control:
	var w := Control.new()
	w.anchor_left = x
	w.anchor_right = x
	w.anchor_top = y
	w.anchor_bottom = y
	w.offset_left = -45
	w.offset_right = 45
	w.offset_top = -42
	w.offset_bottom = 34
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cfg: Dictionary = Avatar.config_for_player(p, seed_w).duplicate()
	var keeper: bool = code == "POR" or p.position == "GK"
	var shirt: Color = Color("#2bbf6a") if keeper else kit
	cfg["tint_clothing"] = shirt.to_html(false)
	cfg["tint_shorts"] = "#1f2026" if shirt.get_luminance() > 0.42 else "#e9e9ec"
	cfg.erase("tint_socks")
	var spr := TextureRect.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.position = Vector2(8, -14)
	spr.size = Vector2(74, 74)
	if not Avatar.fill_3d(spr, cfg, 74):
		var frames: Array = Avatar.anim_frames(cfg, "gk_idle_south" if keeper else "pitch_idle_south")
		if not frames.is_empty():
			spr.texture = frames[0]
	w.add_child(spr)
	var ovr := Label.new()
	ovr.text = str(p.overall)
	ovr.position = Vector2(64, -4)
	ovr.add_theme_font_override("font", Styles.font_black())
	ovr.add_theme_font_size_override("font_size", 12)
	ovr.add_theme_color_override("font_outline_color", Color.BLACK)
	ovr.add_theme_constant_override("outline_size", 4)
	w.add_child(ovr)
	var nm := Label.new()
	var parts: PackedStringArray = p.player_name.split(" ", false)
	nm.text = ("TÚ" if mine else (parts[parts.size() - 1] if parts.size() > 0 else p.player_name))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(-10, 52)
	nm.size = Vector2(110, 18)
	nm.clip_text = true
	nm.add_theme_font_override("font", Styles.font_semibold())
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", Styles.GOLD if mine else Color.WHITE)
	nm.add_theme_color_override("font_outline_color", Color.BLACK)
	nm.add_theme_constant_override("outline_size", 4)
	w.add_child(nm)
	return w
