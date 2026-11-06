extends RefCounted
class_name LifestyleEngine

## "Vida": vivienda y coche del jugador — PlayerData.home_type/car_type,
## campos dormidos desde el día 1 (nunca se fijaban ni se mostraban).
## Cosmético, pagado de PlayerData.balance (Fase 8b), con un empujón
## pequeño de reputación al mejorar — la prensa se fija en cómo vives.
## Sin efecto en overall/atributos: esto es estilo de vida, no rendimiento.

const HOME_TIERS := [
	{"key": "shared_apartment", "label": "Piso compartido", "cost": 0},
	{"key": "small_apartment", "label": "Apartamento pequeño", "cost": 300},
	{"key": "apartment", "label": "Apartamento", "cost": 1200},
	{"key": "house", "label": "Casa", "cost": 4000},
	{"key": "mansion", "label": "Mansión", "cost": 15000},
]
const CAR_TIERS := [
	{"key": "none", "label": "Sin coche", "cost": 0},
	{"key": "economy", "label": "Coche económico", "cost": 200},
	{"key": "sedan", "label": "Sedán", "cost": 800},
	{"key": "sports_car", "label": "Deportivo", "cost": 3000},
	{"key": "luxury_car", "label": "Coche de lujo", "cost": 10000},
]

const UPGRADE_REPUTATION_BONUS := 2

## Métricas de bienestar DERIVADAS — PlayerData no tiene campos propios de
## felicidad/moral, se calculan de fatiga mental + relación con el DT +
## rendimiento + confort (vivienda/coche). 0-100, SOLO para mostrar en
## la pantalla Vida (no alimentan ninguna fórmula de balance).
static func wellbeing(player: PlayerData) -> Dictionary:
	var estres: int = clampi(int(round(player.fatigue_mental)), 0, 100)
	var comfort: int = (home_index(player.home_type) + car_index(player.car_type)) * 6 # 0..48
	var felicidad: int = clampi(52 + comfort + RelationshipEngine.happiness_bonus(player) + int((player.coach_trust - 55) / 3.0) - int(estres / 3.0), 5, 100)
	var motivacion: int = clampi(45 + int((player.coach_trust - 50) / 2.0) + player.season_goals * 2 - int(estres / 4.0), 5, 100)
	var adaptacion: int = clampi(player.club_seniority * 22 + player.season_appearances * 4 + int((player.coach_trust - 50) / 2.0), 0, 100)
	return {"felicidad": felicidad, "estres": estres, "motivacion": motivacion, "adaptacion": adaptacion}

## Patrimonio estimado: efectivo + valor de reventa de la vivienda (70%)
## y el coche (60%) acumulados hasta el nivel actual.
static func net_worth(player: PlayerData) -> int:
	var home_val: int = 0
	for i in range(home_index(player.home_type) + 1):
		home_val += int(HOME_TIERS[i]["cost"])
	var car_val: int = 0
	for i in range(car_index(player.car_type) + 1):
		car_val += int(CAR_TIERS[i]["cost"])
	return player.balance + int(home_val * 0.7) + int(car_val * 0.6)

static func home_label(key: String) -> String:
	return _label_of(HOME_TIERS, key)

static func car_label(key: String) -> String:
	return _label_of(CAR_TIERS, key)

static func home_index(key: String) -> int:
	return _index_of(HOME_TIERS, key)

static func car_index(key: String) -> int:
	return _index_of(CAR_TIERS, key)

## true si se pudo comprar (fondos suficientes y es una mejora real, no
## se puede "bajar" de nivel comprando).
static func buy_home(player: PlayerData, tier_key: String) -> bool:
	return _buy(player, HOME_TIERS, tier_key, "home_type")

static func buy_car(player: PlayerData, tier_key: String) -> bool:
	return _buy(player, CAR_TIERS, tier_key, "car_type")

static func _buy(player: PlayerData, tiers: Array, tier_key: String, field: String) -> bool:
	var target_idx: int = _index_of(tiers, tier_key)
	if target_idx < 0:
		return false
	var current_idx: int = _index_of(tiers, player.get(field))
	if target_idx <= current_idx:
		return false
	var cost: int = int(tiers[target_idx]["cost"])
	if player.balance < cost:
		return false
	player.balance -= cost
	player.set(field, tier_key)
	player.reputation = clampi(player.reputation + UPGRADE_REPUTATION_BONUS, 0, 100)
	return true

# =====================================================================
#  Bienestar: recuperación pagada de energía física / tensión mental
# =====================================================================
#
# fatigue_physical la suben los eventos de la sección Mensajes
# (SocialEngine); fatigue_mental la sube un mal partido o una derrota
# (MatchSummary). Ambas se recuperan solas unos puntos por día en
# WorldTickEngine; acá se puede pagar por acelerarlo. Una vez por semana
# cada acción (contador en season["wellness"], aditivo, sin cambio de
# esquema — balance / fatigue_* ya existen).

# Unidad: miles de EUR. Una sesión privada de fisio/psicólogo deportivo
# es calderilla para un profesional (15 = 15 000 €), no un fichaje.
const PHYSIO_COST := 15
const PHYSIO_RECOVERY := 40.0
const PSYCH_COST := 12
const PSYCH_RECOVERY := 40.0

static func _wellness_week(day: int) -> int:
	return int(day / 7.0)

static func wellness_used(season: Dictionary, key: String, day: int) -> bool:
	var w: Dictionary = season.get("wellness", {})
	return int(w.get("week", -1)) == _wellness_week(day) and key in (w.get("used", []) as Array)

static func use_physio(player: PlayerData, season: Dictionary, day: int) -> Dictionary:
	return _use_wellness(player, season, day, "physio", PHYSIO_COST, "fatigue_physical", PHYSIO_RECOVERY)

static func use_psych(player: PlayerData, season: Dictionary, day: int) -> Dictionary:
	return _use_wellness(player, season, day, "psych", PSYCH_COST, "fatigue_mental", PSYCH_RECOVERY)

static func _use_wellness(player: PlayerData, season: Dictionary, day: int, key: String, cost: int, field: String, amount: float) -> Dictionary:
	if wellness_used(season, key, day):
		return {"ok": false, "message": "Ya lo usaste esta semana."}
	if player.balance < cost:
		return {"ok": false, "message": "No te alcanza el saldo."}
	if float(player.get(field)) <= 0.0:
		return {"ok": false, "message": "No hace falta ahora mismo."}
	player.balance -= cost
	player.set(field, maxf(0.0, float(player.get(field)) - amount))
	var w: Dictionary = season.get("wellness", {})
	if int(w.get("week", -1)) != _wellness_week(day):
		w = {"week": _wellness_week(day), "used": []}
	var used: Array = w.get("used", [])
	used.append(key)
	w["used"] = used
	season["wellness"] = w
	return {"ok": true, "message": "Recuperación acelerada. -%s." % CurrencyFormat.format(cost)}

static func _index_of(tiers: Array, key: String) -> int:
	for i in range(tiers.size()):
		if tiers[i]["key"] == key:
			return i
	return 0

static func _label_of(tiers: Array, key: String) -> String:
	var idx: int = _index_of(tiers, key)
	return tiers[idx]["label"]
