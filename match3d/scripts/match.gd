class_name SoccerMatch
extends Node3D
## Partido por "momentos clave", estilo Mini Soccer Star / Soccer World Champs:
## el partido se simula solo (minutos y comentarios) y en momentos puntuales
## intervienes con gestos: tocar para pasar o moverte, deslizar para chutar.
## El equipo 0 (LOCAL) es el tuyo y ataca hacia +X. Tu jugador lleva la marca "TÚ".

## WALKOUT: salida · LOCKER: descanso · OUTRO: despedida después del pitido final.
## CUTSCENE: plano de tu jugador en el banquillo / tu cambio (el reloj no corre)
enum State { SIMULATING, MOMENT_INTRO, MOMENT, MOMENT_RESULT, ENDED, WALKOUT, REPLAY, CUTSCENE, LOCKER, OUTRO, MVP_CEREMONY, AMBIENT_GOAL, PENALTY_SHOOTOUT, CELEBRATION, VAR_REVIEW }
## Jugadas (como ProtoDirector de FootballCareer): cuáles te tocan depende de tu puesto.
## Tres familias: ataque (ATTACK, COUNTER, CROSS, CORNER, FREE_KICK, PENALTY),
## armado (BUILDUP: construir y dar el pase clave) y defensa (DEFENSE, KEEPER).
enum Moment { ATTACK, DEFENSE, PENALTY, COUNTER, CROSS, CORNER, FREE_KICK, KEEPER, BUILDUP }

const FoulRules = preload("res://engine/match/FoulResolver.gd")
const AiTuning = preload("res://engine/match/m3d/AiTuning.gd")
const ShotZone = preload("res://engine/match/m3d/ShotZone.gd")
const DribbleCombo = preload("res://engine/match/m3d/DribbleCombo.gd")
const SkillMove = preload("res://engine/match/m3d/SkillMove.gd")
const CrossZone = preload("res://engine/match/m3d/CrossZone.gd")
const HeaderTiming = preload("res://engine/match/m3d/HeaderTiming.gd")
const PlayChain = preload("res://engine/match/m3d/PlayChain.gd")
const PrePlayChoice = preload("res://engine/match/m3d/PrePlayChoice.gd")
const Momentum = preload("res://engine/match/m3d/Momentum.gd")
const Offside = preload("res://engine/match/m3d/Offside.gd")

# Cancha reglamentaria (metros)
const FIELD_LENGTH := 105.0
const FIELD_WIDTH := 68.0
## Arcos algo más grandes que los reglamentarios (7,32 x 2,44): en el móvil se marca mejor
const GOAL_WIDTH := 8.2
const GOAL_HEIGHT := 2.75
const GOAL_DEPTH := 2.0
const BOX_DEPTH := 16.5
const BOX_WIDTH := 40.3
const SMALL_BOX_DEPTH := 5.5
const SMALL_BOX_WIDTH := 18.3
const PENALTY_DIST := 11.0
const CENTER_RADIUS := 9.15
const PLAYERS_PER_TEAM := 11

## Posición base de cada puesto, igual que ProtoSim de FootballCareer: x a lo ancho (0-68),
## y a lo largo (ataca hacia y = 0, su portería en y = 105). El portero va aparte.
const FORMATION_BASES := {
	"4-4-2": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(9, 70), Vector2(26, 73), Vector2(42, 73), Vector2(59, 70),
		Vector2(28, 58), Vector2(40, 58)],
	"4-3-3": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(34, 79), Vector2(23, 71), Vector2(45, 71),
		Vector2(10, 60), Vector2(34, 57), Vector2(58, 60)],
	"4-2-3-1": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(27, 78), Vector2(41, 78),
		Vector2(10, 65), Vector2(34, 66), Vector2(58, 65), Vector2(34, 57)],
	"3-5-2": [Vector2(20, 88), Vector2(34, 90), Vector2(48, 88),
		Vector2(60, 71), Vector2(34, 79), Vector2(24, 72), Vector2(44, 72), Vector2(8, 71),
		Vector2(28, 58), Vector2(40, 58)],
	"5-3-2": [Vector2(6, 82), Vector2(21, 89), Vector2(34, 90), Vector2(47, 89), Vector2(62, 82),
		Vector2(34, 78), Vector2(23, 72), Vector2(45, 72),
		Vector2(28, 58), Vector2(40, 58)],
	"4-5-1": [Vector2(8, 85), Vector2(25, 89), Vector2(43, 89), Vector2(60, 85),
		Vector2(9, 68), Vector2(24, 73), Vector2(34, 78), Vector2(44, 73), Vector2(59, 68),
		Vector2(34, 59)],
}
## Cómo se mueve cada línea con el balón (ProtoSim: ROLE_SHIFT / ROLE_PUSH).
const ROLE_SHIFT := {"DF": 0.42, "MF": 0.55, "ST": 0.5}
const ROLE_PUSH := {"DF": 7.0, "MF": 11.0, "ST": 17.0}
const ROLE_MIN_X := {"DF": -47.0, "MF": -40.0, "ST": -26.0} # lo más atrás que baja cada línea
const ROLE_MAX_X := {"DF": 12.0, "MF": 30.0, "ST": 43.0}    # lo más arriba que sube
## Puesto del perfil (PlayerProfile.POSITIONS) → línea del motor de FootballCareer.
const PROFILE_ROLE := ["GK", "DF", "MF", "ST"]
## Peso de cada jugada según tu puesto (ProtoDirector.WEIGHTS + jugadas de portero).
const MOMENT_WEIGHTS := {
	"ST": {Moment.ATTACK: 3.0, Moment.COUNTER: 1.6, Moment.CROSS: 1.6, Moment.CORNER: 1.0, Moment.FREE_KICK: 0.9, Moment.PENALTY: 0.35, Moment.DEFENSE: 1.2, Moment.BUILDUP: 0.8},
	"MF": {Moment.ATTACK: 3.0, Moment.COUNTER: 1.4, Moment.CROSS: 1.0, Moment.CORNER: 0.9, Moment.FREE_KICK: 1.0, Moment.PENALTY: 0.25, Moment.DEFENSE: 1.4, Moment.BUILDUP: 2.4},
	"DF": {Moment.ATTACK: 1.5, Moment.COUNTER: 0.8, Moment.CROSS: 0.5, Moment.CORNER: 1.0, Moment.FREE_KICK: 0.6, Moment.PENALTY: 0.15, Moment.DEFENSE: 3.2, Moment.BUILDUP: 1.6},
	"GK": {Moment.KEEPER: 1.0, Moment.BUILDUP: 0.3}, # el arquero también saca jugando
}
const MOMENTS_PER_MATCH := 8
## Diseños de camiseta (player_body.gdshaderinc): lisa repetida para que salga más a menudo.
const KIT_PATTERNS := [0, 0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]

## Datos del partido que manda FootballCareer al lanzarlo (todos opcionales).
## {"home_name", "away_name", "home_formation", "away_formation", "channel",
##  "home_coach", "away_coach", "stadium", "ball_design", "time_of_day",
##  "home_pattern", "away_pattern" (0-7 y 10-28, ver KIT_PATTERNS), "home_color2", "away_color2" ("#rrggbb"),
##  "home_crest_center", "away_crest_center" (escudo en el centro del pecho)}
## Aquí "home" es SIEMPRE tu equipo (equipo 0) y "away" el rival, juegues de local o de visita.
## Además, para jugar con los planteles reales:
##  "profile": PlayerProfile (tu jugador; si no está, el del editor),
##  "away_shirt", "away_shorts", "away_socks" ("#rrggbb"),
##  "home_players", "away_players": [{name, position (GK/DF/MF/ST), stats, look {skin, hair, hair_style, face}}]
##      (tu equipo sin ti), "goal_rate_home", "goal_rate_away" (gol por minuto simulado),
##  "on_finish": Callable(result) al tocar la pantalla tras el pitido final,
##  "bench_until": minuto en que entras desde el banco (0 = titular, >= 90 = no entras);
##      hasta entonces tu hueco lo ocupa un compañero de "home_players" y no hay jugadas.
static var config: Dictionary = {}

## Para la pantalla que lanza el partido (la ficha con tu cara, la nota...).
signal moment_started(title: String)
signal moment_ended(text: String, ok: bool)
signal finished(result: Dictionary)
signal subbed_in(minute: int)
signal outro_finished()

const MATCH_MINUTES := 90.0
const SIM_SECONDS_PER_MINUTE := 0.25 # 90' simulados ≈ 22 s
const MOMENT_SECONDS := 12.0
const MOMENT_TIME_SCALE := 0.8       # cámara algo lenta para dar tiempo a reaccionar
const PREPLAY_INTRO_SECONDS := 2.2   # P1-13: tiempo para elegir antes de la jugada
const DECISION_TIME_SCALE := 0.12    # cámara muy lenta cuando toca decidir
const DECISION_SECONDS := 2.5        # tiempo real para decidir
const DECISION_RADIUS := 3.5         # distancia del defensor que dispara la decisión
const CHARGE_FULL_SECONDS := 0.7    # mantener el gesto este tiempo = potencia máxima
const CHARGE_FLICK_WEIGHT := 0.55   # cuánto aporta el largo/velocidad del gesto
const CHARGE_HOLD_WEIGHT := 0.45    # cuánto aporta mantenerlo cargado
const SHOT_STAMINA_MIN_CAP := 0.55  # con stamina 0 no se pasa de esta potencia
const SHOT_STAMINA_MIN_CURL := 0.45 # con stamina 0 el efecto se reduce a esto
## Multi-toque para correr a un punto: toques seguidos en la misma zona suben
## el boost (1 = rápido, 2 = máximo) y gastan más estamina.
const MULTITAP_WINDOW_MS := 450
const MULTITAP_RADIUS_PX := 80.0
const MOVE_BOOST_MAX := 2
const MOVE_BOOST_DRAIN := 0.010      # estamina por segundo y nivel de boost
const MOVE_BOOST_MIN_STAMINA := 0.12 # por debajo de esto no hay boost
## P1-08 · Pase de primera: jugar el balón que viene sin controlarlo.
const FIRST_TOUCH_RADIUS := 3.4       # distancia máxima al balón para el toque
const FIRST_TOUCH_MAX_HEIGHT := 1.3   # solo balones jugables con el pie/cuerpo
const FIRST_TOUCH_MIN_SPEED := 2.5    # el balón tiene que venir en movimiento
const FIRST_TOUCH_MIN_TARGET := 3.0   # el destino elegido debe estar lejos del jugador
## P1-09 · Mantener el toque del pase este tiempo lo levanta por encima del rival.
const PASS_LOFT_HOLD_SECONDS := 0.45
## P1-10 · Si no eliges zona, el centro sale solo al primer palo tras este tiempo.
const CROSS_ZONE_AUTO_SECONDS := 2.2
const DECISION_HINT := "Toca a un compañero (aro verde): pase   ·   Desliza a la portería: tiro\nDesliza hacia un lado: regate"

const TEAM_COLORS := [Color(0.86, 0.13, 0.16), Color(0.16, 0.38, 0.92)]
const KEEPER_COLORS := [Color(0.98, 0.82, 0.12), Color(0.18, 0.82, 0.42)]
static var TEAM_NAMES := ["LOCAL", "VISITA"]

const TITLES := {
	Moment.ATTACK: "¡OCASIÓN DE GOL!",
	Moment.DEFENSE: "¡DEFIENDE!",
	Moment.PENALTY: "¡PENALTI!",
	Moment.COUNTER: "¡CONTRAATAQUE!",
	Moment.CROSS: "¡CENTRO AL ÁREA!",
	Moment.CORNER: "CÓRNER A FAVOR",
	Moment.FREE_KICK: "TIRO LIBRE",
	Moment.KEEPER: "¡ATAJA!",
	Moment.BUILDUP: "ARMA LA JUGADA",
}
const HINT_ATTACK := "Con balón: toca a un compañero = pase · mantené y soltá a la portería = tiro\nSin balón: toca el césped = desmarcarte · varios toques = sprint · tócate a ti o al compañero = pedirla"
const HINTS := {
	Moment.ATTACK: HINT_ATTACK,
	Moment.COUNTER: HINT_ATTACK,
	Moment.DEFENSE: "Toca al rival con balón: entrada   ·   Toca el césped: moverte\nVarios toques al césped = sprint · Desliza hacia el rival: barrida (si llegas tarde, falta)",
	Moment.PENALTY: "Mantené el gesto hacia la portería para cargar y soltá\nCurvá el dedo para abrir el balón al segundo palo",
	Moment.CROSS: "Elige dónde quieres el centro: 1ER PALO · 2º PALO · PUNTO PENAL\nToca el césped para atacar el hueco · desliza al cabecear para elegir el remate",
	Moment.CORNER: "Toca el césped para moverte en el área · cuando venga el balón,\ndesliza hacia la portería para cabecear",
	Moment.FREE_KICK: "Mantené para cargar y soltá por encima de la barrera\nCurvá el gesto para darle rosca",
	Moment.BUILDUP: "Toca a un compañero = pase · desliza = pase al hueco\nBusca al desmarcado arriba: el pase clave puede ser asistencia",
	Moment.KEEPER: "Toca el césped para colocarte · toca al rival para salir a por él\nCuando dispare, desliza hacia donde te lanzas (hacia arriba = alto)",
}
var ball: SoccerBall
var players: Array[SoccerPlayer] = []
var teams: Array = [[], []]
var human: SoccerPlayer   # jugador que controlas ahora mismo (solo durante un momento)
var star: SoccerPlayer    # tu jugador estrella ("TÚ")
var profile: PlayerProfile # tu jugador creado en el editor
var score := [0, 0]
var minute := 0.0
var state := State.SIMULATING
var moment_type := Moment.ATTACK
## Jugada procedural en curso (PlayGenerator.make): familia, título, banda, presión...
var play: Dictionary = {}
## El rival que ejecuta la acción de la jugada (chutar, centrar, tiro libre) tras play.rival_delay.
var play_carrier: SoccerPlayer = null
var _play_counts := {}
var _last_family := ""
var possession_team := -1

var _moments: Array = []
## Falta a tu favor cerca del área: al acabar la jugada viene un tiro libre.
var _pending_free_kick := false
var _pending_penalty := false
var _pending_fk_spot := Vector3.ZERO
## Expulsado (doble amarilla): ya no hay más jugadas tuyas.
var sent_off := false
## Nota de la jugada que se cierra por falta tuya (para el "XP de toques" de la carrera).
var _foul_grade := ""
## La falta fue a tu favor: la jugada no debe contar como fallida.
var _foul_for_us := false
## Personalidad del árbitro (la manda Match3DBridge desde MatchEngine).
var _referee_foul_mult := 1.0
var _referee_card_mult := 1.0
var _referee_var_mult := 1.0
## Fuera de juego: foto de las posiciones en el último golpeo
## {team, players: {SoccerPlayer: {margin, line_w, px_w}}} (vacío = nada pendiente).
var _offside_snap := {}
## Jugada que el VAR revisaría si acaba en gol: fuera de juego que el línea no vio
## (offside = true) o una muy justa (offside = false, se confirma el gol).
var _var_pending := {}
var _var := {}           # revisión en curso (estado VAR_REVIEW)
var _var_cleared := false
var _corner_exempt := false # del saque de esquina no hay fuera de juego
var _trap_until := [0.0, 0.0]
var _trap_next := [0.0, 0.0]
## Segundos de plano de la tarjeta (la cámara enfoca al árbitro y al infractor).
var _card_cam_t := 0.0
var _card_fouler: SoccerPlayer = null
## La ola: segundos que le quedan (0 = no hay) y espera hasta la próxima.
var _wave_left := 0.0
var _wave_wait := 30.0
const WAVE_SECONDS := 16.0
var _timer := 0.0
# Salida de los equipos: cuándo sale cada uno del túnel y si ya pasó por la banda
var _walk_t := 0.0
var _walk_done_t := 0.0
var _walk_delay: Dictionary = {}
var _walk_via: Dictionary = {}
var _walk_layers: Dictionary = {} # capas de colisión guardadas mientras esperan en el túnel
var replay: ReplayDirector
var _moment_timer := 0.0
var _shot_pending := false
var _shot_timer := 0.0
var _saved := false
var _last_header_ms := -10000
var _penalty_kicked := false
var _rebound_done := false
var _penalty_guess := 0.0
var _move_target: Variant = null
var _move_boost := 0                # 0 = normal, 1..MOVE_BOOST_MAX = multi-toque
var _move_tap_ms := -10000
var _move_tap_count := 0
var _move_tap_pos := Vector2.ZERO
var _tackle_target: SoccerPlayer = null
var pass_requested := false # pediste el balón: el compañero te la pasa en cuanto pueda
var _header_aim := Vector3.ZERO # dirección elegida con el dedo para el próximo cabezazo
var _deciding := false
var _decision_left := 0.0
var _decision_cooldown := 0.0
var _camera: Camera3D
var _cam_focus := Vector3.ZERO
var _cam_focus_v := Vector3.ZERO # velocidad del foco (muelle amortiguado de la cámara de TV)
var _cam_pos := Vector3(0.0, 16.0, 14.0)
var _cam_look := Vector3.ZERO
var _cam_subject: SoccerPlayer  # a quién sigue la cámara en tercera persona
var _hud: MatchHUD
var _aim_zone_radius := 0.0 # P1-03: radio (m) de la zona de tiro segura
var _cross_pending := false          # P1-10: el centro espera a que elijas zona
var _cross_carrier: SoccerPlayer = null # quién va a centrar
var _cross_auto := 0.0               # tiempo antes de lanzar al primer palo
var _cross_zone := ""                # zona elegida (near / far / spot)
var _dodge_chain := 0       # P1-05: quiebros encadenados
var _dodge_window := 0.0    # tiempo que queda para encadenar otro quiebro
var _dodge_dir := Vector3.ZERO # dirección del último quiebro
var _chain_links := 0        # P1-12: quiebros que abren el remate encadenado
var _chain_shot_window := 0.0 # tiempo que queda para rematar con ventaja
var _assist_target: SoccerPlayer = null # P1-12: receptor del último pase
var _assist_window := 0.0    # tiempo que sigue viva la asistencia
var _assist_total := 0.0     # ventana completa (para el decaimiento)
var _assist_shot_counted := false # el receptor ya tiró: no repetir el pase clave
var _preplay_choice := ""    # P1-13: conducir / pase rápido / aguantar
var _preplay_hold := 0.0     # P1-13: tiempo que queda aguantando el balón
var _skill_cooldown := 0.0  # P1-06: enfriamiento de las jugadas de lujo
var _goal_areas: Array[Area3D] = []
var formations := ["4-3-3", "4-4-2"]
var _bases: Array = [[], []]       # posición base (local, ataca hacia +X) de cada jugador
var _wall: Array[SoccerPlayer] = [] # barrera del tiro libre
var _set_piece_ready := false       # balón parado: nadie se mueve hasta el golpeo
var _keeper_deciding := false       # portero: el tiro viene, a cámara lenta eliges el lado
var _keeper_dived := false
var _shot_cross := Vector3.ZERO     # por dónde cruzará la línea el tiro rival
var staff: StadiumStaff
var _subs_done := [0, 0]
var _kit_shirt1 := Color.BLUE # camiseta del rival (rótulos de TV)
## Lo que pasó en el partido (goles, tiros, tus acciones): FootballCareer saca de aquí la nota.
var match_stats := {}
## Pesos de la nota en vivo. FootballCareer manda los suyos en config.rating_weights
## (los de DecisionResolver), así la nota del marcador es la misma que la del resumen.
const RATING_WEIGHTS := {"base": 6.2, "goal": 1.0, "assist": 0.7, "key_pass": 0.2, "shot": 0.05,
	"recov": 0.3, "save": 0.3, "moment_ok": 0.15, "moment_fail": -0.15, "conceded": -0.2,
	"gk_goal_against": -0.3, "win": 0.3, "loss": -0.3, "yellow": -0.3, "red": -1.2}
var _shown_rating := -1.0
var _names: Array = [[], []]          # nombre de cada jugador ("" = sin nombre)
var _star_passed_to: SoccerPlayer = null # a quién diste el último pase (asistencias)
var _moment_goal := -1                # equipo que marcó en la jugada actual
var _scripted_goal_receiver: SoccerPlayer = null # pase clave: el compañero que define
var _bench_until := 0.0               # empiezas en el banco hasta este minuto
var entered := true                   # ya estás en el campo
var _entry_minute := 0
## Estamina del partido (0-1): baja con los minutos que juegas (según tu resistencia) y
## limita el sprint. La carrera manda la energía con la que llegas ("start_energy").
var stamina := 1.0
var subbed_off := false               # pediste el cambio y el técnico te sacó
var _exit_minute := 0
var _exit_request_min := -100.0
var _sub_number := 0                  # dorsal del que entra por ti
var _kits: Array = []
var _cut_target: Node3D = null        # a quién enfoca la escena
var _cut_timer := 0.0
var _cut_sub := false                 # la escena es tu cambio (termina al pisar el campo)


func _ready() -> void:
	_bench_until = float(config.get("bench_until", 0.0))
	_referee_foul_mult = clampf(float(config.get("referee_foul_mult", 1.0)), 0.5, 2.0)
	_referee_card_mult = clampf(float(config.get("referee_card_mult", 1.0)), 0.5, 2.0)
	_referee_var_mult = clampf(float(config.get("referee_var_mult", 1.0)), 0.5, 2.0)
	if config.has("time_of_day"):
		FieldBuilder.time_of_day = int(config.time_of_day)
	elif not Engine.has_meta("keep_time_of_day"):
		FieldBuilder.time_of_day = -1 # día, atardecer o noche al azar en cada partido
	# Estadio del club local: estrellas (1-5), colores y cuánta gente viene
	FieldBuilder.stars = int(config.get("stadium_stars", 4))
	FieldBuilder.home_color = Color(String(config.get("stadium_home_color", "#db2129")))
	FieldBuilder.home_color2 = Color(String(config.get("stadium_home_color2", "#f2f2f2")))
	FieldBuilder.away_color = Color(String(config.get("stadium_away_color", "#2961eb")))
	FieldBuilder.crowd_fill = clampf(float(config.get("crowd_fill", 0.85)), 0.2, 1.0)
	# Trapos de la grada: los tuyos (config.crowd) y los de la hinchada del estadio
	FieldBuilder.crowd = config.get("crowd", {}) as Dictionary
	FieldBuilder.banner_seed_name = String(config.get("stadium", config.get("home_name", "LOCAL")))
	AdBoards.home_name = String(config.get("home_name", ""))
	var goal_areas := FieldBuilder.build(self)
	FieldBuilder.build_tifo(self, String(config.get("home_name", "LOCAL")))
	_goal_areas = goal_areas
	goal_areas[0].body_entered.connect(_on_goal_area_entered.bind(0))
	goal_areas[1].body_entered.connect(_on_goal_area_entered.bind(1))

	add_child(SoundFx.new())

	SoccerBall.design = int(config.get("ball_design", randi() % SoccerBall.DESIGNS.size())) # cada partido, un balón distinto
	ball = SoccerBall.new()
	ball.name = "Ball"
	add_child(ball)
	ball.kicked.connect(_on_ball_kicked)

	var given: Variant = config.get("profile")
	profile = given if given is PlayerProfile else PlayerProfile.load_or_default()
	TEAM_NAMES = [String(config.get("home_name", "LOCAL")), String(config.get("away_name", "VISITA"))]
	formations = [String(config.get("home_formation", ["4-3-3", "4-4-2", "4-2-3-1"].pick_random())),
			String(config.get("away_formation", FORMATION_BASES.keys().pick_random()))]
	var shirts := [profile.shirt, Color(String(config.away_shirt)) if config.has("away_shirt") else _rival_shirt(profile.shirt)]
	_kit_shirt1 = shirts[1]
	for t in 2:
		_bases[t] = _formation_local(formations[t])
		var roles := _formation_roles(formations[t])
		for i in PLAYERS_PER_TEAM:
			var p := SoccerPlayer.new()
			var shirt: Color = KEEPER_COLORS[t] if i == 0 else shirts[t]
			p.setup(self, t, i, shirt)
			p.role = roles[i]
			p.name = "P%d_%d" % [t, i]
			add_child(p)
			players.append(p)
			teams[t].append(p)
	star = teams[0][_star_slot(PROFILE_ROLE[clampi(profile.position, 0, 3)])]
	star.set_star()
	var kits := [_kit_for(0, shirts[0]), _kit_for(1, shirts[1])]
	_kits = kits

	staff = StadiumStaff.new()
	staff.name = "Staff"
	add_child(staff)
	staff.build(self, [profile.shirt, shirts[1]],
			[String(config.get("home_coach", "")), String(config.get("away_coach", ""))], kits)
	staff.sub_entered.connect(_on_sub_entered)
	if _bench_until > 0.0:
		staff.seat_user(profile, kits[0])
	# Stats: el resto al azar; tu jugador, los de tu perfil (los de tu carrera en FootballCareer)
	for p in players:
		p.set_stats(SoccerPlayer.random_stats(randf_range(52.0, 64.0), p.is_keeper))
	star.set_stats(profile.stats)
	_apply_rosters()
	# Tu equipo lleva tu equipación; tu jugador, el aspecto que creaste
	for p: SoccerPlayer in teams[0]:
		if not p.is_keeper:
			p.apply_colors({"shorts_color": profile.shorts, "socks_color": profile.socks})
	if config.has("away_shorts"):
		for p: SoccerPlayer in teams[1]:
			if not p.is_keeper:
				p.apply_colors({"shorts_color": Color(String(config.away_shorts)),
						"socks_color": Color(String(config.get("away_socks", config.away_shorts)))})
	if _bench_until <= 0.0:
		star.apply_profile(profile)
	elif star.star_label:
		star.star_label.visible = false # en tu hueco juega un compañero hasta que entres
	# Diseño de la camiseta de cada equipo (los porteros, lisa con su color)
	for t in 2:
		for p: SoccerPlayer in teams[t]:
			if not p.is_keeper:
				p.apply_colors(kits[t])
	_bake_kit_decals.call_deferred()

	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.current = true

	_hud = MatchHUD.new()
	add_child(_hud)
	var channel := String(config.get("channel", MatchHUD.BROADCAST.keys().pick_random()))
	_hud.setup_broadcast(channel, TEAM_NAMES, [profile.shirt, shirts[1]], {
		"crests": [config.get("home_crest"), config.get("away_crest")],
		"colors2": [kits[0].get("shirt_color2", Color.WHITE), kits[1].get("shirt_color2", Color.WHITE)],
		"competition": String(config.get("competition", ""))})
	_hud.gesture.tapped.connect(_on_tapped)
	_hud.cross_zone_selected.connect(_on_cross_zone_selected)
	replay = ReplayDirector.new()
	add_child(replay)
	_hud.replay_pressed.connect(_start_replay)
	_hud.entry_requested.connect(_on_entry_requested)
	_hud.exit_requested.connect(_on_exit_requested)
	stamina = clampf(float(config.get("start_energy", 1.0)), 0.3, 1.0)
	_hud.choice_made.connect(_on_choice)
	_hud.preplay_selected.connect(_on_preplay_selected)
	_hud.gesture.swiped.connect(_on_swiped)

	_setup_render_quality()
	_restart()


## Calidad de render del partido: escala 3D adaptativa según los fps reales.
func _setup_render_quality() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	if vp == null:
		return
	_perf_scale = 0.9 if OS.has_feature("mobile") else PERF_MAX_SCALE
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = _perf_scale
	# LOD de mallas más agresivo en el móvil (jugadores y prendas lejanos con menos
	# triángulos; a esa distancia y en pantalla pequeña no se nota)
	if OS.has_feature("mobile"):
		vp.mesh_lod_threshold = 3.0


func _process(delta: float) -> void:
	_adapt_render_scale(delta)


