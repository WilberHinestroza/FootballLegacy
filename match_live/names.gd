class_name Names
extends RefCounted
## Nombres ficticios para las fichas de los jugadores del prototipo.
## En FootballCareer se usan los nombres reales del mundo del juego
## (PlayerData.name); esto solo llena el banco de pruebas.

const FIRST := ["J", "M", "A", "L", "C", "D", "S", "F", "R", "E", "N", "P", "G", "T", "V", "B"]
const LAST := ["Pérez", "Gómez", "Rojas", "Herrera", "Castillo", "Vargas", "Morales", "Ortiz",
	"Silva", "Rivas", "Mendoza", "Cardona", "Quintero", "Salazar", "Ríos", "Acosta",
	"Navarro", "Cabrera", "Fuentes", "Aguirre", "Montoya", "Restrepo", "Paredes", "Ibarra",
	"Valencia", "Zapata", "Becerra", "Arango", "Molina", "Peña", "Sosa", "Duarte"]

## "J. Pérez", determinista por semilla.
static func short(seed_int: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_int) + 17
	return "%s. %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
