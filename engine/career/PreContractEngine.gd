extends RefCounted
class_name PreContractEngine

## Precontrato: en tu ÚLTIMO año de contrato, desde que abre el mercado de
## invierno, otros clubes pueden ofrecerte firmar YA para irte gratis al
## acabar la temporada. Llegas libre (sin traspaso), así que te dan una prima
## de fichaje. Firmarlo tiene precio en tu club actual: el DT y la afición
## saben que te vas. Al vencer el contrato, el rollover te lleva directo al
## club nuevo (sin pantalla de renovación).
##
## Estado en `season` (aditivo, sin cambio de esquema; se consume en el
## rollover antes de que la temporada se reconstruya):
##   season["precontract_offer"] -> oferta sin responder (vence a OFFER_DAYS)
##   season["precontract"]       -> el precontrato firmado
##   season["precontract_week"]  -> semana de la última oferta (respiro)

const WEEKLY_CHANCE := 0.16
const OFFER_DAYS := 10
const COOLDOWN_WEEKS := 4
const BONUS_OF_WAGE := 0.3 # prima por llegar libre: ~un tercio del sueldo anual
const TRUST_COST := -8
const FAN_COST := -6
const MAX_AGE := 35

static func offer(season: Dictionary) -> Dictionary:
	return season.get("precontract_offer", {})

static func signed(season: Dictionary) -> Dictionary:
	return season.get("precontract", {})

## ¿Estás en el tramo en que se puede pactar un precontrato?
static func in_window(player: PlayerData, season: Dictionary, day: int) -> bool:
	if player == null or player.club_id == "" or season.is_empty():
		return false
	if player.contract_years_remaining != 1 or player.age > MAX_AGE:
		return false
	if season.has("loan_return"):
		return false # cedido: tu contrato es con el club padre
	var start: int = int(season.get("season_start_epoch_day", 0))
	return day >= start + SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET

## ¿Toca oferta de precontrato esta semana?
static func should_offer(player: PlayerData, season: Dictionary, day: int, rng: RandomNumberGenerator) -> bool:
	if not in_window(player, season, day):
		return false
	if not signed(season).is_empty() or not offer(season).is_empty():
		return false
	if not season.get("pending_transfer", {}).is_empty():
		return false
	if CalendarUtils.week_index(day) < int(season.get("precontract_week", -999)) + COOLDOWN_WEEKS:
		return false
	var rep: float = clampf(float(player.reputation - TransferOfferEngine.REP_FLOOR) / 45.0, 0.25, 1.4)
	return rng.randf() < WEEKLY_CHANCE * rep

## Arma la oferta a partir de una de traspaso normal (club a tu nivel, sueldo
## con techo, rol), sin traspaso y con prima. {} si no hay club.
static func build_offer(player: PlayerData, world: Dictionary, world_seed: int, day: int, rng: RandomNumberGenerator, season: Dictionary) -> Dictionary:
	var base: Dictionary = {}
	for i in 3:
		base = TransferOfferEngine.generate_offer(player, world, world_seed, day, day, rng, season)
		if not base.is_empty() and String(base.get("kind", "")) != "cesión":
			break
	if base.is_empty() or String(base.get("kind", "")) == "cesión":
		return {}
	var wage: int = int(base.get("wage", player.wage))
	return {
		"id": "pre_%d_%d" % [day, rng.randi() % 100000],
		"from_club_id": String(base["from_club_id"]),
		"from_club_name": String(base["from_club_name"]),
		"wage": wage,
		"contract_years": rng.randi_range(3, 4),
		"role": String(base.get("role", "rotación")),
		"signing_bonus": int(round(wage * BONUS_OF_WAGE)),
		"created_day": day,
	}

static func days_left(o: Dictionary, day: int) -> int:
	return int(o.get("created_day", day)) + OFFER_DAYS - day

## Firmar: queda pactado y tu club actual se entera.
static func accept(player: PlayerData, season: Dictionary) -> Dictionary:
	var o: Dictionary = offer(season)
	if o.is_empty():
		return {}
	season["precontract"] = o
	season.erase("precontract_offer")
	season["transfer_inbox"] = [] # ya tienes futuro: el resto de ofertas se cae
	player.coach_trust = clampi(player.coach_trust + TRUST_COST, 0, 100)
	season["fan_sentiment"] = clampi(int(season.get("fan_sentiment", InterviewEngine.FAN_DEFAULT)) + FAN_COST, 0, 100)
	return o

static func reject(season: Dictionary) -> void:
	season.erase("precontract_offer")

## Tick diario: caduca la oferta sin responder. Devuelve el nombre del club si caducó.
static func expire_if_due(season: Dictionary, day: int) -> String:
	var o: Dictionary = offer(season)
	if o.is_empty() or days_left(o, day) > 0:
		return ""
	season.erase("precontract_offer")
	return String(o.get("from_club_name", "El club"))

## Rollover: al vencer el contrato con precontrato firmado, te vas al club
## nuevo. Aplica la prima y el rol; el resto (club, sueldo, años) lo pone
## WorldTickEngine.resolve_contract_decision. Devuelve el precontrato o {}.
static func take_on_expiry(player: PlayerData, season: Dictionary) -> Dictionary:
	var pc: Dictionary = signed(season)
	season.erase("precontract")
	season.erase("precontract_offer")
	if pc.is_empty() or player.contract_years_remaining > 0:
		return {}
	player.balance += int(pc.get("signing_bonus", 0))
	if String(pc.get("role", "")) == "titular":
		player.active_effects["role_titular_matches"] = TransferOfferEngine.TITULAR_PROMISE_MATCHES
	return pc
