extends Control
## Entrenamiento 3D en el ESTADIO DE TU CLUB (8-nov; Wilber: "si tienes el estadio
## del equipo, ¿para qué crear otro escenario?"): FieldBuilder levanta el mismo estadio
## del partido, vacío y de día, y el ejercicio se hace frente a la portería real.
## Tu jugador hace el ejercicio del foco elegido
## (Físico = sprints entre conos, Técnica = slalom con balón y remate, Mental =
## lectura de juego y pase, Equilibrado = un poco de cada; si eres portero,
## blocajes y estiradas). En bucle mientras miras la pantalla; al pulsar "Entrenar"
## hace la sesión entera y avisa al terminar (play_session).
##   const TrainingStage = preload("res://ui/common/TrainingStage.gd")
##   var st := TrainingStage.make(cfg, "technical", is_gk)   # null sin 3D

const CONE := Color(1.0, 0.5, 0.1)
const BALL_R := 0.11
## Los ejercicios se escriben respecto a ORIGIN; la portería real queda a GOAL_X de él.
const GOAL_X := 9.5
const ORIGIN := Vector3(52.5 - GOAL_X, 0.0, 0.0)

## Ejercicios: lista de pasos. Cada paso:
##   anim  animación del modelo · t  duración (s)
##   to    (x, z) adonde va durante el paso; sin "to" se queda en el sitio
##   face  (x, z) hacia dónde mira (si no, hacia donde corre)
##   ball  "dribble" pegado al pie · "kick" sale hacia `aim` · "arrive" le llega desde
##         `from` (portero) · "catch" en las manos
## Zonas separadas (8-nov, Wilber: "¿por qué corre sobre los conos traspasándolos?"):
## carril de sprint en z = 2 (conos al final, donde frena), slalom en z = 0 que se
## recorre en zigzag ALREDEDOR de los conos, y el pase hacia el cono de z = -2,6.
const SLALOM_CONES := [Vector2(-2.0, 0.0), Vector2(-0.5, 0.0), Vector2(1.0, 0.0)]
const LANE_CONES := [Vector2(-4.2, 2.0), Vector2(4.2, 2.0)]
const PASS_CONE := Vector2(4.0, -2.6)
## Dónde empieza cada ejercicio (jugador) y dónde espera el balón.
const STARTS := {
	"physical": [Vector2(-3.5, 2.0), Vector2(-3.0, 3.2)],
	"technical": [Vector2(-3.5, 0.0), Vector2(-3.0, 0.0)],
	"mental": [Vector2(-3.5, -1.8), Vector2(-3.0, -1.8)],
	"balanced": [Vector2(-3.5, 2.0), Vector2(0.5, 2.0)],
	"keeper": [Vector2(GOAL_X - 0.6, 0.0), Vector2(GOAL_X - 4.0, 0.0)],
}
const DRILLS := {
	"physical": [
		{"anim": "run", "to": Vector2(3.5, 2.0), "t": 1.3},
		{"anim": "run", "to": Vector2(-3.5, 2.0), "t": 1.3},
		{"anim": "run", "to": Vector2(3.4, 2.0), "t": 1.2},
		{"anim": "strafe_left", "to": Vector2(3.4, 1.0), "t": 0.6, "face": Vector2(-1.0, 0.0)},
		{"anim": "strafe_right", "to": Vector2(3.4, 3.0), "t": 1.1, "face": Vector2(-1.0, 0.0)},
		{"anim": "run", "to": Vector2(-3.5, 2.0), "t": 1.5},
		{"anim": "tired", "t": 1.8, "face": Vector2(0.3, 1.0)},
	],
	"technical": [
		{"anim": "jog", "to": Vector2(-2.0, 0.75), "t": 0.8, "ball": "dribble"},
		{"anim": "stepover", "to": Vector2(-0.5, -0.75), "t": 0.9, "ball": "dribble"},
		{"anim": "jog", "to": Vector2(1.0, 0.75), "t": 0.9, "ball": "dribble"},
		{"anim": "jog", "to": Vector2(2.6, 0.2), "t": 0.8, "ball": "dribble"},
		{"anim": "shot_strike", "t": 0.9, "ball": "kick", "aim": Vector3(GOAL_X + 0.9, 0.9, -0.9), "face": Vector2(1.0, 0.0)},
		{"anim": "fist_pump", "t": 1.6, "face": Vector2(0.4, 1.0)},
	],
	"mental": [
		{"anim": "point", "t": 1.6, "face": Vector2(0.3, 1.0)},
		{"anim": "dodge_l", "t": 0.6, "face": Vector2(1.0, 0.0)},
		{"anim": "dodge_r", "t": 0.6, "face": Vector2(1.0, 0.0)},
		{"anim": "jog", "to": Vector2(0.0, -1.8), "t": 1.0, "ball": "dribble"},
		{"anim": "pass_inside", "t": 0.7, "ball": "kick", "aim": Vector3(PASS_CONE.x - 0.4, 0.0, PASS_CONE.y + 0.1), "face": Vector2(1.0, -0.2)},
		{"anim": "clap", "t": 1.3, "face": Vector2(0.3, 1.0)},
	],
	"balanced": [
		{"anim": "run", "to": Vector2(0.0, 2.0), "t": 1.1},
		{"anim": "jog", "to": Vector2(1.6, 1.2), "t": 0.7, "ball": "dribble"},
		{"anim": "jog", "to": Vector2(2.6, 0.3), "t": 0.6, "ball": "dribble"},
		{"anim": "shot_strike", "t": 0.9, "ball": "kick", "aim": Vector3(GOAL_X + 0.9, 0.4, 1.0), "face": Vector2(1.0, 0.0)},
		{"anim": "point", "t": 1.2, "face": Vector2(0.3, 1.0)},
		{"anim": "run", "to": Vector2(-3.5, 2.0), "t": 1.5},
	],
	"keeper": [
		{"anim": "keeper_idle", "t": 1.0, "face": Vector2(-1.0, 0.0), "ball": "arrive", "from": Vector3(GOAL_X - 4.0, 0.2, 0.0)},
		{"anim": "keeper_catch", "t": 1.2, "face": Vector2(-1.0, 0.0), "ball": "catch"},
		{"anim": "keeper_throw", "t": 1.4, "face": Vector2(-1.0, 0.0), "ball": "kick", "aim": Vector3(GOAL_X - 9.0, 0.0, 1.5)},
		{"anim": "keeper_idle", "t": 0.8, "face": Vector2(-1.0, 0.0), "ball": "arrive", "from": Vector3(GOAL_X - 4.0, 0.5, 1.6)},
		{"anim": "keeper_dive", "t": 1.8, "face": Vector2(-1.0, 0.0), "ball": "catch"},
		{"anim": "keeper_idle", "t": 0.8, "face": Vector2(-1.0, 0.0)},
	],
}
const TITLES := {"physical": "Sprints y cambios de ritmo", "technical": "Slalom con balón y remate",
	"mental": "Lectura de juego y pase", "balanced": "Circuito mixto", "keeper": "Blocajes y estiradas"}

