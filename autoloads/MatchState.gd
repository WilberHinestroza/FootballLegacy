extends Node
## Autoload. Estado COMPARTIDO entre PreMatchScreen y MatchScreen.
##
## Aprendizaje directo de FL: en Compose, hiltViewModel() por pantalla
## daba instancias DISTINTAS del ViewModel, y tuvieron que compartir
## estado vía el NavBackStackEntry de un nested nav graph padre.
## En Godot el equivalente más simple y robusto es un Autoload: como
## solo hay UNA instancia global, PreMatch y Match leen/escriben el
## mismo estado sin necesidad de pasar nada por parámetros de escena.

var engine: MatchEngine = null
var home_team: MatchTeam = null
var away_team: MatchTeam = null
var user_player: PlayerData = null

var match_result: Dictionary = {}

## Copia de `match_result["user_rating"]` que SOBREVIVE a clear() —
## bug real encontrado (Wilber: "mi prueba siempre es un 6.5 aunque mi
## nota fuera un 9"): MatchSummary._on_continue_pressed() SIEMPRE llama
## clear() (vacía match_result) ANTES de navegar a return_scene, y
## Offers.gd (destino tras el partido de prueba de creación de personaje)
## leía la nota desde match_result — ya vacío para cuando le tocaba
## correr, así que SIEMPRE caía al valor por defecto (BASE_RATING=6.5) de
## Dictionary.get(), nunca la nota real. Este campo se llena junto con
## match_result (ver Match.gd) y clear() lo deja intacto a propósito.
var last_user_rating: float = MatchRatingCalculator.BASE_RATING

## A dónde vuelve MatchScreen cuando el jugador pulsa "Continuar" tras el
## pitido final. La creación de personaje lo apunta a la pantalla de
## ofertas; un partido de liga (Fase 4) lo dejará en el Hub / resumen.
var return_scene: String = "res://scenes/Hub/Hub.tscn"

## Fixture del calendario que originó este partido ({} si es amistoso /
## prueba / debug). El Hub lo usa al volver para registrar el resultado
## real en la temporada.
var fixture: Dictionary = {}

## Elecciones de la previa (PreMatch). Cosméticas: solo afectan cómo se
## dibuja el partido, no el resultado.
##   kit_home_away / kit_away_away: true = ese equipo juega con la 2ª equipación.
##   ball_design: índice en BallDesign.DESIGNS (-1 = determinista del partido).
var kit_home_away: bool = false
var kit_away_away: bool = true
var ball_design: int = -1

## true = el usuario cumple SANCIÓN este partido (roja / doble amarilla la
## fecha pasada). El equipo juega sin él; MatchSummary lo descuenta y no
## suma estadísticas.
var user_suspended: bool = false

## Mapa de tus jugadas del partido en curso (Paquete 2 del ROADMAP): lo
## llena Match.gd con cada momento clave que se vio en la cancha 2D y lo
## dibuja MatchSummary. Solo vive mientras dura el partido + su resumen —
## NO se persiste (no es esquema). Cada entrada: {"kind": String,
## "pos": Vector2, "ok": bool, "goal": bool, "to": Vector2 | null}, en
## coordenadas de cancha entera vertical (PitchPlays.user_full_pos).
var moment_map: Array = []

## PRÁCTICA (8-nov): qué sesión lanzar ({"mode", "facet"}) y lo que salió de la
## última ({"summary", "rewards"}), entre la pantalla Práctica y el partido 3D.
## Solo en memoria: no se guarda (los retos van en season["practice"]).
var practice: Dictionary = {}
var practice_result: Dictionary = {}


func start_new_match(p_home: MatchTeam, p_away: MatchTeam, p_user_player: PlayerData, p_is_knockout: bool = false, p_instant: bool = false) -> void:
	home_team = p_home
	away_team = p_away
	user_player = p_user_player
	engine = MatchEngine.new(p_home, p_away, p_user_player, p_is_knockout, p_instant)
	match_result = {}
	moment_map = []
	gesture_stats = {"perfecto": 0, "bueno": 0, "regular": 0, "flojo": 0, "streak": 0, "best_streak": 0}

## Cómo ejecutaste los gestos de este partido (10-oct): lo llena Match.gd en
## cada momento clave y lo lee MatchSummary para la XP extra.
var gesture_stats: Dictionary = {}

## Si `fixture` trae `tie_agg` (vuelta de una copa a ida y vuelta —
## WorldTickEngine._next_user_cup_fixture la arma), la traslada a `engine`
## para que un empate en el marcador de ESTE partido, con el agregado
## también empatado, vaya a penales. ÚNICA fuente — antes cada pantalla
## que podía correr un partido (Match.gd, y "Simular"/instant en Calendar.gd
## y Hub.gd, club Y selección) tenía que acordarse de repetir este mismo
## chequeo a mano; los 4 sitios de "Simular" nunca lo hacían (bug real
## reportado por Wilber: "quedamos empate en el ida y vuelta y no hay
## penales" — el partido jugado interactivo SÍ lo aplicaba, el simulado
## instantáneo no). Llamar SIEMPRE justo antes de `engine.run_match()`.
func apply_tie_aggregate() -> void:
	var ta = fixture.get("tie_agg", null)
	if engine == null:
		return
	var first_leg := fixture.has("tie_key") and int(fixture.get("leg", 0)) == 1
	engine.set_two_leg_first_leg(first_leg)
	if ta is Dictionary:
		engine.set_tie_aggregate(int(ta.get("home", 0)), int(ta.get("away", 0)))
	elif first_leg:
		# La ida también muestra el global en vivo, que parte de 0-0.
		engine.set_tie_aggregate(0, 0)

func clear() -> void:
	engine = null
	home_team = null
	away_team = null
	user_player = null
	match_result = {}
	moment_map = []
	return_scene = "res://scenes/Hub/Hub.tscn"
	fixture = {}
	user_suspended = false
	kit_home_away = false
	kit_away_away = true
	ball_design = -1
