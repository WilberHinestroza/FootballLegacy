extends Node

## Prueba dirigida a un bug real encontrado al agregar la entrevista a los
## partidos de selección: PostMatchInterview.gd llamaba a
## InterviewEngine.extract_context(fixture, result, player.club_id, ...)
## tal cual — pero un fixture de selección trae "home_country"/
## "away_country" en vez de "home_club_id"/"away_club_id", así que
## extract_context() nunca encontraba la clave real y calculaba
## "¿jugaste de local?" siempre en falso. Arreglado con el mismo alias
## que ya usa NationalMatchSummary.gd. Este probe reproduce la lógica de
## alias tal cual quedó en PostMatchInterview.gd y confirma "won" bien
## calculado jugando de LOCAL y de VISITANTE.
##   godot --headless res://tools/InterviewNationalContextProbe.tscn

func _ready() -> void:
	var ok: bool = true

	var player := PlayerData.new()
	player.player_name = "Probe"
	player.country = "Argentina"
	player.club_id = "c_10_0"
	player.position = "ST"

	# Caso 1: Argentina de LOCAL, gana 2-1 -> won debería ser true.
	var fx_home: Dictionary = {"home_country": "Argentina", "away_country": "Uruguay", "competition": "qualifying"}
	var result_home: Dictionary = {"score": {"home": 2, "away": 1}, "user_rating": 7.0, "rating_events": []}
	var ctx_home: Dictionary = _extract_like_postmatch(fx_home, result_home, player)
	print("Argentina LOCAL, 2-1: won=%s (esperado true)" % ctx_home.get("won", "?"))
	if bool(ctx_home.get("won", false)) != true:
		ok = false

	# Caso 2: Argentina de VISITANTE, pierde 0-1 (Uruguay local) -> won false.
	var fx_away: Dictionary = {"home_country": "Uruguay", "away_country": "Argentina", "competition": "qualifying"}
	var result_away: Dictionary = {"score": {"home": 1, "away": 0}, "user_rating": 5.0, "rating_events": []}
	var ctx_away: Dictionary = _extract_like_postmatch(fx_away, result_away, player)
	print("Argentina VISITANTE, pierde 0-1: won=%s (esperado false)" % ctx_away.get("won", "?"))
	if bool(ctx_away.get("won", true)) != false:
		ok = false

	# Caso 3 (regresión): un fixture de CLUB de verdad no se toca por el alias.
	var fx_club: Dictionary = {"home_club_id": "c_10_0", "away_club_id": "c_10_1", "competition": "league"}
	var result_club: Dictionary = {"score": {"home": 3, "away": 0}, "user_rating": 7.0, "rating_events": []}
	var ctx_club: Dictionary = InterviewEngine.extract_context(fx_club, result_club, player.club_id, player, {})
	print("partido de CLUB (sin tocar), 3-0 de local: won=%s (esperado true)" % ctx_club.get("won", "?"))
	if bool(ctx_club.get("won", false)) != true:
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

## Réplica EXACTA del alias que quedó en PostMatchInterview._ready().
func _extract_like_postmatch(fixture: Dictionary, result: Dictionary, player: PlayerData) -> Dictionary:
	var ctx_fixture: Dictionary = fixture
	var ctx_club_id: String = player.club_id
	if fixture.has("home_country"):
		ctx_fixture = fixture.duplicate()
		ctx_fixture["home_club_id"] = fixture.get("home_country", "")
		ctx_fixture["away_club_id"] = fixture.get("away_country", "")
		ctx_club_id = player.country
	return InterviewEngine.extract_context(ctx_fixture, result, ctx_club_id, player, {})