var _portrait: PlayerPortrait
var _root: Node3D
var _ball: MeshInstance3D
var _drill: Array = []
var _drill_key := ""
var _step := 0
var _t := 0.0
var _from := Vector3.ZERO
var _ball_from := Vector3.ZERO
var _ball_to := Vector3.ZERO
var _pause := 0.0
var _session_cb := Callable()
var _label: Label
var _k := 1.0
var _club: ClubData = null
var _drill_root: Node3D
const Weather = preload("res://engine/match/m3d/Weather.gd")
var _speed := 1.0


## `club`: el club de tu jugador (su estadio y colores); null = estadio genérico.
static func make(cfg: Dictionary, focus: String, is_gk: bool, height := 230, club: ClubData = null) -> Control:
	if not Avatar3D.enabled():
		return null
	var st = load("res://ui/common/TrainingStage.gd").new()
	st._club = club
	st._setup(Avatar.from_legacy(cfg), height)
	st.set_focus(focus, is_gk)
	return st


func _setup(cfg: Dictionary, height: int) -> void:
	custom_minimum_size = Vector2(0, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_portrait = PlayerPortrait.new(height, Color(0.55, 0.74, 0.92), true, "free")
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Avatar3D.apply(_portrait.avatar, cfg)
	Avatar3D._kit_decals(_portrait, cfg)
	add_child(_portrait)
	_k = absf(_portrait.avatar.scale.y)
	var vp: Node = _portrait.avatar.get_parent()
	# El estadio trae su cielo y su sol: fuera la luz de estudio del retrato
	for n in vp.get_children():
		if n is WorldEnvironment or n is DirectionalLight3D:
			n.queue_free()
	_root = Node3D.new()
	_root.scale = Vector3.ONE * _k # el estadio en metros, a la escala del modelo
	_root.position = -ORIGIN * _k # el ejercicio, frente a la portería de +X
	vp.add_child(_root)
	var cam := _portrait._cam
	cam.keep_aspect = Camera3D.KEEP_WIDTH # ancho fijo: entra el ejercicio entero en cualquier pantalla
	cam.fov = 84.0
	cam.far = 300.0
	var eye := Vector3(1.0, 3.9, 10.5) * _k
	cam.transform = Transform3D(Basis.looking_at(Vector3(1.6, 0.4, 0.0) * _k - eye, Vector3.UP), eye)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(10, 6)
	add_child(_label)


## Cambia el ejercicio (al elegir otro foco). Empieza de nuevo, en bucle.
func set_focus(focus: String, is_gk: bool) -> void:
	_drill_key = "keeper" if is_gk else (focus if DRILLS.has(focus) else "balanced")
	_drill = DRILLS[_drill_key]
	if _label != null:
		_label.text = String(TITLES.get(_drill_key, ""))
	_restart()


## Hace la sesión una vez entera (sin bucle, algo acelerada: ~`seconds` s) y
## llama a `done` al terminar.
func play_session(done: Callable, seconds := 4.5) -> void:
	_session_cb = done
	_speed = maxf(1.0, drill_seconds() / seconds)
	_portrait.avatar.anim.speed_scale = _speed
	if _label != null:
		_label.text = "Entrenando: %s…" % String(TITLES.get(_drill_key, ""))
	_restart()


## Duración de una vuelta al ejercicio (s).
func drill_seconds() -> float:
	var s := 0.0
	for st: Dictionary in _drill:
		s += float(st.t)
	return s


func _ready() -> void:
	# El estadio se levanta ya dentro del árbol (FieldBuilder orienta luces con look_at)
	if _ball == null:
		_build_field()
		_restart()


func _restart() -> void:
	if _portrait == null or _ball == null:
		return
	var sp: Array = STARTS[_drill_key]
	var a: Vector2 = sp[0]
	var bl: Vector2 = sp[1]
	_portrait.avatar.position = Vector3(a.x, 0.0, a.y) * _k
	_portrait.avatar.rotation.y = PI * 0.5 if _drill_key != "keeper" else -PI * 0.5
	_ball.position = Vector3(bl.x, BALL_R, bl.y) * _k
	_step = -1
	_pause = 0.0
	_next_step()


func _next_step() -> void:
	_step += 1
	if _step >= _drill.size():
		_step = _drill.size() - 1
		if _session_cb.is_valid():
			var cb := _session_cb
			_session_cb = Callable()
			_speed = 1.0
			_portrait.avatar.anim.speed_scale = 1.0
			_portrait.avatar.anim.play("victory_idle" if _portrait.avatar.anim.has_animation("victory_idle") else "idle", 0.2)
			cb.call()
			return
		_pause = 1.0 # respiro y vuelta a empezar
		_portrait.avatar.anim.play("idle", 0.3)
		return
	var s: Dictionary = _drill[_step]
	_t = 0.0
	var av := _portrait.avatar
	_from = av.position
	if av.anim.has_animation(String(s.anim)):
		av.anim.play(String(s.anim), 0.15)
	match String(s.get("ball", "")):
		"kick":
			var aim: Vector3 = s.aim
			_ball_from = _ball.position
			_ball_to = aim * _k + Vector3(0.0, BALL_R * _k, 0.0)
		"arrive":
			var fr: Vector3 = s.from
			_ball_from = fr * _k
			_ball.position = _ball_from
			_ball_to = _hands(av)


func _hands(av: Node3D) -> Vector3:
	var fwd := Vector3(sin(av.rotation.y), 0.0, cos(av.rotation.y))
	return av.position + fwd * 0.35 * _k + Vector3(0.0, 1.05, 0.0) * _k


func _process(delta: float) -> void:
	if _portrait == null or not is_visible_in_tree() or _drill.is_empty():
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_restart()
		return
	var s: Dictionary = _drill[_step]
	var dur: float = float(s.t)
	delta *= _speed
	_t += delta
	var u := clampf(_t / dur, 0.0, 1.0)
	var av := _portrait.avatar
	if s.has("to"):
		var to2: Vector2 = s.to
		var to := Vector3(to2.x, 0.0, to2.y) * _k
		var dir := to - _from
		av.position = _from.lerp(to, u)
		if s.has("face"):
			var f: Vector2 = s.face
			av.rotation.y = atan2(f.x, f.y)
		elif dir.length() > 0.05:
			av.rotation.y = lerp_angle(av.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 10.0))
	elif s.has("face"):
		var f2: Vector2 = s.face
		av.rotation.y = lerp_angle(av.rotation.y, atan2(f2.x, f2.y), minf(1.0, delta * 8.0))
	match String(s.get("ball", "")):
		"dribble":
			var fwd := Vector3(sin(av.rotation.y), 0.0, cos(av.rotation.y))
			_ball.position = av.position + fwd * 0.5 * _k + Vector3(0.0, BALL_R * _k, 0.0)
			_ball.rotate_x(delta * 8.0)
		"kick":
			# Sale en el golpeo (a un tercio del gesto), en parábola, y se queda allí
			if u > 0.35:
				var v := clampf((u - 0.35) / 0.45, 0.0, 1.0)
				var p := _ball_from.lerp(_ball_to, v)
				var lift := 0.9 if _ball_to.y > BALL_R * _k * 2.0 else 0.2
				p.y += sin(v * PI) * lift * _k
				_ball.position = p
		"arrive":
			_ball.position = _ball_from.lerp(_ball_to, u) + Vector3(0.0, sin(u * PI) * 0.6 * _k, 0.0)
		"catch":
			_ball.position = _hands(av)
	if _t >= dur:
		_next_step()