func _adapt_render_scale(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_perf_acc += delta
	if _perf_acc < 1.5:
		return
	_perf_acc = 0.0
	var vp := get_viewport()
	if vp == null:
		return
	var fps := Engine.get_frames_per_second()
	if fps < PERF_LOW_FPS and _perf_scale > PERF_MIN_SCALE:
		_perf_scale = maxf(PERF_MIN_SCALE, _perf_scale - 0.05)
		vp.scaling_3d_scale = _perf_scale
	elif fps > PERF_HIGH_FPS and _perf_scale < PERF_MAX_SCALE:
		_perf_scale = minf(PERF_MAX_SCALE, _perf_scale + 0.05)
		vp.scaling_3d_scale = _perf_scale


func _exit_tree() -> void:
	# La escala 3D es del viewport raíz: devolverla al salir del partido.
	if DisplayServer.get_name() != "headless":
		var vp := get_viewport()
		if vp != null:
			vp.scaling_3d_scale = 1.0
			vp.mesh_lod_threshold = 1.0
			_perf_scale = 1.0



func _physics_process(delta: float) -> void:
	match state:
		State.SIMULATING:
			if bool(config.get("ambient_ai", true)):
				_run_ai()
			_update_possession(delta)
			_update_shoulder_contacts(delta)
			_sim_step(delta)
		State.LOCKER:
			_freeze_players()
			_update_locker(delta)
		State.OUTRO:
			_update_outro(delta)
		State.MVP_CEREMONY:
			_freeze_players()
		State.AMBIENT_GOAL:
			_freeze_players()
			_update_ambient_goal(delta)
		State.PENALTY_SHOOTOUT:
			_freeze_players()
			_update_shootout(delta)
		State.MOMENT_INTRO:
			_freeze_players()
			_timer -= delta
			if _timer <= 0.0:
				state = State.MOMENT
				Engine.time_scale = MOMENT_TIME_SCALE
				_apply_preplay_choice()
				if _cross_pending:
					_hud.show_cross_zones(true)
		State.MOMENT:
			_moment_timer -= delta
			_update_human(delta)
			_update_decision(delta)
			_update_shot_charge()
			_update_cross_zone(delta)
			_update_play_chain(delta)
			_run_ai()
			_update_possession(delta)
			_update_shoulder_contacts(delta)
			_check_moment_outcome(delta)
		State.MOMENT_RESULT:
			_freeze_players()
			_timer -= delta
			if _timer <= 0.0:
				_back_to_simulation()
		State.ENDED:
			_freeze_players()
			if _trophy != null:
				_trophy.physics_step(delta) # los rivales se van caminando al túnel
		State.WALKOUT:
			_update_walkout(delta)
		State.REPLAY:
			pass
		State.CELEBRATION:
			_update_celebration(delta)
		State.VAR_REVIEW:
			_freeze_players()
			_update_var_review(delta)
		State.CUTSCENE:
			_run_ai()
			_update_possession(delta)
			_cut_timer -= delta
			if _cut_timer <= 0.0:
				_end_cutscene()

	if (state == State.MOMENT or state == State.MOMENT_RESULT or state == State.PENALTY_SHOOTOUT) and not _replay_hold:
		replay.record(self)
	if state == State.SIMULATING or state == State.MOMENT:
		_check_ball_escaped()
	_update_camera(delta)
	_camera_declutter()
	_update_aim_zone()
	_apply_shake(delta)
	_update_wave(delta)
	var hud_key := "%d|%d|%d|%s|%d|%d" % [score[0], score[1], int(minute), State.keys()[state],
		int(_shootout_scores[0]), int(_shootout_scores[1])]
	if hud_key != _hud_key:
		_hud_key = hud_key
		_hud.update_score(score, minute)
		var board_minute := "%d'" % int(minute)
		if minute > MATCH_MINUTES:
			board_minute = "ET %d'" % int(minute - MATCH_MINUTES)
		var board_text := "%s  %d - %d  %s\n%s" % [TEAM_NAMES[0].left(3).to_upper(), score[0], score[1], TEAM_NAMES[1].left(3).to_upper(), board_minute]
		if bool(config.get("has_tie_carry", false)):
			var agg := _aggregate_score()
			board_text += "\nGLOBAL  %d - %d" % [agg[0], agg[1]]
		if state == State.PENALTY_SHOOTOUT:
			_hud.set_shootout_clock()
			board_text = "PENALES  %d - %d\nGLOBAL  %d - %d" % [
				_shootout_scores[0], _shootout_scores[1], _aggregate_score()[0], _aggregate_score()[1]]
		FieldBuilder.set_scoreboard(self, board_text)
	_refresh_rating()
	# Las barras y botones del HUD no necesitan recalcularse 60 veces por segundo.
	_ops_acc += delta
	if _ops_acc >= 0.1:
		_ops_acc = 0.0
		_update_hud_extras()
	if _deciding:
		_hud.set_timer(_decision_left / DECISION_SECONDS, true)
	else:
		_hud.set_timer(_moment_timer / MOMENT_SECONDS, state == State.MOMENT)


# ---------- simulación ----------

## Reparte las jugadas del partido según tu puesto (como ProtoDirector de FootballCareer):
## una por tramo de minutos, con como mucho un penalti.
## Como en World Soccer Champs: todas las jugadas son ocasiones de PELIGRO, a favor
## (cerca del arco rival) o en contra (en tu área). Cuántas de cada una lo dice el
## dominio del partido ("attack_share", de la xG real); tu puesto, qué tipo de ocasión.
func _plan_moments() -> void:
	var role: String = star.role
	var weights: Dictionary = (MOMENT_WEIGHTS.get(role, MOMENT_WEIGHTS["ST"]) as Dictionary).duplicate()
	for k in [Moment.DEFENSE, Moment.KEEPER, Moment.BUILDUP]:
		weights.erase(k) # aquí solo los tipos de ocasión a favor
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var share := 0.0 if role == "GK" else clampf(float(config.get("attack_share", 0.55)), 0.25, 0.8)
	_moments.clear()
	# Desde el banco: solo jugadas después de entrar (menos, según lo que quede)
	var start := maxf(3.0, _bench_until + 2.0) if _bench_until > 0.0 else 3.0
	if start >= 88.0:
		return
	var count := maxi(1, int(round(MOMENTS_PER_MATCH * (89.0 - start) / 86.0)))
	var span := (89.0 - start) / count
	# Cada jugada sale del generador: fase según tu puesto y el dominio del partido,
	# familia según la fase, y la colocación con parámetros al azar
	_play_counts.clear()
	_last_family = ""
	var attack_share := clampf(float(config.get("attack_share", 0.55)), 0.25, 0.8)
	for i in count:
		var phase := PlayGenerator.pick_phase(role, attack_share)
		var pl := PlayGenerator.generate(role, phase, _play_counts, _last_family)
		_play_counts[pl.family] = int(_play_counts.get(pl.family, 0)) + 1
		_last_family = pl.family
		_moments.append({"minute": start + span * i + randf_range(0.0, span * 0.75), "kind": pl.base, "play": pl})


func _sim_step(delta: float) -> void:
	var prev := int(minute)
	var match_end := 120.0 if _extra_time_active else MATCH_MINUTES
	minute = minf(minute + delta / (SIM_SECONDS_PER_MINUTE * Preferences.match_pace_factor()), match_end)
	for m in range(prev + 1, int(minute) + 1):
		_simulate_minute(m)
		if state != State.SIMULATING:
			return # una secuencia de gol ambient pausa el reloj hasta que termine
	if _halftime_pending:
		_halftime_pending = false
		minute = 45.0
		_hud.add_feed("45'  Descanso")
		if _wants_locker():
			_start_locker()
			return
	if _extra_time_break_pending:
		_extra_time_break_pending = false
		minute = 105.0
		_start_extra_time_break()
		return
	if _pending_penalty and minute < match_end - 1.0:
		_pending_penalty = false
		_pending_fk_spot = Vector3.ZERO
		_start_moment(Moment.PENALTY, {})
	elif _pending_free_kick and minute < match_end - 1.0:
		_pending_free_kick = false
		_pending_penalty = false
		var fk_play := PlayGenerator.make("tiro_libre")
		fk_play["spot"] = _pending_fk_spot
		_pending_fk_spot = Vector3.ZERO
		_start_moment(Moment.FREE_KICK, fk_play)
	elif not _moments.is_empty() and minute >= float(_moments[0].minute):
		var mo: Dictionary = _moments.pop_front()
		_start_moment(mo.kind, mo.get("play", {}))
	elif minute >= match_end:
		_end_match()


## Lo que pasa en el resto del partido mientras no intervienes.
func _simulate_minute(m: int) -> void:
	if m == 45:
		_halftime_pending = true
	elif m == 105 and _extra_time_active:
		pass
	if _on_pitch_now():
		# Cansancio por minuto: un 60 de resistencia acaba los 90' con ~45% de energía
		stamina = maxf(stamina - lerpf(0.0085, 0.0045, star.stat("stamina")), 0.05)
	if m == 105 and _extra_time_active:
		_extra_time_break_pending = true
	if not entered and m >= int(_bench_until):
		_enter_from_bench(m)
		if state != State.SIMULATING:
			return # no mezclar la escena del cambio con el relato del minuto
	var rate := [float(config.get("goal_rate_home", 0.005)), float(config.get("goal_rate_away", 0.008))]
	rate = [rate[0] * _tactic_rates[0], rate[1] * _tactic_rates[1]] # la charla del descanso
	if sent_off: # con uno menos: marcas menos y te marcan más (la carrera lo ajusta con "sent_off_rates")
		var k: Array = config.get("sent_off_rates", [0.75, 1.3])
		rate = [rate[0] * float(k[0]), rate[1] * float(k[1])]
	var r := randf()
	if r < rate[1]:
		var who1 := _scorer_name(1)
		_start_ambient_goal(1, m, who1)
		return
	elif r < rate[1] + rate[0]:
		var who0 := _scorer_name(0)
		_start_ambient_goal(0, m, who0)
		return
	elif r < rate[1] + rate[0] + 0.047:
		# Relato neutro, basado en quién lleva el balón: no narrar tiros/faltas
		# que la recreación 3D no está mostrando.
		var holder: SoccerPlayer = ball.owner_player
		if holder != null and holder.visible and randf() < 0.35:
			var miss_team := holder.team
			var miss_name := _name_of(holder) if not holder.is_keeper else _scorer_name(miss_team)
			_start_ambient_miss(miss_team, m, miss_name)
			return
		if holder != null and holder.visible:
			_hud.add_feed("%d'  %s conserva la posesión" % [m, TEAM_NAMES[holder.team]])
		else:
			_hud.add_feed("%d'  Balón dividido; ambos equipos buscan recuperarlo" % m)
	# Cambios: hasta 3 por equipo en la segunda parte (el cuarto árbitro levanta el cartel)
	if m >= 58 and m <= 86:
		for t in 2:
			if _subs_done[t] < 3 and randf() < 0.05:
				_subs_done[t] += 1
				var off := randi_range(2, PLAYERS_PER_TEAM - 1)
				if t == 0 and teams[0][off] == star:
					off = 1 if off != 1 else 2
				var num_off := (teams[t][off] as SoccerPlayer).index + 1
				var num_on: int = 11 + int(_subs_done[t]) * 2 + randi() % 2
				_hud.add_feed("%d'  Cambio en %s: entra el %d por el %d" % [m, TEAM_NAMES[t], num_on, num_off])
				staff.substitution(t, num_off, num_on)
				_hud.show_substitution(TEAM_NAMES[t], [profile.shirt, _kit_shirt1][t], num_off, num_on)


## Los goles de la simulación también se juegan en el césped: pausa el reloj,
## arma un remate corto con el goleador y el portero, y sólo suma el tanto al
## cruzar el balón la línea (o al cerrar el plano de seguridad).
func _start_ambient_goal(team: int, at_minute: int, scorer_name: String) -> void:
	var shooter: SoccerPlayer = null
	for p: SoccerPlayer in teams[team]:
		if _name_of(p) == scorer_name and not p.is_keeper:
			shooter = p
			break
	if shooter == null:
		shooter = _nearest_of_role(team, opponent_goal_center(team), ["ST", "MF"])
	if shooter == null:
		return

	_ambient_goal_team = team
	_ambient_goal_minute = at_minute
	_ambient_goal_name = scorer_name if scorer_name != "" else _name_of(shooter)
	_ambient_goal_shooter = shooter
	_ambient_goal_keeper = teams[1 - team][0]
	_ambient_goal_assist = null
	_ambient_goal_scored = false
	_ambient_keeper_dived = false
	_ambient_goal_timer = 6.0
	_ambient_is_miss = false
	_ambient_dive_wrong = randf() < 0.3
	_ambient_goal_shot_side = 1.0 if randf() < 0.5 else -1.0
	_ambient_goal_shot_height = randf_range(0.45, 0.95)
	_ambient_goal_shot_taken = false
	state = State.AMBIENT_GOAL
	Engine.time_scale = 1.0
	_freeze_players()

	var dir := attack_dir(team)
	var goal := opponent_goal_center(team)
	# Variedad de jugada previa: a veces el goleador recibe de un compañero.
	var assist: SoccerPlayer = null
	for mate: SoccerPlayer in teams[team]:
		if mate != shooter and not mate.is_keeper and mate.visible:
			assist = mate
			break
	var start_z := _ambient_goal_shot_side * randf_range(1.0, 6.0)
	var start := goal - Vector3(dir * randf_range(15.0, 21.0), 0.0, start_z)
	shooter.set_physics_process(true)
	shooter.visible = true
	var shoot_spot := goal - Vector3(dir * 9.0, 0.0, start_z * 0.6)
	shooter.reset_to(shoot_spot, flat(goal - shoot_spot).normalized())
	shooter.move_input = Vector3.ZERO
	shooter.sprinting = false
	if _ambient_goal_keeper != null:
		# Bien colocado, en la bisectriz entre el balón y la portería (el tiro va al otro palo)
		var keeper_pos := goal - Vector3(dir * 1.1, 0.0, 0.0)
		keeper_pos.z = lerpf(goal.z, shoot_spot.z, 0.2)
		_ambient_goal_keeper.set_physics_process(true)
		_ambient_goal_keeper.visible = true
		_ambient_goal_keeper.reset_to(keeper_pos, flat(shoot_spot - keeper_pos).normalized())
	if assist != null:
		_ambient_goal_assist = assist
		assist.set_physics_process(true)
		assist.visible = true
		var assist_start := goal - Vector3(dir * 22.0, 0.0, start_z * 0.3)
		assist.reset_to(assist_start, flat(shoot_spot - assist_start).normalized())
		assist.move_input = Vector3.ZERO
		_give_ball_now(assist)
		assist.pass_ball(shooter)
		_hud.add_feed("%d'  %s recibe de %s y define" % [at_minute, _ambient_goal_name if _ambient_goal_name != "" else TEAM_NAMES[team],
				_name_of(assist)])
	else:
		_give_ball_now(shooter)
		shooter.shoot_exact(goal + Vector3(0.0, _ambient_goal_shot_height, _ambient_goal_shot_side * (GOAL_WIDTH * 0.5 - randf_range(0.4, 0.9))), 0.68)
		_ambient_goal_shot_taken = true
		_hud.add_feed("%d'  %s conduce y dispara" % [at_minute, _ambient_goal_name if _ambient_goal_name != "" else TEAM_NAMES[team]])
	SoundFx.set_crowd(-7.0)


func _start_ambient_miss(team: int, at_minute: int, shooter_name: String) -> void:
	var shooter: SoccerPlayer = null
	for pp: SoccerPlayer in teams[team]:
		if _name_of(pp) == shooter_name and not pp.is_keeper:
			shooter = pp
			break
	if shooter == null:
		shooter = _nearest_of_role(team, opponent_goal_center(team), ["ST", "MF"])
	if shooter == null:
		return
	_ambient_goal_team = team
	_ambient_goal_minute = at_minute
	_ambient_goal_name = shooter_name if shooter_name != "" else _name_of(shooter)
	_ambient_goal_shooter = shooter
	_ambient_goal_keeper = teams[1 - team][0]
	_ambient_goal_scored = false
	_ambient_keeper_dived = false
	_ambient_goal_timer = 4.0
	_ambient_is_miss = true
	_ambient_dive_wrong = randf() < 0.2
	_ambient_goal_shot_side = 1.0 if randf() < 0.5 else -1.0
	_ambient_goal_shot_height = randf_range(0.6, 1.4)
	_ambient_goal_shot_taken = true
	state = State.AMBIENT_GOAL
	Engine.time_scale = 1.0
	_freeze_players()
	var dir := attack_dir(team)
	var goal := opponent_goal_center(team)
	var wide := randf() < 0.5
	var target: Vector3
	if wide:
		target = goal + Vector3(0.0, randf_range(0.4, 1.2), _ambient_goal_shot_side * (GOAL_WIDTH * 0.5 + randf_range(0.6, 2.0)))
	else:
		target = goal + Vector3(0.0, GOAL_HEIGHT + randf_range(0.3, 1.2), randf_range(-2.0, 2.0))
	var start := goal - Vector3(dir * randf_range(14.0, 20.0), 0.0, _ambient_goal_shot_side * randf_range(1.0, 6.0))
	shooter.set_physics_process(true)
	shooter.visible = true
	shooter.reset_to(start, flat(goal - start).normalized())
	shooter.move_input = Vector3.ZERO
	shooter.sprinting = false
	if _ambient_goal_keeper != null:
		var keeper_pos := goal - Vector3(dir * 1.1, 0.0, 0.0)
		keeper_pos.z = lerpf(goal.z, start.z, 0.2)
		_ambient_goal_keeper.set_physics_process(true)
		_ambient_goal_keeper.visible = true
		_ambient_goal_keeper.reset_to(keeper_pos, flat(start - keeper_pos).normalized())
	_give_ball_now(shooter)
	shooter.shoot_exact(target, 0.72) # sin desvío: el fallo es fallo
	_hud.add_feed("%d'  %s prueba el disparo" % [at_minute, _ambient_goal_name if _ambient_goal_name != "" else TEAM_NAMES[team]])
	SoundFx.set_crowd(-9.0)


func _update_ambient_goal(delta: float) -> void:
	_ambient_goal_timer -= delta
	if not _ambient_keeper_dived and _ambient_goal_keeper != null and _ambient_goal_shot_taken \
			and ball.owner_player == null and ball.linear_velocity.length() > 5.0:
		_ambient_keeper_dive()
	_ambient_support_run()
	if not _ambient_goal_scored and not _ambient_goal_shot_taken and _ambient_goal_assist != null:
		# En esta fase nadie más toca el balón: el goleador sale a por el pase y lo controla
		# él (antes el pase le pasaba de largo y se quedaba quieto viéndolo rodar).
		var sh := _ambient_goal_shooter
		if ball.owner_player == null and ball.last_touch == _ambient_goal_assist:
			if flat_dist(sh.global_position, ball.global_position) < 0.9 and ball.global_position.y < 1.0:
				ball.trap(sh)
				_give_ball(sh)
			else:
				var meet := ball.global_position + flat(ball.linear_velocity) * 0.35
				AiBrain.move_to(sh, meet, 0.2, true)
		if ball.owner_player == _ambient_goal_shooter:
			var goal := opponent_goal_center(_ambient_goal_team)
			_ambient_goal_shooter.shoot_exact(goal + Vector3(0.0, _ambient_goal_shot_height, _ambient_goal_shot_side * (GOAL_WIDTH * 0.5 - randf_range(0.4, 0.9))), 0.68)
			_ambient_goal_shot_taken = true
		elif _ambient_goal_timer < 3.0:
			# Pase fallido: el goleador define igualmente
			var goal2 := opponent_goal_center(_ambient_goal_team)
			_give_ball_now(_ambient_goal_shooter)
			_ambient_goal_shooter.shoot_exact(goal2 + Vector3(0.0, _ambient_goal_shot_height, _ambient_goal_shot_side * (GOAL_WIDTH * 0.5 - randf_range(0.4, 0.9))), 0.68)
			_ambient_goal_shot_taken = true
	if _ambient_goal_scored:
		if _ambient_goal_timer <= 0.0:
			var shooter := _ambient_goal_shooter
			if shooter != null and is_instance_valid(shooter) and shooter.team == _ambient_goal_team \
					and not shooter.is_keeper and shooter.visible:
				_start_goal_celebration(shooter, _ambient_goal_team, _finish_ambient_goal, CELEB_DANCE_AMBIENT)
			else:
				_finish_ambient_goal()
		return
	if _ambient_goal_timer <= 0.0:
		# Si el balón no entró en la red, la ocasión se queda en nada: sin teletransporte
		# ni marcador (antes se forzaba el gol de golpe, después de verlo ir fuera).
		_hud.show_message("¡NO ENTRA!", 1.2)
		_hud.add_feed("%d'  Ocasión de %s, el balón se va" % [_ambient_goal_minute,
				_ambient_goal_name if _ambient_goal_name != "" else TEAM_NAMES[_ambient_goal_team]])
		_finish_ambient_goal()


## El portero de la jugada de fondo se estira al ver venir el balón: casi siempre hacia
## él pero sin llegar (el tiro va lejos de sus manos), a veces engañado al otro lado.
## Si va por encima del larguero, solo lo mira. Nunca queda en la trayectoria.
func _ambient_keeper_dive() -> void:
	var k := _ambient_goal_keeper
	var dir := attack_dir(_ambient_goal_team)
	var v := ball.linear_velocity
	var vx := v.x * dir
	var gap := (k.global_position.x - ball.global_position.x) * dir
	if gap < 0.0:
		_ambient_keeper_dived = true # ya pasó
		return
	if vx < 1.0:
		return
	var t := gap / vx
	# Engañado se tira antes (adivina); bien leído, en el último momento
	if t > SoccerPlayer.DIVE_LEAD + (0.3 if _ambient_dive_wrong else 0.1):
		return
	_ambient_keeper_dived = true
	var zp := ball.global_position.z + v.z * t
	var yp := clampf(ball.global_position.y + v.y * t - 4.9 * t * t, 0.3, 2.0)
	if yp > GOAL_HEIGHT + 0.1:
		return # se va por arriba: lo sigue con la mirada
	var kz := k.global_position.z
	var side := signf(zp - kz) if absf(zp - kz) > 0.05 else 1.0
	var tz: float
	if _ambient_dive_wrong:
		tz = kz - side * 2.0
	else:
		# Hacia el balón, pero las manos se quedan cortas (es gol / se va fuera)
		tz = zp - side * (1.2 if not _ambient_is_miss else 0.7)
		if (tz - kz) * side < 0.7:
			tz = kz + side * 0.7
	k.start_dive(Vector3(k.global_position.x, yp, tz), 1.0)


## El resto no se queda de estatua: los atacantes acompañan la jugada hacia el área
## y los defensores cierran hacia su portería.
func _ambient_support_run() -> void:
	var goal := opponent_goal_center(_ambient_goal_team)
	var dir := attack_dir(_ambient_goal_team)
	for p: SoccerPlayer in players:
		if not p.visible or p.is_keeper or p == _ambient_goal_shooter or p == _ambient_goal_assist:
			continue
		if flat_dist(p.global_position, goal) > 45.0:
			continue
		var target: Vector3
		if p.team == _ambient_goal_team:
			target = goal - Vector3(dir * (11.0 + (p.index % 4) * 3.0), 0.0, 0.0)
			target.z = clampf(p.global_position.z * 0.7, -18.0, 18.0)
		else:
			# Cierran por el lado del palo cercano, nunca en la línea del tiro (que va
			# al palo largo): si no, el balón les atravesaría
			var sh_z := _ambient_goal_shooter.global_position.z if _ambient_goal_shooter != null else 0.0
			target = goal - Vector3(dir * (4.0 + (p.index % 3) * 2.5), 0.0, 0.0)
			target.z = clampf(sh_z - _ambient_goal_shot_side * (2.5 + (p.index % 2) * 2.0), -14.0, 14.0)
		AiBrain.move_to(p, target, 1.5)


func _finish_ambient_goal() -> void:
	if _ambient_goal_team < 0:
		return
	var half_pending := _halftime_pending
	var extra_break_pending := _extra_time_break_pending
	_ambient_goal_team = -1
	_ambient_goal_shooter = null
	_ambient_goal_keeper = null
	_ambient_goal_assist = null
	_ambient_goal_scored = false
	_ambient_goal_timer = 0.0
	state = State.SIMULATING
	SoundFx.set_crowd(-14.0)
	_ambient_kickoff()
	if half_pending:
		_halftime_pending = false
		minute = 45.0
		_hud.add_feed("45'  Descanso")
		if _wants_locker():
			_start_locker()
	elif extra_break_pending:
		_extra_time_break_pending = false
		minute = 105.0
		_start_extra_time_break()


## Durante la simulación se ve un partido de fondo, solo como ambiente: al empezar,
## saque de centro; tras una jugada, el juego sigue con un medio en su campo.
func _ambient_kickoff() -> void:
	_offside_snap = {}
	_var_pending = {}
	if minute < 1.0:
		var kicking := randi() % 2
		for t in 2:
			for i in PLAYERS_PER_TEAM:
				var p: SoccerPlayer = teams[t][i]
				p.reset_to(to_world(t, _bases[t][i]), Vector3(attack_dir(t), 0.0, 0.0))
		var kicker: SoccerPlayer = _nearest_of_role(kicking, Vector3.ZERO, ["ST"])
		_place(kicker, to_world(kicking, Vector3(-0.6, 0.0, 0.0)))
		_give_ball_now(kicker)
		return
	var team := randi() % 2
	var bp := to_world(team, Vector3(randf_range(-25.0, 0.0), 0.0, randf_range(-15.0, 15.0)))
	possession_team = team
	_place_team_for(bp, team)
	var carrier: SoccerPlayer = _nearest_of_role(team, bp, ["MF"])
	_place(carrier, bp)
	_give_ball_now(carrier)


# ---------- salida de los equipos ----------

## Los dos equipos salen del túnel en fila, con los árbitros delante en medio, y se
## alinean en la mitad del campo mirando a la cámara de TV. Luego, saque de centro.
var _tifo_v := 0.0
var _tifo_shot := 0.0 # segundos de plano del tifo al empezar la salida


func _start_walkout() -> void:
	state = State.WALKOUT
	_walk_t = 0.0
	# Si el fondo local tiene tifo, la realización abre con él mientras se despliega
	var tifo := get_node_or_null("Tifo") as Node3D
	_tifo_shot = 3.6 if tifo else 0.0
	_walk_done_t = 0.0
	_walk_delay.clear()
	_walk_via.clear()
	# Salen desde dentro del pasillo del túnel (sin colisión hasta pisar el césped)
	var tunnel_mouth_z := -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS
	var exit := Vector3(FieldBuilder.TUNNEL_X, 0.0, tunnel_mouth_z - 0.8)
	for t in 2:
		for i in PLAYERS_PER_TEAM:
			var p: SoccerPlayer = teams[t][i]
			# Dos filas dentro del hueco del túnel, con espacio entre jugadores:
			# antes los 22 se apilaban en sólo dos puntos y parecían teletransportarse.
			# Salen por la puerta iluminada del vestuario, al fondo del pasillo: se
			# les ve cruzar la luz y recorrer el túnel, no "aparecer" en la boca.
			p.reset_to(_door_spot(t), Vector3.BACK)
			p.visible = false
			p.walk_normal = true
			# Esperan en el túnel sin chocar entre ellos
			_walk_layers[p] = [p.collision_layer, p.collision_mask]
			p.collision_layer = 0
			p.collision_mask = 0
			_walk_delay[p] = WALK_TEAMS + i * WALK_GAP + _tifo_shot
			_walk_via[p] = false
	ball.reset_to(Vector3(0.0, SoccerBall.RADIUS, 0.0))
	ball.visible = false
	# Detrás de los titulares salen el banquillo y los técnicos, caminando a su sitio
	staff.parade_in(WALK_TEAMS + PLAYERS_PER_TEAM * WALK_GAP + _tifo_shot + 0.8)
	var refs: Array[Node3D] = staff.refs
	staff.ref_targets = [Vector3(0.0, 0.0, -1.2), Vector3(-0.9, 0.0, -1.2), Vector3(0.9, 0.0, -1.2)]
	# Los árbitros abren la salida (el central delante) y los equipos van detrás:
	# así la fila del centro del campo queda ordenada, con ellos en medio.
	staff.ref_delay = []
	staff.ref_hide_z = -INF
	staff.ref_walk_speed = SoccerPlayer.SPEED * WALK_PACE # al paso de los jugadores
	for i in refs.size():
		refs[i].position = Vector3(FieldBuilder.TUNNEL_X + (i - 1) * 0.45, 0.0, tunnel_mouth_z - 3.6)
		refs[i].rotation.y = 0.0
		refs[i].visible = false
		staff.ref_delay.append(WALK_REFS + _tifo_shot + (0.0 if i == 0 else 0.3))
	# Primero recto hasta la banda (como los jugadores), luego a su sitio
	staff.ref_via = []
	for i in refs.size():
		staff.ref_via.append(Vector3(FieldBuilder.TUNNEL_X + (i - 1) * 0.8, 0.0, -FIELD_WIDTH * 0.5 + 2.0))
	_cam_pos = exit + Vector3(6.0, 3.0, 14.0)
	_cam_look = exit
	_hud.set_sim_visible(false)
	# Las alineaciones salen con la fila formada: no tapan a los que salen del túnel
	_hud.show_walkout_intro(_walkout_intro_data(), 0.4, false)
	# La tribuna habla de ti (trapos con tu nombre o silbidos): la frase va en la
	# línea de abajo, que no choca con el cartel ni las alineaciones de la tele.
	var crowd_line := String(FieldBuilder.crowd.get("line", ""))
	_hud.set_hint((crowd_line + " · " if crowd_line != "" else "Salen los equipos · ") + "toca para empezar")
	FieldBuilder.set_crowd_excitement(self, 1.0)
	SoundFx.play("cheer", -4.0)
	SoundFx.set_crowd(-6.0)
	# Bengalas en los dos fondos mientras salen los equipos
	FieldBuilder.flares(self, 1.0, _kit_shirt1, 9.0)
	if _tifo_shot <= 0.0: # con tifo, el humo del fondo local sale después del plano
		FieldBuilder.flares(self, -1.0, profile.shirt, 9.0)


## Punto de salida de cada equipo: justo tras la puerta del vestuario, al fondo del pasillo.
func _door_spot(team: int) -> Vector3:
	var mouth_z := -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS
	return Vector3(FieldBuilder.TUNNEL_X + (-0.45 if team == 0 else 0.45), 0.0, mouth_z - 3.6)


## Datos del cartel y las alineaciones que la tele enseña mientras salen los equipos.
func _walkout_intro_data() -> Dictionary:
	var lineups: Array = [[], []]
	for t in 2:
		# Se estira la formación para que ocupe todo el dibujo (portero abajo, puntas arriba)
		var x0 := INF
		var x1 := -INF
		var zw := 1.0
		for b: Vector3 in _bases[t]:
			x0 = minf(x0, b.x)
			x1 = maxf(x1, b.x)
			zw = maxf(zw, absf(b.z))
		for i in PLAYERS_PER_TEAM:
			var p: SoccerPlayer = teams[t][i]
			var b: Vector3 = _bases[t][i]
			var full := String(_names[t][i]) if i < _names[t].size() else ""
			# Si estás de suplente, el hueco lo ocupa el titular real: no te marques
			# ni muestres tu nombre en la gráfica de formación inicial.
			var you := t == 0 and p == star and _bench_until <= 0.0
			if you:
				full = String(profile.player_name)
			var num := _shirt_number(t, i)
			var words := full.split(" ", false)
			lineups[t].append({
				"x": 0.5 + b.z / zw * 0.4, # a lo ancho de todo el dibujo
				"y": 0.1 + 0.8 * (1.0 - (b.x - x0) / maxf(x1 - x0, 1.0)),
				"num": num, "name": words[-1] if words.size() > 0 else "", "you": you})
	return {"names": TEAM_NAMES, "colors": [profile.shirt, _kit_shirt1],
		"colors2": [Color(String(config.get("home_color2", "#ffffff"))), Color(String(config.get("away_color2", "#ffffff")))],
		"competition": String(config.get("competition", "")), "stadium": String(config.get("stadium", "")),
		"formations": formations, "lineups": lineups,
		"crests": [config.get("home_crest"), config.get("away_crest")],
		"coaches": [String(config.get("home_coach", "")), String(config.get("away_coach", ""))]}


## Posición de cada uno en la fila de la mitad del campo (local a la izquierda de la cámara).
func _walk_slot(p: SoccerPlayer) -> Vector3:
	var side := -1.0 if p.team == 0 else 1.0
	return Vector3(side * (1.9 + p.index * 1.05), 0.0, -2.0)


func _update_walkout(delta: float) -> void:
	_tifo_v = minf(_tifo_v + delta * 0.4, 1.0) # el fondo local despliega el tifo
	if _tifo_shot > 0.0 and _walk_t < _tifo_shot and _walk_t + delta >= _tifo_shot:
		FieldBuilder.flares(self, -1.0, profile.shirt, 7.0)
	FieldBuilder.set_tifo(self, smoothstep(0.0, 1.0, _tifo_v))
	_walk_t += delta
	var all_in := true
	for p: SoccerPlayer in players:
		if _walk_t < float(_walk_delay[p]):
			all_in = false
			continue
		if not p.visible:
			# Cruza la puerta: desde aquí choca con los demás (no se atraviesan) pero
			# no con los muros del estadio, que cierran la grada donde está el túnel.
			p.visible = true
			p.collision_layer = WALK_BODY_LAYER
			p.collision_mask = WALK_BODY_LAYER
		# Primero recto hasta la banda (las dos filas juntas), luego a su sitio en la fila
		var target := _walk_slot(p)
		if not bool(_walk_via[p]):
			target = Vector3(FieldBuilder.TUNNEL_X + (-0.8 if p.team == 0 else 0.8), 0.0, -FIELD_WIDTH * 0.5 + 3.0)
			# Cambia de rumbo antes de pisar el punto: abre la curva hacia su sitio
			# en vez de clavar un giro de 90° encima de él. Sin choques hasta el
			# saque: con la física puesta, en la fila apretada se empujaban.
			if flat_dist(p.global_position, target) < 2.2:
				_walk_via[p] = true
		AiBrain.move_to(p, target, 0.25)
		p.move_input *= _walk_pace(p)
		_keep_spacing(p)
		p.sprinting = false
		if bool(_walk_via[p]) and flat_dist(p.global_position, target) < 0.3:
			p.move_input = Vector3.ZERO
			p.ease_facing(Vector3.BACK, delta) # se da la vuelta hacia la cámara, sin pegar el giro
		else:
			all_in = false
	# Chorros de CO2 a los lados de la manga cuando asoman los primeros
	var first_out := WALK_REFS + 1.1 + _tifo_shot # los árbitros asoman a la boca
	if _walk_t - delta < first_out and _walk_t >= first_out:
		_tunnel_jets()
	if all_in:
		if _walk_done_t == 0.0:
			_hud.show_walkout_lineups(WALK_LINE_PAN - 1.0)
			# Ya en fila: aplauden a la grada (cada uno a su ritmo) y saludan con la mano
			for p: SoccerPlayer in players:
				var d := randf_range(0.0, 1.4)
				var act: String = ["clap", "clap", "victory", "fist_pump"].pick_random()
				get_tree().create_timer(d, false).timeout.connect(func() -> void:
					if is_instance_valid(p) and state == State.WALKOUT:
						p.play_action(act, 1.0, 1.6))
		_walk_done_t += delta
		if _walk_done_t > WALK_LINE_PAN:
			_end_walkout()


## Ya dentro del vestuario: invisible y sin cuerpo. Antes seguía siendo sólido y
## taponaba el pasillo: los de atrás se quedaban apretados empujando en la manga.
func _vanish(p: SoccerPlayer) -> void:
	p.move_input = Vector3.ZERO
	p.sprinting = false
	p.visible = false
	p.collision_layer = 0
	p.collision_mask = 0


## Paso de la procesión: todos igual (sin el extra del atributo de velocidad), al
## mismo ritmo que los árbitros; si no, los rápidos los alcanzaban y se mezclaban.
func _walk_pace(p: SoccerPlayer) -> float:
	return WALK_PACE / lerpf(0.86, 1.14, p.stat("speed"))


## Andando en grupo (túnel): si alguien va justo delante, afloja el paso; si hay
## alguien pegado, se abre un poco hacia un lado. Así no se atraviesan ni se empujan.
func _keep_spacing(p: SoccerPlayer) -> void:
	var mv := p.move_input
	if mv.length() < 0.05:
		return
	var dir := mv.normalized()
	var slow := 1.0
	var push := Vector3.ZERO
	for o: SoccerPlayer in players:
		if o == p or not o.visible:
			continue
		var off := flat(p.global_position - o.global_position)
		var d := off.length()
		if d < 0.001 or d > 1.2:
			continue
		var ahead := (-off / d).dot(dir)
		if ahead > 0.55:
			slow = minf(slow, clampf((d - 0.55) / 0.6, 0.0, 1.0))
		push += off / d * (1.2 - d) * 0.9
	var side := push - dir * push.dot(dir) # solo de lado: no lo frena ni lo acelera
	p.move_input = (mv * maxf(slow, 0.12) + side * mv.length()).limit_length(mv.length())


const WALK_LINE_PAN := 5.5 # segundos de travelling a lo largo de la fila formada
const WALK_BODY_LAYER := 2   # capa de los jugadores (ver reset de la segunda parte)
const WALK_REFS := 1.0      # los árbitros cruzan la puerta del vestuario
const WALK_TEAMS := 3.0     # y detrás de ellos (unos metros), los equipos
const WALK_GAP := 0.36      # segundos entre un jugador y el siguiente al salir del túnel
const WALK_PACE := 0.6      # paso de la salida (fracción de la carrera)
const OUTRO_PACE := 0.46    # paso de la vuelta al túnel (caminando, no al trote)
const TUNNEL_SHOT := 5.6    # segundos de plano desde el césped mirando a la boca del túnel


## Textura de bocanada de humo: círculo blanco que se desvanece hacia el borde.
static var _puff_tex: Texture2D = null
static func _soft_puff() -> Texture2D:
	if _puff_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_puff_tex = t
	return _puff_tex


## Dos columnas de humo blanco (CO2) a los lados de la salida de la manga.
func _tunnel_jets() -> void:
	var z := -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_BOARDS + 0.9
	var smoke := StandardMaterial3D.new()
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.vertex_color_use_as_albedo = true
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Bocanada redonda y difusa: sin textura cada partícula era un cuadrado blanco
	# (los "bloques" que tapaban la salida del túnel).
	smoke.albedo_texture = _soft_puff()
	# Aditivo: el humo solo aclara. Con mezcla normal algunas bocanadas pegadas a
	# la cámara salían como manchas negras.
	smoke.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smoke.albedo_color = Color(0.85, 0.85, 0.85)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	quad.material = smoke
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	for sx: float in [-1.0, 1.0]:
		var jet := CPUParticles3D.new()
		jet.mesh = quad
		jet.amount = 70
		jet.lifetime = 1.8
		jet.explosiveness = 0.0
		jet.direction = Vector3(0.0, 1.0, 0.0)
		jet.spread = 9.0
		jet.initial_velocity_min = 6.0
		jet.initial_velocity_max = 8.5
		jet.gravity = Vector3(0.0, -2.5, 0.0)
		jet.damping_min = 2.5
		jet.damping_max = 3.5
		jet.scale_amount_min = 0.6
		jet.scale_amount_max = 1.6
		jet.color_ramp = fade
		jet.position = Vector3(FieldBuilder.TUNNEL_X + sx * 3.1, 0.2, z)
		add_child(jet)
		jet.emitting = true
		# Dos ráfagas, como en los estadios grandes
		var tw := create_tween()
		tw.tween_interval(1.6)
		tw.tween_callback(func() -> void: jet.emitting = false)
		tw.tween_interval(0.8)
		tw.tween_callback(func() -> void: jet.emitting = true)
		tw.tween_interval(1.4)
		tw.tween_callback(func() -> void: jet.emitting = false)
		tw.tween_interval(2.5)
		tw.tween_callback(jet.queue_free)
	SoundFx.play("cheer", -6.0)


func _walk_release(p: SoccerPlayer) -> void:
	p.visible = true
	if _walk_layers.has(p):
		p.collision_layer = _walk_layers[p][0]
		p.collision_mask = _walk_layers[p][1]
		_walk_layers.erase(p)


func _end_walkout() -> void:
	if state != State.WALKOUT:
		return
	_hud.hide_walkout_intro()
	# Si se saltó la salida (o empiezas en el banco y va el plano tuyo sentado), el
	# banquillo ya está en su sitio; si no, los últimos terminan de llegar con el balón en juego.
	if _walk_done_t <= 0.0 or _bench_until > 0.0:
		staff.parade_finish()
	for p in players:
		_walk_release(p)
		p.walk_normal = false
	ball.visible = true
	staff.ref_targets = []
	staff.ref_delay = []
	for r: Node3D in staff.refs:
		r.visible = true # si se saltó la salida con alguno aún en el vestuario
	var tw := create_tween() # el tifo se recoge al empezar
	tw.tween_method(func(v: float) -> void: FieldBuilder.set_tifo(self, v), 1.0, 0.0, 1.5)
	FieldBuilder.set_crowd_excitement(self, 0.0)
	SoundFx.set_crowd(-14.0)
	SoundFx.play("whistle", -4.0)
	_hud.hide_message()
	_hud.set_hint("")
	_hud.set_sim_visible(true)
	minute = 0.0
	state = State.SIMULATING
	_ambient_kickoff()
	if _bench_until > 0.0 and staff.user_seat != null:
		# Empiezas de suplente: plano de ti sentado en el banquillo
		_start_cutscene(staff.user_seat, 4.0, false)
		_hud.show_message("%s empieza en el banco" % profile.player_name, 3.0)


func _start_replay() -> void:
	# P0-10 · La tanda también se puede rever: se graba entera y, al terminar,
	# el botón abre la cancha de repetición con cámara libre.
	if state == State.PENALTY_SHOOTOUT and _shootout_phase == "winner" and replay.has_frames():
		_hud.show_replay_button(false)
		_replay_return_state = state
		_replay_return_phase = _shootout_phase
		state = State.REPLAY
		replay.play(self, _resume_shootout_after_replay)
		return
	if state != State.MOMENT_RESULT or not replay.has_frames():
		return
	_hud.show_replay_button(false)
	state = State.REPLAY
	replay.play(self)


## Al cerrar la repetición de la tanda se vuelve al ganador y, si el jugador
## quiere, se puede ver otra vez o dejar que el partido termine.
func _resume_shootout_after_replay() -> void:
	_camera.make_current()
	state = _replay_return_state if _replay_return_state >= 0 else State.PENALTY_SHOOTOUT
	_shootout_phase = _replay_return_phase
	_shootout_timer = 3.0
	_replay_return_state = -1
	_replay_return_phase = ""
	_hud.show_message("TANDA DE PENALES\n%s gana %d - %d" % [
		TEAM_NAMES[_shootout_winner_team], _shootout_scores[0], _shootout_scores[1]], 999.0)
	_hud.show_replay_button(replay.has_frames())


## Lo llama la repetición al cerrarse: vuelve al final de la jugada y sigue el partido.
func end_replay() -> void:
	_camera.make_current()
	state = State.MOMENT_RESULT
	_timer = 0.4


func _back_to_simulation() -> void:
	_hud.show_replay_button(false)
	state = State.SIMULATING
	var match_end := 120.0 if _extra_time_active else MATCH_MINUTES
	minute = minf(minute + 1.0, match_end)
	_hud.set_sim_visible(true)
	_ambient_kickoff()
	if sent_off and star.visible:
		# Expulsado: se va al vestuario (tu equipo sigue con uno menos)
		star.visible = false
		star.collision_layer = 0
		star.collision_mask = 0
		star.move_input = Vector3.ZERO
		star.velocity = Vector3.ZERO
		star.global_position = Vector3(FieldBuilder.TUNNEL_X, 0.0, -FIELD_WIDTH * 0.5 - 6.0)
		_hud.add_feed("%d'  Te vas expulsado al vestuario" % int(minute))


func _end_match() -> void:
	if state in [State.OUTRO, State.ENDED, State.PENALTY_SHOOTOUT]:
		return
	Engine.time_scale = 1.0
	if _needs_extra_time():
		_start_extra_time()
		return
	if _needs_shootout():
		_start_penalty_shootout()
		return
	_finish_match()


func _has_return_leg() -> bool:
	return bool(config.get("has_tie_carry", false))


func _aggregate_score() -> Array:
	return [int(score[0]) + int(config.get("carry_us", 0)),
		int(score[1]) + int(config.get("carry_them", 0))]


func _aggregate_tied() -> bool:
	var agg := _aggregate_score()
	return int(agg[0]) == int(agg[1])


func _needs_extra_time() -> bool:
	if not bool(config.get("knockout", false)) or _extra_time_active:
		return false
	if bool(config.get("two_leg_first_leg", false)):
		return false # la ida nunca tiene prórroga: se decide en la vuelta
	return _aggregate_tied()


func _needs_shootout() -> bool:
	return _extra_time_active and bool(config.get("knockout", false)) and _aggregate_tied()


func _winner_team() -> int:
	if _shootout_winner_team >= 0:
		return _shootout_winner_team
	var agg := _aggregate_score()
	if int(agg[0]) > int(agg[1]):
		return 0
	if int(agg[1]) > int(agg[0]):
		return 1
	return -1


func _start_extra_time() -> void:
	_extra_time_active = true
	minute = 90.0
	state = State.SIMULATING
	Engine.time_scale = 1.0
	_set_human(null)
	_hud.set_sim_visible(true)
	_hud.set_hint("")
	var agg := _aggregate_score()
	_hud.show_message("EMPATE GLOBAL  %d - %d\nPRÓRROGA · 2 tiempos de 15'" % [agg[0], agg[1]], 3.0)
	_hud.add_feed("90'  El global está empatado. Comienza la prórroga")
	SoundFx.play("whistle", -3.0)
	Haptics.hit("whistle")
	SoundFx.set_crowd(-8.0)
	_ambient_kickoff()


func _finish_match() -> void:
	state = State.ENDED
	Engine.time_scale = 1.0
	_hud.show_replay_button(false)
	SoundFx.play("whistle_end", -3.0)
	Haptics.hit("whistle")
	_set_human(null)
	_hud.set_sim_visible(false)
	_hud.set_hint("")
	var winner := _winner_team()
	var result: String = "EMPATE" if winner < 0 else "GANA " + String(TEAM_NAMES[winner])
	var trophy := String(config.get("final_trophy", ""))
	if trophy != "" and winner == 0:
		_trophy = TrophyCeremony.new()
		add_child(_trophy)
		_trophy.start(self, trophy)
		_tap_lock = Time.get_ticks_msec() + 3500
		_hud.show_message("¡CAMPEONES!\n" + trophy, 3.0)
		get_tree().create_timer(TrophyCeremony.DURATION).timeout.connect(func() -> void:
			if state == State.ENDED:
				_start_outro())
		return
	_start_outro()


func _start_penalty_shootout() -> void:
	state = State.PENALTY_SHOOTOUT
	Engine.time_scale = 1.0
	_set_human(null)
	_freeze_players()
	ball.freeze = false
	ball.visible = true
	for team in 2:
		for i in teams[team].size():
			_place_shootout_waiter(teams[team][i])
	_hud.set_sim_visible(false)
	_hud.set_hint("")
	_shootout_scores = [0, 0]
	_shootout_kicks = [0, 0]
	_shootout_cursor = 0
	_shootout_sudden = 0
	_shootout_ball_entered = false
	_shootout_winner_team = -1
	_shootout_in_user_kick = false
	_shootout_sequence = _build_shootout_sequence()
	replay.begin() # P0-10: la tanda entera queda grabada para reverla
	_hud.add_feed("120'  El global sigue empatado. Tanda de penales")
	SoundFx.play("whistle", -2.0)
	Haptics.hit("big")
	_shootout_phase = ""
	_start_next_shootout_kick()


func _build_shootout_sequence() -> Array:
	var sequence: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Siempre las 5 tandas reglamentarias por equipo: el ganador se decide con
	# los resultados REALES. Antes se recortaba la lista usando los resultados
	# previstos, pero el penalti del usuario puede no coincidir con el plan y la
	# tanda terminaba antes de tiempo (o abría una segunda jugada).
	for round in 5:
		for team in 2:
			sequence.append({"team": team, "outcome": _roll_shootout_outcome(team, round, rng)})
	return sequence


func _roll_shootout_outcome(team: int, kick_index: int, rng: RandomNumberGenerator) -> String:
	var taker := _shootout_taker(team, kick_index)
	var keeper: SoccerPlayer = teams[1 - team][0]
	var p := 0.76
	if taker != null:
		p += (taker.stat("shooting") - 0.5) * 0.18
		p += (taker.stat("composure") - 0.5) * 0.08
	if keeper != null:
		p -= (keeper.keeper_skill() - 0.5) * 0.16
	p = clampf(p, 0.6, 0.9)
	var r := rng.randf()
	if r < p:
		return "goal"
	if r < p + 0.18:
		return "saved"
	return "miss"


func _shootout_taker(team: int, kick_index: int) -> SoccerPlayer:
	var takers: Array[SoccerPlayer] = []
	if team == 0 and star != null and star.visible:
		takers.append(star)
	for p: SoccerPlayer in teams[team]:
		if p.is_keeper or p == star or not p.visible:
			continue
		takers.append(p)
	if takers.is_empty():
		return teams[team][1] if teams[team].size() > 1 else teams[team][0]
	return takers[kick_index % takers.size()]


func _place_shootout_waiter(p: SoccerPlayer) -> void:
	var x := -4.0 if p.team == 0 else 4.0
	var z := (float(p.index) - 5.0) * 0.88
	p.visible = true
	p.set_physics_process(true)
	p.collision_layer = 0
	p.collision_mask = 0
	p.reset_to(Vector3(x, 0.0, z), Vector3(attack_dir(p.team), 0.0, 0.0))


func _finish_shootout() -> void:
	_start_next_shootout_kick()


func _start_next_shootout_kick() -> void:
	state = State.PENALTY_SHOOTOUT
	Engine.time_scale = 1.0
	_hud.hide_power()
	_set_human(null)
	_shot_pending = false
	_saved = false
	_penalty_kicked = false
	_rebound_done = false
	_moment_goal = -1
	_shootout_in_user_kick = false
	_hud.show_replay_button(false)
	if _shootout_cursor >= _shootout_sequence.size():
		# El ganador sale del marcador real (el penalti del usuario puede no coincidir
		# con la secuencia planeada). Si sigue empatada, muerte súbita.
		if _shootout_scores[0] == _shootout_scores[1]:
			_shootout_sudden += 1
			if _shootout_sudden > 10:
				# Seguridad: una tanda no puede quedar en un bucle infinito.
				_shootout_sequence.append({"team": 0, "outcome": "goal"})
				_shootout_sequence.append({"team": 1, "outcome": "miss"})
			else:
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				for team in 2:
					_shootout_sequence.append({"team": team, "outcome": _roll_shootout_outcome(team, _shootout_kicks[team], rng)})
			_start_next_shootout_kick()
			return
		_shootout_winner_team = 0 if _shootout_scores[0] > _shootout_scores[1] else 1
		_hud.show_message("TANDA DE PENALES\n%s gana %d - %d" % [TEAM_NAMES[_shootout_winner_team], _shootout_scores[0], _shootout_scores[1]], 999.0)
		_hud.show_replay_button(replay.has_frames())
		_shootout_phase = "winner"
		_shootout_timer = 6.0
		return
	var kick: Dictionary = _shootout_sequence[_shootout_cursor]
	_shootout_team = int(kick.team)
	_shootout_goal = String(kick.outcome) == "goal"
	_shootout_ball_entered = false
	_shootout_shooter = _shootout_taker(_shootout_team, _shootout_kicks[_shootout_team])
	_shootout_keeper = teams[1 - _shootout_team][0]
	for p: SoccerPlayer in players:
		if p != _shootout_shooter and p != _shootout_keeper:
			_place_shootout_waiter(p)
	# El penalti del usuario se juega por el momento normal: el gesto decide
	# la potencia y direccion y los stats (shooting/control) afinan el disparo,
	# con el portero rival controlado por su reflejo (keeper_skill).
	if _shootout_team == 0 and _shootout_shooter == star and star.visible:
		_shootout_in_user_kick = true
		_start_moment(Moment.PENALTY, {})
		return
	_shootout_shot_side = 1.0 if randf() < 0.5 else -1.0
	var dir := attack_dir(_shootout_team)
	var goal := opponent_goal_center(_shootout_team)
	var mark := goal - Vector3(dir * PENALTY_DIST, 0.0, 0.0)
	var keeper_side := _shootout_shot_side if String(kick.outcome) == "saved" else -_shootout_shot_side
	var keeper_pos := goal - Vector3(dir * 0.8, 0.0, keeper_side * 0.7)
	_shootout_shooter.reset_to(mark, flat(goal - mark).normalized())
	_shootout_shooter.visible = true
	_shootout_shooter.set_physics_process(true)
	_shootout_keeper.reset_to(keeper_pos, flat(mark - keeper_pos).normalized())
	_shootout_keeper.visible = true
	_shootout_keeper.set_physics_process(true)
	match String(kick.outcome):
		"goal":
			_shootout_target = goal + Vector3(0.0, 0.8, _shootout_shot_side * (GOAL_WIDTH * 0.5 - 0.55))
		"saved":
			# El balón va a las manos del portero, delante de la línea; no debe
			# cruzar la red y contradecir una atajada ya decidida.
			_shootout_target = keeper_pos + Vector3(dir * 0.25, 1.0, 0.0)
		_:
			_shootout_target = goal + Vector3(0.0, 0.7, _shootout_shot_side * (GOAL_WIDTH * 0.5 + 1.3))
	ball.freeze = false
	ball.visible = true
	_give_ball_now(_shootout_shooter)
	_hud.show_message("TANDA DE PENALES\n%s · %d de %d   |   %d - %d" % [
		TEAM_NAMES[_shootout_team], _shootout_kicks[_shootout_team] + 1, 5, _shootout_scores[0], _shootout_scores[1]], 999.0)
	_shootout_phase = "prepare"
	_shootout_timer = 0.65


func _update_shootout(delta: float) -> void:
	if _shootout_phase == "winner":
		_shootout_timer -= delta
		if _shootout_timer <= 0.0:
			_finish_match()
		return
	if _shootout_phase == "prepare":
		_shootout_timer -= delta
		if _shootout_timer <= 0.0:
			var prepare_outcome: String = String(_shootout_sequence[_shootout_cursor].outcome)
			_shootout_shooter.shoot_at(_shootout_target, 0.58 if prepare_outcome == "saved" else 0.74)
			if prepare_outcome != "miss":
				var keeper_target := _shootout_target
				if _shootout_goal:
					keeper_target.z = -_shootout_shot_side * (GOAL_WIDTH * 0.5 - 0.5)
				_shootout_keeper.start_dive(keeper_target, 0.85)
			_shootout_phase = "flight"
			_shootout_timer = 0.5 if prepare_outcome == "saved" else 1.5
		return
	if _shootout_phase == "flight":
		var flight_outcome: String = String(_shootout_sequence[_shootout_cursor].outcome)
		# Sin rebote: al llegar a la línea de gol el balón se detiene donde se decidió
		# (parada o fuera). Un gol lo recoge la red.
		if flight_outcome != "goal" and not _shootout_ball_entered \
				and absf(ball.global_position.x - opponent_goal_center(_shootout_team).x) < 0.9:
			ball.owner_player = null
			ball.freeze = true
			ball.linear_velocity = Vector3.ZERO
			ball.global_position = _shootout_target
			if flight_outcome == "saved":
				_shootout_keeper.play_action("keeper_catch", 0.8, 1.0)
			_shootout_phase = "resolve"
			_shootout_timer = 0.75
			return
		if flight_outcome == "saved":
			_shootout_timer -= delta
			if _shootout_timer <= 0.0:
				ball.owner_player = null
				ball.freeze = true
				ball.global_position = _shootout_keeper.hands_position()
				_shootout_keeper.play_action("keeper_catch", 0.8, 1.0)
				_shootout_phase = "resolve"
				_shootout_timer = 0.75
			return
		if _shootout_ball_entered:
			_shootout_phase = "resolve"
			_shootout_timer = 0.7
			return
		_shootout_timer -= delta
		if _shootout_timer <= 0.0:
			ball.owner_player = null
			if _shootout_goal:
				ball.linear_velocity = Vector3.ZERO
				ball.global_position = _goal_areas[_shootout_team].global_position
				_on_goal_area_entered(ball, _shootout_team)
				_shootout_phase = "resolve"
				_shootout_timer = 0.7
			else:
				ball.freeze = true
				ball.linear_velocity = Vector3.ZERO
				ball.global_position = _shootout_target
				_shootout_phase = "resolve"
				_shootout_timer = 0.75
		return
	if _shootout_phase == "resolve":
		_shootout_timer -= delta
		if _shootout_timer > 0.0:
			return
		var resolve_outcome := String(_shootout_sequence[_shootout_cursor].outcome)
		if resolve_outcome == "goal":
			_shootout_scores[_shootout_team] += 1
		_shootout_kicks[_shootout_team] += 1
		_hud.add_feed("Penal %s: %s" % [TEAM_NAMES[_shootout_team], "¡gol!" if resolve_outcome == "goal" else ("atajado" if resolve_outcome == "saved" else "fuera")])
		_shootout_cursor += 1
		_start_next_shootout_kick()


var _trophy: TrophyCeremony
var _tap_lock := 0 # ms: hasta entonces tocar no cierra (que se vea la copa)


func _start_outro() -> void:
	if state == State.OUTRO:
		return
	state = State.OUTRO
	_outro_t = 0.0
	_outro_sent = false
	_outro_delay.clear()
	_outro_target.clear()
	Engine.time_scale = 1.0
	_set_human(null)
	_freeze_players()
	_hud.show_replay_button(false)
	_hud.set_sim_visible(false)
	_hud.set_hint("")
	_hud.show_final_card(_final_card_data(), 6.0)
	_hud.add_feed("%d'  Final del partido" % int(minute))
	SoundFx.play("whistle_end", -3.0)
	Haptics.hit("whistle")
	SoundFx.set_crowd(-4.0)
	# La copa ya terminó; libera a los jugadores colocados para la foto.
	if _trophy != null:
		_trophy.queue_free()
		_trophy = null
	_camera.make_current()
	_outro_via.clear()
	_outro_pace.clear()
	# Entran primero los que están más cerca del túnel (antes iban por dorsal y se
	# cruzaban todos); antes de irse aplauden a la grada.
	var mouth_v := Vector3(FieldBuilder.TUNNEL_X, 0.0, -FIELD_WIDTH * 0.5)
	var order: Array[SoccerPlayer] = []
	for p: SoccerPlayer in players:
		if p.visible:
			order.append(p)
	order.sort_custom(func(a: SoccerPlayer, b: SoccerPlayer) -> bool:
		return flat_dist(a.global_position, mouth_v) < flat_dist(b.global_position, mouth_v))
	var deep := FieldBuilder.TUNNEL_ROWS * FieldBuilder.ROW_DEPTH + 1.5
	for rank in order.size():
		var p: SoccerPlayer = order[rank]
		# Cuatro carriles en el pasillo (dos por equipo): en fila india se atascaban
		var col := (-1.0 if p.team == 0 else 1.0) * (0.55 if rank % 2 == 0 else 1.45)
		# Destino al fondo del pasillo: desaparecen ya dentro, sin "pop" en la boca
		_outro_target[p] = Vector3(FieldBuilder.TUNNEL_X + col, 0.0,
				-FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS - deep)
		_outro_via[p] = false
		# Se van de a poco, caminando: los más cercanos primero pero con huecos
		# irregulares, y unos cuantos se quedan un rato aplaudiendo a la grada.
		var lingers := randf() < 0.35
		_outro_delay[p] = 1.0 + float(rank) * 0.28 + randf_range(0.0, 0.7) + (1.4 if lingers else 0.0)
		_outro_pace[p] = OUTRO_PACE * randf_range(0.85, 1.15)
		var clap_d := randf_range(0.0, 0.5) + (float(_outro_delay[p]) - 1.8 if lingers else 0.0)
		# Los que ganan festejan (algún salto); los que pierden aplauden y se van cabizbajos
		var won := _winner_team() == p.team
		p.sad_gait = _winner_team() >= 0 and not won
		var act: String = (["clap", "fist_pump", "jump_cheer", "clap"] if won else ["clap"]).pick_random()
		get_tree().create_timer(maxf(clap_d, 0.0), false).timeout.connect(func() -> void:
			if is_instance_valid(p) and state == State.OUTRO:
				p.play_action(act, 1.0, 1.2)) # el giro a la grada lo hace _update_outro, de a poco
		p.stun_timer = 0.0
		p.set_physics_process(true) # los del podio de campeones estaban quietos a mano
		p.global_position.y = 0.0
		p.walk_normal = true
		# Entre ellos sí chocan (no se atraviesan en la manga); los muros no, para
		# poder meterse en el túnel.
		p.collision_layer = WALK_BODY_LAYER
		p.collision_mask = WALK_BODY_LAYER
	ball.freeze = true
	ball.owner_player = null
	ball.visible = false
	ball.global_position = Vector3(FieldBuilder.TUNNEL_X, 0.0, -FIELD_WIDTH * 0.5 - 12.0)
	var mouth_z := -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS
	# El banquillo y los técnicos también se van al vestuario, de a poco
	staff.parade_out(0.8)
	# Los árbitros se van juntos al vestuario: hasta el fondo del pasillo y ahí
	# desaparecen tras la puerta (antes se quedaban plantados en la boca).
	staff.ref_delay = []
	staff.ref_via = []
	for i in staff.refs.size():
		staff.ref_via.append(Vector3(FieldBuilder.TUNNEL_X + (i - 1) * 0.7, 0.0, -FIELD_WIDTH * 0.5 + 1.5))
	staff.ref_hide_z = mouth_z - 3.4
	staff.ref_targets = [
		Vector3(FieldBuilder.TUNNEL_X, 0.0, mouth_z - 4.2),
		Vector3(FieldBuilder.TUNNEL_X - 0.4, 0.0, mouth_z - 4.2),
		Vector3(FieldBuilder.TUNNEL_X + 0.4, 0.0, mouth_z - 4.2),
	]


func _update_outro(delta: float) -> void:
	_outro_t += delta
	var pending := 0
	var mouth_z := -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS
	for p: SoccerPlayer in players:
		if not p.visible or not _outro_target.has(p):
			continue
		if _outro_t < float(_outro_delay.get(p, 0.0)):
			p.move_input = Vector3.ZERO
			p.sprinting = false
			# Mientras esperan, se van girando hacia la grada del túnel (a aplaudir)
			if _outro_t > 0.6:
				p.ease_facing(Vector3.FORWARD, delta, 2.5)
			pending += 1
			continue
		var target: Vector3 = _outro_target[p]
		# Primero a la banda frente a la manga (en fila, por equipo), luego adentro
		if not bool(_outro_via.get(p, true)):
			var via := Vector3(target.x * 0.7 + FieldBuilder.TUNNEL_X * 0.3, 0.0, -FIELD_WIDTH * 0.5 + 1.2)
			if flat_dist(p.global_position, via) < 2.2: # curva abierta hacia la manga
				_outro_via[p] = true
			else:
				target = via
		var tunnel_depth := FieldBuilder.TUNNEL_ROWS * FieldBuilder.ROW_DEPTH - 0.35
		if mouth_z - p.global_position.z >= tunnel_depth:
			_vanish(p)
			continue
		if flat_dist(p.global_position, target) < 0.9:
			_vanish(p) # desaparece al entrar al túnel, no al acabar el plano
			continue
		AiBrain.move_to(p, target, 0.3, false)
		# Desde lejos vienen trotando y el último tramo, ya cerca de la manga, caminando
		var far := clampf((flat_dist(p.global_position, Vector3(FieldBuilder.TUNNEL_X, 0.0, mouth_z)) - 14.0) / 22.0, 0.0, 1.0)
		p.move_input *= float(_outro_pace.get(p, OUTRO_PACE)) * lerpf(1.0, 2.2, far) * _walk_pace(p) / WALK_PACE
		_keep_spacing(p)
		pending += 1
	if pending == 0 or _outro_t > 24.0:
		_finish_outro()


func _finish_outro() -> void:
	if _outro_sent:
		return
	_outro_sent = true
	for p: SoccerPlayer in players:
		p.move_input = Vector3.ZERO
		p.sprinting = false
		p.visible = false
	for ref: Node3D in staff.refs:
		ref.visible = false
	ball.visible = false
	_hud.hide_message()
	_hud.set_hint("")
	outro_finished.emit()


func finish_and_exit() -> void:
	if _finished_sent:
		return
	_finished_sent = true
	Engine.time_scale = 1.0
	var res := result()
	finished.emit(res)
	if config.has("on_finish"):
		(config.on_finish as Callable).call(res)
	else:
		get_tree().change_scene_to_file("res://scenes/editor.tscn")


## Datos del marcador final: equipos, escudos, resultado y goleadores con minuto.
func _final_card_data() -> Dictionary:
	var footer := ""
	if bool(config.get("has_tie_carry", false)):
		var aggregate := _aggregate_score()
		footer = "GLOBAL  %d - %d" % [aggregate[0], aggregate[1]]
	if _shootout_scores[0] + _shootout_scores[1] > 0:
		footer += ("   ·   " if footer != "" else "") + "PENALES  %d - %d" % [_shootout_scores[0], _shootout_scores[1]]
	var goals: Array = []
	for g: Dictionary in match_stats.goals_log:
		var who := String(g.get("name", ""))
		var words := who.split(" ", false)
		goals.append({"team": int(g.team), "minute": int(g.minute), "star": bool(g.get("star", false)),
			"name": words[-1] if words.size() > 0 else who})
	return {"names": TEAM_NAMES, "colors": [profile.shirt, _kit_shirt1],
		"colors2": [_kits[0].get("shirt_color2", Color.WHITE), _kits[1].get("shirt_color2", Color.WHITE)],
		"crests": [config.get("home_crest"), config.get("away_crest")],
		"score": [score[0], score[1]], "winner": _winner_team(), "goals": goals, "footer": footer,
		"competition": String(config.get("competition", ""))}


func _result_text() -> String:
	var winner := _winner_team()
	var text: String = "EMPATE" if winner < 0 else "GANA " + String(TEAM_NAMES[winner])
	if bool(config.get("has_tie_carry", false)):
		var aggregate := _aggregate_score()
		text += "\nGLOBAL  %d - %d" % [aggregate[0], aggregate[1]]
	if _shootout_scores[0] + _shootout_scores[1] > 0:
		text += "\nPENALES  %d - %d" % [_shootout_scores[0], _shootout_scores[1]]
	return text


## ---------- vestuario del descanso ----------

## En el 45' (si estás en el campo) el partido se para y vas al vestuario: charla del
## míster según el resultado y tu nota, y eliges cómo salir. Sin elegir, a los 12 s se sigue el plan.
const TACTICS := [
	{"label": "¡A por ellos!", "share": 0.12, "rates": [1.25, 1.2], "feed": "Salís a por todas"},
	{"label": "Seguid el plan", "share": 0.0, "rates": [1.0, 1.0], "feed": "Mismo plan en la segunda parte"},
	{"label": "Cerrad el partido", "share": -0.12, "rates": [0.8, 0.75], "feed": "Salís a cerrar el partido"},
]
var _locker: LockerRoom
var _halftime_pending := false
var _locker_wait := 0.0
var _tactic := 1
var _tactic_rates := [1.0, 1.0]
var _outro_t := 0.0
var _outro_delay: Dictionary = {}
var _outro_target: Dictionary = {}
var _outro_via: Dictionary = {} # punto en la banda, frente a la manga (ya pasó = true)
var _outro_pace: Dictionary = {} # paso de cada uno: caminan, cada cual a su ritmo
var _outro_sent := false
var _finished_sent := false
var _hud_key := ""
var _occlusion_acc := 0.0
var _ops_acc := 0.0
var _wave_shown := -1.0

# ---------- rendimiento ----------
# Resolución 3D adaptativa: en el móvil casi todo el coste es relleno de píxeles.
# Si el partido baja de ~50 fps se recorta un poco la resolución del 3D (la UI
# sigue nítida); si sobra margen se vuelve a subir. No toca la jugabilidad.
const PERF_MIN_SCALE := 0.65
const PERF_MAX_SCALE := 1.0
const PERF_LOW_FPS := 50.0
const PERF_HIGH_FPS := 58.0
var _perf_acc := 0.0
var _perf_scale := 1.0
var _ambient_goal_team := -1
var _ambient_goal_minute := 0
var _ambient_goal_name := ""
var _ambient_goal_shooter: SoccerPlayer
var _ambient_goal_keeper: SoccerPlayer
var _ambient_goal_timer := 0.0
var _ambient_goal_scored := false
var _ambient_keeper_dived := false
var _ambient_is_miss := false
var _ambient_dive_wrong := false
var _ambient_goal_shot_side := 1.0
var _ambient_goal_shot_height := 0.7
var _ambient_goal_shot_taken := false
var _ambient_goal_assist: SoccerPlayer = null
var _extra_time_active := false
var _extra_time_break_pending := false
var _shootout_scores := [0, 0]
var _shootout_kicks := [0, 0]
var _shootout_sequence: Array = []
var _shootout_cursor := 0
var _shootout_sudden := 0
var _shootout_team := 0
var _shootout_goal := false
var _shootout_ball_entered := false
var _shootout_phase := ""
var _shootout_timer := 0.0
var _shootout_in_user_kick := false
var _shootout_winner_team := -1
var _shootout_shooter: SoccerPlayer
var _shootout_keeper: SoccerPlayer
var _shootout_shot_side := 1.0
var _shootout_target := Vector3.ZERO
var _replay_return_state := -1
var _replay_return_phase := ""


func _wants_locker() -> bool:
	# El equipo entra al vestuario también si el usuario empezó como suplente
	# o fue expulsado: el descanso pertenece al partido, no a su estado en cancha.
	return bool(config.get("halftime_locker", true)) and star != null


func _start_locker() -> void:
	stamina = minf(stamina + 0.08, 1.0) # el descanso recupera un poco
	state = State.LOCKER
	Engine.time_scale = 1.0
	_freeze_players()
	SoundFx.play("whistle", -3.0)
	Haptics.hit("whistle")
	_locker = LockerRoom.new()
	add_child(_locker)
	_locker.position = Vector3(0.0, -400.0, 0.0) # lejos del estadio: no se ve nada de fuera
	_locker.build(self)
	_locker.camera.make_current()
	_locker_wait = 12.0
	_hud.set_sim_visible(false)
	_hud.set_hint("")
	SoundFx.set_crowd(-30.0)
	_hud.show_message("DESCANSO\n%s %d - %d %s" % [TEAM_NAMES[0], score[0], score[1], TEAM_NAMES[1]], 2.2, 0.62)
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if state != State.LOCKER:
			return
		_locker.focus_you()
		var names: Array[String] = []
		for t: Dictionary in TACTICS:
			names.append(String(t.label))
		if MatchState.user_player != null and int(MatchState.user_player.consumables.get("energy_drink", 0)) > 0:
			names.append("Usar bebida energizante")
		_hud.show_choices(_coach_title(), _halftime_speech(), names))


