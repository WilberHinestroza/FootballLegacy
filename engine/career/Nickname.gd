extends RefCounted
class_name Nickname

## Apodo que le pone la prensa/afición al jugador al alcanzar cierto peso
## en su carrera. DETERMINISTA (nombre + world_seed + posición), no se
## persiste — se recalcula. Antes del hito devuelve "".
##
## Se usa en titulares (PressGenerator), en Mi Perfil y en el Hub.

const _POOLS := {
	"ST": ["El Pistolero", "El Tanque", "La Pantera", "El Killer", "El Ariete",
		"El Depredador", "El Torito", "La Bestia", "El Francotirador", "El Verdugo"],
	"MF": ["El Cerebro", "El Maestro", "El Motorcito", "La Brújula", "El Timón",
		"El Mago", "El Metrónomo", "El Faro", "El Arquitecto", "El General"],
	"DF": ["El Muro", "El Cerrojo", "El Mariscal", "La Roca", "El Comandante",
		"El Candado", "El Coloso", "El Central de Hierro", "El Jefe", "El Bastión"],
	"GK": ["El Gato", "El Pulpo", "La Muralla", "El Portento", "Manos de Seda",
		"El Felino", "El Guardián", "El Uno", "El Cóndor", "El Búnker"],
}

## ¿Ya se ganó el apodo? Umbral por posición.
static func earned(player: PlayerData) -> bool:
	if player == null:
		return false
	match player.position:
		"ST":
			return player.career_goals >= 35 or (player.reputation >= 72 and player.career_matches >= 60)
		"MF":
			return player.career_assists >= 25 or (player.reputation >= 72 and player.career_matches >= 90)
		_:
			return player.career_matches >= 110 or player.reputation >= 76

static func for_player(player: PlayerData, world_seed: int) -> String:
	if not earned(player):
		return ""
	var pool: Array = _POOLS.get(player.position, _POOLS["MF"])
	var h: int = absi(hash("nick:" + player.player_name + player.position) ^ world_seed)
	return String(pool[h % pool.size()])

## Nombre "de prensa": el apodo si ya se ganó, si no el apellido.
static func press_name(player: PlayerData, world_seed: int) -> String:
	var nk := for_player(player, world_seed)
	if nk != "":
		return nk
	var parts: PackedStringArray = player.player_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else player.player_name
