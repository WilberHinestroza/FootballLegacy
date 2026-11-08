extends RefCounted
class_name ImageRightsEngine

## Derechos de imagen: qué parte de lo que genera tu imagen (camisetas,
## campañas, redes) te queda a ti y qué parte se queda el club. Tu imagen vale
## más cuanto mayor es tu reputación y tu número de seguidores; tu parte te
## entra cada semana junto al sueldo.
##
## El porcentaje se pacta con cada club: al fichar por uno nuevo vuelve al
## estándar (o al que traiga la oferta, p. ej. las del Golfo). Con tu agente
## puedes pedir más porcentaje o vender tu parte al club por un pago único.
##
## Estado: player.active_effects["image_rights_share"] (0..MAX_SHARE; sin la
## clave = DEFAULT_SHARE) y season["image_rights_cd_day"] (respiro de la
## negociación). Diccionario ya existente: sin cambio de esquema.

const KEY := "image_rights_share"
const DEFAULT_SHARE := 20
const GULF_SHARE := 50
const MAX_SHARE := 60
const ASK_STEP := 15
const COOLDOWN_DAYS := 120
const FAIL_TRUST := -3
## Venta al club: este múltiplo del valor anual de tu parte, de una vez.
const SELL_MULT := 1.6

static func share(player: PlayerData) -> int:
	if player == null:
		return DEFAULT_SHARE
	return clampi(int(player.active_effects.get(KEY, DEFAULT_SHARE)), 0, MAX_SHARE)

static func set_share(player: PlayerData, pct: int) -> void:
	player.active_effects[KEY] = clampi(pct, 0, MAX_SHARE)

## Valor ANUAL de tu imagen entera (miles de €): cúbica en la reputación
## (las estrellas valen muchísimo más) más un plus por seguidores.
static func annual_value(player: PlayerData) -> int:
	if player == null:
		return 0
	var rep: float = clampf(float(player.reputation) / 100.0, 0.0, 1.0)
	var v: float = pow(rep, 3.0) * 9000.0 + float(SocialEngine.followers(player)) * 0.004
	return int(round(v))

## Lo que te entra por semana por tu parte.
static func weekly_income(player: PlayerData) -> int:
	return int(round(float(annual_value(player)) * float(share(player)) / 100.0 / 52.0))

## Nuevo contrato con OTRO club: el porcentaje se vuelve a pactar.
static func on_new_club(player: PlayerData, offer_share: int = -1) -> void:
	set_share(player, offer_share if offer_share >= 0 else DEFAULT_SHARE)

## Probabilidad de que el club acepte darte más porcentaje: cuanto más pesas
## en el club (tu media frente a la suya, reputación, confianza del DT).
static func ask_chance(player: PlayerData, club_base_overall: int) -> float:
	var weight: float = float(player.overall - club_base_overall) / 20.0
	var rep: float = float(player.reputation - 50) / 80.0
	var trust: float = float(player.coach_trust - 50) / 100.0
	var p: float = 0.3 + weight + rep + trust - float(share(player) - DEFAULT_SHARE) / 100.0
	return clampf(p, 0.08, 0.85)

## "" si se puede negociar hoy; si no, el motivo.
static func blocker(player: PlayerData, season: Dictionary, today: int) -> String:
	if player == null or player.club_id == "":
		return "Sin club."
	if player.contract_years_remaining <= 0:
		return "Se pacta con el próximo contrato."
	var cd: int = int(season.get("image_rights_cd_day", -9999))
	if today < cd:
		return "Ya se habló hace poco (faltan %d días)." % (cd - today)
	return ""

## Pedir más porcentaje. Devuelve {ok, message}.
static func ask_more(player: PlayerData, season: Dictionary, today: int, club_base_overall: int, rng: RandomNumberGenerator) -> Dictionary:
	var b: String = blocker(player, season, today)
	if b != "":
		return {"ok": false, "message": b}
	if share(player) >= MAX_SHARE:
		return {"ok": false, "message": "Ya tienes el máximo que un club concede (%d%%)." % MAX_SHARE}
	season["image_rights_cd_day"] = today + COOLDOWN_DAYS
	if rng.randf() < ask_chance(player, club_base_overall):
		var nw: int = mini(share(player) + ASK_STEP, MAX_SHARE)
		set_share(player, nw)
		return {"ok": true, "message": "El club acepta: ahora te quedas el %d%% de tus derechos de imagen." % nw}
	player.coach_trust = clampi(player.coach_trust + FAIL_TRUST, 0, 100)
	return {"ok": false, "message": "El club se niega y no le gustó la petición (%d confianza)." % FAIL_TRUST}

## Lo que te pagaría el club por quedarse con toda tu parte.
static func sell_price(player: PlayerData) -> int:
	return int(round(float(annual_value(player)) * float(share(player)) / 100.0 * SELL_MULT))

## Vender tu parte al club: cobras ya, dejas de cobrar cada semana.
static func sell(player: PlayerData, season: Dictionary, today: int) -> Dictionary:
	var b: String = blocker(player, season, today)
	if b != "":
		return {"ok": false, "message": b}
	var price: int = sell_price(player)
	if share(player) <= 0 or price <= 0:
		return {"ok": false, "message": "No te queda parte que vender."}
	player.balance += price
	set_share(player, 0)
	season["image_rights_cd_day"] = today + COOLDOWN_DAYS
	return {"ok": true, "message": "Vendes tus derechos de imagen al club por %s." % CurrencyFormat.format(price)}