## Descanso corto entre los dos tiempos extra (105'): conserva el mismo vestuario 3D.
func _start_extra_time_break() -> void:
	state = State.LOCKER
	Engine.time_scale = 1.0
	_freeze_players()
	SoundFx.play("whistle", -3.0)
	Haptics.hit("whistle")
	_locker = LockerRoom.new()
	add_child(_locker)
	_locker.position = Vector3(0.0, -400.0, 0.0)
	_locker.build(self)
	_locker.camera.make_current()
	_locker_wait = 12.0
	_hud.set_sim_visible(false)
	_hud.set_hint("")
	SoundFx.set_crowd(-30.0)
	_hud.show_message("DESCANSO DE LA PRÓRROGA\n%s %d - %d %s" % [TEAM_NAMES[0], score[0], score[1], TEAM_NAMES[1]], 2.2, 0.62)
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if state != State.LOCKER:
			return
		_locker.focus_you()
		var names: Array[String] = []
		for tactic: Dictionary in TACTICS:
			names.append(String(tactic.label))
		if MatchState.user_player != null and int(MatchState.user_player.consumables.get("energy_drink", 0)) > 0:
			names.append("Usar bebida energizante")
		_hud.show_choices(_coach_title(), _extra_time_speech(), names))


func _extra_time_speech() -> String:
	var you := String(profile.player_name).get_slice(" ", 0)
	var line := "Quedan quince minutos. Cada jugada puede decidir el pase."
	if live_rating() >= 7.0:
		line += "\n%s, sigue pidiéndola." % you
	elif live_rating() < 6.0:
		line += "\n%s, necesito una última reacción." % you
	return line + "\n¿Cómo salimos?"


func _coach_title() -> String:
	var n := String(config.get("home_coach", ""))
	return "El míster" if n == "" else n


## Lo que dice el míster: según cómo va el partido y cómo lo estás haciendo tú.
func _halftime_speech() -> String:
	var d: int = score[0] - score[1]
	var line := ""
	if d > 0:
		line = "Vamos por delante, pero esto no ha acabado. Ni un balón regalado."
	elif d == 0:
		line = "Empate. Ellos están igual de cansados que vosotros: el que más quiera, gana."
	else:
		line = "¡Así no! Vamos %d abajo y quedan 45 minutos. Quiero ver otra cara." % -d
	var r := live_rating()
	var you := String(profile.player_name).get_slice(" ", 0)
	if r >= 7.0:
		line += "\n%s, estás siendo el mejor. Sigue pidiéndola." % you
	elif r < 6.0:
		line += "\n%s, necesito más de ti. Despierta." % you
	else:
		line += "\n%s, bien, pero puedes dar más." % you
	return line + "\n¿Cómo salimos?"


func _on_choice(i: int) -> void:
	if state != State.LOCKER:
		return
	if i == TACTICS.size():
		_use_halftime_drink()
		return
	_tactic = clampi(i, 0, TACTICS.size() - 1)
	var t: Dictionary = TACTICS[_tactic]
	_tactic_rates = (t.rates as Array).duplicate()
	_replan_second_half(float(t.share))
	_locker.cheer()
	_hud.show_message("¡VAMOS!", 1.4)
	_hud.add_feed("%d'  %s" % [106 if _extra_time_active and minute >= 105.0 else 46, String(t.feed)])
	SoundFx.set_crowd(-18.0)
	_locker_wait = 2.2 # un momento para ver la reacción y salimos


func _use_halftime_drink() -> void:
	var player: PlayerData = MatchState.user_player
	if player == null:
		return
	var used: Dictionary = ShopEngine.use_halftime(player)
	if not bool(used.get("ok", false)):
		return
	star.energy = 1.0
	stamina = maxf(stamina, 0.9)
	if MatchState.engine != null:
		MatchState.engine.set_fatigue_relief(float(used.get("relief", 0.0)))
	SaveManager.save_player(player)
	Haptics.hit("success")
	var names: Array[String] = []
	for tactic: Dictionary in TACTICS:
		names.append(String(tactic.label))
	_locker_wait = 12.0
	_hud.show_choices(_coach_title(), "Bebida energizante: energía recuperada. ¿Cómo salimos?", names)


## Las jugadas de la segunda parte se rehacen con la nueva actitud (más o menos ataque).
func _replan_second_half(share_delta: float) -> void:
	if star.role == "GK" or is_zero_approx(share_delta):
		return
	var share := clampf(float(config.get("attack_share", 0.55)) + share_delta, 0.2, 0.85)
	for e: Dictionary in _moments:
		if float(e.minute) <= 45.0 or not e.has("play"):
			continue
		var phase := PlayGenerator.pick_phase(star.role, share)
		var pl := PlayGenerator.generate(star.role, phase, _play_counts, _last_family)
		_play_counts[pl.family] = int(_play_counts.get(pl.family, 0)) + 1
		_last_family = pl.family
		e.kind = pl.base
		e.play = pl


func _update_locker(delta: float) -> void:
	_locker_wait -= delta
	if _locker_wait > 0.0:
		return
	if _hud.choices_visible():
		_hud.hide_choices()
		_on_choice(1) # sin respuesta: se sigue el plan
		return
	_locker.queue_free()
	_locker = null
	_camera.make_current()
	state = State.SIMULATING
	SoundFx.play("whistle", -4.0)
	Haptics.hit("whistle")
	SoundFx.set_crowd(-14.0)
	_hud.set_sim_visible(true)
	_ambient_kickoff()


## Resultado para FootballCareer: marcador (0 = tu equipo) y lo que pasó.
func result() -> Dictionary:
	var aggregate := _aggregate_score()
	var winner := _winner_team()
	return {"score": score.duplicate(), "stats": match_stats.duplicate(true), "star_position": star.role,
		"bench": _bench_until > 0.0, "entered": entered, "entry_minute": _entry_minute,
		"halftime_tactic": ["attack", "plan", "defend"][_tactic], "trophy_lifted": _trophy != null,
		"extra_time_played": _extra_time_active, "aggregate": aggregate,
		"shootout_score": _shootout_scores.duplicate(), "shootout_winner_team": _shootout_winner_team,
		"tie_winner_team": winner, "subbed_off": subbed_off, "exit_minute": _exit_minute,
		"end_stamina": stamina}


## El míster te mete al campo: el compañero de tu hueco sale y entras tú (con el cartel
## del cuarto árbitro y el rótulo de TV).
## Estamina visible y el botón de pedir entrar (solo en el banquillo, antes de la hora de entrada).
var _entry_request_min := -100.0

