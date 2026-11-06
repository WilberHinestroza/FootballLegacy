extends Resource
class_name LeagueData

## Una liga doméstica del mundo del juego.
##
## Aprendizaje de Football Legacy: las selecciones nacionales usan el
## sentinela league_id == -1 (ver ClubData.is_national_team()) y DEBEN
## filtrarse de todo lo que sea liga / fichajes / calendario. Aquí los
## league_id son siempre >= 1.
##
## Sin nombres de marca con licencia (misma disciplina que con los
## futbolistas): las ligas se nombran por país + división, p. ej.
## "Primera División (España)".

const FORMAT_SINGLE_RR := "single_round_robin"   # todos contra todos una vez
const FORMAT_DOUBLE_RR := "double_round_robin"   # ida y vuelta (lo habitual)
const FORMAT_TRIPLE_RR := "triple_round_robin"   # ligas muy pequeñas

@export var league_id: int = 0
@export var league_name: String = ""
@export var country: String = ""
@export var tier: int = 1
@export var team_count: int = 20
@export var format: String = FORMAT_DOUBLE_RR
@export var has_playoffs: bool = false           # liguilla / play-off de título tras la fase regular
@export var has_domestic_cup: bool = true
@export var reputation: int = 50                 # 0-100: escala dificultad y calidad de ofertas

func rounds_multiplier() -> int:
	match format:
		FORMAT_SINGLE_RR:
			return 1
		FORMAT_TRIPLE_RR:
			return 3
		_:
			return 2

func matches_per_team() -> int:
	return rounds_multiplier() * (team_count - 1)

func matchdays() -> int:
	# team_count par -> nº de jornadas == partidos por equipo.
	# team_count impar -> cada jornada un equipo descansa, y hacen falta
	# team_count jornadas por vuelta.
	if team_count % 2 == 0:
		return matches_per_team()
	return rounds_multiplier() * team_count
