extends RefCounted
class_name Venue

## Datos de ambiente de un partido — estadio, aforo, público y árbitro.
## TODO derivado determinista de club_id + fixture + world_seed. Nada se
## persiste (mismo criterio "mundo vivo" que los resultados de IA). Es
## puro sabor para la previa / el partido.

const _WORDS := [
	"Metropolitano", "Municipal", "del Centenario", "La Cantera", "El Coloso",
	"Olímpico", "del Parque", "Nuevo Coliseo", "La Fortaleza", "del Sur",
	"Ciudad Deportiva", "El Templo", "La Caldera", "del Bosque", "Monumental",
]

static func stadium_name(club: ClubData) -> String:
	if club == null:
		return "el estadio"
	if not club.stadium_name.is_empty():
		return club.stadium_name
	var h: int = absi(hash("venue:" + club.club_id))
	return "Estadio %s" % _WORDS[h % _WORDS.size()]

## Bug real encontrado en la auditoría: usaba `club.reputation`, un campo
## que NUNCA existió en ClubData (solo PlayerData y LeagueData lo tienen)
## — "reputation" in club daba siempre false, así que TODO club, del más
## chico al más grande, caía siempre al mismo valor fijo (45). Aforo y
## público quedaban iguales para cualquier equipo, pese a que el
## comentario de abajo dice explícitamente "crece con la reputación de
## los dos clubes". `league_ambition` (0-100, ya existe en ClubData) es el
## proxy real de prestigio POR CLUB que sí tiene esta clase.
static func capacity(club: ClubData) -> int:
	var rep: int = club.league_ambition if club != null else 45
	var cap: int = 14000 + rep * 780
	return clampi(int(round(cap / 500.0)) * 500, 12000, 85000)

## Estrellas de infraestructura del estadio (1-5), por su aforo: de un campo de barrio
## (menos de 20.000) a un gran estadio (más de 62.000). Sin dato nuevo en el club.
static func stars(club: ClubData) -> int:
	var cap: int = capacity(club)
	if cap <= 20000:
		return 1
	if cap <= 32000:
		return 2
	if cap <= 46000:
		return 3
	if cap <= 62000:
		return 4
	return 5

## Estilo del gran estadio cubierto (solo 5 estrellas; BigStadium): cada club
## grande tiene el suyo, fijo por su id. "" = estadio de siempre.
const DESIGNS := ["cuenco", "catedral", "anillo"]
static func design(club: ClubData) -> String:
	if club == null or stars(club) < 5:
		return ""
	return String(DESIGNS[absi(hash("stadium_design:" + club.club_id)) % DESIGNS.size()])

## Público del partido: crece con la ambición/prestigio de los dos clubes y
## si es derbi; nunca supera el aforo.
static func attendance(home: ClubData, away: ClubData, is_derby: bool, seed_key: String, world_seed: int) -> int:
	var cap: int = capacity(home)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("att:" + seed_key) ^ world_seed)
	var home_rep: float = float(home.league_ambition) if home != null else 45.0
	var away_rep: float = float(away.league_ambition) if away != null else 45.0
	var frac: float = 0.5 + home_rep / 260.0 + away_rep / 400.0 + (0.18 if is_derby else 0.0) + rng.randf_range(-0.06, 0.12)
	return clampi(int(round(cap * clampf(frac, 0.35, 1.0) / 100.0)) * 100, 3000, cap)

static func referee(fixture: Dictionary, world_seed: int) -> String:
	var key := "%s|%s|%d" % [
		String(fixture.get("home_club_id", "")), String(fixture.get("competition", "")),
		int(fixture.get("epoch_day", fixture.get("matchday", 0))),
	]
	return WorldFactory.synthetic_person_name(hash("ref:" + key) ^ world_seed)