func _update_hud_extras() -> void:
	if _hud == null or star == null:
		return
	var on_pitch := _on_pitch_now() and state in [State.SIMULATING, State.MOMENT]
	# El sprint no puede pasar de lo que te queda; la barra baja un poco al esprintar
	if star.energy > maxf(stamina, 0.3):
		star.energy = maxf(stamina, 0.3)
	_hud.set_stamina(stamina * lerpf(0.85, 1.0, clampf(star.energy / maxf(stamina, 0.3), 0.0, 1.0)), on_pitch)
	_hud.show_exit_button(on_pitch and state == State.SIMULATING and minute < _match_end_minute() - 2.0)
	var can_request := state == State.SIMULATING and _bench_until > 0.0 and not entered and minute < _bench_until
	_hud.show_request_button(can_request)
	# Tu marca "TÚ" se pone naranja si estás adelantado y tu equipo tiene el balón
	if star.star_label != null:
		var adelantado := state == State.MOMENT and ball.owner_player != null and ball.owner_player.team == star.team \
				and ball.owner_player != star and is_offside_now(star)
		star.star_label.modulate = Color(1.0, 0.45, 0.15) if adelantado else Color(1.0, 0.92, 0.2)
		star.star_label.text = "TÚ · ADELANTADO" if adelantado else "TÚ"


func _on_pitch_now() -> bool:
	return star != null and star.visible and entered and not subbed_off and not sent_off


func _match_end_minute() -> float:
	return 120.0 if _extra_time_active else MATCH_MINUTES


## Pides el cambio: el técnico lo piensa según lo cansado que estés y el minuto.
func _on_exit_requested() -> void:
	if state != State.SIMULATING or not _on_pitch_now():
		return
	if _exit_request_min > -50.0 and minute - _exit_request_min < 5.0:
		_hud.show_message("El técnico: \"aguanta un poco más\"", 2.0)
		return
	_exit_request_min = minute
	var tired := 1.0 - stamina
	var chance := clampf(0.1 + tired * 0.9 + (0.15 if minute >= 60.0 else -0.1), 0.05, 0.95)
	if stamina < 0.3:
		chance = 0.95
	if randf() < chance:
		_hud.show_message("El técnico acepta: te vas al banquillo", 2.2)
		_sub_off_star(int(minute))
	else:
		_hud.show_message("El técnico dice que sigas en el campo", 2.2)


## Sales del campo: entra un suplente en tu hueco (con su nombre y su cara) y ya no
## hay más jugadas para ti; el partido sigue simulándose hasta el final.
func _sub_off_star(m: int) -> void:
	subbed_off = true
	_exit_minute = m
	_moments.clear()
	_pending_penalty = false
	_pending_free_kick = false
	_subs_done[0] += 1
	_sub_number = 12 + int(_subs_done[0]) * 2 + randi() % 2
	var sub_name := ""
	var bench: Array = (config.get("home_bench", []) as Array).duplicate()
	var pick: Dictionary = {}
	for d: Dictionary in bench:
		if String(d.get("position", "")) == star.role:
			pick = d
			break
	if pick.is_empty():
		for d: Dictionary in bench:
			if String(d.get("position", "")) != "GK":
				pick = d
				break
	if star.star_label:
		star.star_label.visible = false
	star.reset_generic_look()
	star.set_stats(SoccerPlayer.random_stats(randf_range(52.0, 64.0), star.is_keeper))
	if not pick.is_empty():
		sub_name = String(pick.get("name", ""))
		if pick.get("stats") is Dictionary:
			star.set_stats(pick.stats)
		if pick.get("look") is Dictionary:
			star.apply_look(pick.look)
	if not star.is_keeper:
		star.apply_colors({"shorts_color": profile.shorts, "socks_color": profile.socks})
		star.apply_colors(_kits[0])
	_names[0][star.index] = sub_name
	_bake_kit_decals()
	staff.substitution(0, int(profile.number), _sub_number)
	_hud.show_substitution(TEAM_NAMES[0], profile.shirt, int(profile.number), _sub_number)
	_hud.add_feed("%d'  Cambio en %s: sale %s, entra %s" % [m, TEAM_NAMES[0], profile.player_name,
			sub_name if sub_name != "" else "el %d" % _sub_number])
	_hud.show_exit_button(false)


func _on_entry_requested() -> void:
	if state != State.SIMULATING or entered or _bench_until <= 0.0:
		return
	if _entry_request_min > -50.0 and minute - _entry_request_min < 4.0:
		_hud.show_message("El técnico te ha pedido paciencia", 2.0)
		return
	_entry_request_min = minute
	# El técnico mira a su banquillo: más probable si tu media es alta y vas en forma
	var chance := clampf(0.2 + float(profile.overall()) / 100.0 * 0.6 + star.energy * 0.1, 0.0, 0.85)
	if randf() < chance:
		_hud.show_message("El técnico te da luz verde", 2.0)
		_enter_from_bench(int(minute))
	else:
		_hud.show_message("El técnico dice que no, por ahora", 2.5)


func _enter_from_bench(m: int) -> void:
	entered = true
	_entry_minute = m
	var off_name := _name_of(star)
	var num_off := star.index + 1
	_hud.add_feed("%d'  Cambio en %s: entra %s%s" % [m, TEAM_NAMES[0], profile.player_name, (" por " + off_name) if off_name != "" else ""])
	_hud.show_substitution(TEAM_NAMES[0], profile.shirt, num_off, profile.number)
	_names[0][star.index] = profile.player_name
	_subs_done[0] += 1
	var seat := staff.user_seat
	staff.substitution(0, num_off, profile.number, seat)
	if seat != null:
		_start_cutscene(seat, 16.0, true) # se acaba cuando pisas el campo (_on_sub_entered)
		_hud.show_message("¡TE TOCA!\nEntras al campo", 2.5)
	else:
		_swap_in_star(Vector3.INF)
	subbed_in.emit(m)


## Tu jugador sustituye al compañero de tu hueco (donde pisaste el campo, si hay escena).
func _swap_in_star(at: Vector3) -> void:
	star.set_stats(profile.stats)
	star.apply_profile(profile)
	_bake_kit_decals() # tu nombre a la espalda
	if not star.is_keeper:
		star.apply_colors(_kits[0])
	if star.star_label:
		star.star_label.visible = true
	if at != Vector3.INF:
		star.reset_to(Vector3(at.x, 0.0, at.z), Vector3.BACK)


func _on_sub_entered(pos: Vector3) -> void:
	if state == State.CUTSCENE and _cut_sub:
		_swap_in_star(pos)
		_end_cutscene()


# ---------- escenas (banquillo / cambio) ----------

func _start_cutscene(target: Node3D, secs: float, is_sub: bool) -> void:
	state = State.CUTSCENE
	_cut_target = target
	_cut_timer = secs
	_cut_sub = is_sub
	_hud.set_sim_visible(false)
	_hud.set_hint("")


func _end_cutscene() -> void:
	if state != State.CUTSCENE:
		return
	if _cut_sub and staff.user_seat != null:
		_swap_in_star(Vector3.INF) # por si la escena se acabó antes de pisar el campo
	_cut_target = null
	_cut_sub = false
	state = State.SIMULATING
	_hud.set_sim_visible(true)


func _restart() -> void:
	score = [0, 0]
	minute = 0.0
	_subs_done = [0, 0]
	entered = _bench_until <= 0.0
	_entry_minute = 0
	_halftime_pending = false
	_locker_wait = 0.0
	_tactic = 1
	_tactic_rates = [1.0, 1.0]
	_outro_t = 0.0
	_outro_sent = false
	_finished_sent = false
	_ambient_goal_team = -1
	_ambient_goal_scored = false
	_ambient_goal_timer = 0.0
	_ambient_keeper_dived = false
	_extra_time_active = false
	_extra_time_break_pending = false
	_shootout_scores = [0, 0]
	_shootout_kicks = [0, 0]
	_shootout_sequence.clear()
	_shootout_cursor = 0
	_shootout_winner_team = -1
	_shootout_phase = ""
	_shootout_ball_entered = false
	_outro_delay.clear()
	_outro_target.clear()
	ball.freeze = false
	for p: SoccerPlayer in players:
		p.visible = true
		p.walk_normal = false
		p.collision_layer = 2
		p.collision_mask = FieldBuilder.LAYER_WALLS | 2
		p.set_physics_process(true)
	if staff != null:
		staff.ref_targets = []
		for ref: Node3D in staff.refs:
			ref.visible = true
	_pending_free_kick = false
	_pending_penalty = false
	_pending_fk_spot = Vector3.ZERO
	sent_off = false
	match_stats = {"shots": [0, 0], "sot": [0, 0], "corners": [0, 0], "fouls": [0, 0], "yellows": [0, 0],
		"goals_log": [], "moments": 0, "moment_log": [],
		"me": {"goals": 0, "assists": 0, "shots": 0, "key_passes": 0, "recov": 0, "saves": 0, "conceded": 0, "moments_ok": 0,
			"yellows": 0, "red": false}}
	Engine.time_scale = 1.0
	_set_human(null)
	_hud.hide_message()
	_hud.clear_feed()
	_hud.set_hint("")
	_hud.set_sim_visible(true)
	_hud.add_feed("0'  ¡Empieza el partido!")
	if String(config.get("energy_note", "")) != "":
		_hud.add_feed("0'  " + String(config.energy_note)) # la energía con la que llegas de la carrera
	_plan_moments()
	if bool(config.get("walkout", true)):
		_start_walkout()
	else:
		_ambient_kickoff()
		state = State.SIMULATING


# ---------- momentos clave ----------

func _start_moment(kind: Moment, pl: Dictionary = {}) -> void:
	moment_type = kind
	play = pl
	play_carrier = null
	state = State.MOMENT_INTRO
	_timer = 1.6
	_moment_timer = MOMENT_SECONDS
	_shot_pending = false
	_saved = false
	_penalty_kicked = false
	_rebound_done = false
	_deciding = false
	_decision_cooldown = 0.3
	pass_requested = false
	_set_piece_ready = false
	_keeper_deciding = false
	_keeper_dived = false
	_wall.clear()
	_set_human(null)
	_star_passed_to = null
	_moment_goal = -1
	_scripted_goal_receiver = null
	_offside_snap = {}
	_var_pending = {}
	_corner_exempt = kind == Moment.CORNER
	_foul_grade = ""
	_foul_for_us = false
	_cross_pending = false
	_cross_carrier = null
	_cross_auto = 0.0
	_cross_zone = ""
	_reset_play_chain()
	_preplay_choice = ""
	_preplay_hold = 0.0
	if _hud != null:
		_hud.hide_cross_zones()
		_hud.hide_preplay_choices()
	match_stats.moments += 1
	replay.begin()
	_replay_hold = false
	for p in players:
		p.set_highlight(false)
	if not _setup_play():
		_setup_base(kind)
	_onside_setup(kind)
	var title: String = TITLES[kind] if String(play.get("title", "")) == "" else String(play.title)
	var hint: String = HINTS[kind] if String(play.get("hint", "")) == "" else String(play.hint)
	_hud.set_sim_visible(false)
	_hud.show_message("%d'\n%s" % [int(minute), title], 1.5)
	SoundFx.play("whistle", -4.0)
	SoundFx.set_crowd(-8.0) # el público se viene arriba en la jugada
	_hud.set_hint(hint)
	# P1-13: si atacas y llevas el balón, eliges cómo arranca la jugada.
	var can_choose := _preplay_available()
	if can_choose:
		_timer = maxf(_timer, PREPLAY_INTRO_SECONDS)
	_hud.show_preplay_choices(can_choose)
	moment_started.emit(title)


## P1-13 · ¿Tiene sentido elegir antes de la jugada? Solo en ataque abierto
## con tu jugador llevando el balón.
func _preplay_available() -> bool:
	return moment_type in [Moment.ATTACK, Moment.COUNTER] \
		and human != null and human.has_ball()


## P1-13 · Guarda la elección hecha durante la intro. Se aplica cuando
## arranca la jugada, no antes.
func _on_preplay_selected(choice_id: String) -> void:
	if state != State.MOMENT_INTRO or not _preplay_available():
		return
	if not PrePlayChoice.is_valid(choice_id):
		return
	_preplay_choice = choice_id
	_hud.hide_preplay_choices()


## P1-13 · Aplica la elección al empezar la jugada. Sin elección, la jugada
## arranca como siempre.
func _apply_preplay_choice() -> void:
	_hud.hide_preplay_choices()
	var choice := _preplay_choice
	_preplay_choice = ""
	if choice == "" or human == null or not human.has_ball() or not is_attacking_moment():
		return
	match choice:
		PrePlayChoice.DRIVE:
			_start_drive()
		PrePlayChoice.QUICK_PASS:
			var mate := _best_preplay_pass()
			if mate != null:
				_reset_move_boost()
				_reset_dodge_combo()
				human.pass_ball(mate)
				_hud.show_message("¡PASE RÁPIDO!", 0.7)
			else:
				_start_drive()
		PrePlayChoice.HOLD:
			_start_hold()


## Conducir: arranca hacia la portería con un sprint corto.
func _start_drive() -> void:
	var target := PrePlayChoice.drive_target(human.global_position, opponent_goal_center(0))
	_move_target = _clamp_to_field(target)
	_move_boost = PrePlayChoice.DRIVE_BOOST
	_reset_dodge_combo()
	_hud.show_message("¡CONDUCE!", 0.7)


## Aguantar: frena, protege el balón y frena la primera entrada rival.
func _start_hold() -> void:
	_move_target = null
	_reset_move_boost()
	_preplay_hold = PrePlayChoice.HOLD_SECONDS
	stamina = PrePlayChoice.hold_stamina(stamina)
	for o: SoccerPlayer in teams[1]:
		if o.is_keeper:
			continue
		if flat_dist(o.global_position, human.global_position) <= PrePlayChoice.HOLD_SHIELD_RADIUS:
			o.tackle_cooldown = maxf(o.tackle_cooldown, PrePlayChoice.HOLD_TACKLE_DELAY)
	_hud.show_message("¡AGUANTA!", 0.7)


## Mejor compañero para el pase rápido: el que más avanza sin estar lejísimos.
func _best_preplay_pass() -> SoccerPlayer:
	var goal := opponent_goal_center(0)
	var best: SoccerPlayer = null
	var best_score := 0.0
	for mate: SoccerPlayer in teams[0]:
		if mate == human or mate.is_keeper:
			continue
		var score := PrePlayChoice.pass_score(mate.global_position, human.global_position, goal)
		if score > best_score:
			best_score = score
			best = mate
	if best != null:
		return best
	# Sin un pase claro hacia adelante: al compañero más cercano en rango.
	var nearest: SoccerPlayer = null
	var nearest_d := PrePlayChoice.PASS_RANGE
	for mate: SoccerPlayer in teams[0]:
		if mate == human or mate.is_keeper:
			continue
		var d := flat_dist(mate.global_position, human.global_position)
		if d < nearest_d:
			nearest_d = d
			nearest = mate
	return nearest


## La colocación clásica de cada mecánica (jugadas sin familia propia).
func _setup_base(kind: Moment) -> void:
	match kind:
		Moment.ATTACK:
			_setup_attack(false)
		Moment.COUNTER:
			_setup_attack(true)
		Moment.CROSS:
			_setup_cross()
		Moment.CORNER:
			_setup_corner()
		Moment.FREE_KICK:
			_setup_free_kick()
		Moment.DEFENSE:
			_setup_defense()
		Moment.PENALTY:
			_setup_penalty()
		Moment.KEEPER:
			_setup_keeper()
		Moment.BUILDUP:
			_setup_buildup()

## Coloca la jugada procedural en curso. Devuelve false si la familia usa la colocación
## clásica de su mecánica (elaborado, centro, córner, tiro libre, penalti...).
func _setup_play() -> bool:
	if play.is_empty():
		return false
	var side: float = play.side
	var depth: float = play.depth
	match String(play.family):
		"mano_a_mano":
			var bp := Vector3(lerpf(12.0, 26.0, depth), 0.0, side * randf_range(0.0, 9.0))
			_attack_base(bp)
			# La defensa rota: los rivales quedan detrás, persiguiéndote
			var chasers := 0
			for o: SoccerPlayer in teams[1]:
				if o.is_keeper or o.global_position.x < bp.x - 3.0:
					continue
				var back := randf_range(2.5, 5.0) if chasers < 2 else randf_range(9.0, 16.0)
				chasers += 1
				_place(o, Vector3(bp.x - back, 0.0, o.global_position.z * 0.6 + bp.z * 0.4))
			_star_carries(bp)
		"superioridad":
			var bp := Vector3(randf_range(-2.0, 10.0), 0.0, side * randf_range(0.0, 9.0))
			_attack_base(bp)
			var att := int(play.get("attackers", 2))
			var defn := int(play.get("defenders", 1))
			var used: Array = [star]
			var mates: Array = []
			for i in att - 1:
				var lane := (1.0 if i == 0 else -1.0) * -side * randf_range(8.0, 12.0)
				var mt := _nearest_of_role(0, bp, ["ST", "MF"], used)
				if mt == null:
					break
				used.append(mt)
				mates.append(mt)
				_place(mt, bp + Vector3(randf_range(0.0, 3.0), 0.0, lane))
			var rivals_used: Array = []
			for i in defn:
				var d := _nearest_of_role(1, bp, ["DF"], rivals_used)
				if d == null:
					break
				rivals_used.append(d)
				_place(d, Vector3(bp.x + randf_range(13.0, 18.0), 0.0, bp.z + (i - (defn - 1) * 0.5) * 7.0))
				d.facing = Vector3.LEFT
			# El resto del rival, lejos: volviendo desde atrás
			for o: SoccerPlayer in teams[1]:
				if o.is_keeper or o in rivals_used:
					continue
				_place(o, Vector3(bp.x - randf_range(8.0, 18.0), 0.0, o.global_position.z))
			if randf() < 0.6 or mates.is_empty():
				_star_carries(bp)
			else:
				var c: SoccerPlayer = mates[0]
				_place(star, bp)
				_place(c, bp + Vector3(0.5, 0.0, -side * 5.0))
				_give_ball_now(c)
				c.ai_timer = 0.9
				_set_human(star)
		"frontal":
			var bp := Vector3(randf_range(24.0, 30.0), 0.0, randf_range(-9.0, 9.0))
			_attack_base(bp)
			_star_carries(bp)
			_press_ring(bp, int(play.pressure), 3.0, 5.0, true)
			_crowd_box(0, 2, [star])
		"desborde":
			var bp := Vector3(lerpf(22.0, 36.0, depth), 0.0, side * randf_range(21.0, 27.0))
			_attack_base(bp)
			_star_carries(bp)
			var fb := _nearest_of_role(1, bp, ["DF"], [])
			_place(fb, bp + Vector3(4.5, 0.0, -side * 1.0))
			fb.facing = flat(star.global_position - fb.global_position).normalized()
			_crowd_box(0, 2, [star])
			_spread_rivals_in_box(3, [fb])
		"pared":
			var bp := Vector3(randf_range(16.0, 26.0), 0.0, randf_range(-10.0, 10.0))
			_attack_base(bp)
			_star_carries(bp)
			var mt := _nearest_of_role(0, bp, ["ST", "MF"], [star])
			var lat := -signf(bp.z) if bp.z != 0.0 else side
			_place(mt, bp + Vector3(randf_range(2.0, 4.0), 0.0, lat * randf_range(4.0, 6.0)))
			_press_ring(bp, int(play.pressure), 3.0, 4.5, true)
		"rechace":
			var spot := Vector3(randf_range(39.0, 44.0), 0.0, randf_range(-6.0, 6.0))
			possession_team = 0
			_place_team_for(spot, 0)
			_crowd_box(0, 2, [star])
			_spread_rivals_in_box(4, [])
			_place(star, spot + Vector3(-randf_range(2.2, 3.4), 0.0, randf_range(-2.0, 2.0)))
			var d := _nearest_of_role(1, spot, ["DF"], [])
			_place(d, spot + Vector3(randf_range(3.0, 4.5), 0.0, randf_range(-2.5, 2.5)))
			ball.reset_to(spot + Vector3.UP * SoccerBall.RADIUS)
			ball.release(Vector3(randf_range(-2.0, 1.0), 0.6, randf_range(-1.5, 1.5)))
			_set_human(star)
		"entre_lineas":
			var bp := Vector3(randf_range(-4.0, 8.0), 0.0, randf_range(-10.0, 10.0))
			_build_base(bp)
			# Línea defensiva rival adelantada y tu delantero a su espalda, listo para picar
			var line_x := bp.x + randf_range(17.0, 21.0)
			var k := 0
			for o: SoccerPlayer in teams[1]:
				if o.role == "DF":
					_place(o, Vector3(line_x, 0.0, -14.0 + k * 9.5 + randf_range(-1.0, 1.0)))
					o.facing = Vector3.LEFT
					k += 1
			var runner := _nearest_of_role(0, Vector3(line_x, 0.0, bp.z), ["ST"], [star])
			if runner == null:
				runner = _nearest_of_role(0, Vector3(line_x, 0.0, bp.z), ["MF"], [star])
			_place(runner, Vector3(line_x - 1.5, 0.0, bp.z + randf_range(-8.0, 8.0)))
			var chaser := _nearest_of_role(1, bp, ["MF"], [])
			_place(chaser, bp + Vector3(-2.5, 0.0, randf_range(-1.5, 1.5)))
		"cambio_orientacion":
			var bp := Vector3(randf_range(-14.0, -2.0), 0.0, side * randf_range(16.0, 23.0))
			_build_base(bp)
			_press_ring(bp, 3, 4.0, 7.0, false)
			var far := _nearest_of_role(0, Vector3(bp.x + 10.0, 0.0, -side * 20.0), ["MF", "ST", "DF"], [star])
			_place(far, Vector3(bp.x + randf_range(8.0, 14.0), 0.0, -side * randf_range(18.0, 25.0)))
			play.key_far_side = true
		"contra_rapida":
			var bp := Vector3(randf_range(-22.0, -10.0), 0.0, randf_range(-12.0, 12.0))
			_build_base(bp)
			# El rival estaba atacando: casi todos por detrás del balón; solo dos atrás
			var back := 0
			for o: SoccerPlayer in teams[1]:
				if o.is_keeper:
					continue
				if o.role == "DF" and back < 2:
					_place(o, Vector3(randf_range(24.0, 30.0), 0.0, (back - 0.5) * 12.0))
					back += 1
				else:
					_place(o, Vector3(bp.x + randf_range(-8.0, 4.0), 0.0, o.global_position.z * 0.7))
			var runner := _nearest_of_role(0, Vector3(10.0, 0.0, 0.0), ["ST"], [star])
			if runner:
				_place(runner, Vector3(bp.x + randf_range(16.0, 22.0), 0.0, randf_range(-12.0, 12.0)))
			var presser := _nearest_of_role(1, bp, ["MF", "ST"], [])
			_place(presser, bp + Vector3(-2.0, 0.0, randf_range(-1.5, 1.5)))
		"dos_contra_uno":
			var bp := Vector3(randf_range(-26.0, -16.0), 0.0, side * randf_range(0.0, 10.0))
			var a := _defense_base(bp)
			var b := _nearest_of_role(1, bp, ["ST", "MF"], [a])
			_place(b, bp + Vector3(-randf_range(2.0, 4.0), 0.0, -side * randf_range(7.0, 10.0)))
			_place(star, bp + Vector3(-6.0, 0.0, -side * 3.0))
			star.facing = flat(a.global_position - star.global_position).normalized()
			# Tus compañeros, pillados arriba
			for mt: SoccerPlayer in teams[0]:
				if mt == star or mt.is_keeper:
					continue
				_place(mt, Vector3(bp.x + randf_range(9.0, 20.0), 0.0, mt.global_position.z))
		"repliegue":
			var bp := Vector3(randf_range(-8.0, 6.0), 0.0, randf_range(-12.0, 12.0))
			var a := _defense_base(bp)
			_place(star, bp + Vector3(randf_range(3.5, 5.0), 0.0, randf_range(-2.5, 2.5)))
			star.facing = Vector3.LEFT
			var d := 0
			for mt: SoccerPlayer in teams[0]:
				if mt == star or mt.is_keeper:
					continue
				if mt.role == "DF" and d < 2:
					_place(mt, Vector3(randf_range(-32.0, -26.0), 0.0, (d - 0.5) * 14.0))
					d += 1
				else:
					_place(mt, Vector3(bp.x + randf_range(5.0, 15.0), 0.0, mt.global_position.z))
			a.ai_timer = 0.5
		"presion_alta":
			var bp := Vector3(randf_range(34.0, 42.0), 0.0, randf_range(-12.0, 12.0))
			possession_team = 1
			_place_team_for(bp, 1)
			var holder := _nearest_of_role(1, bp, ["DF"], [])
			_place(holder, bp)
			holder.facing = Vector3.LEFT
			_place(star, bp + Vector3(-randf_range(6.0, 8.0), 0.0, randf_range(-2.0, 2.0)))
			star.facing = Vector3.RIGHT
			var mate := _nearest_of_role(0, bp, ["ST", "MF"], [star])
			_place(mate, bp + Vector3(-9.0, 0.0, -signf(bp.z + 0.01) * 9.0))
			_give_ball_now(holder)
			holder.ai_timer = 0.7
			_set_human(star)
		"centro_rival", "centro_gk":
			var bp := Vector3(randf_range(-44.0, -36.0), 0.0, side * randf_range(22.0, 27.0))
			possession_team = 1
			_place_team_for(Vector3(-38.0, 0.0, side * 10.0), 1)
			var crosser := _nearest_of_role(1, bp, ["MF", "ST", "DF"], [])
			_place(crosser, bp)
			crosser.facing = Vector3(0.0, 0.0, -side)
			_box_battle(3, 3, [crosser])
			_rival_play(crosser, false)
		"corner_contra", "corner_gk":
			var corner := Vector3(-FIELD_LENGTH * 0.5 + 0.4, 0.0, side * (FIELD_WIDTH * 0.5 - 0.4))
			possession_team = 1
			_place_team_for(Vector3(-30.0, 0.0, 0.0), 1)
			var taker := _nearest_of_role(1, corner, ["MF"], [])
			_place(taker, corner + Vector3(0.6, 0.0, -side * 0.3))
			taker.facing = flat(Vector3(-46.0, 0.0, 0.0) - corner).normalized()
			_box_battle(6, 6, [taker])
			_rival_play(taker, true)
		"remate_area":
			_setup_keeper(false)
		"mano_a_mano_gk":
			_setup_keeper(true)
		"disparo_lejano":
			var bp := Vector3(randf_range(-34.0, -27.0), 0.0, randf_range(-12.0, 12.0))
			possession_team = 1
			_place_team_for(bp, 1)
			var shooter := _nearest_of_role(1, bp, ["MF", "ST"], [])
			_place(shooter, bp)
			_keeper_in_goal(bp)
			# Los defensas no llegan a tapar: a los lados del tirador
			for mt: SoccerPlayer in teams[0]:
				if not mt.is_keeper and flat_dist(mt.global_position, bp) < 5.0:
					_place(mt, mt.global_position + Vector3(0.0, 0.0, 5.0 * signf(mt.global_position.z - bp.z + 0.01)))
			_rival_play(shooter, false)
		"penalti_contra":
			var spot := Vector3(-FIELD_LENGTH * 0.5 + PENALTY_DIST, 0.0, 0.0)
			possession_team = 1
			var kicker := _nearest_of_role(1, spot, ["ST"], [])
			if kicker == null:
				kicker = _nearest_of_role(1, spot, ["MF"], [])
			_place(kicker, spot + Vector3(0.7, 0.0, 0.0))
			kicker.facing = Vector3.LEFT
			var others: Array = []
			for p in players:
				if p != kicker and not p.is_keeper:
					others.append(p)
			for i in others.size():
				_place(others[i], Vector3(-FIELD_LENGTH * 0.5 + BOX_DEPTH + 1.5 + (i % 3) * 1.5, 0.0, -14.0 + i * 1.5))
			_place(teams[1][0], goal_center(1) + Vector3(-1.5, 0.0, 0.0))
			_place(star, goal_center(0) + Vector3(0.4, 0.0, 0.0))
			star.facing = Vector3.RIGHT
			_give_ball_now(kicker)
			_rival_play(kicker, true)
			play.penalty = true
		"tiro_libre_contra":
			var spot := Vector3(-FIELD_LENGTH * 0.5 + randf_range(19.0, 26.0), 0.0, randf_range(-11.0, 11.0))
			possession_team = 1
			_place_team_for(spot, 1)
			var kicker := _nearest_of_role(1, spot, ["MF", "ST"], [])
			_place(kicker, spot + Vector3(0.7, 0.0, 0.0))
			var to_goal := flat(goal_center(0) - spot).normalized()
			kicker.facing = to_goal
			# Tu barrera: cuatro a 9,15 m tapando el palo más cercano
			var right := to_goal.cross(Vector3.UP)
			var wall_center := spot + to_goal * 9.15 - right * signf(spot.z) * 0.6
			var used: Array = []
			for i in 4:
				var w := _nearest_of_role(0, wall_center, ["MF", "ST", "DF"], used)
				used.append(w)
				_place(w, wall_center + right * (i - 1.5) * 0.62)
				w.facing = -to_goal
				_wall.append(w)
			for p in players:
				if p != kicker and not (p in _wall) and not p.is_keeper and flat_dist(p.global_position, spot) < 9.5:
					_place(p, spot + flat(p.global_position - spot).normalized() * 9.5)
			_place(star, goal_center(0) + Vector3(0.5, 0.0, clampf(-spot.z * 0.08, -1.2, 1.2)))
			star.facing = Vector3.RIGHT
			_give_ball_now(kicker)
			_rival_play(kicker, true)
		_:
			return false
	return true


## Ataque con tu equipo con el balón cerca de `bp` (la colocación base de las jugadas de ataque).
func _attack_base(bp: Vector3) -> void:
	possession_team = 0
	_place_team_for(bp, 0)


## Tú con el balón en `bp`, mirando a la portería rival.
func _star_carries(bp: Vector3) -> void:
	_place(star, bp)
	star.facing = flat(opponent_goal_center(0) - bp).normalized()
	_give_ball_now(star)
	_set_human(star)


## Creación: tú con el balón en `bp`, de cara al campo rival.
func _build_base(bp: Vector3) -> void:
	possession_team = 0
	_place_team_for(bp, 0)
	_place(star, bp)
	star.facing = Vector3.RIGHT
	_give_ball_now(star)
	_set_human(star)


## Defensa: el rival ataca con el balón en `bp`; devuelve quién lo lleva.
func _defense_base(bp: Vector3) -> SoccerPlayer:
	possession_team = 1
	_place_team_for(bp, 1)
	var a := _nearest_of_role(1, bp, ["ST", "MF"], [])
	_place(a, bp)
	a.facing = Vector3.LEFT
	_give_ball_now(a)
	_set_human(star)
	return a


## `count` rivales encima de `bp`, a `dmin`-`dmax` m; `goal_side` = del lado de su portería.
func _press_ring(bp: Vector3, count: int, dmin: float, dmax: float, goal_side: bool) -> void:
	var used: Array = []
	for i in count:
		var o := _nearest_of_role(1, bp, ["DF", "MF", "ST"], used)
		if o == null:
			return
		used.append(o)
		var base_ang := 0.0 if goal_side else randf() * TAU
		var ang := base_ang + (i - (count - 1) * 0.5) * 0.8 + randf_range(-0.2, 0.2)
		_place(o, bp + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(dmin, dmax))
		o.facing = flat(bp - o.global_position).normalized()


## Rivales repartidos por su área (la de +X), sin pegarse a tu jugador.
func _spread_rivals_in_box(count: int, exclude: Array) -> void:
	var used := exclude.duplicate()
	for i in count:
		var spot := Vector3(randf_range(40.0, 49.0), 0.0, randf_range(-11.0, 11.0))
		var o := _nearest_of_role(1, spot, ["DF", "MF"], used)
		if o == null:
			return
		used.append(o)
		_place(o, spot)
		o.facing = Vector3.LEFT


## Centro o córner en contra: `att` rivales y `def` de los tuyos en tu área, cada uno con su marca.
func _box_battle(att: int, def: int, exclude: Array) -> void:
	var used := exclude.duplicate()
	used.append(star)
	var targets: Array = []
	for i in att:
		var spot := Vector3(randf_range(-48.5, -40.0), 0.0, randf_range(-9.0, 9.0))
		var o := _nearest_of_role(1, spot, ["ST", "MF", "DF"], used)
		if o == null:
			break
		used.append(o)
		_place(o, spot)
		o.facing = Vector3.LEFT
		targets.append(o)
	var mark_used: Array = [star]
	for i in mini(def, targets.size()):
		var t: SoccerPlayer = targets[i]
		var mk := _nearest_of_role(0, t.global_position, ["DF", "MF"], mark_used)
		if mk == null:
			break
		mark_used.append(mk)
		_place(mk, t.global_position + Vector3(-1.1, 0.0, randf_range(-0.7, 0.7)))
	if star.is_keeper:
		_place(star, goal_center(0) + Vector3(1.0, 0.0, 0.0))
		star.facing = Vector3.RIGHT
	elif not targets.is_empty():
		# Tú marcas al más peligroso (el más cerca del punto de penalti)
		var spot := goal_center(0) + Vector3(PENALTY_DIST, 0.0, 0.0)
		var best: SoccerPlayer = targets[0]
		for t: SoccerPlayer in targets:
			if flat_dist(t.global_position, spot) < flat_dist(best.global_position, spot):
				best = t
		_place(star, best.global_position + Vector3(-1.2, 0.0, randf_range(-0.6, 0.6)))
		star.facing = flat(best.global_position - star.global_position).normalized()
	_set_human(star)


## Portero en su sitio, cerrando el ángulo hacia `bp`.
func _keeper_in_goal(bp: Vector3) -> void:
	_place(star, goal_center(0) + Vector3(1.2, 0.0, clampf(bp.z * 0.12, -1.5, 1.5)))
	star.facing = Vector3.RIGHT
	_set_human(star)


## El rival `p` tendrá el balón y hará la acción de la jugada tras play.rival_delay;
## `set_piece` = espera quieto (balón parado).
func _rival_play(p: SoccerPlayer, set_piece: bool) -> void:
	if ball.owner_player != p:
		_give_ball_now(p)
	play_carrier = p
	play.set_piece = set_piece
	p.ai_timer = float(play.get("rival_delay", 1.2))
	_set_human(star)


