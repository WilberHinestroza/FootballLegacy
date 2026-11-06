extends Node

## Borrador de creación de personaje que sobrevive el salto entre las
## pantallas del flujo (CharacterCreation → AvatarCreator → vuelta al
## test de personalidad). NO se persiste: es de un solo uso, se limpia
## al terminar la creación. Mismo patrón que MatchState pero para este
## flujo.

var identity: Dictionary = {}   # {name, country, pos, pos2, foot, origin, age}
var avatar: Dictionary = {}     # config de Avatar.gd (capas + tintes)

## true = AvatarCreator se abrió desde "Editar" en Mi Perfil (edita el
## avatar del jugador ya guardado y vuelve al perfil). false = flujo de
## creación de personaje normal.
var edit_mode: bool = false

## true SÓLO cuando el jugador salió del creador de avatar con "Siguiente"
## (apariencia terminada → toca el test). Si vuelve con "Volver", queda en
## false y CharacterCreation reabre la identidad (con los datos puestos)
## en vez de saltar al test. Antes se usaba `has_avatar()` para eso, pero
## el avatar también queda guardado al pulsar "Volver" (para no perderlo),
## así que no servía para distinguir los dos casos — ese era el bug de
## "vuelvo del editor y parece que estoy creando el jugador de nuevo".
var avatar_done: bool = false

func has_identity() -> bool:
	return not identity.is_empty()

func has_avatar() -> bool:
	return not avatar.is_empty()

func clear() -> void:
	identity = {}
	avatar = {}
	edit_mode = false
	avatar_done = false
