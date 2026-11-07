extends Node
## Partido 3D (MiniSoccer3D en res://match3d/) dentro de la carrera.
## En la versión vertical gira la pantalla a horizontal (en FootballLegacy H,
## que ya es horizontal, no gira nada), monta el partido con los planteles reales
## (Match3DBridge) y encima tu ficha con la cara de tu avatar: aparece en cada
## jugada tuya con la nota en vivo. Al pitido final vuelve a vertical y sigue
## al resumen de siempre (MatchSummary) con el resultado en MatchState.

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")
const MvpCeremonyScript = preload("res://match3d/scripts/mvp_ceremony.gd")
const MATCH_SCENE := "res://match3d/main.tscn"
const LANDSCAPE := Vector2i(1280, 720)   # base de la interfaz del partido 3D

var _cfg: Dictionary = {}
var _match: SoccerMatch
var _saved_scale := Vector2i.ZERO
var _saved_window := Vector2i.ZERO
var _saved_emulate := false
var _rotated := false   # solo si el juego es vertical
var _card: PanelContainer
var _card_title: Label
var _card_rating: Label
var _card_tween: Tween
var _sub_card_reset: Tween
var _done := false
var _final_result: Dictionary = {} # M3DBridge tiene componentes aleatorios: calcular una vez
var _mvp_ceremony: Node3D

func _ready() -> void:
	Audio.music_stop()
	Audio.crowd_stop()
	_go_landscape()
	_cfg = Match3DBridge.build_config(_on_finished)
	SoccerMatch.config = _cfg
	_match = (load(MATCH_SCENE) as PackedScene).instantiate()
	add_child(_match)
	_match.moment_started.connect(_on_moment_started)
	_match.moment_ended.connect(_on_moment_ended)
	_match.subbed_in.connect(_on_subbed_in)
	_match.outro_finished.connect(_on_outro_finished)
	if bool(_cfg.get("has_tie_carry", false)):
		_match._hud.set_aggregate(int(_cfg.get("carry_us", 0)), int(_cfg.get("carry_them", 0)))
	_build_card()
	if float(_cfg.get("bench_until", 0.0)) > 0.0:
		_show_card("En el banco · calentando", 4.0)

func _exit_tree() -> void:
	SoccerMatch.config = {}
	Engine.time_scale = 1.0
	_go_portrait()

# ---------------------------------------------------------------- pantalla
func _go_landscape() -> void:
	var root := get_tree().root
	_saved_scale = root.content_scale_size
	_saved_emulate = Input.emulate_touch_from_mouse
	root.content_scale_size = LANDSCAPE
	Input.emulate_touch_from_mouse = true   # en PC el ratón hace de dedo (gestos)
	# En el móvil el MSAA 2x encarece mucho el relleno; la resolución 3D adaptativa
	# ya suaviza los bordes sin ese coste. En PC se mantiene el 2x.
	root.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("mobile") else Viewport.MSAA_2X
	_rotated = _saved_scale.y > _saved_scale.x
	if not _rotated:
		return
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	elif DisplayServer.get_name() != "headless":
		_saved_window = DisplayServer.window_get_size()
		DisplayServer.window_set_size(Vector2i(_saved_window.y, _saved_window.x))

func _go_portrait() -> void:
	if _saved_scale == Vector2i.ZERO:
		return
	var root := get_tree().root
	root.content_scale_size = _saved_scale
	root.msaa_3d = Viewport.MSAA_DISABLED
	Input.emulate_touch_from_mouse = _saved_emulate
	if _rotated and OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	elif _rotated and _saved_window != Vector2i.ZERO:
		DisplayServer.window_set_size(_saved_window)
	_saved_scale = Vector2i.ZERO

# ---------------------------------------------------------------- tu ficha
## Recuadro con tu cara (el retrato pixel art de tu avatar), nombre y nota.
func _build_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = Vector2(16.0, 150.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.06, 0.82)
	sb.border_color = Styles.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8.0)
	_card.add_theme_stylebox_override("panel", sb)
	layer.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	# Tu cara con el modelo 3D del partido (va reemplazando al retrato pixel art)
	var face := PlayerPortrait.new(84)
	face.set_profile(_cfg.profile, {"shirt_pattern": int(_cfg.get("home_pattern", 0)),
		"shirt_color2": Color(String(_cfg.get("home_color2", "#ffffff")))})
	row.add_child(face)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var p: PlayerData = _card_player()
	col.add_child(_label("%s · %s" % [p.player_name, p.position], 20, Color.WHITE))
	_card_title = _label("", 16, Styles.GOLD)
	col.add_child(_card_title)
	_card_rating = _label("", 16, Color(0.85, 0.9, 0.86))
	col.add_child(_card_rating)
	_card.modulate.a = 0.0
	_card.visible = false   # oculta no renderiza el retrato 3D