## La acción preparada del rival (la llama AiBrain cuando se le acaba el tiempo).
func do_rival_action(p: SoccerPlayer) -> void:
	play_carrier = null
	var goal := goal_center(0)
	var half := GOAL_WIDTH * 0.5 - 0.6
	match String(play.get("rival_action", "")):
		"shoot":
			var aim := goal + Vector3(0.0, 0.0, randf_range(-half, half))
			var base_power := randf_range(0.72, 0.9) if bool(play.get("penalty", false)) else randf_range(0.6, 0.95)
			# Un rematador flojo chuta más suave; uno con tiro alto, más fuerte.
			p.shoot_at(aim, clampf(base_power * lerpf(0.85, 1.12, p.stat("shooting")), 0.3, 1.0))
		"free_kick":
			# Por encima de la barrera, con rosca hacia el palo que no tapa
			var far := -signf(p.global_position.z) if absf(p.global_position.z) > 0.5 else (1.0 if randf() < 0.5 else -1.0)
			var aim := goal + Vector3(0.0, 0.0, far * randf_range(1.5, half))
			var dir := flat(aim - p.global_position).normalized()
			p.shoot_vector(dir * randf_range(21.0, 24.0) + Vector3.UP * randf_range(6.6, 7.2), -far * randf_range(0.0, 0.5))
		"cross":
			# A la cabeza del rival mejor colocado en tu área
			var spot := goal + Vector3(PENALTY_DIST * 0.7, 0.0, 0.0)
			var best: SoccerPlayer = null
			for o: SoccerPlayer in teams[1]:
				if o == p or o.is_keeper or not in_own_box(0, o.global_position):
					continue
				if best == null or flat_dist(o.global_position, spot) < flat_dist(best.global_position, spot):
					best = o
			if best:
				p.cross_to(best)
			else:
				p.shoot_at(goal, 0.8)


## Creación lograda: un compañero recibe en campo rival (o en la otra banda, en el cambio de orientación).
func _creation_success(holder: SoccerPlayer) -> bool:
	if bool(play.get("key_far_side", false)):
		return signf(holder.global_position.z) == -float(play.side) and absf(holder.global_position.z) > 8.0
	return holder.global_position.x > 15.0



## Penalti o tiro libre aún sin lanzar: tu jugador espera quieto junto al balón.
## En cuanto golpeas, queda libre para ir a la segunda jugada.
func _awaiting_set_piece() -> bool:
	return (moment_type == Moment.PENALTY or moment_type == Moment.FREE_KICK) and human != null and human.has_ball()


## Dorsal de cada uno: el del hueco (1 el portero…); tu jugador lleva el de tu perfil
## y el compañero que lo tuviera se queda con el tuyo.
func _shirt_number(t: int, i: int) -> int:
	var num := i + 1
	if t == 0 and star != null:
		if teams[0][i] == star:
			num = _sub_number if subbed_off else int(profile.number)
		elif num == int(profile.number) and not subbed_off:
			num = star.index + 1
	return num


## Estampa escudo, patrocinio, dorsal y apellido en la camiseta de cada jugador.
## El escudo lo manda FootballCareer (home_crest / away_crest: Callable -> Control);
## si no, uno dibujado. El patrocinio, el del config o uno inventado fijo por club.
func _bake_kit_decals() -> void:
	var jobs := []
	for t in 2:
		var side: String = ["home", "away"][t]
		var shirt: Color = [profile.shirt, _kit_shirt1][t]
		var c2: Color = _kits[t].get("shirt_color2", Color.WHITE)
		var maker: Variant = config.get(side + "_crest")
		var team := String(TEAM_NAMES[t])
		var crest := func() -> Control: return KitDecals.crest_control(team, shirt, c2, maker)
		var sponsor := String(config.get(side + "_sponsor", KitDecals.sponsor_for(team)))
		for i in PLAYERS_PER_TEAM:
			var p: SoccerPlayer = teams[t][i]
			var base: Color = KEEPER_COLORS[t] if p.is_keeper else shirt
			var ink := _kit_ink(base, Color.BLACK if p.is_keeper else c2)
			var words := _name_of(p).split(" ", false)
			jobs.append({"target": p.apply_decals, "crest": crest, "crest_key": t, "sponsor": sponsor,
					"number": _shirt_number(t, i), "name": words[-1] if words.size() > 0 else "", "ink": ink,
					"edge": _kit_edge(base, ink, int(_kits[t].get("shirt_pattern", 0)))})
	await KitDecals.bake_all(self, jobs)


## Contorno de las letras: en diseños cargados (rayas, cuadros...), grueso y del color
## de la camiseta oscurecido o aclarado, para que el dorsal se lea; en lisas, ninguno.
func _kit_edge(shirt: Color, ink: Color, pattern: int) -> Color:
	if not pattern in [1, 2, 3, 6, 10, 12, 17, 18, 20, 21, 24, 26]:
		return Color(0, 0, 0, 0)
	return shirt.darkened(0.55) if ink.get_luminance() > 0.5 else shirt.lightened(0.7)

## Color de las letras: el segundo color si contrasta con la camiseta; si no, blanco o negro.
func _kit_ink(shirt: Color, c2: Color) -> Color:
	if absf(shirt.get_luminance() - c2.get_luminance()) > 0.45:
		return c2
	return Color(0.08, 0.08, 0.1) if shirt.get_luminance() > 0.55 else Color(0.97, 0.97, 0.97)

## Diseño de camiseta del equipo: lo manda FootballCareer (home_pattern / home_color2…)
## o sale al azar. El segundo color contrasta con el principal.
func _kit_for(t: int, shirt: Color) -> Dictionary:
	var side: String = ["home", "away"][t]
	var pattern := int(config.get(side + "_pattern", KIT_PATTERNS.pick_random()))
	var c2: Color
	if config.has(side + "_color2"):
		c2 = Color(String(config[side + "_color2"]))
	elif shirt.get_luminance() > 0.6:
		c2 = [Color(0.08, 0.12, 0.3), Color(0.7, 0.08, 0.1), Color(0.05, 0.05, 0.06)].pick_random()
	else:
		c2 = [Color(0.96, 0.96, 0.96), Color(0.98, 0.82, 0.15), Color(0.05, 0.05, 0.06)].pick_random()
	return {"shirt_pattern": pattern, "shirt_color2": c2, "crest_center": bool(config.get(side + "_crest_center", false))}


## La jugada es nuestra (atacamos) o del rival (defensa / portero).
func is_attacking_moment() -> bool:
	return moment_type != Moment.DEFENSE and moment_type != Moment.KEEPER


## Ataque elaborado o contraataque. Si eres defensa, llegas desde atrás al ataque.
func _setup_attack(counter: bool) -> void:
	var bp := Vector3(randf_range(14.0, 26.0), 0.0, randf_range(-16.0, 16.0))
	if counter:
		bp = Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-14.0, 14.0))
	possession_team = 0
	_place_team_for(bp, 0)
	if counter:
		# El rival estaba arriba: su defensa queda mal parada (solo los centrales atrás)
		for o: SoccerPlayer in teams[1]:
			if o.role == "MF" or o.role == "ST":
				_place(o, o.global_position + Vector3(-randf_range(14.0, 22.0), 0.0, 0.0))
			elif o.role == "DF" and absf(o.global_position.z) > 12.0:
				_place(o, o.global_position + Vector3(-randf_range(8.0, 14.0), 0.0, 0.0))
	var carrier: SoccerPlayer
	var star_carries := randf() < (0.55 if counter else 0.45) and star.role != "DF"
	if star_carries:
		carrier = star
	else:
		carrier = _nearest_of_role(0, bp, ["MF", "ST"], [star])
	_place(carrier, bp)
	if carrier != star:
		# Tu jugador cerca de la jugada: delantero por delante, medio al lado, defensa llegando
		var side := -signf(bp.z) if bp.z != 0.0 else 1.0
		var off := Vector3(9.0, 0.0, side * randf_range(5.0, 9.0))
		if star.role == "MF":
			off = Vector3(3.0, 0.0, side * 8.0)
		elif star.role == "DF":
			off = Vector3(-7.0, 0.0, side * 10.0)
		_place(star, bp + off)
	_give_ball_now(carrier)
	_set_human(star)
	if carrier != star:
		carrier.ai_timer = 0.8 # da tiempo a desmarcarte antes del primer pase


## Un compañero de banda llega a línea de fondo y centra; tú atacas el área.
func _setup_cross() -> void:
	var side := 1.0 if randf() < 0.5 else -1.0
	var bp := Vector3(randf_range(36.0, 44.0), 0.0, side * randf_range(24.0, 28.0))
	possession_team = 0
	_place_team_for(Vector3(38.0, 0.0, side * 10.0), 0)
	var crosser := _nearest_of_role(0, bp, ["MF", "ST", "DF"], [star])
	_place(crosser, bp)
	crosser.facing = Vector3(0.0, 0.0, -side)
	_place(star, Vector3(randf_range(36.0, 40.0), 0.0, randf_range(-6.0, 6.0)))
	# Atacantes y defensores en el área
	_crowd_box(0, 2, [star, crosser])
	_crowd_box(1, 4, [])
	_give_ball_now(crosser)
	# P1-10: el centro espera tu elección de zona. La IA no lo lanza sola hasta
	# que se agota el tiempo de selección.
	crosser.ai_timer = CROSS_ZONE_AUTO_SECONDS + 1.0
	_cross_pending = true
	_cross_carrier = crosser
	_cross_auto = CROSS_ZONE_AUTO_SECONDS
	_cross_zone = ""
	_set_human(star)


## P1-10 · El jugador eligió zona para el centro desde el HUD.
func _on_cross_zone_selected(zone_id: String) -> void:
	if state != State.MOMENT or not _cross_pending:
		return
	_execute_cross(zone_id)


## P1-10 · Si el jugador no elige, el centro sale solo al primer palo.
func _update_cross_zone(delta: float) -> void:
	if not _cross_pending:
		return
	if moment_type != Moment.CROSS or _cross_carrier == null \
			or not is_instance_valid(_cross_carrier) or not _cross_carrier.has_ball():
		_cancel_cross_zone()
		return
	_cross_auto = maxf(_cross_auto - delta, 0.0)
	if _cross_auto <= 0.0:
		_execute_cross(CrossZone.DEFAULT)


## P1-10 · Lanza el centro a la zona elegida y manda a tu jugador a atacarla.
func _execute_cross(zone_id: String) -> void:
	if not _cross_pending or _cross_carrier == null or not _cross_carrier.has_ball():
		_cancel_cross_zone()
		return
	if not CrossZone.is_valid(zone_id):
		zone_id = CrossZone.DEFAULT
	var side := signf(_cross_carrier.global_position.z)
	if side == 0.0:
		side = 1.0
	var zones := CrossZone.targets(opponent_goal_center(0), side, GOAL_WIDTH * 0.5)
	var zone := CrossZone.zone_by_id(zones, zone_id)
	var point: Vector3 = zone.get("point", opponent_goal_center(0))
	var height := float(zone.get("height", 1.75))
	_cross_pending = false
	_cross_zone = zone_id
	_cross_auto = 0.0
	_hud.hide_cross_zones()
	# Tu jugador ataca la zona elegida (sin salirse del campo).
	_move_target = _clamp_to_field(point)
	_tackle_target = null
	_reset_move_boost()
	_cross_carrier.cross_to_point(point, height)
	_hud.show_message("CENTRO AL %s" % CrossZone.label_for(zone_id), 0.7)


## P1-10 · Cancela la espera de zona (fin de jugada, cambio de momento, etc.).
func _cancel_cross_zone() -> void:
	_cross_pending = false
	_cross_carrier = null
	_cross_auto = 0.0
	if _hud != null:
		_hud.hide_cross_zones()


## Córner: el especialista lo bota y tú buscas el remate en el área.
func _setup_corner() -> void:
	var side := 1.0 if randf() < 0.5 else -1.0
	var corner := Vector3(FIELD_LENGTH * 0.5 - 0.4, 0.0, side * (FIELD_WIDTH * 0.5 - 0.4))
	possession_team = 0
	_place_team_for(Vector3(30.0, 0.0, 0.0), 0)
	var taker := _nearest_of_role(0, corner, ["MF"], [star])
	_place(taker, corner + Vector3(-0.6, 0.0, -side * 0.3))
	taker.facing = flat(Vector3(46.0, 0.0, 0.0) - corner).normalized()
	_place(star, Vector3(randf_range(41.0, 45.0), 0.0, randf_range(-5.0, 5.0)))
	_crowd_box(0, 4, [star, taker])
	_crowd_box(1, 7, [])
	_give_ball_now(taker)
	taker.ai_timer = 1.4
	_set_piece_ready = true
	_set_human(star)


## Tiro libre al borde del área: tú lo lanzas por encima de la barrera.
func _setup_free_kick() -> void:
	var spot: Vector3
	if play.has("spot") and play.spot is Vector3 and play.spot != Vector3.ZERO:
		spot = play.spot
	else:
		spot = Vector3(FIELD_LENGTH * 0.5 - randf_range(19.0, 27.0), 0.0, randf_range(-12.0, 12.0))
	possession_team = 0
	_place_team_for(spot, 0)
	_crowd_box(0, 3, [star])
	_crowd_box(1, 5, [])
	var goal := opponent_goal_center(0)
	var to_goal := flat(goal - spot).normalized()
	_place(star, spot - to_goal * 0.7)
	star.facing = to_goal
	# Barrera de 4 a 9,15 m, tapando el palo más cercano
	var right := to_goal.cross(Vector3.UP)
	var wall_center := spot + to_goal * 9.15 + right * signf(spot.z) * 0.6
	var used: Array = [star]
	for i in 4:
		var w := _nearest_of_role(1, wall_center, ["MF", "ST", "DF"], used)
		used.append(w)
		_place(w, wall_center + right * (i - 1.5) * 0.62)
		w.facing = -to_goal
		_wall.append(w)
	# Nadie a menos de 9 m del balón
	for p in players:
		if p != star and not (p in _wall) and flat_dist(p.global_position, spot) < 9.5:
			_place(p, spot + flat(p.global_position - spot).normalized() * 9.5)
	_give_ball_now(star)
	_set_piece_ready = true
	_set_human(star)


## Mete `count` jugadores del equipo `team` en el área rival del equipo 0 (la de +X).
func _crowd_box(team: int, count: int, exclude: Array) -> void:
	var used := exclude.duplicate()
	for i in count:
		var spot := Vector3(randf_range(38.0, 48.0), 0.0, randf_range(-11.0, 11.0))
		var p := _nearest_of_role(team, spot, ["DF", "MF", "ST"], used)
		if p == null:
			return
		used.append(p)
		_place(p, spot)
	# Marcaje en el área: un defensor pegado a tu jugador
	if team == 1:
		var m := _nearest_of_role(1, star.global_position, ["DF"], [])
		if m:
			_place(m, star.global_position + Vector3(1.2, 0.0, randf_range(-0.8, 0.8)))


## El rival ataca: según tu puesto llegas cerrando de frente, de lado o desde atrás.
func _setup_defense() -> void:
	var bp := Vector3(randf_range(-30.0, -16.0), 0.0, randf_range(-16.0, 16.0))
	possession_team = 1
	_place_team_for(bp, 1)
	var attacker := _nearest_of_role(1, bp, ["ST", "MF"])
	_place(attacker, bp)
	var side := -1.0 if bp.z > 0.0 else 1.0
	match star.role:
		"DF":
			_place(star, bp + Vector3(-4.5, 0.0, -side * 1.5))
		"MF":
			_place(star, bp + Vector3(-1.5, 0.0, side * 4.0))
		_:
			_place(star, bp + Vector3(5.0, 0.0, side * 2.5)) # el delantero baja a ayudar
	star.facing = flat(attacker.global_position - star.global_position).normalized()
	_give_ball_now(attacker)
	_set_human(star)


func _setup_penalty() -> void:
	var spot := Vector3(FIELD_LENGTH * 0.5 - PENALTY_DIST, 0.0, 0.0)
	_place(star, spot - Vector3(0.7, 0.0, 0.0))
	_place(teams[1][0], goal_center(1) + Vector3(-0.4, 0.0, 0.0))
	_place(teams[0][0], goal_center(0) + Vector3(1.5, 0.0, 0.0))
	var others: Array = []
	for p in players:
		if p != star and not p.is_keeper:
			others.append(p)
	for i in others.size():
		_place(others[i], Vector3(FIELD_LENGTH * 0.5 - BOX_DEPTH - 1.5 - (i % 3) * 1.5, 0.0, -14.0 + i * 1.5))
	_give_ball_now(star)
	_set_human(star)
	var half := GOAL_WIDTH * 0.5
	_penalty_guess = [-(half - 1.4), -(half - 2.6), 0.0, half - 2.6, half - 1.4].pick_random()


## Armado: tienes el balón en tu campo o en la medular, con presión encima, y tu
## trabajo es hacerlo avanzar hasta dar un pase clave en campo rival.
## El defensa sale desde atrás, el medio en el centro, el delantero baja a apoyar,
## el arquero saca jugando desde su área.
func _setup_buildup() -> void:
	var bx: float = {"GK": -FIELD_LENGTH * 0.5 + 2.0, "DF": -32.0, "MF": -12.0}.get(star.role, -2.0)
	var bp := Vector3(bx + randf_range(-3.0, 3.0), 0.0, randf_range(-12.0, 12.0))
	if star.role == "GK":
		bp = Vector3(bx, 0.0, 0.0)
	possession_team = 0
	_place_team_for(bp, 0)
	_place(star, bp)
	star.facing = Vector3.RIGHT
	# Dos rivales presionan: uno encima y otro cerrando la línea de pase
	var pressers: Array = []
	for i in int(play.get("pressure", 2)):
		var o := _nearest_of_role(1, bp, ["ST", "MF", "DF"], pressers)
		if o == null:
			break
		pressers.append(o)
		var ang := randf_range(-0.9, 0.9) + (0.0 if i == 0 else signf(randf() - 0.5) * 0.9)
		_place(o, bp + Vector3(cos(ang), 0.0, sin(ang)) * (5.5 + i * 3.0))
	_give_ball_now(star)
	_set_human(star)


## Segunda jugada: el portero rechaza (o el penalti da en el palo) y se juega el rebote;
## todos entran al área y tu jugador puede volver a rematar. Solo una por jugada.
func _rebound() -> void:
	_rebound_done = true
	moment_type = Moment.ATTACK
	_shot_pending = false
	_saved = false
	_moment_timer = maxf(_moment_timer, 4.5)
	_hud.show_message("¡REBOTE!", 0.7)
	_hud.set_hint("¡Segunda jugada! Tu jugador va al rechace · desliza hacia la portería para rematar")


## Un compañero recibe tu pase en campo rival: asistencia (gol) o al menos ocasión.
## P0-13: la ocasión NO mueve el marcador por decreto. El receptor remata de
## verdad y el gol solo cuenta cuando el balón cruza la línea (lo resuelve
## `_on_goal_area_entered`, igual que cualquier otro remate).
func _key_pass(receiver: SoccerPlayer) -> void:
	var adv := clampf((receiver.global_position.x - 15.0) / 40.0, 0.0, 1.0)
	var chance := 0.22 + star.stat("passing") * 0.2 + adv * 0.25
	match_stats.me.key_passes += 1
	if randf() < chance:
		_star_passed_to = receiver
		_scripted_goal_receiver = receiver
		var goal := opponent_goal_center(0)
		var target := goal + Vector3(0.0, randf_range(0.55, 1.15), randf_range(-2.2, 2.2))
		var from := ball.global_position
		var dist := maxf(flat_dist(from, target), 1.0)
		var speed := clampf(dist / 0.55, 18.0, 34.0)
		var flight := SoccerBall.flight_time(dist, speed)
		var vel := flat(target - from).normalized() * speed
		vel.y = SoccerBall.lift_for(target.y - from.y, flight)
		ball.kick(receiver, vel, 0.0, "shot")
		match_stats.shots[0] += 1
		_shot_pending = true
		_shot_timer = flight + 1.0
		# El portero no puede atrapar la definición del pase clave: la jugada ya
		# está decidida y el balón tiene que verse entrar (o irse fuera).
		var keeper: SoccerPlayer = teams[1][0]
		if keeper != null:
			ball.block_pickup(keeper, flight + 1.2)
		_hud.show_message("¡PASE CLAVE!", 0.8)
		_hud.set_hint("Tu compañero define...")
	else:
		_finish_moment("¡PASE CLAVE!\nOcasión, pero la saca el portero")


## Eres el portero: un rival se planta delante y dispara. Tú eliges dónde lanzarte.
func _setup_keeper(force: Variant = null) -> void:
	var one_on_one: bool = randf() < 0.4 if force == null else bool(force)
	var bp := Vector3(randf_range(-36.0, -28.0), 0.0, randf_range(-14.0, 14.0))
	if one_on_one:
		bp = Vector3(randf_range(-38.0, -34.0), 0.0, randf_range(-6.0, 6.0))
	possession_team = 1
	_place_team_for(bp, 1)
	var attacker := _nearest_of_role(1, bp, ["ST", "MF"])
	_place(attacker, bp)
	if one_on_one:
		# Se ha escapado: tus defensas quedan atrás
		for d: SoccerPlayer in teams[0]:
			if not d.is_keeper and flat_dist(d.global_position, bp) < 8.0:
				_place(d, d.global_position + Vector3(8.0, 0.0, 0.0))
	_place(star, goal_center(0) + Vector3(1.2, 0.0, clampf(bp.z * 0.15, -1.5, 1.5)))
	star.facing = Vector3.RIGHT
	_give_ball_now(attacker)
	attacker.ai_timer = 0.6
	_set_human(star)


func _place(p: SoccerPlayer, pos: Vector3) -> void:
	pos.x = clampf(pos.x, -FIELD_LENGTH * 0.5 + 0.8, FIELD_LENGTH * 0.5 - 0.8)
	pos.z = clampf(pos.z, -FIELD_WIDTH * 0.5 + 1.0, FIELD_WIDTH * 0.5 - 1.0)
	p.reset_to(pos, Vector3(attack_dir(p.team), 0.0, 0.0))


## Texto del desenlace fallido del penalti del usuario en la tanda: distingue
## palo, parada y fuera para que el relato no mienta.
func _shootout_miss_text() -> String:
	if ball.last_hit_post:
		return "¡AL PALO!"
	if _saved:
		return "¡PARADA DEL PORTERO!"
	return "¡FUERA!"


func _check_moment_outcome(delta: float) -> void:
	var holder := ball.owner_player
	# P0-05 · El penalti del usuario en la tanda no admite segunda jugada:
	# termina con el primer desenlace (gol, parada, palo o fuera). El jugador
	# queda congelado y no puede recoger el rechace ni volver a rematar.
	if _shootout_in_user_kick and _penalty_kicked:
		if _moment_goal >= 0:
			return
		if holder != null:
			if holder == human:
				_finish_moment(_shootout_miss_text())
			elif holder.is_keeper:
				_finish_moment("¡PARADA DEL PORTERO!")
			else:
				_finish_moment("¡Disparo bloqueado!")
			return
		if _shot_pending:
			_shot_timer -= delta
			var stopped := _shot_timer < 2.6 and ball.speed() < 1.0
			if _shot_timer <= 0.0 or stopped:
				_finish_moment(_shootout_miss_text())
			return
		if _moment_timer <= 0.0:
			_finish_moment(_shootout_miss_text())
		return
	if not is_attacking_moment():
		if holder != null and holder.team == 0:
			var txt := "¡BALÓN RECUPERADO!"
			if holder.is_keeper:
				txt = "¡PARADÓN!" if holder == star else "¡PARADA!"
			_finish_moment(txt)
			return
	elif holder != null:
		if holder.team == 1:
			if holder.is_keeper:
				_finish_moment("¡PARADA DEL PORTERO!")
			else:
				_finish_moment("¡Disparo bloqueado!" if _shot_pending else "Balón perdido")
			return
		if moment_type == Moment.BUILDUP:
			if holder != star and _creation_success(holder):
				_key_pass(holder)
				return
			if holder == star and holder.global_position.x > 22.0:
				# Te has plantado tú arriba: ya es ocasión de gol
				moment_type = Moment.ATTACK
				_hud.set_hint(HINT_ATTACK)
		_shot_pending = false # un compañero recoge el rechace: la jugada sigue

	# Segunda jugada del penalti: si el portero rechaza o el balón vuelve (palo), se juega el rebote
	if not _rebound_done and holder == null and ball.global_position.x < FIELD_LENGTH * 0.5 - 0.3:
		# En una tanda no hay rebote: el penalti acaba en gol, parada o fuera
		var pen := moment_type == Moment.PENALTY and _penalty_kicked and not _shootout_in_user_kick \
				and (_saved or ball.linear_velocity.x < 2.0)
		var parried := moment_type != Moment.PENALTY and is_attacking_moment() and _shot_pending and _saved
		if pen or parried:
			_rebound()
			return

	if _shot_pending:
		_shot_timer -= delta
		var stopped := _shot_timer < 2.6 and holder == null and ball.speed() < 1.0
		if _shot_timer <= 0.0 or stopped:
			_finish_moment("¡PARADA!" if _saved else "¡Fuera!")
		return

	if _moment_timer <= 0.0:
		_finish_moment("¡Peligro evitado!" if not is_attacking_moment() else "Se acabó la ocasión")


## Tu nota ahora mismo (misma fórmula que la carrera: m3d_user_rating + tarjetas).
func live_rating() -> float:
	if match_stats.is_empty():
		return 6.0
	var w: Dictionary = RATING_WEIGHTS.merged(config.get("rating_weights", {}), true)
	var me: Dictionary = match_stats.me
	var ok := int(me.moments_ok)
	var r := float(w.base)
	r += int(me.goals) * float(w.goal) + int(me.assists) * float(w.assist)
	r += int(me.key_passes) * float(w.key_pass) + int(me.shots) * float(w.shot)
	r += int(me.recov) * float(w.recov) + int(me.saves) * float(w.save)
	r += ok * float(w.moment_ok) + maxi(match_stats.moment_log.size() - ok, 0) * float(w.moment_fail)
	r += int(me.conceded) * float(w.conceded)
	if star and star.is_keeper:
		r += score[1] * float(w.gk_goal_against)
	var winner := _winner_team()
	if winner == 0:
		r += float(w.win)
	elif winner == 1:
		r += float(w.loss)
	r = clampf(r, 3.0, 10.0)
	if int(me.get("yellows", 0)) > 0:
		r += float(w.yellow)
	if bool(me.get("red", false)):
		r += float(w.red)
	return clampf(r, 1.0, 10.0)


func _refresh_rating() -> void:
	if match_stats.is_empty():
		return
	var r := snappedf(live_rating(), 0.1)
	if absf(r - _shown_rating) < 0.05:
		return
	var change := 0.0 if _shown_rating < 0.0 else r - _shown_rating
	_shown_rating = r
	_hud.set_rating(r, change)


func _finish_moment(text: String) -> void:
	if state == State.MOMENT_RESULT:
		return # ya cerrada: evita doble conteo si el balón entra y vence el timer
	_cancel_cross_zone()
	_reset_play_chain()
	_hud.hide_preplay_choices()
	_preplay_choice = ""
	_preplay_hold = 0.0
	_scripted_goal_receiver = null
	_reset_dodge_combo()
	if _shootout_in_user_kick and state == State.MOMENT:
		# Penalti del usuario en la tanda 3D: el primer desenlace cierra la
		# jugada (gol, parada, palo o fuera). No se juega ningún rebote.
		var scored := _moment_goal == _shootout_team
		if scored:
			_shootout_scores[_shootout_team] += 1
		_shootout_kicks[_shootout_team] += 1
		_shootout_cursor += 1
		_hud.add_feed("Penal %s: %s" % [TEAM_NAMES[_shootout_team], "¡gol!" if scored else text])
		_shootout_in_user_kick = false
		_finish_shootout()
		return
	var ok := _moment_goal == 0 if is_attacking_moment() else _moment_goal != 1
	if _foul_for_us:
		# Una falta a tu favor no es una jugada fallida: la jugada sigue viva
		# en el penalti/tiro libre que se cobra después.
		ok = true
		_foul_for_us = false
	if not is_attacking_moment() and _moment_goal != 1 and star.is_keeper and (_saved or ball.owner_player == star):
		match_stats.me.saves += 1
	if not is_attacking_moment() and ball.owner_player == star and not star.is_keeper:
		match_stats.me.recov += 1
	if _moment_goal == 1:
		match_stats.me.conceded += 1
	if ok:
		match_stats.me.moments_ok += 1
	# Nota de la jugada (la carrera la usa como "toques": perfecto / bueno / regular / flojo)
	var grade := "bueno" if ok else "flojo"
	if is_attacking_moment():
		if ok:
			grade = "perfecto"
		elif _saved:
			grade = "regular" # a puerta, pero parada
	elif ok and (ball.owner_player == star or _saved):
		grade = "perfecto" # la robaste tú / la paraste tú
	if _foul_grade != "":
		grade = _foul_grade
		_foul_grade = ""
	match_stats.moment_log.append({"minute": int(minute), "kind": Moment.keys()[moment_type], "ok": ok, "text": text, "grade": grade,
			"play": String(play.get("family", ""))})
	moment_ended.emit(text, ok)
	Haptics.hit("success" if ok else "fail")
	_end_decision()
	state = State.MOMENT_RESULT
	_timer = 3.2 # tiempo para pulsar "Repetición"
	_hud.show_replay_button(true)
	Engine.time_scale = 1.0
	_set_human(null)
	SoundFx.set_crowd(-14.0)
	_hud.set_hint("")
	_hud.show_message(text, 2.0)
	_hud.add_feed("%d'  %s" % [int(minute), text])


func on_shot(_shooter: SoccerPlayer) -> void:
	# El penalti del usuario en la tanda se resuelve como una jugada normal,
	# pero no debe sumar tiros ni tiros a puerta a las estadísticas del partido.
	if _shootout_in_user_kick:
		_shot_pending = true
		_shot_timer = 3.0
		_saved = false
		_penalty_kicked = true
		return
	# P1-12 · El receptor de tu pase define dentro de la ventana de asistencia:
	# cuenta el pase clave y el remate sale algo más fuerte.
	if _assist_target != null and _shooter == _assist_target and PlayChain.assist_active(_assist_window):
		if not _assist_shot_counted:
			_assist_shot_counted = true
			match_stats.me.key_passes += 1
			_hud.show_message("¡ASISTENCIA!", 0.7)
			_boost_assisted_ball()
			# La asistencia ya se consumió con este remate.
			_assist_target = null
			_assist_window = 0.0
	# Cada remate cuenta una vez, en cualquier estado (jugada, simulación o
	# corte ambiental), para que los tiros a puerta nunca superen a los tiros.
	match_stats.shots[_shooter.team] += 1
	if state == State.SIMULATING or state == State.AMBIENT_GOAL:
		return
	if state != State.MOMENT or moment_type == Moment.BUILDUP: # en el armado es un pase al hueco
		return
	if _shooter == star:
		match_stats.me.shots += 1
	_shot_pending = true
	_shot_timer = 3.0
	_saved = false
	if moment_type == Moment.PENALTY:
		_penalty_kicked = true


## P1-12 · El remate del receptor de una asistencia sale algo más fuerte. El
## balón puede estar todavía en la velocidad pendiente del golpeo, así que se
## refuerzan las dos.
func _boost_assisted_ball() -> void:
	var boost := 1.0 + PlayChain.assist_shot_bonus(_assist_window, _assist_total)
	if boost <= 1.0:
		return
	ball.linear_velocity *= boost
	if ball._pending_velocity != null:
		ball._pending_velocity = (ball._pending_velocity as Vector3) * boost


## Tiro a puerta: se cuenta UNA vez por remate. Antes se sumaba al entrar el
## gol y otra vez al pararlo el portero, y salían más tiros a puerta que
## remates. El balón recuerda el tipo de golpe y si ya se contó.
func _count_sot(team: int) -> void:
	if ball.sot_counted:
		return
	var kind := ball.last_kick_kind
	if kind != "shot" and kind != "header" and kind != "penalty":
		return
	ball.sot_counted = true
	match_stats.sot[team] += 1


## Temblor de cámara (golpes fuertes, palos, goles): sube con `amount` y se apaga solo.
var _shake := 0.0


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func _apply_shake(delta: float) -> void:
	if _camera == null:
		return
	var real := delta / maxf(Engine.time_scale, 0.01)
	_shake = maxf(_shake - real * 2.2, 0.0)
	var a := _shake * _shake * 0.22
	var t := Time.get_ticks_msec() * 0.001
	_camera.h_offset = a * sin(t * 47.0) * cos(t * 13.0)
	_camera.v_offset = a * sin(t * 59.0 + 1.3)


func _on_goal_area_entered(body: Node3D, scoring_team: int) -> void:
	if body != ball:
		return
	if state == State.MOMENT and _shootout_in_user_kick:
		# El gol del penalti de la tanda no cuenta en el marcador del partido:
		# solo suma en la tanda. Evita goles fantasma y doble conteo.
		if _moment_goal >= 0 or scoring_team != _shootout_team:
			return
		shake(0.9)
		FieldBuilder.net_hit(_goal_areas[scoring_team], ball.global_position)
		SoundFx.play("net", -2.0)
		SoundFx.play("cheer", 0.0 if scoring_team == 0 else -8.0)
		Haptics.hit("goal" if scoring_team == 0 else "goal_against")
		ball.owner_player = null
		_moment_goal = scoring_team
		_shootout_ball_entered = true
		_finish_moment("¡GOL EN LA TANDA!")
		return
	if state == State.PENALTY_SHOOTOUT:
		if _shootout_cursor >= _shootout_sequence.size() or _shootout_ball_entered or scoring_team != _shootout_team \
				or String(_shootout_sequence[_shootout_cursor].outcome) != "goal":
			return
		shake(0.9)
		FieldBuilder.net_hit(_goal_areas[scoring_team], ball.global_position)
		SoundFx.play("net", -2.0)
		SoundFx.play("cheer", 0.0 if scoring_team == 0 else -8.0)
		Haptics.hit("goal" if scoring_team == 0 else "goal_against")
		ball.owner_player = null
		_shootout_ball_entered = true
		return
	# Un tiro que la simulación decidió fallado no puede acabar sumando un gol que no
	# existe en el resultado (pasaba si el desvío aleatorio lo metía entre los palos).
	if state == State.AMBIENT_GOAL and (scoring_team != _ambient_goal_team or _ambient_goal_scored or _ambient_is_miss):
		return
	if (state == State.MOMENT or state == State.SIMULATING) and not _var_cleared \
			and int(_var_pending.get("team", -1)) == scoring_team:
		shake(0.9)
		FieldBuilder.net_hit(_goal_areas[scoring_team], ball.global_position)
		SoundFx.play("net", -2.0)
		_start_var_review(scoring_team)
		return
	var revisited := _var_cleared
	_var_cleared = false
	if not revisited:
		shake(0.9)
		FieldBuilder.net_hit(_goal_areas[scoring_team], ball.global_position)
		SoundFx.play("net", -2.0)
	if state == State.AMBIENT_GOAL:
		# La simulación sólo confirma el resultado cuando la escena muestra el balón en la red.
		score[scoring_team] += 1
		_count_sot(scoring_team)
		_log_goal(scoring_team, _ambient_goal_minute, _ambient_goal_name, false)
		_hud.add_feed("%d'  ¡Gol de %s! Marca %s" % [
			_ambient_goal_minute, TEAM_NAMES[scoring_team], _ambient_goal_name if _ambient_goal_name != "" else "un compañero"])
		ball.owner_player = null
		staff.on_goal(scoring_team)
		SoundFx.play("cheer", 0.0 if scoring_team == 0 else -8.0)
		Haptics.hit("goal" if scoring_team == 0 else "goal_against")
		FieldBuilder.celebrate(self, _goal_areas[scoring_team])
		_ambient_goal_scored = true
		_ambient_goal_timer = 0.6 # un instante viendo la red y arranca la carrera al córner
		return
	if state == State.SIMULATING:
		# Un remate espontáneo de la IA también cuenta en el marcador y en el
		# relato; antes el balón entraba, pero el gol se ignoraba.
		var ambient_scorer: SoccerPlayer = ball.last_touch
		var ambient_name := _name_of(ambient_scorer) if ambient_scorer != null and ambient_scorer.team == scoring_team else _scorer_name(scoring_team)
		score[scoring_team] += 1
		_count_sot(scoring_team)
		_log_goal(scoring_team, int(minute), ambient_name, false)
		_hud.add_feed("%d'  ¡Gol de %s! Marca %s" % [int(minute), TEAM_NAMES[scoring_team], ambient_name if ambient_name != "" else "un compañero"])
		ball.owner_player = null
		staff.on_goal(scoring_team)
		Haptics.hit("goal" if scoring_team == 0 else "goal_against")
		FieldBuilder.celebrate(self, _goal_areas[scoring_team])
		_ambient_goal_team = scoring_team
		_ambient_goal_minute = int(minute)
		_ambient_goal_name = ambient_name
		_ambient_goal_shooter = ambient_scorer
		_ambient_goal_keeper = teams[1 - scoring_team][0]
		_ambient_goal_scored = true
		_ambient_keeper_dived = true
		_ambient_goal_timer = 0.6
		state = State.AMBIENT_GOAL
		return
	if state == State.MOMENT:
		score[scoring_team] += 1
		var scorer := ball.last_touch
		ball.owner_player = null
		_moment_goal = scoring_team
		_count_sot(scoring_team)
		var by_star := scorer == star and scoring_team == 0
		var assisted := scoring_team == 0 and not by_star and scorer != null and scorer == _star_passed_to
		var key_receiver := _scripted_goal_receiver
		_scripted_goal_receiver = null
		if by_star:
			match_stats.me.goals += 1
		elif assisted:
			match_stats.me.assists += 1
		var scorer_name := profile.player_name if by_star else (_name_of(scorer) if scorer != null and scorer.team == scoring_team else "")
		if scorer_name == "":
			scorer_name = _scorer_name(scoring_team)
		_log_goal(scoring_team, int(minute), scorer_name, assisted, by_star)
		var text := "Gol de %s" % TEAM_NAMES[1]
		if scoring_team == 0:
			text = "¡GOOOL de %s!" % profile.player_name if scorer == star else "¡GOOOL!"
		if key_receiver != null and scoring_team == 0:
			text = "¡PASE CLAVE!\nGol con asistencia de %s" % profile.player_name
		_finish_moment(text)
		# La grada salta y se va calmando
		SoundFx.play("cheer", 0.0 if scoring_team == 0 else -8.0)
		Haptics.hit("goal" if scoring_team == 0 else "goal_against")
		staff.on_goal(scoring_team)
		if scoring_team == 0:
			FieldBuilder.celebrate(self, _goal_areas[scoring_team])
			FieldBuilder.flares(self, signf(_goal_areas[scoring_team].global_position.x), [profile.shirt, _kit_shirt1][scoring_team], 7.0)
		# El goleador corre al banderín y allí lo celebra de frente a la cámara
		if state == State.MOMENT_RESULT and scorer != null and scorer.team == scoring_team and not scorer.is_keeper:
			_start_goal_celebration(scorer, scoring_team, _after_moment_celebration,
					CELEB_DANCE if scoring_team == 0 else CELEB_DANCE_AMBIENT)
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: FieldBuilder.set_crowd_excitement(self, v), 1.0, 0.0, 9.0)
	elif state == State.SIMULATING:
		_ambient_kickoff.call_deferred() # el partido de fondo es solo ambiente


