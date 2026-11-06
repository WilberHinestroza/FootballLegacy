extends Resource
class_name ClubData

## Equivalente a ClubEntity. league_id = -1 identifica un club virtual
## "Selección X" — DEBE filtrarse de ofertas de traspaso, fichajes de IA,
## finanzas y scouting (aprendizaje directo de Football Legacy).

@export var club_id: String = ""
@export var club_name: String = ""
@export var short_name: String = ""
@export var league_id: int = 0
@export var primary_color_hex: String = "#1B5E20"
@export var secondary_color_hex: String = "#FFD54F"

@export var league_ambition: int = 50   # 0-100, ligado a objetivos de temporada
@export var cup_ambition: int = 50
@export var europe_ambition: int = 0

## Nombre REAL del estadio si vino en el JSON importado (columna
## "stadiumName", documentada pero nunca leída hasta ahora). Vacío en
## mundos procedurales — ahí `Venue.stadium_name()` sigue con su nombre
## inventado determinista de siempre.
@export var stadium_name: String = ""

func is_national_team() -> bool:
	return league_id == -1
