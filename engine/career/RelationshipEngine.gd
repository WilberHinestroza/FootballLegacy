extends RefCounted
class_name RelationshipEngine

## Vida familiar (sección de Vida personal) — pedido de Wilber: pareja
## con efecto sobre el bienestar. Estado en `PlayerData.partner` (schema
## v18): {} sin pareja, {name, since_day} en pareja. Persiste POR CARRERA.
## Sin licencias: nombres inventados.
##
## PLACEHOLDER liviano a propósito (v1): conocer a alguien, terminar la
## relación, y un bono pasivo. Hijos / eventos de relación / crisis
## quedan para después.

const NAMES := [
	"Camila", "Julieta", "Mateo", "Sofía", "Lucas", "Valentina",
	"Tomás", "Martina", "Nicolás", "Renata", "Bruno", "Emilia",
]

const MEET_CHANCE := 0.45   # probabilidad de "salir a conocer gente"

static func has_partner(player: PlayerData) -> bool:
	return not player.partner.is_empty()

## Intento de conocer a alguien. Determinista por (día ^ world_seed) para
## que no se pueda recargar hasta que salga. Devuelve {ok, name}.
static func try_meet(player: PlayerData, day: int, world_seed: int) -> Dictionary:
	if has_partner(player):
		return {"ok": false, "name": ""}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("meet:%d" % day) ^ world_seed
	if rng.randf() > MEET_CHANCE:
		return {"ok": false, "name": ""}
	var name: String = NAMES[rng.randi() % NAMES.size()]
	player.partner = {"name": name, "since_day": day}
	return {"ok": true, "name": name}

static func end_relationship(player: PlayerData) -> void:
	player.partner = {}

## Puntos extra de felicidad (métrica derivada de LifestyleEngine.wellbeing).
static func happiness_bonus(player: PlayerData) -> int:
	return 10 if has_partner(player) else 0

## Recuperación mental extra por día (una pareja estable ayuda a bajar el
## estrés). La consume WorldTickEngine._tick_fatigue_and_development.
static func mental_recovery_bonus(player: PlayerData) -> float:
	return 0.7 if has_partner(player) else 0.0

static func status_line(player: PlayerData, today: int) -> String:
	if not has_partner(player):
		return "Sin pareja. Tu vida social es libre."
	var days: int = maxi(0, today - int(player.partner.get("since_day", today)))
	return "En pareja con %s · juntos hace %d días." % [String(player.partner.get("name", "?")), days]