# ---------- celebración de gol ----------
## El goleador corre al banderín de córner más cercano (los compañeros detrás) y allí
## celebra con la cámara de frente. Al acabar sigue `_celeb_then` (repetición o simulación).
const CELEB_RUN_MAX := 5.5        # segundos como mucho de carrera hasta el banderín
const CELEB_DANCE := 6.0          # baile de tus goles y los de tu equipo en una jugada
const CELEB_DANCE_AMBIENT := 2.5  # goles del partido de fondo y del rival: corto (eran ~10 s por gol ajeno)
const CELEB_RUN_AMBIENT := 2.5
var _celeb_run_max := CELEB_RUN_MAX
var _celeb_scorer: SoccerPlayer = null
var _celeb_team := 0
var _celeb_spot := Vector3.ZERO
var _celeb_face := Vector3.BACK
var _celeb_t := 0.0
var _celeb_dance := CELEB_DANCE
var _celeb_dancing := false
var _celeb_then := Callable()
var _celeb_mates: Array[SoccerPlayer] = []
var _celeb_cheered: Dictionary = {}
var _replay_hold := false # la repetición termina en el gol: la celebración no se graba


func _start_goal_celebration(scorer: SoccerPlayer, team: int, then: Callable, dance := CELEB_DANCE) -> void:
	_celeb_run_max = CELEB_RUN_MAX if dance >= CELEB_DANCE else CELEB_RUN_AMBIENT
	_celeb_scorer = scorer
	_celeb_team = team
	_celeb_then = then
	_celeb_dance = dance
	_celeb_t = 0.0
	_celeb_dancing = false
	_celeb_cheered.clear()
	_replay_hold = true
	var gx := attack_dir(team) * FIELD_LENGTH * 0.5
	var zs := signf(scorer.global_position.z)
	if zs == 0.0:
		zs = 1.0
	# Un poco dentro del campo, junto al banderín
	_celeb_spot = Vector3(gx - attack_dir(team) * 2.4, 0.0, zs * (FIELD_WIDTH * 0.5 - 2.4))
	# Mira hacia el campo: la cámara se pone delante y detrás queda la grada del córner
	_celeb_face = flat(Vector3(gx * 0.6, 0.0, zs * FIELD_WIDTH * 0.15) - _celeb_spot).normalized()
	_celeb_mates.clear()
	var near: Array = []
	for mate: SoccerPlayer in teams[team]:
		if mate != scorer and not mate.is_keeper and mate.visible:
			near.append(mate)
	near.sort_custom(func(a: SoccerPlayer, b: SoccerPlayer) -> bool:
		return flat_dist(a.global_position, scorer.global_position) < flat_dist(b.global_position, scorer.global_position))
	for i in mini(4, near.size()):
		_celeb_mates.append(near[i])
	_set_human(null)
	_hud.show_replay_button(false)
	_hud.set_hint("")
	Engine.time_scale = 1.0
	state = State.CELEBRATION


func _update_celebration(delta: float) -> void:
	_celeb_t += delta
	_freeze_players()
	var s := _celeb_scorer
	if s == null or not is_instance_valid(s):
		_end_goal_celebration()
		return
	if not _celeb_dancing:
		var to := flat(_celeb_spot - s.global_position)
		if to.length() < 0.9 or _celeb_t > _celeb_run_max:
			_celeb_dancing = true
			_celeb_t = 0.0
			s.velocity = Vector3.ZERO
			s.facing = _celeb_face
			s.celebrate(_celeb_dance)
		else:
			s.move_input = to.normalized()
			s.sprinting = true
	elif _celeb_t > _celeb_dance:
		_end_goal_celebration()
		return
	# Los compañeros llegan corriendo y se le abren a los lados (sin tapar la cámara)
	var side := _celeb_face.cross(Vector3.UP)
	for i in _celeb_mates.size():
		var m: SoccerPlayer = _celeb_mates[i]
		if not is_instance_valid(m):
			continue
		var row := float(i / 2)
		var slot := s.global_position + side * (1.5 + row * 1.1) * (1.0 if i % 2 == 0 else -1.0) \
				- _celeb_face * (0.7 + row * 0.9)
		var to_m := flat(slot - m.global_position)
		var d := to_m.length()
		if d > 0.6 and not _celeb_cheered.has(m):
			m.move_input = to_m / d * clampf(d / 2.0, 0.35, 1.0)
			m.sprinting = d > 4.0
		elif _celeb_dancing and not _celeb_cheered.has(m):
			_celeb_cheered[m] = true
			m.velocity = Vector3.ZERO
			m.facing = _celeb_face
			m.play_action(["fist_pump", "fist_pump_2", "victory", "charge", "clap", "jump_cheer", "jump_cheer"].pick_random(), 1.0,
					maxf(_celeb_dance - _celeb_t, 0.5))


func _end_goal_celebration() -> void:
	_celeb_mates.clear()
	_celeb_cheered.clear()
	_celeb_scorer = null
	var then := _celeb_then
	_celeb_then = Callable()
	if then.is_valid():
		then.call()


func _after_moment_celebration() -> void:
	state = State.MOMENT_RESULT
	_timer = 2.6 # tiempo para pulsar "Repetición"
	_hud.show_replay_button(replay.has_frames())


## Primero un travelling por delante mientras corre al banderín; luego, plano de frente.
func _celebration_camera(delta: float) -> void:
	_update_occlusion(false)
	var s := _celeb_scorer
	if s == null or not is_instance_valid(s):
		return
	var p := s.global_position
	var tp: Vector3
	var tl: Vector3
	var fov := 48.0
	if _celeb_dancing:
		tp = p + _celeb_face * 4.0 + Vector3(0.0, 1.45, 0.0)
		tl = p + Vector3(0.0, 1.05, 0.0)
		fov = 42.0
	else:
		# De lado (desde dentro del campo) y un poco por delante: aguanta bien el sprint
		var run := flat(_celeb_spot - p)
		var dir := run.normalized() if run.length() > 0.5 else -_celeb_face
		var perp := dir.cross(Vector3.UP)
		if perp.dot(_celeb_face) < 0.0:
			perp = -perp
		tp = p + flat(s.velocity) * 0.5 + perp * 7.0 + dir * 3.0 + Vector3(0.0, 2.4, 0.0)
		tl = p + flat(s.velocity) * 0.25 + Vector3(0.0, 1.0, 0.0)
	var k := minf(1.0, (2.2 if _celeb_dancing else 4.0) * delta)
	_cam_pos = _cam_pos.lerp(tp, k)
	_cam_look = _cam_look.lerp(tl, minf(1.0, 9.0 * delta))
	_camera.fov = lerpf(_camera.fov, fov, k)
	_camera.global_position = _cam_pos
	_camera.look_at(_cam_look, Vector3.UP)


func _check_ball_escaped() -> void:
	var b := ball.global_position
	# Fuera de banda, o pasa la línea de fondo sin entrar en la portería (gol lo detecta su área)
	var past_line := absf(b.x) > FIELD_LENGTH * 0.5 + 0.4
	var in_goal_mouth := absf(b.z) < GOAL_WIDTH * 0.5 and b.y < GOAL_HEIGHT
	var out := absf(b.z) > FIELD_WIDTH * 0.5 + 0.4 or (past_line and not in_goal_mouth) \
			or absf(b.x) > FIELD_LENGTH * 0.5 + GOAL_DEPTH + 1.0 or b.y < -2.0
	if out and ball.owner_player == null:
		if state == State.MOMENT:
			_finish_moment("¡Fuera!")
		else:
			_ambient_kickoff()


# ---------- gestos ----------

func _on_tapped(pos: Vector2) -> void:
	if state == State.WALKOUT:
		if bool(config.get("walkout_skip", true)):
			_end_walkout() # tocar = saltar la salida
		return
	if state == State.CUTSCENE or state == State.LOCKER:
		return
	if state == State.OUTRO:
		_finish_outro() # tocar acelera la salida al túnel
		return
	if state == State.ENDED:
		# La ceremonia del trofeo se cierra sola y continúa con el outro.
		return
	if state != State.MOMENT or human == null or _awaiting_set_piece():
		return
	# P1-13 · Cualquier toque explícito cancela el aguante: vuelves a mandar tú.
	_preplay_hold = 0.0
	if _shootout_in_user_kick and _penalty_kicked:
		return # la tanda ya está decidida: no hay segunda jugada
	if _cross_pending and _hud.cross_zone_at(pos):
		return # el toque fue en un botón de zona del centro
	var hit := _player_at_screen(pos)
	_end_decision()
	if is_attacking_moment():
		# P1-08: tocar antes de que llegue el balón lo juega de primera.
		if _try_first_touch(pos, hit):
			return
		if hit != null and hit.team == 0 and hit != human and human.has_ball():
			_reset_move_boost()
			_reset_dodge_combo()
			# P1-09: mantener el toque levanta el pase por encima del rival.
			if _hud.gesture.last_tap_hold_seconds() >= PASS_LOFT_HOLD_SECONDS:
				human.lofted_pass(hit)
				_hud.show_message("¡BOMBEADO!", 0.6)
			else:
				human.pass_ball(hit)
			return
		# Sin balón: tocarte a ti o al compañero que la lleva = pedirla
		var holder := ball.owner_player
		if hit != null and holder != null and holder.team == 0 and holder != human \
				and (hit == human or hit == holder):
			_reset_move_boost()
			pass_requested = true
			_hud.show_message("¡PÁSALA!", 0.6)
			return
	else:
		if hit != null and hit.team == 1:
			_reset_move_boost()
			_tackle_target = hit
			_move_target = null
			return
	_move_target = _clamp_to_field(_ground_point(pos))
	_tackle_target = null
	_register_move_tap(pos)


## Detecta toques seguidos en la misma zona y sube el boost de carrera.
## Un toque normal (o cambiar de zona) vuelve a 0; dos o tres toques seguidos
## dan 1 o 2 niveles. La ventana es corta para que no se active al navegar.
static func multitap_level(now_ms: int, pos: Vector2, last_ms: int, last_pos: Vector2, count: int) -> int:
	if now_ms - last_ms <= MULTITAP_WINDOW_MS and pos.distance_to(last_pos) <= MULTITAP_RADIUS_PX:
		return mini(count + 1, MOVE_BOOST_MAX + 1)
	return 1


func _register_move_tap(pos: Vector2) -> void:
	var now := Time.get_ticks_msec()
	_move_tap_count = multitap_level(now, pos, _move_tap_ms, _move_tap_pos, _move_tap_count)
	_move_tap_ms = now
	_move_tap_pos = pos
	var previous := _move_boost
	_move_boost = clampi(_move_tap_count - 1, 0, MOVE_BOOST_MAX)
	if _move_boost > previous:
		_hud.show_message("¡SPRINT!" if _move_boost == 1 else "¡A FULL!", 0.35)


func _reset_move_boost() -> void:
	_move_boost = 0
	_move_tap_count = 0
	_move_tap_ms = -10000


## P1-08 · Pase de primera: si el balón viene hacia ti y tocas antes de que
## llegue, lo juegas de un toque sin controlarlo. Tocar a un compañero se lo
## manda; tocar el césped lo manda al hueco. Devuelve true si lo jugó.
func _try_first_touch(pos: Vector2, hit: SoccerPlayer) -> bool:
	if human == null or not is_attacking_moment():
		return false
	if ball.owner_player != null or human.is_kicking():
		return false
	var bpos := ball.global_position
	var to_human := flat(human.global_position - bpos)
	var dist := to_human.length()
	if dist > FIRST_TOUCH_RADIUS or bpos.y > FIRST_TOUCH_MAX_HEIGHT:
		return false
	if ball.speed() < FIRST_TOUCH_MIN_SPEED:
		return false
	# Solo vale si el balón viene hacia el jugador; si se aleja, hay que correrlo.
	var vel := ball.velocity_now()
	if vel.length() > 0.1 and dist > 0.05:
		var approach := Vector2(vel.x, vel.z).normalized().dot(Vector2(to_human.x, to_human.z).normalized())
		if approach < 0.25:
			return false
	var target: SoccerPlayer = null
	var point := _clamp_to_field(_ground_point(pos))
	if hit != null and hit.team == 0 and hit != human:
		target = hit
		point = hit.global_position
	elif flat_dist(point, human.global_position) < FIRST_TOUCH_MIN_TARGET:
		return false # tocar cerca de uno mismo es moverse, no jugarla de primera
	human.first_touch_pass(target, point)
	_hud.show_message("¡DE PRIMERA!", 0.6)
	return true


func _update_shot_charge() -> void:
	var charging := state == State.MOMENT and human != null and human.has_ball() \
		and _hud.gesture.is_holding() and _hud.gesture.held_seconds() >= 0.12 \
		and moment_type in [Moment.ATTACK, Moment.COUNTER, Moment.PENALTY, Moment.FREE_KICK]
	if not charging:
		_hud.hide_power()
		return
	_hud.show_power(_shot_power_preview(_hud.gesture.current_points(), _hud.gesture.held_seconds()),
		_shot_power_cap())


## Techo de potencia que impone la stamina: cansado no se llega al 100%.
func _shot_power_cap() -> float:
	return lerpf(SHOT_STAMINA_MIN_CAP, 1.0, clampf(stamina, 0.0, 1.0))


## Techo de efecto (curva) que impone la stamina: cansado el balón obedece
## menos al dedo (P1-02).
func _shot_curl_cap() -> float:
	return lerpf(SHOT_STAMINA_MIN_CURL, 1.0, clampf(stamina, 0.0, 1.0))


## Potencia del remate = gesto (largo/velocidad) + tiempo mantenido, con
## techo de stamina. Se usa igual para la barra en vivo y para el disparo.
func _shot_power_preview(points: PackedVector2Array, duration: float) -> float:
	var screen_len := 0.0
	if points.size() >= 2:
		screen_len = points[points.size() - 1].distance_to(points[0])
	var vp_h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var flick := clampf(screen_len / (vp_h * 0.5), 0.0, 1.0)
	var hold := clampf(duration / CHARGE_FULL_SECONDS, 0.0, 1.0)
	var raw := flick * CHARGE_FLICK_WEIGHT + hold * CHARGE_HOLD_WEIGHT
	return clampf(raw, 0.2, _shot_power_cap())


## P1-03 · Zona de tiro visible: proyecta sobre el arco un aro cuyo radio es el
## área que el jugador puede cubrir con seguridad. Se achica con la distancia,
## la fatiga y la presión del rival. Solo se dibuja cuando hay un remate posible.
func _update_aim_zone() -> void:
	var show := state == State.MOMENT and human != null and human.has_ball() \
		and not _shot_pending and not _penalty_kicked \
		and moment_type in [Moment.ATTACK, Moment.COUNTER, Moment.PENALTY, Moment.FREE_KICK]
	if not show:
		_aim_zone_radius = 0.0
		_hud.hide_aim_zone()
		return
	var goal := opponent_goal_center(0)
	var from := human.global_position
	var dist := flat_dist(from, goal)
	var nearest := 999.0
	for o: SoccerPlayer in teams[1]:
		if o.stun_timer > 0.0:
			continue
		nearest = minf(nearest, flat_dist(from, o.global_position))
	var r := ShotZone.radius(dist, stamina, nearest)
	_aim_zone_radius = r
	# Punto de mira: la dirección del gesto si ya está arrastrando; si no, al arco.
	var aim_z := 0.0
	var pts := _hud.gesture.current_points()
	if _hud.gesture.is_holding() and pts.size() >= 2:
		var g0 := _ground_point(pts[0])
		var g1 := _ground_point(pts[pts.size() - 1])
		var d := flat(g1 - g0)
		if d.length() > 0.5:
			var dir := _shot_dir_assist(d.normalized(), flat(goal - from).normalized())
			if absf(dir.x) > 0.15:
				var t := (goal.x - from.x) / dir.x
				if t > 0.0:
					aim_z = from.z + dir.z * t
	aim_z = clampf(aim_z, -GOAL_WIDTH * 0.5 + 0.5, GOAL_WIDTH * 0.5 - 0.5)
	var aim := Vector3(goal.x, GOAL_HEIGHT * 0.55, aim_z)
	var center := _camera.unproject_position(aim)
	if _camera.is_position_behind(aim):
		_hud.hide_aim_zone()
		return
	# Radio en píxeles: proyecta un punto a `r` metros sobre el plano del arco.
	var edge := _camera.unproject_position(aim + Vector3(0.0, 0.0, r))
	var px := center.distance_to(edge)
	_hud.show_aim_zone(center, px, ShotZone.color_for(r))


## P1-04 · Aplica la asistencia de puntería configurada al gesto de remate.
func _shot_dir_assist(dir: Vector3, to_goal: Vector3) -> Vector3:
	return ShotZone.assist_dir(dir, to_goal, Preferences.aim_assist)


func _on_swiped(points: PackedVector2Array, duration: float) -> void:
	if state != State.MOMENT or human == null:
		return
	if _shootout_in_user_kick and _penalty_kicked:
		return # el penalti de la tanda ya se ejecutó; no hay segundo remate
	var g0 := _ground_point(points[0])
	var g_end := _ground_point(points[points.size() - 1])
	var d_total := flat(g_end - g0)
	if d_total.length() < 0.5:
		return
	var dir := d_total.normalized()
	var to_goal := flat(opponent_goal_center(0) - human.global_position).normalized()

	if moment_type == Moment.KEEPER:
		_keeper_swipe(points)
		return
	if moment_type == Moment.DEFENSE:
		# Barrida en la dirección del gesto
		human.facing = dir
		request_tackle(human, true)
		return
	if not human.has_ball():
		# Balón por el aire (un centro): el gesto elige hacia dónde cabeceas
		if ball.owner_player == null and ball.global_position.y > 0.8:
			_header_aim = dir
			_hud.show_message("¡A LA CABEZA!", 0.5)
		return
	_end_decision()

	# P1-06: un gesto dibujado (círculo, V, arco o curva) es una jugada de lujo.
	if _try_skill_move(points, dir, to_goal):
		return

	# Deslizar hacia un lado (no hacia la portería) = regate
	if moment_type == Moment.ATTACK or moment_type == Moment.COUNTER:
		if dir.dot(to_goal) < 0.45:
			_do_dodge(dir)
			return

	# Efecto: diferencia entre la dirección inicial del gesto y la final
	var g_early := _ground_point(points[int((points.size() - 1) * 0.35)])
	var d_early := flat(g_early - g0)
	var bend := 0.0
	if d_early.length() > 0.3:
		bend = clampf(d_early.normalized().signed_angle_to(dir, Vector3.UP), -0.6, 0.6)

	# Potencia: longitud y velocidad del gesto
	var screen_len := points[points.size() - 1].distance_to(points[0])
	var vp_h := get_viewport().get_visible_rect().size.y
	var speed_px := screen_len / maxf(duration, 0.05)
	var power := clampf(screen_len / (vp_h * 0.5) * 0.5 + speed_px / (vp_h * 2.5) * 0.5, 0.25, 1.0)

	if moment_type == Moment.BUILDUP:
		# P1-07: el pase al hueco cae en el punto que dibujaste con el dedo.
		_through_pass_to(_clamp_to_field(_ground_point(points[points.size() - 1])), power)
		return

	# P1-04: la asistencia configurable endereza el gesto hacia la portería.
	# P1-12: un regate exitoso deja el remate abierto: más potencia y puntería.
	var chain_links := _chain_links
	var chain_window := _chain_shot_window
	_reset_dodge_combo()
	_reset_shot_chain()
	dir = _shot_dir_assist(dir, to_goal)

	# Tiro: la potencia decide la velocidad y a qué altura llega a la portería
	# (suave = raso, fuerte = a la escuadra, al límite = se puede ir por encima).
	# P1-01: se carga manteniendo el gesto y la stamina pone el techo; tu
	# tiro/fuerza afinan cuánto de esa potencia aprovechás.
	power = _shot_power_preview(points, duration)
	var chain_bonus := PlayChain.shot_bonus(chain_links, chain_window)
	var chain_accuracy := PlayChain.shot_accuracy(chain_links, chain_window)
	power = clampf(power * (1.0 + chain_bonus), 0.2, _shot_power_cap())
	var shot_skill := human.stat("shooting") * 0.6 + human.stat("strength") * 0.4
	power = clampf(power * lerpf(0.82, 1.12, shot_skill), 0.2, _shot_power_cap())
	var spd := lerpf(14.0, 31.0, power)
	var target_h := lerpf(0.25, GOAL_HEIGHT - 0.25, smoothstep(0.25, 0.9, power))
	if power > 0.93:
		target_h += (power - 0.93) * 18.0 # pasarse de fuerza = balón alto
	# El control decide hasta qué altura puedes colocar el balón.
	target_h = minf(target_h, lerpf(0.7, GOAL_HEIGHT - 0.25, human.stat("control")))
	var to_line := absf(opponent_goal_center(0).x - human.global_position.x) / maxf(absf(dir.x), 0.3)
	var flight := SoccerBall.flight_time(minf(to_line, 45.0), spd)
	# Efecto: curva de verdad pero el balón acaba yendo hacia donde apuntaste.
	# P1-02: el cansancio reduce el efecto disponible (misma stamina que la
	# potencia), así que al 85' hay que elegir entre colocar o golpear.
	var curl := bend * 1.3 * _shot_curl_cap()
	var launch := dir.rotated(Vector3.UP, -curl * flight * 0.5)
	var lift := SoccerBall.lift_for(target_h - SoccerBall.RADIUS, flight)
	human.shoot_vector(launch * spd + Vector3.UP * clampf(lift, 0.3, 11.0), curl, chain_accuracy)
	if chain_bonus > 0.0:
		_hud.show_message("¡REGATE + REMATE!", 0.7)


## Jugada de decisión: si un defensor se acerca a tu jugador con balón,
## todo va a cámara muy lenta y eliges pase, tiro o regate.
func _update_decision(delta: float) -> void:
	if _deciding:
		_decision_left -= delta / maxf(Engine.time_scale, 0.01)
		if _decision_left <= 0.0 or human == null or not human.has_ball():
			_end_decision()
		return
	_decision_cooldown = maxf(_decision_cooldown - delta, 0.0)
	if not (moment_type == Moment.ATTACK or moment_type == Moment.COUNTER) or human == null or not human.has_ball():
		return
	if _decision_cooldown > 0.0 or _shot_pending or human.dodge_timer > 0.0:
		return
	var to_goal := flat(opponent_goal_center(0) - human.global_position).normalized()
	for o: SoccerPlayer in teams[1]:
		if o.stun_timer > 0.0:
			continue
		var off := flat(o.global_position - human.global_position)
		var d := off.length()
		if d < 2.0 or (d < DECISION_RADIUS and off.normalized().dot(to_goal) > 0.0):
			_start_decision()
			return


func _start_decision() -> void:
	_deciding = true
	_decision_left = DECISION_SECONDS
	Engine.time_scale = DECISION_TIME_SCALE
	for mate: SoccerPlayer in teams[0]:
		if mate == human or mate.is_keeper:
			continue
		var open := lane_clear(human.global_position, mate.global_position, 0) \
				and nearest_opponent_distance(mate, mate.global_position) > 2.5
		mate.set_highlight(open)
	_hud.set_hint(DECISION_HINT)
	_hud.show_message("¡DECIDE!", 0.8)


func _end_decision() -> void:
	if not _deciding:
		return
	_deciding = false
	_decision_cooldown = 1.5
	if state == State.MOMENT:
		Engine.time_scale = MOMENT_TIME_SCALE
		_hud.set_hint(HINTS[moment_type])
	for p in players:
		p.set_highlight(false)


## Quiebro lateral: los defensores cercanos suelen quedarse atrás. Encadenar
## dos o tres quiebros en direcciones distintas (P1-05) suma probabilidad y
## deja al rival mareado más tiempo; repetir el mismo lado no cuenta.
func _do_dodge(dir: Vector3) -> void:
	human.dodge(dir)
	_dodge_chain = DribbleCombo.next_chain(_dodge_chain, _dodge_dir, dir, _dodge_window)
	_dodge_window = DribbleCombo.WINDOW
	_dodge_dir = flat(dir).normalized()
	var beaten := false
	for o: SoccerPlayer in teams[1]:
		if flat_dist(o.global_position, human.global_position) > DECISION_RADIUS + 0.5:
			continue
		# Regate (dribbling + combo) contra la fuerza defensiva del rival.
		var chance := DribbleCombo.beat_chance(
			human.stat("dribbling"), o.duel_skill(true), _dodge_chain, o.is_keeper)
		if randf() < chance:
			o.stun(DribbleCombo.stun_time(_dodge_chain))
			beaten = true
	if beaten:
		_open_shot_chain(_dodge_chain)
		if _dodge_chain >= 2:
			_hud.show_message("¡COMBO x%d!" % _dodge_chain, 0.6)
		else:
			_hud.show_message("¡REGATE!", 0.6)


## P1-12 · El regate deja abierto el remate con ventaja durante unos segundos.
func _open_shot_chain(chain: int) -> void:
	_chain_links = clampi(chain, 1, DribbleCombo.MAX_CHAIN)
	_chain_shot_window = PlayChain.DRIBBLE_SHOT_WINDOW


## Corta la ventana del remate encadenado (pase, remate o fin de jugada).
func _reset_shot_chain() -> void:
	_chain_links = 0
	_chain_shot_window = 0.0


## P1-12 · Ventanas de la jugada encadenada: el remate tras regate y la
## asistencia tras el pase se apagan solos.
func _update_play_chain(delta: float) -> void:
	if _chain_shot_window > 0.0:
		_chain_shot_window = maxf(_chain_shot_window - delta, 0.0)
		if _chain_shot_window <= 0.0:
			_chain_links = 0
	if _assist_window > 0.0:
		_assist_window = maxf(_assist_window - delta, 0.0)
		if _assist_window <= 0.0:
			_assist_target = null


## Corta toda la jugada encadenada (inicio/fin de momento, cambio de jugador).
func _reset_play_chain() -> void:
	_reset_shot_chain()
	_assist_target = null
	_assist_window = 0.0
	_assist_total = 0.0
	_assist_shot_counted = false


## P1-12 · Abre la asistencia cuando tu pase sale hacia un compañero.
func _open_assist(target: SoccerPlayer) -> void:
	if target == null:
		return
	_assist_target = target
	_assist_total = PlayChain.assist_window(star.stat("passing") if star != null else 0.5)
	_assist_window = _assist_total
	_assist_shot_counted = false


## Corta el combo de regate (pase, remate, cambio de jugador o fin de jugada).
func _reset_dodge_combo() -> void:
	_dodge_chain = 0
	_dodge_window = 0.0
	_dodge_dir = Vector3.ZERO


## P1-06 · Si el gesto dibuja una jugada de lujo, la ejecuta y devuelve true.
## Solo con balón y en jugadas de ataque/armado; el enfriamiento evita spam.
func _try_skill_move(points: PackedVector2Array, dir: Vector3, to_goal: Vector3) -> bool:
	if human == null or not human.has_ball():
		return false
	if _skill_cooldown > 0.0 or _shot_pending or _penalty_kicked:
		return false
	if not (moment_type in [Moment.ATTACK, Moment.COUNTER, Moment.BUILDUP]):
		return false
	var move := SkillMove.classify(points)
	if move == "":
		return false
	_execute_skill_move(move, dir, to_goal, points)
	return true


## Jugada de lujo: el éxito depende de los atributos del jugador y de la fuerza
## defensiva del rival más cercano. Si falla, el costo es quedar expuesto.
func _execute_skill_move(move: String, dir: Vector3, to_goal: Vector3,
		points: PackedVector2Array) -> void:
	_skill_cooldown = 1.1
	stamina = maxf(stamina - SkillMove.stamina_cost(move), 0.05)
	var nearest: SoccerPlayer = null
	var nearest_d := 999.0
	for o: SoccerPlayer in teams[1]:
		var d := flat_dist(o.global_position, human.global_position)
		if d < nearest_d:
			nearest = o
			nearest_d = d
	var duel := nearest.duel_skill(true) if nearest != null else 0.0
	var chance := SkillMove.success_chance(move, human.stat("dribbling"),
		human.stat("control"), human.stat("passing"), duel)
	var ok := randf() < chance
	match move:
		"elastica":
			human.dodge(dir)
			_dodge_chain = mini(_dodge_chain + 1, DribbleCombo.MAX_CHAIN)
			_dodge_window = DribbleCombo.WINDOW
			_dodge_dir = flat(dir).normalized()
			if ok:
				_stun_near(3.0, 1.2)
				_open_shot_chain(_dodge_chain)
				_hud.show_message("¡ELÁSTICA!", 0.7)
			else:
				human.stun(0.5)
				_hud.show_message("SE LE FUE LARGO", 0.7)
		"bicicleta":
			human.dodge(dir)
			human.velocity *= 0.4 # amague: se mueve poco, pero marea
			if ok:
				_stun_near(3.2, 0.7)
				_open_shot_chain(maxi(_dodge_chain, 1))
				_hud.show_message("¡BICICLETA!", 0.7)
			else:
				_hud.show_message("NO PICÓ", 0.7)
		"sombrero":
			var over := human.global_position + to_goal * 8.0
			if nearest != null:
				over = nearest.global_position + to_goal * 2.5
			_reset_dodge_combo()
			human.chip_ball(over, 1.0 if ok else 0.62)
			_hud.show_message("¡SOMBRERO!" if ok else "¡SE QUEDÓ CORTO!", 0.7)
		"rabona":
			var mate := _nearest_open_teammate()
			_reset_dodge_combo()
			if mate != null:
				human.rabona_pass(mate, SkillMove.rabona_curl(points) * (1.0 if ok else 0.55))
				_hud.show_message("¡RABONA!" if ok else "¡RABONA FORZADA!", 0.7)
			else:
				# Sin compañero libre: sale como remate con efecto, también arriesgado.
				human.shoot_vector(dir * 20.0 + Vector3.UP * 1.5, SkillMove.rabona_curl(points))
				_hud.show_message("¡RABONA!", 0.7)


func _stun_near(radius: float, t: float) -> void:
	for o: SoccerPlayer in teams[1]:
		if flat_dist(o.global_position, human.global_position) <= radius:
			o.stun(t)


## Compañero más cercano con espacio (sin un rival encima) para la rabona.
func _nearest_open_teammate() -> SoccerPlayer:
	var best: SoccerPlayer = null
	var best_d := 999.0
	for mate: SoccerPlayer in teams[0]:
		if mate == human or mate.is_keeper:
			continue
		var d := flat_dist(mate.global_position, human.global_position)
		if d >= best_d:
			continue
		var open := true
		for o: SoccerPlayer in teams[1]:
			if flat_dist(o.global_position, mate.global_position) < 2.5:
				open = false
				break
		if open:
			best = mate
			best_d = d
	return best


## P1-07 · Pase al hueco: manda la pelota al punto dibujado y el compañero más
## cercano a ese punto es el que corre a recibirla (los rivales también).
func _through_pass_to(point: Vector3, power: float) -> void:
	if human == null or not human.has_ball():
		return
	_reset_dodge_combo()
	human.pass_to_point(point, _nearest_teammate_to(point), lerpf(0.85, 1.15, clampf(power, 0.0, 1.0)))


## Compañero más cercano al punto de destino (hasta 24 m); null si no hay nadie.
func _nearest_teammate_to(point: Vector3) -> SoccerPlayer:
	var best: SoccerPlayer = null
	var best_d := 24.0
	for mate: SoccerPlayer in teams[0]:
		if mate == human or mate.is_keeper:
			continue
		var d := flat_dist(mate.global_position, point)
		if d < best_d:
			best = mate
			best_d = d
	return best


## Órdenes del jugador y, después, el desgaste real del sprint (P1-14).
func _update_human(delta := 0.0) -> void:
	_update_human_orders(delta)
	_drain_sprint_stamina(delta)


