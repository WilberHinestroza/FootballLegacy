extends RefCounted
class_name TransferRequestEngine

## El JUGADOR pide salir del club. El presidente y el técnico lo evalúan y
## responden una de tres cosas (pedido de Wilber):
##   "listen" -> "Escucharemos ofertas": abre la veda, empiezan a llegar
##               ofertas de traspaso MUCHO más seguido durante unas semanas.
##   "loan"   -> "Te dejamos salir cedido": se muestra la lista de clubes
##               para elegir una cesión (LoanEngine).
##   "stay"   -> "Contamos con vos / eres intransferible": te retienen; a
##               veces te ponen sobre la mesa una mejora de contrato.
##
## Estado en el dict `season` (aditivo, sin cambio de esquema):
##   season["transfer_request"] = {kind:"listen", since_week:int, expires_week:int}
##   season["transfer_request_cooldown_week"] = int  (no podés volver a pedir
##       hasta 6 semanas después de un "stay")

const LISTEN_WEEKS := 8
const STAY_COOLDOWN_WEEKS := 6

static func _week(day: int) -> int:
	return int(day / 7.0)

## ¿Se puede mostrar el botón "pedir salida"? (en el club, sin acuerdo
## pendiente, sin cesión en curso, sin un pedido ya activo y fuera del
## enfriamiento tras una negativa).
static func can_request(player: PlayerData, season: Dictionary, day: int) -> bool:
	if player == null or player.club_id == "":
		return false
	if not season.get("pending_transfer", {}).is_empty():
		return false
	if season.get("loan_return", null) != null:
		return false
	if not active(season, day).is_empty():
		return false
	if _week(day) < int(season.get("transfer_request_cooldown_week", -999)):
		return false
	return true

## Pedido "escucharemos ofertas" en curso (o {} si no hay / ya venció).
static func active(season: Dictionary, day: int) -> Dictionary:
	var r: Dictionary = season.get("transfer_request", {})
	if r.is_empty():
		return {}
	if _week(day) > int(r.get("expires_week", 0)):
		return {}
	return r

## Evalúa el pedido. `club_base_overall` = nivel del club actual.
static func evaluate(player: PlayerData, club_base_overall: int, season: Dictionary, day: int, rng: RandomNumberGenerator) -> Dictionary:
	var importance: float = clampf((float(player.overall) - float(club_base_overall) + 6.0) / 18.0, 0.0, 1.0)
	var trust: float = clampf(float(player.coach_trust) / 100.0, 0.0, 1.0)
	var contract: float = clampf(float(player.contract_years_remaining) / 4.0, 0.0, 1.0)
	var barely_playing: bool = player.season_appearances <= 3 or player.coach_trust < 48
	var young: bool = player.age <= 21
	var veteran: bool = player.age >= 33

	# --- Cesión: juvenil que no juega. El club lo prefiere sumando minutos.
	if young and barely_playing and player.contract_years_remaining >= 1:
		return {
			"decision": "loan",
			"coach": "El técnico admite que ahora mismo no vas a tener minutos acá.",
			"president": "El club ve con buenos ojos que salgas cedido una temporada para foguearte.",
			"summary": "Te dejan salir a préstamo. Elegí el club.",
		}

	# --- Retener: te valoran, tenés contrato largo, el DT cuenta con vos.
	var retain: float = 0.14 + importance * 0.5 + trust * 0.16 + contract * 0.2
	if veteran and importance < 0.5:
		retain -= 0.35
	if player.contract_years_remaining <= 1:
		retain -= 0.45  # no te pueden retener con el contrato por vencer
	if barely_playing:
		retain -= 0.2
	retain = clampf(retain, 0.03, 0.93)

	if rng.randf() < retain:
		var coach_line: String = "El técnico cuenta con vos y no quiere dejarte ir." if trust >= 0.55 \
			else "El técnico prefiere no mover el plantel a mitad de camino."
		var pres_line: String = "El presidente te considera intransferible por ahora." if importance >= 0.55 \
			else "El club dice que tu contrato está vigente y no piensa negociarte."
		return {
			"decision": "stay",
			"coach": coach_line,
			"president": pres_line,
			"summary": "El club te retiene. Podés volver a intentarlo más adelante.",
			"offer_improvement": importance >= 0.45 and trust >= 0.4,
		}

	# --- Escuchar ofertas.
	return {
		"decision": "listen",
		"coach": "El técnico entiende tu decisión y no se opondrá." if trust >= 0.4 \
			else "Al técnico no le tiembla el pulso: si querés irte, adelante.",
		"president": "El club dejará que lleguen ofertas. Si son buenas, te dejarán salir en la próxima ventana.",
		"summary": "Pediste salir. Los clubes ya lo saben — van a empezar a llegar ofertas.",
	}

## Registra un pedido "listen" aceptado.
static func grant_listen(season: Dictionary, day: int) -> void:
	var w: int = _week(day)
	season["transfer_request"] = {
		"kind": "listen",
		"since_week": w,
		"expires_week": w + LISTEN_WEEKS,
	}

## Registra el enfriamiento tras una negativa ("stay").
static func mark_denied(season: Dictionary, day: int) -> void:
	season["transfer_request_cooldown_week"] = _week(day) + STAY_COOLDOWN_WEEKS

## El jugador retira el pedido a mano.
static func withdraw(season: Dictionary) -> void:
	season.erase("transfer_request")
