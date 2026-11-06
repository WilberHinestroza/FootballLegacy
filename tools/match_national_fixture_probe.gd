extends Node

## Prueba dirigida del bug real reportado por Wilber en un partido de
## SELECCIÓN: "las pantallas de selección no son como las normales" /
## "no necesitan escudos, con la bandera basta". Causa raíz: Match.gd (la
## pantalla EN VIVO del partido, distinta del resumen post-partido que ya
## tiene NationalMatchSummary) seguía buscando el club por
## fixture["home_club_id"]/["away_club_id"] — un fixture de selección usa
## ["home_country"]/["away_country"], así que WorldFactory.find_club()
## daba SIEMPRE null y todo caía a un genérico en blanco (escudo, color
## de camiseta) o a comparaciones que daban siempre false
## (_user_side_is(), _context_mods() de visitante).
##
## No instancia Match.tscn completo (necesitaría un MatchEngine real
## corriendo) — llama los métodos de Match.gd DIRECTO sobre una instancia
## sin agregar al árbol (nunca se dispara _ready(), así que los @onready
## de nodos de UI no importan: ninguno de los métodos probados los toca).
##   godot --headless res://tools/MatchNationalFixtureProbe.tscn

func _ready() -> void:
	var problems: int = 0
	var m = (load("res://scenes/Match/Match.gd") as GDScript).new()

	# --- Partido de selección: Argentina (local) vs Brasil ---
	MatchState.fixture = {"competition": "qualifying", "home_country": "Argentina", "away_country": "Brasil"}
	var p := PlayerData.new()
	p.player_name = "Probe"
	p.country = "Argentina"
	p.club_id = "algun_club_real"   # sigue jugando en un club — no cambia por estar convocado
	MatchState.user_player = p

	var is_national: bool = m._is_national_fixture()
	print("_is_national_fixture() en partido de selección: %s (esperado true)" % is_national)
	if not is_national:
		problems += 1

	var home_name: String = m._side_name(true)
	var away_name: String = m._side_name(false)
	print("nombres: home=%s away=%s (esperado Argentina/Brasil)" % [home_name, away_name])
	if home_name != "Argentina" or away_name != "Brasil":
		problems += 1

	var home_crest = m._side_crest(true, 40)
	var away_crest = m._side_crest(false, 40)
	print("crests no-null: home=%s away=%s" % [home_crest != null, away_crest != null])
	if home_crest == null or away_crest == null:
		problems += 1

	m._resolve_team_colors()
	var colors_differ: bool = m._home_color != m._away_color
	var not_default_blue: bool = m._home_color != Color(0.2, 0.45, 0.75)
	print("colores derivados del país: home=%s away=%s (distintos=%s, no-genérico=%s)" % [m._home_color, m._away_color, colors_differ, not_default_blue])
	if not colors_differ or not not_default_blue:
		problems += 1

	# El usuario juega de LOCAL (Argentina = home) — _user_side_is(true)
	# debe dar true (antes daba SIEMPRE false en partidos de selección).
	var user_is_home_side: bool = m._user_side_is(true)
	var user_is_away_side: bool = m._user_side_is(false)
	print("_user_side_is(): local=%s visitante=%s (esperado true/false, jugando de local)" % [user_is_home_side, user_is_away_side])
	if not user_is_home_side or user_is_away_side:
		problems += 1

	# --- El mismo usuario ahora de VISITANTE (Brasil de local) ---
	MatchState.fixture = {"competition": "qualifying", "home_country": "Brasil", "away_country": "Argentina"}
	var mods: Array = m._context_mods()
	print("_context_mods() de visitante en selección: width_factor=%.3f (esperado < 1.0, penalización de visitante)" % float(mods[0]))
	if float(mods[0]) >= 1.0:
		problems += 1

	# --- Partido de CLUB normal: nada de esto debería cambiar de comportamiento ---
	MatchState.fixture = {"home_club_id": "club_a", "away_club_id": "club_b"}
	var is_national_club: bool = m._is_national_fixture()
	print("_is_national_fixture() en partido de club: %s (esperado false)" % is_national_club)
	if is_national_club:
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