## P1-14 · Esprintar gasta estamina del partido; el multi-toque, más. Sin
## fondo físico se corta el sprint y el boost, y el jugador vuelve a trotar.
func _drain_sprint_stamina(delta: float) -> void:
	if human == null or human.is_keeper or delta <= 0.0:
		return
	if stamina <= MOVE_BOOST_MIN_STAMINA:
		human.sprinting = false
		human.move_boost = 0.0
		return
	var boost := _move_boost if human.move_boost > 0.01 else 0
	if not human.sprinting and boost <= 0:
		return
	stamina = maxf(stamina - Momentum.stamina_cost(delta, human.sprinting, boost), 0.05)


func _update_human_orders(delta := 0.0) -> void:
	if human == null:
		return
	# P1-13 · Aguantar: el jugador protege el balón sin avanzar. Si tocas el
	# césped o a un rival, recuperas el control y sales del aguante.
	if _preplay_hold > 0.0:
		if _move_target != null or _tackle_target != null:
			_preplay_hold = 0.0
		else:
			_preplay_hold = maxf(_preplay_hold - delta, 0.0)
			human.move_input = Vector3.ZERO
			human.sprinting = false
			human.move_boost = 0.0
			return
	# P1-05: la ventana del combo de regate se agota sola.
	_dodge_window = maxf(_dodge_window - delta, 0.0)
	if _dodge_window <= 0.0:
		_dodge_chain = 0
	_skill_cooldown = maxf(_skill_cooldown - delta, 0.0)
	human.sprinting = false
	human.move_boost = 0.0
	# Tras el penalti de la tanda el jugador no persigue el rechace: la jugada
	# ya está decidida y no puede haber una segunda.
	if _shootout_in_user_kick and _penalty_kicked:
		human.move_input = Vector3.ZERO
		return
	if _awaiting_set_piece():
		human.move_input = Vector3.ZERO
		return
	if moment_type == Moment.KEEPER and _update_human_keeper():
		return
	if _tackle_target != null:
		var to := flat(_tackle_target.global_position - human.global_position)
		if to.length() < 1.6:
			human.facing = to.normalized()
			human.move_input = Vector3.ZERO
			request_tackle(human)
			_tackle_target = null
		else:
			human.move_input = to.normalized()
			human.sprinting = true
		return
	if _move_target != null:
		var target: Vector3 = _move_target
		var to := flat(target - human.global_position)
		if to.length() < 0.5:
			_move_target = null
			_reset_move_boost()
			human.move_input = Vector3.ZERO
		else:
			human.move_input = to.normalized()
			# El multi-toque mantiene el sprint y añade velocidad extra, pero
			# solo si queda estamina suficiente. El gasto lo cobra
			# _drain_sprint_stamina (P1-14), no este bloque.
			var boost := _move_boost if stamina > MOVE_BOOST_MIN_STAMINA else 0
			human.move_boost = float(boost) / float(MOVE_BOOST_MAX)
			human.sprinting = to.length() > 2.0 or boost > 0
		return
	# Sin órdenes, tu jugador hace lo lógico solo
	var holder := ball.owner_player
	if holder == human:
		# Avanza despacio hacia la portería; tú decides cuándo pasar, chutar o regatear
		if not _deciding:
			human.move_input = flat(opponent_goal_center(0) - human.global_position).normalized() * 0.5
		else:
			human.move_input = Vector3.ZERO
	elif holder == null and flat_dist(human.global_position, ball.global_position) < 12.0:
		# Ir a por el balón suelto, al punto donde lo alcanzas (p. ej. al recibir un pase)
		AiBrain.move_to(human, intercept_point(human), 0.0, true)
	elif holder != null and holder.team == 0:
		AiBrain.move_to(human, _support_spot(holder), 0.8, true)
	elif holder != null:
		# Defender: cerrar el camino entre el rival y tu portería
		var own := goal_center(0)
		var guard := holder.global_position + flat(own - holder.global_position).normalized() * 2.0
		AiBrain.move_to(human, guard, 0.5, flat_dist(human.global_position, guard) > 3.0)
	else:
		human.move_input = Vector3.ZERO


## Portero controlado: se coloca solo (como la IA) salvo que le mandes moverse o salir
## a por el rival. Si el rival dispara a puerta, todo va a cámara lenta y eliges el lado.
## Devuelve false cuando debe seguir la lógica normal (tus órdenes de moverte / salir).
func _update_human_keeper() -> bool:
	var k := human
	k.sprinting = false
	if k.is_diving():
		k.move_input = Vector3.ZERO
		return true
	var v := ball.linear_velocity
	var b := ball.global_position
	if not _keeper_dived and ball.owner_player == null and v.x < -6.0 \
			and ball.last_touch != null and ball.last_touch.team == 1:
		var t := (k.global_position.x - b.x) / (v.x * 0.9)
		if t > 0.0 and t < 1.6:
			var cz := b.z + v.z * t
			var cy := b.y + v.y * t - 4.9 * t * t
			if absf(cz) < GOAL_WIDTH * 0.5 + 0.5 and cy < GOAL_HEIGHT + 0.4:
				_shot_cross = Vector3(k.global_position.x, maxf(cy, 0.25), cz)
				if not _keeper_deciding:
					_keeper_deciding = true
					Engine.time_scale = 0.18
					_hud.show_message("¡LÁNZATE!", 0.6)
					_hud.set_hint("Desliza hacia el lado del balón · hacia arriba = estirada alta")
				elif t <= SoccerPlayer.DIVE_LEAD + 0.03:
					# No elegiste a tiempo: se estira por reflejo, con menos acierto
					_keeper_commit(_shot_cross, "miss" if randf() < 0.5 else "")
				k.move_input = Vector3.ZERO
				return true
	if _move_target != null or _tackle_target != null:
		return false
	AiBrain.think(k, self)
	return true


## Deslizar siendo portero: lado (izquierda / derecha de la portería) y altura del gesto.
func _keeper_swipe(points: PackedVector2Array) -> void:
	var k := human
	if k.is_diving() or _keeper_dived or not _keeper_deciding:
		return
	var vp := get_viewport().get_visible_rect().size
	var d := points[points.size() - 1] - points[0]
	# La cámara está detrás de tu portería mirando al campo: derecha de la pantalla = -Z
	var side := -signf(d.x) if absf(d.x) > vp.x * 0.04 else 0.0
	var reach := clampf(absf(d.x) / (vp.x * 0.3), 0.35, 1.0) * (GOAL_WIDTH * 0.5 - 0.3)
	var high := -d.y > vp.y * 0.1
	var chosen := Vector3(k.global_position.x, 1.7 if high else 0.45,
			clampf(k.global_position.z + side * reach, -GOAL_WIDTH * 0.5, GOAL_WIDTH * 0.5))
	# Acierto: cerca de por donde pasa de verdad el balón
	var err := Vector2(chosen.z - _shot_cross.z, (chosen.y - _shot_cross.y) * 0.6).length()
	if err < 1.4:
		_keeper_commit(_shot_cross, "")
		_hud.show_message("¡BIEN LEÍDO!", 0.5)
	else:
		_keeper_commit(chosen, "wrong")


## Lanza al portero: "" = sus reflejos deciden, "miss" = no llega, "wrong" = al lado equivocado.
func _keeper_commit(target: Vector3, outcome: String) -> void:
	var k := human
	_keeper_dived = true
	_keeper_deciding = false
	Engine.time_scale = MOMENT_TIME_SCALE
	_hud.set_hint(HINTS[moment_type])
	var lateral := absf(target.z - k.global_position.z)
	if outcome == "wrong":
		k.set_meta("dive_outcome", "miss")
		ball.block_pickup(k, 1.5)
		if lateral > 0.8:
			k.start_dive(target, 1.0)
		return
	if lateral > 0.8:
		keeper_dive(k, target, outcome)
	elif outcome == "":
		# Al centro: blocaje de pie si llega a tiempo
		k.set_meta("dive_outcome", "catch")


## Hueco para recibir cuando un compañero lleva el balón: por delante y a un lado, cerca del área.
func _support_spot(holder: SoccerPlayer) -> Vector3:
	var goal := opponent_goal_center(0)
	var hp := holder.global_position
	var side := signf(human.global_position.z - hp.z)
	if side == 0.0:
		side = 1.0
	var spot := Vector3(minf(hp.x + 7.0, goal.x - 5.0), 0.0, hp.z + side * 5.5)
	# Lejos del defensor más cercano a ese punto
	for o: SoccerPlayer in teams[1]:
		var off := flat(spot - o.global_position)
		if off.length() < 2.5 and off.length() > 0.01:
			spot += off.normalized() * (2.5 - off.length())
	return _clamp_to_field(spot)


func _player_at_screen(pos: Vector2) -> SoccerPlayer:
	var best: SoccerPlayer = null
	var best_d := 70.0
	for p in players:
		var sp := _camera.unproject_position(p.global_position + Vector3.UP)
		var d := sp.distance_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func _ground_point(screen: Vector2) -> Vector3:
	var o := _camera.project_ray_origin(screen)
	var n := _camera.project_ray_normal(screen)
	if n.y > -0.01:
		return o + flat(n).normalized() * 60.0
	return o + n * (-o.y / n.y)


func _clamp_to_field(v: Vector3) -> Vector3:
	return Vector3(
		clampf(v.x, -FIELD_LENGTH * 0.5 + 0.5, FIELD_LENGTH * 0.5 - 0.5),
		0.0,
		clampf(v.z, -FIELD_WIDTH * 0.5 + 0.5, FIELD_WIDTH * 0.5 - 0.5))


# ---------- IA, posesión y entradas ----------

func _run_ai() -> void:
	var in_moment := state == State.MOMENT
	_update_offside_trap()
	# Balón parado: todos quietos hasta que sale el golpeo (el lanzador del córner sí piensa)
	if _set_piece_ready and ball.owner_player == null:
		_set_piece_ready = false
	for p in players:
		if p == human or (sent_off and p == star):
			continue
		if in_moment and _set_piece_ready and not p.is_keeper and p != ball.owner_player:
			p.move_input = Vector3.ZERO
			p.sprinting = false
			continue
		if in_moment and moment_type == Moment.PENALTY:
			if p.is_keeper and p.team == 1:
				_keeper_penalty(p)
			else:
				p.move_input = Vector3.ZERO
				p.sprinting = false
			continue
		# Sin balón, cada jugador decide cada 2 frames (alternados): la IA cuesta menos
		# y el movimiento sigue igual porque move_input se mantiene entre decisiones.
		var skip_frame := (Engine.get_physics_frames() + p.index) % 2 != 0
		if skip_frame and not p.is_keeper and p != ball.owner_player and p.move_input != Vector3.ZERO:
			continue
		AiBrain.think(p, self)
		if in_moment and is_attacking_moment() and p.team == 1 and not p.is_keeper:
			p.sprinting = false # rivales algo más lentos para dar tiempo a reaccionar


func _keeper_penalty(k: SoccerPlayer) -> void:
	if ball.owner_player == k:
		k.move_input = Vector3.ZERO
		return
	var line_x := goal_center(1).x - 0.5
	if k.is_diving():
		k.move_input = Vector3.ZERO
		return
	if not _penalty_kicked:
		AiBrain.move_to(k, Vector3(line_x, 0.0, 0.0), 0.1)
		return
	# Se tira a un lado (el que adivinó) justo antes de que llegue el balón
	var v := ball.linear_velocity
	if ball.owner_player == null and v.x > 3.0 and absf(_penalty_guess) > 0.6:
		var t := (k.global_position.x - ball.global_position.x) / v.x
		if t > 0.0 and t <= SoccerPlayer.DIVE_LEAD + 0.03:
			var cy := ball.global_position.y + v.y * t - 4.9 * t * t
			keeper_dive(k, Vector3(k.global_position.x, clampf(cy, 0.3, 2.0), _penalty_guess), "auto")
			return
	k.move_input = Vector3.ZERO


func _freeze_players() -> void:
	for p in players:
		p.move_input = Vector3.ZERO
		p.sprinting = false
		p.move_boost = 0.0


func _set_human(p: SoccerPlayer) -> void:
	if p == human:
		return
	if human:
		human.set_human(false)
	human = p
	_move_target = null
	_reset_move_boost()
	_reset_dodge_combo()
	_reset_play_chain()
	_tackle_target = null
	if p:
		p.set_human(true)
		_cam_subject = p


func _give_ball_now(p: SoccerPlayer) -> void:
	ball.reset_to(p.global_position + p.facing * 0.45 + Vector3.UP * SoccerBall.RADIUS)
	_give_ball(p)


func _update_possession(delta: float) -> void:
	var holder := ball.owner_player
	var bpos := ball.global_position
	if holder == null:
		# P0-13 · El remate del pase clave ya está decidido: nadie lo intercepta.
		# Solo se resuelve cuando el balón entra (gol) o se va fuera.
		if _scripted_goal_receiver != null:
			return
		for k: SoccerPlayer in [teams[0][0], teams[1][0]]:
			if k.is_diving() and state != State.PENALTY_SHOOTOUT:
				_check_dive_contact(k)
		if ball.owner_player != null:
			return
		# Barrera: el balón que no pasa por encima rebota en ella
		for w in _wall:
			if flat_dist(w.global_position, bpos) < 0.5 and bpos.y < 1.95 and ball.linear_velocity.length() > 6.0:
				var v := ball.linear_velocity
				ball.release(Vector3(-v.x * 0.25, 2.5, -v.z * 0.25 + randf_range(-3.0, 3.0)), w, 0.5)
				ball.last_touch = w
				SoundFx.play("touch", -4.0)
				_hud.show_message("¡A LA BARRERA!", 0.7)
				_wall.clear()
				# El rechace de la barrera se sigue jugando: segunda jugada
				_shot_pending = false
				_moment_timer = maxf(_moment_timer, 4.0)
				_hud.set_hint("¡Segunda jugada! Ve al rechace · desliza hacia la portería para rematar"
						if is_attacking_moment() else "¡Rechace! Ve a por el balón antes que ellos")
				return
		# Balón alto a la altura de la cabeza: cabecea solo el más cercano, con el balón
		# bajando, y con un respiro entre cabezazos (si no, rebota sin que nadie lo controle).
		# P0-15: un balón a media altura y velocidad controlable es para el cuerpo,
		# no para la cabeza — si no, el cabezazo se lo come antes de poder bajarlo.
		var body_reachable := bpos.y >= 0.95 and bpos.y <= 1.65 and ball.linear_velocity.length() <= 9.0
		# P1-11 · Cabezazo con timing: solo en la franja de la cabeza y con el
		# balón bajando. El más cercano tiene prioridad, pero si llega tarde o
		# está lejos el contacto no sale (o sale flojo).
		if HeaderTiming.in_window(bpos.y, ball.linear_velocity.y) \
				and not body_reachable and Time.get_ticks_msec() - _last_header_ms > 900:
			var header_p: SoccerPlayer = null
			var header_d := HeaderTiming.MAX_DISTANCE
			for p in players:
				if p.is_keeper or p.stun_timer > 0.0 or not ball.can_be_picked_by(p):
					continue
				var hd := flat_dist(p.global_position, bpos)
				if hd < header_d:
					header_d = hd
					header_p = p
			if header_p != null:
				_last_header_ms = Time.get_ticks_msec()
				var q := HeaderTiming.quality(bpos.y, header_d,
						header_p.stat("strength"), header_p.stat("composure"))
				if HeaderTiming.can_contact(q):
					_header(header_p, q)
					return
				if header_p == human:
					_hud.show_message("¡LLEGÓ TARDE!", 0.6)
		var best: SoccerPlayer = null
		var best_d := INF
		var best_body := false
		var ball_spd := ball.linear_velocity.length()
		for p in players:
			if p.stun_timer > 0.0 or not ball.can_be_picked_by(p) or p.is_diving():
				continue
			var reach := 0.85
			var max_h := 0.95
			var body := false
			if p.is_keeper and in_own_box(p.team, bpos):
				reach = 1.5
				max_h = GOAL_HEIGHT + 0.2
			elif bpos.y >= 0.95 and bpos.y <= 1.65 and ball_spd <= 9.0:
				# P0-15 · Balón dividido / pase fuerte a media altura: se puede
				# controlar con el cuerpo (pecho o muslo), no solo con el pie.
				reach = 0.95
				max_h = 1.65
				body = true
			var d := flat_dist(p.global_position, bpos)
			if d < reach and bpos.y < max_h and d < best_d:
				best = p
				best_d = d
				best_body = body
		if best:
			if best_body:
				ball.trap_body(best)
				best.body_trap(bpos.y)
			_try_receive(best, best_body)
	elif not holder.is_keeper and holder.dodge_timer <= 0.0:
		# Un rival pegado al balón puede robarlo por contacto
		for p: SoccerPlayer in teams[1 - holder.team]:
			if p.stun_timer > 0.0:
				continue
			var rate := 1.4 * lerpf(0.6, 1.5, p.duel_skill(true)) * lerpf(1.5, 0.55, holder.duel_skill(false))
			if flat_dist(p.global_position, bpos) < 0.7 and randf() < rate * delta:
				holder.stun(0.35)
				_give_ball(p)
				break


## El portero decide estirarse: se calcula ya si llegará (reflejos vs. potencia y colocación del tiro).
## Si no llega, la estirada se queda corta de verdad; si llega, sus manos van al balón.
func keeper_dive(k: SoccerPlayer, cross: Vector3, outcome := "") -> void:
	var lateral := absf(cross.z - k.global_position.z)
	if outcome == "":
		var spd := ball.linear_velocity.length()
		var beaten := (spd - 14.0) / 16.0 * 0.4 + maxf(lateral - 1.2, 0.0) * 0.12
		if cross.y > 1.9:
			beaten += 0.15 # por la escuadra
		beaten = clampf(beaten * lerpf(1.4, 0.6, k.keeper_skill()), 0.03, 0.85)
		outcome = "miss"
		if randf() >= beaten:
			outcome = "catch" if spd < 19.0 and randf() < 0.55 else "parry"
	k.set_meta("dive_outcome", outcome)
	var reach := 1.0
	if outcome == "miss":
		reach = clampf((lateral - 0.9) / maxf(lateral, 0.01), 0.3, 0.75)
		ball.block_pickup(k, 1.5)
	k.start_dive(cross, reach)


## Durante la estirada: cuando las manos llegan al balón, blocaje o despeje.
func _check_dive_contact(k: SoccerPlayer) -> void:
	var left := k.dive_contact_left()
	if left > 0.15 or left < -0.35 or ball.owner_player != null:
		return
	var outcome: String = k.get_meta("dive_outcome", "miss")
	if outcome == "miss" or ball.global_position.distance_to(k.hands_position()) > 1.1:
		return
	if outcome == "auto": # penalti: si adivinó el lado, para según sus reflejos
		outcome = "parry" if randf() < 0.35 + k.keeper_skill() * 0.45 else "miss"
		if outcome == "miss":
			k.set_meta("dive_outcome", "miss")
			ball.block_pickup(k, 1.0)
			return
	k.set_meta("dive_outcome", "miss") # solo un toque por estirada
	if state == State.MOMENT and ball.last_touch != null and ball.last_touch.team != k.team:
		_saved = true
	if ball.last_touch != null and ball.last_touch.team != k.team:
		_count_sot(ball.last_touch.team)
	if outcome == "catch":
		_give_ball(k)
	else:
		ball.deflect(k)


## Cabezazo: cerca de la portería rival, a gol (al palo contrario al portero o hacia donde
## deslizaste el dedo); lejos, despeje hacia arriba.
func _header(p: SoccerPlayer, quality := 1.0) -> void:
	var goal := opponent_goal_center(p.team)
	var to_goal := flat(goal - p.global_position)
	var vel: Vector3
	var attacking := to_goal.length() < 18.0
	if attacking:
		var aim := goal
		if p == human and _header_aim != Vector3.ZERO:
			aim = p.global_position + _header_aim * to_goal.length()
		else:
			var keeper: SoccerPlayer = teams[1 - p.team][0]
			var away := -signf(keeper.global_position.z - goal.z)
			aim.z = (away if away != 0.0 else 1.0) * randf_range(1.2, GOAL_WIDTH * 0.5 - 0.5)
		var skill := p.stat("strength") * 0.4 + p.stat("shooting") * 0.6
		# P1-11 · Un contacto tarde o lejos resta fuerza y puntería.
		var power := HeaderTiming.power_scale(quality)
		var spread := (1.0 - skill) * 0.12 + (1.0 - HeaderTiming.accuracy_scale(quality)) * 0.16
		var dir := flat(aim - p.global_position).normalized().rotated(Vector3.UP, randf_range(-1.0, 1.0) * spread)
		vel = dir * lerpf(13.0, 19.0, skill) * power + Vector3.UP * randf_range(-1.5, 1.0) * power
	else:
		var away_dir := flat(p.global_position - goal_center(p.team)).normalized()
		vel = away_dir * 9.0 + Vector3.UP * 3.5
	_header_aim = Vector3.ZERO
	p.play_action_from("header", SoccerPlayer.HEADER_CONTACT - 0.1, SoccerPlayer.HEADER_SPEED, 0.4)
	# Marcado como remate para las estadísticas (y para que el portero lo cante
	# como tiro a puerta si lo toca); un despeje lejos de la portería es un pase.
	ball.kick(p, vel, 0.0, "shot" if attacking else "pass")
	if attacking:
		on_shot(p)
		if state == State.MOMENT and p.team == 0:
			_hud.show_message("¡CABEZAZO!" if HeaderTiming.is_clean(quality) else "¡TESTAZO FLOJO!", 0.7)


func _try_receive(p: SoccerPlayer, body_control := false) -> void:
	var from_rival := ball.last_touch != null and ball.last_touch.team != p.team
	var spd := ball.linear_velocity.length()
	# P0-09 · Remate fuerte que se cruza en un defensor de campo: se desvía en
	# su cuerpo, no se queda limpio. El portero tiene su propia lógica abajo.
	if not p.is_keeper and from_rival and spd > 13.0 \
			and ball.last_kick_kind in ["shot", "penalty"]:
		ball.deflect_body(p)
		if state == State.MOMENT:
			_hud.show_message("¡SE DESVÍA!", 0.6)
		return
	if p.is_keeper and from_rival and spd > 16.0:
		if ball.last_touch != null:
			_count_sot(ball.last_touch.team)
		# Tiros fuertes y lejos del cuerpo del portero pueden superarle
		var lateral := absf(ball.global_position.z - p.global_position.z)
		var beaten := clampf((spd - 16.0) / 14.0 * 0.35 + lateral * 0.25, 0.0, 0.6)
		beaten = clampf(beaten * lerpf(1.4, 0.6, p.keeper_skill()), 0.0, 0.75)
		# Al cuerpo no le supera nunca: el balón le da y lo para o rebota
		# (antes seguía de largo y se veía atravesándole).
		if flat_dist(ball.global_position, p.global_position) < 0.6 and ball.global_position.y < 1.85:
			beaten = 0.0
		var r := randf()
		if r < beaten:
			ball.block_pickup(p, 0.4)
			return
		if r < beaten + 0.3:
			ball.deflect(p)
			if state == State.MOMENT:
				_saved = true
			return
	if not p.is_keeper and spd > 5.5 and not body_control:
		# Control: el balón llega rápido y se para junto al pie, no sale rebotando
		ball.trap(p)
	_give_ball(p)


func _give_ball(p: SoccerPlayer) -> void:
	if _offside_touch(p):
		return # fuera de juego: ya se pitó y se reanudó
	_reset_dodge_combo()
	var spd := ball.linear_velocity.length()
	if p.is_keeper and spd > 4.0:
		SoundFx.play("catch", lerpf(-10.0, 0.0, clampf(spd / 25.0, 0.0, 1.0)))
	elif spd > 6.0:
		SoundFx.play("touch", -8.0) # control de un pase
	ball.owner_player = p
	ball.last_touch = p
	possession_team = p.team
	p.on_gained_ball()
	if p == star:
		pass_requested = false


## Solo manejas a tu jugador: tras pasar, se desmarca solo para la pared.
func on_pass(passer: SoccerPlayer, target: SoccerPlayer) -> void:
	if passer == star and state == State.MOMENT:
		_star_passed_to = target
		# P1-12: el pase abre la asistencia; si el receptor define dentro de la
		# ventana, cuenta como pase clave y su remate sale con algo más de fuerza.
		_open_assist(target)
	if state != State.MOMENT or passer != human or target == null:
		return
	_reset_dodge_combo()
	_reset_shot_chain()
	_move_target = null
	_reset_move_boost()
	target.ai_timer = randf_range(0.5, 0.9) # el compañero controla antes de devolverla


## slide: barrida (planchazo). Más arriesgada: si llega tarde o se pasa, puede ser falta y amarilla.
func request_tackle(t: SoccerPlayer, slide := false) -> void:
	if t.tackle_cooldown > 0.0 or t.stun_timer > 0.0:
		return
	t.tackle_cooldown = 0.9
	t.lunge()
	var holder := ball.owner_player
	if holder == null or holder.team == t.team or holder.is_keeper:
		return
	if flat_dist(t.global_position, ball.global_position) > BallContact.tackle_reach(ball.exposure) + 0.3:
		return
	# El árbitro solo puede cobrar en una jugada (en la simulación no hay faltas).
	var can_foul := state == State.MOMENT
	var decision := t.stat("decision_making")
	var composure := t.stat("composure")
	if holder.dodge_timer > 0.0:
		t.stun(0.4) # el regate le ha dejado atrás
		if can_foul and randf() < FoulRules.foul_chance(false, slide, true, decision, composure, _referee_foul_mult):
			_call_foul(t, holder, false, slide) # se lo lleva por delante
		return
	var chance := 0.45 + (t.duel_skill(true) - holder.duel_skill(false)) * 0.6
	# Entrar cuando el balón se le ha ido del pie (toque largo) es mucho más fácil
	chance += BallContact.tackle_bonus(ball.exposure)
	if t.is_human:
		chance += 0.25 # el momento es tuyo: elegir bien cuándo entrar se premia
	chance = clampf(chance, 0.15, 0.9)
	var won := randf() < chance
	# Planchazo: si no llega al balón casi siempre es falta; aun ganándolo, a veces se pasa.
	# La lectura y la sangre fría del defensor (y el árbitro) mueven el riesgo.
	if can_foul and randf() < FoulRules.foul_chance(won, slide, false, decision, composure, _referee_foul_mult):
		_call_foul(t, holder, false, slide)
		return
	if won:
		if slide or t.is_keeper:
			holder.stun(0.7) # a ras de suelo: se lo lleva y cae
		else:
			# Entrada de pie limpia: le quita el balón y lo deja descompensado, sin tirarlo
			holder.stun(0.3)
			holder.stumble(0.5, flat(holder.global_position - t.global_position))
		if t.is_keeper:
			_give_ball(t) # el portero sale y se lanza a sus pies
			return
		ball.release(flat(t.facing) * 4.0 + Vector3.UP * 1.0, holder, 0.8)
		ball.last_touch = t
	else:
		t.stun(0.4)


var _shoulder_acc := 0.0


## Choque hombro con hombro: un rival que corre a la par del que lleva el balón, pegado
## a su costado, lo empuja. El más fuerte desequilibra al otro un instante (tambaleo:
## más lento y con peor pase/tiro); si el balón ya iba suelto, se le puede escapar.
## Es contacto legal: no hay falta. La matemática está en BallContact.
func _update_shoulder_contacts(delta: float) -> void:
	_shoulder_acc += delta
	if _shoulder_acc < 0.1:
		return
	_shoulder_acc = 0.0
	var h := ball.owner_player
	if h == null or h.is_keeper or h.is_kicking() or h.stumble_timer > 0.0 or h.stun_timer > 0.0:
		return
	var hv := flat(h.velocity)
	if hv.length() < 3.0:
		return
	var fwd := hv.normalized()
	var now := Time.get_ticks_msec()
	for d: SoccerPlayer in teams[1 - h.team]:
		if d.is_keeper or not d.visible or d.stun_timer > 0.0 or d.stumble_timer > 0.0 or d.is_kicking():
			continue
		var rel := flat(d.global_position - h.global_position)
		var dist := rel.length()
		if dist > 1.15 or dist < 0.15:
			continue
		# A la par: a su costado (o medio cuerpo por detrás, el que persigue para
		# recuperar) y corriendo en la misma dirección; de frente es una entrada, no esto
		var along := rel.dot(fwd) / dist
		if along > 0.55 or along < -0.8 or flat(d.velocity).dot(fwd) < 0.5:
			continue
		if now - int(d.get_meta("shoulder_ms", -100000)) < 1500:
			continue
		d.set_meta("shoulder_ms", now)
		var away := rel / dist # del que lleva el balón hacia el defensor
		var win_p := BallContact.shoulder_win_chance(d.stat("strength"), h.stat("strength"), h.stat("control"))
		var roll := randf()
		SoundFx.play("touch", -8.0, 0.7)
		if roll < win_p:
			var margin := (win_p - roll) / maxf(win_p, 0.01)
			var expo := ball.exposure
			h.stumble(BallContact.stumble_time(margin), -away)
			if BallContact.shoulder_loses_ball(expo, margin):
				ball.release(fwd * 4.5 - away * 1.5 + Vector3.UP * 0.3, h, 0.6)
				ball.last_touch = d
		else:
			var margin2 := (roll - win_p) / maxf(1.0 - win_p, 0.01)
			d.stumble(BallContact.stumble_time(margin2), away)
		return


