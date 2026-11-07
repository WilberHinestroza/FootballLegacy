extends Control
## PRÁCTICA (8-nov): práctica libre, por faceta del juego o titulares contra
## suplentes, en el partido 3D y en el estadio de tu club. No avanza el día ni
## cuenta para tus estadísticas. Retos de la semana: cumplirlos da XP de carrera,
## como mucho MAX_CLAIMS_PER_WEEK por semana (la regla vive en PracticeEngine).
## Se entra desde Entrenamiento.

const MATCH_SCENE := "res://scenes/Practice/PracticeMatch.tscn"
const BACK_SCENE := "res://scenes/Training/Training.tscn"

@onready var vbox: VBoxContainer = $Margin/Scroll/VBox

var _player: PlayerData


func _ready() -> void:
	WorldTickEngine.load_runtime()
	UiScroll.make_touch($Margin/Scroll)
	_player = SaveManager.load_player()
	if _player == null:
		return
	_build()


func _build() -> void:
	var is_gk: bool = _player.position == "GK"
	var st: Dictionary = PracticeEngine.state(WorldTickEngine.season, WorldTickEngine.current_epoch_day,
			SaveManager.load_world_seed(), is_gk)
	var face := Styles.portrait_frame(Avatar.for_player(_player, SaveManager.load_world_seed(), 72), 72, Styles.BLUE)
	vbox.add_child(UiKit.hero(Styles.BLUE, face, "Práctica",
			"Entrena jugadas en el partido 3D, en tu estadio. No pasa el día ni cuenta para tus estadísticas.",
			[["Retos cobrados: %d/%d esta semana" % [int(st.claims), PracticeEngine.MAX_CLAIMS_PER_WEEK], Styles.GOLD]]))
	_build_last_result()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	vbox.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	var injured: bool = _player.injury_days_remaining > 0
	if injured:
		var l := _text("Estás lesionado: no puedes practicar hasta recuperarte.", 15, Styles.RED)
		left.add_child(l)
	# --- Modos
	left.add_child(Styles.section_label("Modos"))
	left.add_child(_mode_button("Práctica libre", "%d jugadas de las tuyas, como en un partido" % PracticeEngine.SESSION_MOMENTS,
			Styles.GREEN, "free", "", injured))
	left.add_child(_mode_button("Titulares vs Suplentes", "Partido completo contra el banco, con peto",
			Styles.AMBER, "scrim", "", injured))
	left.add_child(Styles.section_label("Por faceta"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	left.add_child(grid)
	for k: String in PracticeEngine.facets_for(is_gk):
		var f: Dictionary = PracticeEngine.FACETS[k]
		grid.add_child(_mode_button(String(f.label), String(f.desc), Styles.BLUE, "facet", k, injured))
	# --- Retos
	right.add_child(Styles.section_label("Retos de la semana"))
	var left_claims := PracticeEngine.claims_left(st)
	right.add_child(_text("Cada reto se cumple en una sola sesión. Puedes cobrar %d por semana (te quedan %d)." % [
			PracticeEngine.MAX_CLAIMS_PER_WEEK, left_claims], 13, Styles.GRAY_TEXT))
	for c: Dictionary in st.list:
		right.add_child(_challenge_card(c, left_claims > 0))
	var back := Button.new()
	back.text = "Volver a Entrenamiento"
	back.custom_minimum_size = Vector2(0, 48)
	back.focus_mode = Control.FOCUS_NONE
	back.icon = Icons.load_icon(Icons.BACK)
	back.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(BACK_SCENE))
	vbox.add_child(back)


## Lo que salió de la última sesión (y los retos que se cumplieron).
func _build_last_result() -> void:
	var r: Dictionary = MatchState.practice_result
	if r.is_empty():
		return
	MatchState.practice_result = {}
	var s: Dictionary = r.get("summary", {})
	var rw: Dictionary = r.get("rewards", {})
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(_pad(col))
	var head := "Sesión terminada"
	if String(s.get("mode", "")) == "scrim":
		head = "Titulares %d - %d Suplentes" % [int(s.us), int(s.them)]
	col.add_child(_text(head, 18, Color.WHITE))
	var line := "Jugadas logradas %d de %d" % [int(s.ok), int(s.moments)]
	if int(s.goals) > 0:
		line += " · %d gol%s" % [int(s.goals), "" if int(s.goals) == 1 else "es"]
	if int(s.assists) > 0:
		line += " · %d asistencia%s" % [int(s.assists), "" if int(s.assists) == 1 else "s"]
	if int(s.saves) > 0:
		line += " · %d parada%s" % [int(s.saves), "" if int(s.saves) == 1 else "s"]
	col.add_child(_text(line, 14, Styles.GRAY_TEXT))
	for d in rw.get("completed", []):
		col.add_child(_text("✔ Reto cumplido: %s" % String(d), 14, Styles.GREEN))
	if int(rw.get("xp", 0)) > 0:
		var xp_line := "+%d XP de carrera" % int(rw.xp)
		if int(rw.get("levels", 0)) > 0:
			xp_line += " · ¡subiste de nivel!"
		col.add_child(_text(xp_line, 15, Styles.GOLD))
	for d in rw.get("locked", []):
		col.add_child(_text("Cumpliste \"%s\", pero ya cobraste los %d retos de esta semana." % [String(d), PracticeEngine.MAX_CLAIMS_PER_WEEK], 13, Styles.GRAY_TEXT))
	vbox.add_child(card)


func _mode_button(title: String, desc: String, color: Color, mode: String, facet: String, disabled: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.text = "%s\n%s" % [title, desc]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = disabled
	Styles.styled_button(b, Styles.pill_outlined(color), Color.WHITE)
	b.pressed.connect(func() -> void: _launch(mode, facet))
	return b


func _challenge_card(c: Dictionary, can_claim: bool) -> PanelContainer:
	var done := bool(c.get("done", false))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GREEN if done else Styles.BLUE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(_pad(row))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_text(String(c.desc), 15, Color.WHITE))
	var status := "Cumplido" if done else ("Mejor intento: %d/%d" % [int(c.progress), int(c.target)])
	if not done and not can_claim:
		status += " · sin cobros esta semana"
	col.add_child(_text(status, 13, Styles.GREEN if done else Styles.GRAY_TEXT))
	row.add_child(UiKit.chip("+%d XP" % int(c.xp), Styles.GOLD if not done else Styles.GREEN))
	return card


func _pad(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 8)
	m.add_child(c)
	return m


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _launch(mode: String, facet: String) -> void:
	MatchState.practice = {"mode": mode, "facet": facet}
	MatchState.practice_result = {}
	get_tree().change_scene_to_file(MATCH_SCENE)