func _build_field() -> void:
	# El estadio de tu club, vacío y de día (es un entrenamiento, no un partido)
	FieldBuilder.time_of_day = 0
	FieldBuilder.weather = Weather.CLEAR
	FieldBuilder.crowd_fill = 0.0
	FieldBuilder.crowd = {}
	FieldBuilder.stars = Venue.stars(_club) if _club != null else 3
	if _club != null:
		FieldBuilder.home_color = Color(_club.primary_color_hex)
		FieldBuilder.home_color2 = Color(_club.secondary_color_hex)
		FieldBuilder.away_color = FieldBuilder.home_color
		FieldBuilder.banner_seed_name = _club.club_name
		AdBoards.home_name = _club.club_name
	var stadium := Node3D.new()
	_root.add_child(stadium)
	FieldBuilder.build(stadium)
	# Lo de entrenar, en coordenadas del ejercicio (respecto a ORIGIN)
	var drill := Node3D.new()
	drill.position = ORIGIN
	_root.add_child(drill)
	_drill_root = drill
	# Conos: fin del carril de sprint, slalom y el del pase (ninguno en el camino)
	for c: Vector2 in SLALOM_CONES + LANE_CONES + [PASS_CONE]:
		_cone(Vector3(c.x, 0.0, c.y))
	# Balón (vive con el jugador, fuera del estadio escalado)
	_ball = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = BALL_R * _k
	sp.height = BALL_R * 2.0 * _k
	sp.radial_segments = 16
	sp.rings = 8
	_ball.mesh = sp
	_ball.material_override = _mat(Color(0.96, 0.96, 0.96))
	_portrait.avatar.get_parent().add_child(_ball)


func _cone(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02 * _k
	cm.bottom_radius = 0.13 * _k
	cm.height = 0.32 * _k
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _mat(CONE)
	mi.scale = Vector3.ONE / _k # (el padre ya va escalado)
	mi.position = Vector3(p.x, 0.16, p.z)
	_drill_root.add_child(mi)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m