## De vez en cuando, mientras se simula, la grada hace la ola (y la corta en las jugadas).
func _update_wave(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	if state == State.SIMULATING:
		if _wave_left > 0.0:
			_wave_left -= real
		else:
			_wave_wait -= real
			if _wave_wait <= 0.0:
				_wave_left = WAVE_SECONDS
				_wave_wait = randf_range(35.0, 70.0)
	else:
		_wave_left = minf(_wave_left, 1.5) # se apaga enseguida
		_wave_left -= real
	var v := clampf(minf(_wave_left, WAVE_SECONDS - _wave_left) / 2.0, 0.0, 1.0) if _wave_left > 0.0 else 0.0
	# Solo se manda al shader cuando cambia de verdad (evita subir el parámetro cada frame).
	if absf(v - _wave_shown) > 0.004:
		_wave_shown = v
		FieldBuilder.set_crowd_wave(self, v)


## Falta de `fouler` sobre `victim` en una jugada: silbato, el rival al suelo y, a veces, amarilla.
## Falta tuya (en contra): se corta la jugada. Falta a tu favor: penalti o tiro libre según el área.
func _call_foul(fouler: SoccerPlayer, victim: SoccerPlayer, force_yellow := false, slide := false) -> void:
	if state != State.MOMENT:
		return
	victim.stun(1.2) # al suelo
	SoundFx.play("whistle", -2.0)
	match_stats.fouls[fouler.team] += 1
	var yellow := force_yellow
	if not yellow:
		yellow = randf() < FoulRules.card_chance(slide, fouler.stat("decision_making"),
				fouler.stat("composure"), _referee_card_mult)
	var who := _name_of(fouler)
	var text: String
	if yellow:
		match_stats.yellows[fouler.team] += 1
		text = "¡FALTA de %s!
Tarjeta amarilla" % who
	else:
		text = "¡FALTA de %s!" % who
	var for_us := fouler.team == 1
	if for_us and victim.team == 0:
		# Falta en el área -> penalti; en campo rival -> tiro libre desde el lugar.
		var kind := FoulRules.set_piece_kind(victim.global_position, attack_dir(victim.team),
				FIELD_LENGTH, BOX_DEPTH, BOX_WIDTH)
		if kind == "penalty":
			_pending_penalty = true
			_pending_fk_spot = Vector3.ZERO
			text += "\n¡Penalti a favor!"
		elif kind == "free_kick":
			_pending_free_kick = true
			_pending_fk_spot = victim.global_position
			text += "\nTiro libre a favor"
		# Una falta a favor nunca debe cerrar la jugada como fallo tuyo.
		_foul_for_us = true
		_foul_grade = "bueno" if victim == star else "regular"
	elif not for_us:
		text += "
Cortas la jugada a base de falta"
	if fouler == star:
		_foul_grade = "regular"
		if yellow:
			match_stats.me.yellows += 1
			if match_stats.me.yellows >= 2:
				# Doble amarilla: roja y a la calle (la carrera pone la sanción)
				match_stats.me.red = true
				sent_off = true
				_moments.clear()
				_pending_free_kick = false
				_pending_penalty = false
				_pending_fk_spot = Vector3.ZERO
				text = "¡SEGUNDA AMARILLA!
%s, expulsado" % who
	if yellow:
		_hud.add_feed("%d'  %s para %s" % [int(minute), "Roja" if (fouler == star and sent_off) else "Amarilla", who])
		staff.show_card(fouler, fouler == star and sent_off) # el árbitro va y se la enseña
		_card_cam_t = 2.8
		_card_fouler = fouler
	_finish_moment(text)


## Simulación: vista de transmisión. Momentos clave: tercera persona detrás
## del jugador que controlas, mirando hacia la portería rival.
## Lo que queda pegado a la cámara no se dibuja (antes salían cabezas gigantes o
## manchas tapando media pantalla) y la marca "TÚ" no crece al acercarse.
func _camera_declutter() -> void:
	if _camera == null:
		return
	var cp := _camera.global_position
	for p: SoccerPlayer in players:
		if p._avatar != null:
			p._avatar.visible = cp.distance_to(p.global_position + Vector3.UP * 0.9) > 1.7
	if star != null and star.star_label != null:
		var d := cp.distance_to(star.star_label.global_position)
		star.star_label.scale = Vector3.ONE * clampf(d / 14.0, 0.25, 1.0)


func _update_camera(delta: float) -> void:
	if state == State.REPLAY:
		return # la cámara libre de la repetición manda
	var b := ball.global_position
	var third := state == State.MOMENT_INTRO or state == State.MOMENT or state == State.MOMENT_RESULT
	var target_pos: Vector3
	var target_look: Vector3
	var target_fov := 55.0
	if state == State.CELEBRATION:
		_celebration_camera(delta)
		return
	if state == State.VAR_REVIEW:
		_var_camera(delta)
		return
	if state == State.PENALTY_SHOOTOUT and _shootout_shooter != null:
		var pen_dir := attack_dir(_shootout_team)
		var pen_goal := opponent_goal_center(_shootout_team)
		var pen_mark := pen_goal - Vector3(pen_dir * PENALTY_DIST, 0.0, 0.0)
		var pen_shooter_pos := _shootout_shooter.global_position
		target_pos = pen_shooter_pos - Vector3(pen_dir * 4.5, 0.0, 0.0) + Vector3(0.0, 2.7, _shootout_shot_side * 5.0)
		target_look = pen_mark.lerp(pen_goal, 0.58) + Vector3(0.0, 1.0, 0.0)
		var kp := minf(1.0, 3.0 * delta)
		_cam_pos = _cam_pos.lerp(target_pos, kp)
		_cam_look = _cam_look.lerp(target_look, kp)
		_camera.fov = lerpf(_camera.fov, 46.0, kp)
		_camera.global_position = _cam_pos
		_camera.look_at(_cam_look, Vector3.UP)
		return
	if state == State.AMBIENT_GOAL and _ambient_goal_shooter != null:
		var shooter_pos := _ambient_goal_shooter.global_position
		var dir := attack_dir(_ambient_goal_team)
		var goal := opponent_goal_center(_ambient_goal_team)
		target_pos = shooter_pos - Vector3(dir * 6.0, 0.0, 0.0) + Vector3(0.0, 2.6, _ambient_goal_shot_side * 4.5)
		target_look = shooter_pos.lerp(goal, 0.58) + Vector3(0.0, 1.0, 0.0)
		var kg := minf(1.0, 3.0 * delta)
		_cam_pos = _cam_pos.lerp(target_pos, kg)
		_cam_look = _cam_look.lerp(target_look, kg)
		_camera.fov = lerpf(_camera.fov, 50.0, kg)
		_camera.global_position = _cam_pos
		_camera.look_at(_cam_look, Vector3.UP)
		return
	if state == State.OUTRO:
		var mouth := Vector3(FieldBuilder.TUNNEL_X, 0.0, -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS)
		var push := clampf(_outro_t / 16.0, 0.0, 1.0)
		# Cámara en el césped mirando hacia la boca: desde el plano anterior,
		# los jugadores venían por detrás de cámara y casi no se veía la salida.
		# Alta y abierta al principio (se ve a todos yendo al túnel, sin que nadie
		# pase por delante de la lente); después baja y se acerca a la boca.
		var e := smoothstep(0.0, 1.0, push)
		target_pos = mouth + Vector3(lerpf(15.0, 7.5, e), lerpf(10.0, 3.6, e), lerpf(34.0, 13.0, e))
		target_look = mouth + Vector3(0.0, lerpf(0.0, 1.0, e), lerpf(14.0, 0.0, e))
		var ko := minf(1.0, 1.8 * delta)
		_cam_pos = _cam_pos.lerp(target_pos, ko)
		_cam_look = _cam_look.lerp(target_look, ko)
		_camera.fov = lerpf(_camera.fov, 50.0, ko)
		_camera.global_position = _cam_pos
		_camera.look_at(_cam_look, Vector3.UP)
		return
	if state == State.WALKOUT:
		# Plano bajo que acompaña a los equipos; con la fila formada, travelling a lo largo
		var c := Vector3.ZERO
		var n := 0
		for p in players:
			if p.visible:
				c += p.global_position
				n += 1
		c = c / float(n) if n > 0 else Vector3(0.0, 0.0, -FIELD_WIDTH * 0.5)
		var tifo := get_node_or_null("Tifo") as Node3D
		if tifo and _walk_t < _tifo_shot:
			# Plano general del fondo: el tifo se despliega de abajo arriba
			var tp := tifo.global_position
			var k := _walk_t / _tifo_shot
			_camera.global_position = Vector3(tp.x + lerpf(30.0, 26.0, k), lerpf(9.0, 10.5, k), lerpf(6.0, 2.0, k))
			_camera.fov = 52.0
			_camera.look_at(tp + Vector3(0.0, -0.5, 0.0), Vector3.UP)
			_cam_pos = _camera.global_position
			_cam_look = Vector3(FieldBuilder.TUNNEL_X, 0.0, -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS - 2.5)
			return
		var t0 := WALK_REFS + _tifo_shot # cruzan la puerta los árbitros
		if _walk_done_t <= 0.0 and _walk_t < t0 + TUNNEL_SHOT:
			# Desde el césped, a la altura de los ojos y mirando dentro de la manga: los
			# equipos salen hacia la cámara, que retrocede despacio y los sigue
			var k := clampf((_walk_t - (t0 - 1.0)) / (TUNNEL_SHOT + 1.0), 0.0, 1.0)
			var mouth_z := -FIELD_WIDTH * 0.5 - FieldBuilder.SIDE_STANDS
			var lead := Vector3(FieldBuilder.TUNNEL_X, 0.0, mouth_z - 1.5)
			for p in players:
				if p.visible and p.global_position.z > lead.z:
					lead = p.global_position
			for r: Node3D in staff.refs:
				if r.visible and r.global_position.z > lead.z:
					lead = r.global_position
			# A un costado del recorrido (los jugadores giran hacia la banda delante de
			# la manga): ni atraviesan la lente ni se cuelan las mamparas de los bancos.
			target_pos = Vector3(FieldBuilder.TUNNEL_X + lerpf(2.0, 3.0, k), lerpf(1.3, 1.7, k),
					-FIELD_WIDTH * 0.5 + lerpf(0.0, 2.0, k))
			# Pequeño vaivén de cámara al hombro
			target_pos += Vector3(sin(_walk_t * 1.7) * 0.06, sin(_walk_t * 2.3) * 0.04, 0.0)
			target_look = Vector3(FieldBuilder.TUNNEL_X, 1.35, lerpf(mouth_z - 1.0, lead.z, 0.7))
			target_fov = lerpf(38.0, 48.0, k)
			if _walk_t < t0 - 0.9:
				_cam_pos = target_pos # corte limpio desde el plano del tifo / la intro
				_cam_look = target_look
		elif _walk_done_t > 0.0:
			var x := lerpf(-10.0, 10.0, smoothstep(0.0, 1.0, clampf(_walk_done_t / WALK_LINE_PAN, 0.0, 1.0)))
			target_pos = Vector3(x, 1.7, 4.8)
			target_look = Vector3(x * 0.8, 1.3, -2.0)
			target_fov = 46.0
		else:
			# Los acompaña de lado, a ras de césped, camino de la fila
			target_pos = c + Vector3(5.5, 2.2, 8.5)
			target_look = c + Vector3(0.0, 1.1, 0.0)
		var kw := minf(1.0, 2.0 * delta)
		_cam_pos = _cam_pos.lerp(target_pos, kw)
		_cam_look = _cam_look.lerp(target_look, kw)
		_camera.fov = lerpf(_camera.fov, target_fov, kw)
		_camera.global_position = _cam_pos
		_camera.look_at(_cam_look, Vector3.UP)
		return
	if state == State.CUTSCENE and is_instance_valid(_cut_target):
		# Plano a pie de banda, de frente al banquillo / a ti saliendo a la banda
		var tp := _cut_target.global_position
		target_pos = tp + Vector3(2.2, 1.5, 3.6)
		target_look = tp + Vector3(0.0, 0.9, 0.0)
		target_fov = 45.0
		var kc := minf(1.0, 3.0 * delta)
		_cam_pos = _cam_pos.lerp(target_pos, kc)
		_cam_look = _cam_look.lerp(target_look, kc)
		_camera.fov = lerpf(_camera.fov, target_fov, kc)
		_camera.global_position = _cam_pos
		_camera.look_at(_cam_look, Vector3.UP)
		return
	if _card_cam_t > 0.0 and is_instance_valid(_card_fouler) and not staff.refs.is_empty():
		# Plano de la tarjeta: árbitro y jugador de perfil, a media altura
		_card_cam_t -= delta / maxf(Engine.time_scale, 0.01)
		var rp: Vector3 = staff.refs[0].global_position
		var fp := _card_fouler.global_position
		var mid := fp.lerp(rp, 0.4)
		var side := flat(rp - fp).cross(Vector3.UP).normalized()
		if side.length() < 0.5:
			side = Vector3.BACK
		if side.z < 0.0:
			side = -side # siempre desde el lado de la cámara de TV
		var kc := minf(1.0, 3.5 * delta)
		_cam_pos = _cam_pos.lerp(mid + side * 6.0 + Vector3(0.0, 2.0, 0.0), kc)
		_cam_look = _cam_look.lerp(mid + Vector3(0.0, 1.3, 0.0), kc)
		_camera.fov = lerpf(_camera.fov, 45.0, kc)
		_camera.global_position = _cam_pos
		_camera.look_at(_cam_look, Vector3.UP)
		return
	var broadcast := false
	if third and moment_type == Moment.KEEPER and _cam_subject != null:
		# Portero: detrás de tu portería, mirando al campo (la jugada viene hacia ti)
		var gz := clampf(b.z * 0.25, -3.0, 3.0)
		target_pos = goal_center(0) + Vector3(-5.0, 3.0, gz)
		target_look = Vector3(lerpf(-40.0, b.x, 0.5), 0.6, b.z * 0.5)
		target_fov = 62.0
	elif third and _cam_subject != null:
		var p := _cam_subject.global_position
		var look_point := p + Vector3(9.0, 0.0, 0.0)
		# Si el balón vuela lejos (pase, tiro) la cámara gira un poco hacia él
		if ball.owner_player == null and flat_dist(p, b) > 4.0:
			look_point = look_point.lerp(flat(b), 0.35)
		# La cámara SIEMPRE queda detrás del jugador, en la dirección en que mira
		# (su facing se va girando suave al correr, así la cámara también gira suave).
		var fwd := flat(_cam_subject.facing).normalized()
		if fwd == Vector3.ZERO:
			fwd = flat(look_point - p).normalized()
		if fwd == Vector3.ZERO:
			fwd = Vector3(attack_dir(0), 0.0, 0.0)
		var right := fwd.cross(Vector3.UP)
		target_pos = p - fwd * 2.9 - right * 0.5 + Vector3(0.0, 3.3, 0.0)
		# Mira hacia delante; si el balón vuela lejos, se gira un poco hacia él
		var look_dir := fwd
		if ball.owner_player == null and flat_dist(p, b) > 4.0:
			look_dir = flat(look_point.lerp(flat(b), 0.35) - p).normalized()
			if look_dir.dot(fwd) < 0.2:
				look_dir = fwd
		target_look = p + look_dir * 6.0 + Vector3(0.0, 0.3, 0.0)
		target_fov = 65.0
	else:
		# Cámara de transmisión: alta en la banda de enfrente de los banquillos.
		# El foco no va pegado al balón: con dueño mira un poco por delante de él (se ve
		# el espacio hacia donde ataca) y con el balón volando lo sigue con un muelle
		# amortiguado, algo más lento cuanto más rápido va (en un pase largo no pega el
		# latigazo y da tiempo a leer adónde cae).
		var raw := flat(b)
		var holder := ball.owner_player
		var lag := 0.45
		if holder != null:
			raw = flat(holder.global_position).lerp(raw, 0.6) + flat(holder.facing) * 3.0
		else:
			var bv := flat(ball.linear_velocity)
			raw += bv.limit_length(12.0) * 0.18
			lag = lerpf(0.45, 0.8, clampf((bv.length() - 8.0) / 14.0, 0.0, 1.0))
		raw.x = clampf(raw.x, -FIELD_LENGTH * 0.5 + 14.0, FIELD_LENGTH * 0.5 - 14.0)
		raw.z *= 0.4
		if _cam_focus == Vector3.ZERO and _cam_focus_v == Vector3.ZERO:
			_cam_focus = raw
		_cam_focus = _smooth_damp(_cam_focus, raw, lag, delta)
		target_pos = Vector3(_cam_focus.x * 0.85, 21.0, _cam_focus.z + 34.0)
		target_look = _cam_focus + Vector3(0.0, 0.0, -2.0)
		target_fov = 48.0
		broadcast = true
	# La de TV ya va suavizada por su muelle: aquí solo se funde rápido con el plano anterior
	var k := minf(1.0, (7.0 if broadcast else 4.0) * delta)
	_cam_pos = _cam_pos.lerp(target_pos, k)
	_cam_look = _cam_look.lerp(target_look, k)
	_camera.fov = lerpf(_camera.fov, target_fov, k)
	_camera.global_position = _cam_pos
	_camera.look_at(_cam_look, Vector3.UP)
	_update_occlusion(third and _cam_subject != null)


## Muelle críticamente amortiguado (como SmoothDamp): llega a `target` en unos
## `smooth_time` segundos sin rebotar y sin tirones, guardando la velocidad en _cam_focus_v.
func _smooth_damp(cur: Vector3, target: Vector3, smooth_time: float, dt: float) -> Vector3:
	if dt <= 0.0:
		return cur
	var omega := 2.0 / maxf(smooth_time, 0.01)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var temp := (_cam_focus_v + change * omega) * dt
	_cam_focus_v = (_cam_focus_v - temp * omega) * e
	return target + (change + temp) * e


## Vuelve semitransparentes a los jugadores que tapan a tu jugador o al balón.
func _update_occlusion(active: bool) -> void:
	_occlusion_acc += get_physics_process_delta_time()
	if _occlusion_acc < 0.08:
		return
	_occlusion_acc = 0.0
	var cam := _cam_pos
	var targets: Array[Vector3] = []
	if active:
		targets.append(_cam_subject.global_position + Vector3.UP)
		targets.append(ball.global_position)
	for p in players:
		var fade := false
		if active and p != _cam_subject:
			var body := p.global_position + Vector3.UP
			if cam.distance_to(body) < 3.5:
				fade = true
			else:
				for target in targets:
					var seg := target - cam
					var t := (body - cam).dot(seg) / maxf(seg.length_squared(), 0.001)
					if t > 0.0 and t < 0.95 and (cam + seg * t).distance_to(body) < 1.0:
						fade = true
						break
		p.set_faded(fade)


# ---------- consultas que usa la IA ----------

func attack_dir(team: int) -> float:
	return 1.0 if team == 0 else -1.0


## Centro de la portería que defiende `team`.
func goal_center(team: int) -> Vector3:
	return Vector3(-FIELD_LENGTH * 0.5 * attack_dir(team), 0.0, 0.0)


func opponent_goal_center(team: int) -> Vector3:
	return goal_center(1 - team)


func to_world(team: int, local: Vector3) -> Vector3:
	var s := attack_dir(team)
	return Vector3(local.x * s, 0.0, local.z * s)


func in_own_box(team: int, pos: Vector3) -> bool:
	var lx := pos.x * attack_dir(team)
	return lx < -FIELD_LENGTH * 0.5 + BOX_DEPTH and absf(pos.z) < BOX_WIDTH * 0.5


## Posición táctica (como ProtoSim): cada línea se desplaza con el balón lo suyo,
## sube si tenemos la posesión y no pasa de sus límites.
func formation_target(p: SoccerPlayer, bpos: Variant = null, poss: int = -2) -> Vector3:
	var b: Vector3 = ball.global_position if bpos == null else bpos
	if poss == -2:
		poss = possession_team
	var base: Vector3 = _bases[p.team][p.index]
	var s := attack_dir(p.team)
	if p.is_keeper:
		return to_world(p.team, Vector3(-FIELD_LENGTH * 0.5 + 1.5, 0.0, clampf(b.z * s * 0.1, -2.0, 2.0)))
	var role := p.role
	var bx := b.x * s
	var attacking := poss == p.team
	var bxx := base.x
	if role == "DF" and not attacking:
		bxx = _df_base_mean(p.team) # defensa en línea: todos a la misma altura
	var x: float = bxx + (bx + 5.0) * float(ROLE_SHIFT[role]) + (float(ROLE_PUSH[role]) if attacking else -3.0)
	if role == "DF" and not attacking and _now_s() < float(_trap_until[p.team]):
		x += 3.5 # salen todos a la vez: el delantero queda en fuera de juego
	x = clampf(x, float(ROLE_MIN_X[role]), float(ROLE_MAX_X[role]))
	# La defensa no se queda por detrás del balón cuando atacamos (fuera de juego del rival)
	if attacking and role == "DF":
		x = maxf(x, minf(bx - 30.0, 0.0))
	var z := clampf(base.z * 0.85 + b.z * s * 0.3, -FIELD_WIDTH * 0.5 + 1.5, FIELD_WIDTH * 0.5 - 1.5)
	return to_world(p.team, Vector3(x, 0.0, z))


## Formación en coordenadas locales (ataca hacia +X, portería propia en x = -52.5).
func _formation_local(fname: String) -> Array:
	var bases: Array = FORMATION_BASES.get(fname, FORMATION_BASES["4-3-3"])
	var out: Array = [Vector3(-FIELD_LENGTH * 0.5 + 1.5, 0.0, 0.0)]
	for v: Vector2 in bases:
		out.append(Vector3(FIELD_LENGTH * 0.5 - v.y, 0.0, v.x - FIELD_WIDTH * 0.5))
	return out


## Línea de cada puesto: "4-3-3" = 4 DF, 3 MF, 3 ST; "4-2-3-1" = 4 DF, 5 MF, 1 ST.
func _formation_roles(fname: String) -> Array:
	var parts := fname.split("-")
	var roles: Array = ["GK"]
	for i in parts.size():
		var role := "DF" if i == 0 else ("ST" if i == parts.size() - 1 else "MF")
		for k in int(parts[i]):
			roles.append(role)
	while roles.size() < PLAYERS_PER_TEAM:
		roles.append("MF")
	return roles


## Hueco de la formación para tu jugador: el de tu línea más centrado.
func _star_slot(role: String) -> int:
	if role == "GK":
		return 0
	var best := PLAYERS_PER_TEAM - 1
	var best_z := INF
	for i in range(1, PLAYERS_PER_TEAM):
		var p: SoccerPlayer = teams[0][i]
		var z := absf((_bases[0][i] as Vector3).z)
		if p.role == role and z < best_z:
			best_z = z
			best = i
	return best


## Coloca a todos donde estarían si el balón estuviera en `bp` y lo tuviera `poss`.
func _place_team_for(bp: Vector3, poss: int) -> void:
	for p in players:
		var target := formation_target(p, bp, poss)
		target += Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		_place(p, target)


func _nearest_of_role(team: int, point: Vector3, roles: Array, exclude: Array = []) -> SoccerPlayer:
	var best: SoccerPlayer = null
	var best_d := INF
	for p: SoccerPlayer in teams[team]:
		if p in exclude or not (p.role in roles):
			continue
		var d := flat_dist(p.global_position, point)
		if d < best_d:
			best_d = d
			best = p
	return best


## Dónde puede alcanzar `p` el balón suelto: recorre su trayectoria futura (con el frenado
## del césped) y devuelve el primer punto al que llega a tiempo corriendo.
var _intercept_cache := {}
var _intercept_frame := -1

## Mismo resultado que intercept_point, pero calculado una vez por frame y jugador.
func intercept_point_cached(p: SoccerPlayer) -> Vector3:
	var f := Engine.get_physics_frames()
	if f != _intercept_frame:
		_intercept_cache.clear()
		_intercept_frame = f
	if not _intercept_cache.has(p):
		_intercept_cache[p] = intercept_point(p)
	return _intercept_cache[p]


func intercept_point(p: SoccerPlayer) -> Vector3:
	var b := flat(ball.global_position)
	var v := flat(ball.linear_velocity)
	if v.length() < 1.0:
		return b
	var spd := SoccerPlayer.SPRINT_SPEED * lerpf(0.86, 1.14, p.stat("speed"))
	var y0 := ball.global_position.y
	var vy := ball.linear_velocity.y
	if y0 > 0.5 or vy > 2.0:
		# Por el aire (frenado k del aire): el primer punto al que llega con el balón a la
		# altura de la cabeza (bajando) o, si no, donde bota
		var k := 0.4
		var pos := b
		for i in range(1, 31):
			var t := i * 0.06
			var f := (1.0 - exp(-k * t)) / k
			pos = b + v * f
			var y := y0 + (vy + 9.8 / k) * f - 9.8 * t / k
			var falling := vy - 9.8 * t < 0.0
			var head := not p.is_keeper and falling and y < 2.1 and y > 1.3
			if y < 0.3 or head:
				if y < 0.3 or flat_dist(p.global_position, pos) <= spd * t * 0.85 + 0.4:
					return _clamp_to_field(pos)
		return _clamp_to_field(pos)
	var damp := 0.6
	var pos := b
	for i in range(1, 21):
		var t := i * 0.1
		pos = b + v * (1.0 - exp(-damp * t)) / damp
		if flat_dist(p.global_position, pos) <= spd * t * 0.85 + 0.6:
			return _clamp_to_field(pos)
	return _clamp_to_field(pos)


func closest_to_point(team: int, point: Vector3, exclude_keeper: bool) -> SoccerPlayer:
	var best: SoccerPlayer = null
	var best_d := INF
	for p: SoccerPlayer in teams[team]:
		if exclude_keeper and p.is_keeper:
			continue
		var d := flat_dist(p.global_position, point)
		if d < best_d:
			best_d = d
			best = p
	return best


## Igual que closest_to_point, pero el resultado se comparte dentro del mismo frame:
## la IA pregunta por el mismo balón diez veces por frame y no hace falta repetirlo.
var _closest_cache := {}
var _closest_frame := -1

func closest_to_point_cached(team: int, point: Vector3, exclude_keeper: bool) -> SoccerPlayer:
	var f := Engine.get_physics_frames()
	if f != _closest_frame:
		_closest_cache.clear()
		_closest_frame = f
	var key := Vector3i(team * 2 + (1 if exclude_keeper else 0), roundi(point.x * 4.0), roundi(point.z * 4.0))
	if not _closest_cache.has(key):
		_closest_cache[key] = closest_to_point(team, point, exclude_keeper)
	return _closest_cache[key]


func nearest_opponent_distance(p: SoccerPlayer, point: Vector3) -> float:
	var best := INF
	for o: SoccerPlayer in teams[1 - p.team]:
		best = minf(best, flat_dist(o.global_position, point))
	return best


func lane_clear(a: Vector3, b: Vector3, team: int) -> bool:
	var ab := flat(b - a)
	var len2 := maxf(ab.length_squared(), 0.001)
	for o: SoccerPlayer in teams[1 - team]:
		var ao := flat(o.global_position - a)
		var t := clampf(ao.dot(ab) / len2, 0.0, 1.0)
		if (ao - ab * t).length() < 1.2:
			return false
	return true


func best_pass_option(p: SoccerPlayer) -> SoccerPlayer:
	var best: SoccerPlayer = null
	var best_score := -INF
	var s := attack_dir(p.team)
	for mate: SoccerPlayer in teams[p.team]:
		if mate == p or mate.is_keeper or not mate.visible: # (el expulsado no cuenta)
			continue
		var to := flat(mate.global_position - p.global_position)
		var d := to.length()
		if d < 3.0 or d > 32.0:
			continue
		if not lane_clear(p.global_position, mate.global_position, p.team):
			continue
		# Ve que está adelantado y no se la da (con poca visión, a veces sí)
		if is_offside_now(mate) and randf() < AiTuning.offside_awareness(p.stat("passing"), p.stat("decision_making")):
			continue
		var open := minf(nearest_opponent_distance(mate, mate.global_position), 6.0)
		# Un pasador con mejor visión valora más al hombre desmarcado.
		var value := to.x * s * 0.35 + open * AiTuning.vision_weight(p.stat("passing")) - d * 0.05
		if value > best_score:
			best_score = value
			best = mate
	return best


## Camiseta del rival que no se confunda con la tuya.
# ---------- planteles reales (FootballCareer) ----------

## Pone nombre, stats y cara a cada jugador con los planteles que manda FootballCareer:
## cada uno va a un hueco de su línea (GK / DF / MF / ST); si no queda, al que sobre.
func _apply_rosters() -> void:
	for t in 2:
		_names[t] = []
		_names[t].resize(PLAYERS_PER_TEAM)
		_names[t].fill("")
		var pool: Array = (config.get(["home_players", "away_players"][t], []) as Array).duplicate()
		for i in PLAYERS_PER_TEAM:
			var p: SoccerPlayer = teams[t][i]
			if p == star and _bench_until <= 0.0:
				_names[t][i] = profile.player_name
				continue
			if pool.is_empty():
				continue
			var pick := -1
			for k in pool.size():
				if String((pool[k] as Dictionary).get("position", "")) == p.role:
					pick = k
					break
			if pick < 0:
				for k in pool.size():
					if (String((pool[k] as Dictionary).get("position", "")) == "GK") == p.is_keeper:
						pick = k
						break
			if pick < 0:
				pick = 0
			var d: Dictionary = pool.pop_at(pick)
			_names[t][i] = String(d.get("name", ""))
			if d.get("stats") is Dictionary:
				p.set_stats(d.stats)
			if d.get("look") is Dictionary:
				p.apply_look(d.look)


func _name_of(p: SoccerPlayer) -> String:
	if p == null or _names[p.team].size() <= p.index:
		return ""
	return String(_names[p.team][p.index])


## Goleador del resto del partido: sobre todo delanteros y medios (nunca tú: tus goles
## son los de las jugadas). "" si no hay planteles.
func _scorer_name(t: int) -> String:
	var total := 0.0
	var opts: Array = []
	for p: SoccerPlayer in teams[t]:
		var n := _name_of(p)
		if n == "" or p == star or p.is_keeper:
			continue
		var w: float = {"ST": 3.0, "MF": 1.6, "DF": 0.5}.get(p.role, 1.0)
		total += w
		opts.append([n, w])
	var r := randf() * total
	for o: Array in opts:
		r -= float(o[1])
		if r <= 0.0:
			return String(o[0])
	return ""


func _log_goal(t: int, m: int, who: String, assist_star: bool, by_star := false) -> void:
	match_stats.goals_log.append({"team": t, "minute": m, "name": who, "assist_star": assist_star, "star": by_star})


static func _rival_shirt(mine: Color) -> Color:
	for c: Color in [TEAM_COLORS[1], TEAM_COLORS[0], Color("f5c518"), Color("1f9d4a")]:
		if Vector3(c.r - mine.r, c.g - mine.g, c.b - mine.b).length() > 0.45:
			return c
	return TEAM_COLORS[1]


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return flat(a - b).length()


# ---------- fuera de juego y VAR ----------

func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0


## Línea de fuera de juego (x del mundo) para los atacantes de `team`.
func offside_line_world(team: int) -> float:
	var s := attack_dir(team)
	var xs: Array = []
	for o: SoccerPlayer in teams[1 - team]:
		if o.visible:
			xs.append(o.global_position.x * s)
	return Offside.line_x(xs, ball.global_position.x * s) * s


## Metros que `p` está por delante de la línea ahora mismo (> 0: adelantado).
func offside_margin_now(p: SoccerPlayer) -> float:
	var s := attack_dir(p.team)
	return Offside.margin(p.global_position.x * s, offside_line_world(p.team) * s)


func is_offside_now(p: SoccerPlayer) -> bool:
	return offside_margin_now(p) > Offside.TOLERANCE


## En cada golpeo: foto de quién del equipo que golpea está adelantado o en línea.
func _on_ball_kicked(by: SoccerPlayer, _kind: String) -> void:
	if by == null or not (state == State.MOMENT or state == State.SIMULATING):
		_offside_snap = {}
		return
	if _offside_touch(by):
		return # remató de primeras un balón que le llegó en fuera de juego
	if not _var_pending.is_empty() and int(_var_pending.get("team", -1)) != by.team:
		_var_pending = {}
	if _corner_exempt:
		_corner_exempt = false
		_offside_snap = {}
		return
	var s := attack_dir(by.team)
	var line := offside_line_world(by.team) * s
	var list := {}
	for mate: SoccerPlayer in teams[by.team]:
		if mate == by or not mate.visible:
			continue
		var mg := Offside.margin(mate.global_position.x * s, line)
		if mg > -0.5: # adelantado o muy justo (el VAR lo miraría)
			list[mate] = {"margin": mg, "line_w": line * s, "px_w": mate.global_position.x}
	_offside_snap = {"team": by.team, "players": list}


## `p` toca el balón: si en el último pase estaba adelantado, se pita (o el línea no
## lo ve y queda para el VAR). Devuelve true si se cortó la jugada.
func _offside_touch(p: SoccerPlayer) -> bool:
	if _offside_snap.is_empty() or _scripted_goal_receiver != null:
		return false
	if int(_offside_snap.team) != p.team:
		_offside_snap = {} # lo jugó el rival: se acabó el fuera de juego
		_var_pending = {}
		return false
	var e: Variant = (_offside_snap.players as Dictionary).get(p)
	_offside_snap = {}
	if e == null:
		return false
	var info: Dictionary = e
	var margin := float(info.margin)
	var offside := margin > Offside.TOLERANCE
	if offside and not DecisionResolver.offside_flag_missed(margin):
		_call_offside(p)
		return true
	_var_pending = {"team": p.team, "offside": offside, "player": p,
		"line_w": info.line_w, "px_w": info.px_w, "z": p.global_position.z}
	return false


## Bandera del línea y silbato. En una jugada la cierra; en la simulación, tiro
## libre para el equipo que defendía desde donde estaba el adelantado.
func _call_offside(p: SoccerPlayer) -> void:
	_offside_snap = {}
	_var_pending = {}
	SoundFx.play("whistle", -2.0)
	if staff != null:
		staff.flag_up(0 if p.global_position.x >= 0.0 else 1, 2.6)
	var who := profile.player_name if p == star else _name_of(p)
	if state == State.MOMENT:
		var text := "¡FUERA DE JUEGO!"
		if p == star:
			text += "\nTe adelantaste: espera en la línea"
		elif p.team == 0:
			text += "\n%s estaba adelantado" % (who if who != "" else "Tu compañero")
		else:
			text += "\nLa defensa dejó adelantado a %s" % (who if who != "" else "su delantero")
		_finish_moment(text)
		return
	_hud.add_feed("%d'  Fuera de juego%s" % [int(minute), (" de " + who) if who != "" else ""])
	_hud.show_message("FUERA DE JUEGO", 1.2, 0.3)
	_offside_restart(p.global_position, 1 - p.team)


func _offside_restart(spot: Vector3, team: int) -> void:
	var taker: SoccerPlayer = null
	var best := INF
	for d: SoccerPlayer in teams[team]:
		if d.is_keeper or not d.visible:
			continue
		var dd := flat_dist(d.global_position, spot)
		if dd < best:
			best = dd
			taker = d
	if taker == null:
		_ambient_kickoff()
		return
	var at := Vector3(clampf(spot.x, -FIELD_LENGTH * 0.5 + 2.0, FIELD_LENGTH * 0.5 - 2.0), 0.0,
			clampf(spot.z, -FIELD_WIDTH * 0.5 + 1.0, FIELD_WIDTH * 0.5 - 1.0))
	_place(taker, at)
	taker.facing = Vector3(attack_dir(team), 0.0, 0.0)
	possession_team = team
	_give_ball_now(taker)


## Al preparar una jugada, nadie del equipo que ataca empieza adelantado (los
## compañeros esperan en la línea; tú también). Del córner y del penalti no.
func _onside_setup(kind: Moment) -> void:
	if kind == Moment.CORNER or kind == Moment.PENALTY or ball.owner_player == null:
		return
	var team := ball.owner_player.team
	var s := attack_dir(team)
	var line := offside_line_world(team) * s
	for p: SoccerPlayer in teams[team]:
		if p == ball.owner_player or p.is_keeper or not p.visible:
			continue
		if p.global_position.x * s > line - 0.3:
			_place(p, Vector3((line - randf_range(0.4, 1.6)) * s, 0.0, p.global_position.z))


## Línea adelantada: cada pocos segundos, si el rival lleva el balón, la defensa
## puede salir a la vez (AiTuning.offside_trap_chance según su lectura).
func _update_offside_trap() -> void:
	var holder := ball.owner_player
	if holder == null:
		return
	var t := 1 - holder.team
	var now := _now_s()
	if now < float(_trap_next[t]):
		return
	_trap_next[t] = now + randf_range(3.0, 6.0)
	# Solo con el balón lejos de su área (si no, salir es regalar el gol)
	if flat_dist(holder.global_position, goal_center(t)) < 30.0:
		return
	var dm := 0.0
	var n := 0
	for d: SoccerPlayer in teams[t]:
		if d.role == "DF":
			dm += d.stat("decision_making")
			n += 1
	if n > 0 and randf() < AiTuning.offside_trap_chance(dm / n):
		_trap_until[t] = now + 1.4


## Altura media de los defensas en la formación (para defender en línea).
func _df_base_mean(team: int) -> float:
	var sum := 0.0
	var n := 0
	for i in PLAYERS_PER_TEAM:
		var p: SoccerPlayer = teams[team][i]
		if p.role == "DF":
			sum += (_bases[team][i] as Vector3).x
			n += 1
	return sum / n if n > 0 else -30.0


## El VAR revisa el gol: líneas en el césped, cámara lateral y la decisión.
func _start_var_review(team: int) -> void:
	var info := _var_pending.duplicate()
	_var_pending = {}
	_offside_snap = {}
	var caught := bool(info.get("offside", false)) and DecisionResolver.var_catches_offside(_referee_var_mult)
	_var = {"team": team, "from": state, "t": 0.0, "caught": caught, "info": info, "done": false}
	_end_decision()
	state = State.VAR_REVIEW
	Engine.time_scale = 1.0
	_set_human(null)
	ball.owner_player = null
	_hud.set_hint("")
	_hud.show_message("VAR\nRevisando posible fuera de juego", 2.8, 0.3)
	SoundFx.set_crowd(-20.0)
	_var_lines(info)


func _var_lines(info: Dictionary) -> void:
	var old := get_node_or_null("VarLines")
	if old:
		old.free()
	var root := Node3D.new()
	root.name = "VarLines"
	add_child(root)
	var lx := float(info.get("line_w", 0.0))
	var px := float(info.get("px_w", lx))
	var line := FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(0.08, 0.02, FIELD_WIDTH)), Vector3(lx, 0.03, 0.0), Color(1.4, 0.15, 0.2), true)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mark := FieldBuilder.add_mesh(root, FieldBuilder.box(Vector3(0.08, 0.02, 9.0)), Vector3(px, 0.04, float(info.get("z", 0.0))), Color(0.2, 0.6, 1.5), true)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _var_camera(delta: float) -> void:
	var info: Dictionary = _var.get("info", {})
	var lx := float(info.get("line_w", 0.0))
	var z := float(info.get("z", 0.0))
	var side := -1.0 if z >= 0.0 else 1.0
	var target_pos := Vector3(lx, 11.0, z + side * 16.0)
	var target_look := Vector3(lx, 0.0, z)
	var k := minf(1.0, 2.5 * delta)
	_cam_pos = _cam_pos.lerp(target_pos, k)
	_cam_look = _cam_look.lerp(target_look, k)
	_camera.global_position = _cam_pos
	_camera.look_at(_cam_look, Vector3.UP)


func _update_var_review(delta: float) -> void:
	_var.t = float(_var.t) + delta
	if bool(_var.done):
		if float(_var.t) > 4.6:
			_finish_var_review()
		return
	if float(_var.t) < 3.0:
		return
	_var.done = true
	var team := int(_var.team)
	if bool(_var.caught):
		var who_p: SoccerPlayer = _var.info.get("player")
		var who := profile.player_name if who_p == star else _name_of(who_p)
		_hud.show_message("GOL ANULADO\nFuera de juego%s" % ((" de " + who) if who != "" else ""), 1.8, 0.3)
		SoundFx.play("whistle", -2.0)
		_hud.add_feed("%d'  VAR: gol anulado por fuera de juego" % int(minute))
	else:
		_hud.show_message("VAR\n¡GOL VÁLIDO!", 1.6, 0.3)
		SoundFx.play("cheer", 0.0 if team == 0 else -8.0)


func _finish_var_review() -> void:
	var old := get_node_or_null("VarLines")
	if old:
		old.queue_free()
	var team := int(_var.team)
	var from: int = int(_var.from)
	var info: Dictionary = _var.info
	state = from as State
	if bool(_var.caught):
		if from == State.MOMENT:
			_finish_moment("GOL ANULADO\nEl VAR vio fuera de juego")
		else:
			var spot := Vector3(float(info.get("px_w", 0.0)), 0.0, float(info.get("z", 0.0)))
			_offside_restart(spot, 1 - team)
		SoundFx.set_crowd(-14.0)
		return
	if from == State.MOMENT:
		Engine.time_scale = MOMENT_TIME_SCALE
	_var_cleared = true
	_on_goal_area_entered(ball, team)