## El jugador de la ficha (la práctica lo pasa sin MatchState).
func _card_player() -> PlayerData:
	return MatchState.user_player

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l

## La misma nota que la chapa del marcador (y que la del resumen final).
func _live_rating() -> float:
	return _match.live_rating()

func _show_card(title: String, secs: float) -> void:
	_card_title.text = title
	_card_rating.text = "Nota  %.1f" % _live_rating()
	if _card_tween:
		_card_tween.kill()
	_card.visible = true
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.25)
	_card_tween.tween_interval(secs)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.4)
	_card_tween.tween_callback(func() -> void: _card.visible = false)

func _on_moment_started(title: String) -> void:
	_card.position.y = 150.0
	_show_card(title.replace("¡", "").replace("!", ""), 2.6)

func _on_moment_ended(_text: String, ok: bool) -> void:
	_card.position.y = 150.0
	_show_card("Jugada lograda" if ok else "Jugada fallida", 2.2)

func _on_subbed_in(minute: int) -> void:
	_card.position.y = 240.0 # deja libre el cartel del cuarto árbitro
	_show_card("¡Entras al campo! (%d')" % minute, 3.5)
	if _sub_card_reset != null:
		_sub_card_reset.kill()
	_sub_card_reset = create_tween()
	_sub_card_reset.tween_interval(4.2)
	_sub_card_reset.tween_callback(func() -> void:
		if _card != null:
			_card.position.y = 150.0)

## Animación de premio individual en el césped: el ganador aparece con el trofeo MVP,
## lo levanta y la cámara lo acompaña. Sin diálogo ni pantalla de entrevista.
func _hide_card() -> void:
	if _card_tween != null:
		_card_tween.kill()
	if _card != null:
		_card.visible = false
		_card.modulate.a = 0.0


func _on_outro_finished() -> void:
	_hide_card()
	# Las notas IA usan azar y el puente actualiza stats: calcular una sola vez.
	_final_result = Match3DBridge.to_match_result(_match.result(), _cfg)
	var ratings: Array = _final_result.get("player_ratings", [])
	if ratings.is_empty():
		_match.finish_and_exit()
		return
	var mvp: Dictionary = ratings[0]
	var team_name := String(mvp.get("team", "home"))
	var on_user_side := (team_name == "home") == bool(_cfg.get("user_home", true))
	var team_index := 0 if on_user_side else 1
	var winner: SoccerPlayer = null
	if bool(mvp.get("is_user", false)):
		winner = _match.star
	else:
		for p: SoccerPlayer in _match.teams[team_index]:
			if _match._name_of(p) == String(mvp.get("name", "")):
				winner = p
				break
	if winner == null and _match.teams[team_index].size() > 1:
		winner = _match.teams[team_index][1]
	if winner == null:
		_match.finish_and_exit()
		return
	_match.state = SoccerMatch.State.MVP_CEREMONY
	_mvp_ceremony = MvpCeremonyScript.new()
	_match.add_child(_mvp_ceremony)
	_mvp_ceremony.connect("finished", _on_mvp_animation_finished)
	var team_color: Color = FieldBuilder.home_color if team_index == 0 else FieldBuilder.away_color
	_mvp_ceremony.call("start", _match, winner, String(mvp.get("name", "MVP")), team_color)


func _on_mvp_animation_finished() -> void:
	if _mvp_ceremony != null:
		_mvp_ceremony.queue_free()
		_mvp_ceremony = null
	if _match != null:
		_match.finish_and_exit()
# ---------------------------------------------------------------- final
func _on_finished(res: Dictionary) -> void:
	if _done:
		return
	_done = true
	var out: Dictionary = _final_result if not _final_result.is_empty() else Match3DBridge.to_match_result(res, _cfg)
	MatchState.match_result = out
	MatchState.last_user_rating = float(out.get("user_rating", MatchRatingCalculator.BASE_RATING))
	_go_portrait()
	# Selección: su propio resumen (como el partido clásico, Match.gd)
	var comp: String = String(MatchState.fixture.get("competition", ""))
	if MatchState.fixture.has("home_country") or comp in ["qualifying", "world_cup", "national_cup"]:
		get_tree().change_scene_to_file("res://scenes/NationalMatchSummary/NationalMatchSummary.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MatchSummary/MatchSummary.tscn")
