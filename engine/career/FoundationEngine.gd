extends RefCounted
class_name FoundationEngine

## Tu fundación: la creas con un aporte inicial (desde cierta reputación),
## eliges una causa y donas cada semana un % de tu sueldo. Lo donado sube el
## nivel de la fundación (de barrio a internacional); cada nivel da reputación,
## ánimo y una noticia, y suma seguidores. Cada ~4 meses puedes organizar una
## gala benéfica que recauda según tu fama. Cuenta para tu legado al retirarte.
##
## Estado: player.active_effects["foundation"] = {name, cause, created_day,
## pct, donated, level, last_gala} (diccionario ya existente, sin cambio de esquema).
## Dinero en miles de €, como todo el juego.

const KEY := "foundation"
const MIN_REPUTATION := 30
const CREATE_COST := 150
const PCTS := [0, 5, 10, 20]
const DEFAULT_PCT := 5
## Total donado (incluido el aporte inicial) para cada nivel 1..5.
const LEVEL_AT := [0, 150, 600, 2000, 6000]
const LEVEL_NAMES := ["", "Barrio", "Ciudad", "Regional", "Nacional", "Internacional"]
const LEVEL_REP := 2
const LEVEL_MOOD := 5
const WEEKLY_MOOD_PCT := 10      # donando esto o más, +1 de ánimo a la semana
const GALA_COOLDOWN := 120
const GALA_COST := 50
const FOLLOWERS_PER_LEVEL2 := 12000

const CAUSES := [
	{"id": "escuelas", "name": "Escuelas de fútbol", "desc": "Canchas, balones y entrenadores para los chicos de tu barrio.", "rep": 1.0, "fans": 1.3, "mood": 1.0},
	{"id": "salud", "name": "Salud infantil", "desc": "Equipos para hospitales y tratamientos para niños sin recursos.", "rep": 1.3, "fans": 1.0, "mood": 1.0},
	{"id": "becas", "name": "Becas de estudio", "desc": "Que ningún chaval deje el colegio por tener que trabajar.", "rep": 1.1, "fans": 0.9, "mood": 1.3},
	{"id": "barrios", "name": "Barrios y comedores", "desc": "Comedores sociales y ayuda a las familias que más lo necesitan.", "rep": 1.0, "fans": 1.2, "mood": 1.2},
]

static func data(player: PlayerData) -> Dictionary:
	var d = player.active_effects.get(KEY, {})
	return d if d is Dictionary else {}

static func has_foundation(player: PlayerData) -> bool:
	return not data(player).is_empty()

static func cause(id: String) -> Dictionary:
	for c in CAUSES:
		if String(c["id"]) == id:
			return c
	return CAUSES[0]

static func foundation_name(player: PlayerData) -> String:
	var parts: PackedStringArray = player.player_name.split(" ", false)
	return "Fundación %s" % (parts[parts.size() - 1] if parts.size() > 0 else player.player_name)

static func level_for(donated: int) -> int:
	var lv := 1
	for i in range(LEVEL_AT.size()):
		if donated >= int(LEVEL_AT[i]):
			lv = i + 1
	return lv

## Progreso hacia el siguiente nivel (0..1); 1 si ya está en el máximo.
static func progress(donated: int) -> float:
	var lv: int = level_for(donated)
	if lv >= LEVEL_AT.size():
		return 1.0
	var a: float = float(LEVEL_AT[lv - 1])
	var b: float = float(LEVEL_AT[lv])
	return clampf((float(donated) - a) / (b - a), 0.0, 1.0)

## "" si puedes crearla; si no, el motivo.
static func create_blocker(player: PlayerData) -> String:
	if has_foundation(player):
		return "Ya tienes tu fundación."
	if player.reputation < MIN_REPUTATION:
		return "Necesitas más nombre (reputación %d de %d) para que una fundación tenga eco." % [player.reputation, MIN_REPUTATION]
	if player.balance < CREATE_COST:
		return "El aporte inicial es de %s." % CurrencyFormat.format(CREATE_COST)
	return ""

static func create(player: PlayerData, cause_id: String, today: int) -> Dictionary:
	var b: String = create_blocker(player)
	if b != "":
		return {"ok": false, "message": b}
	player.balance -= CREATE_COST
	player.active_effects[KEY] = {
		"name": foundation_name(player), "cause": cause(cause_id)["id"], "created_day": today,
		"pct": DEFAULT_PCT, "donated": CREATE_COST, "level": level_for(CREATE_COST), "last_gala": -9999,
	}
	player.reputation = clampi(player.reputation + 1, 0, 100)
	player.mood = clampi(player.mood + LEVEL_MOOD, 0, 100)
	return {"ok": true, "message": "Nace la %s." % foundation_name(player)}

static func set_pct(player: PlayerData, pct: int) -> void:
	var d: Dictionary = data(player)
	if d.is_empty() or not (pct in PCTS):
		return
	d["pct"] = pct
	player.active_effects[KEY] = d

## Donación de esta semana según tu sueldo.
static func weekly_donation(player: PlayerData) -> int:
	var d: Dictionary = data(player)
	if d.is_empty():
		return 0
	return int(round(float(ContractEngine.weekly_income(player.wage)) * float(d.get("pct", 0)) / 100.0))

## Suma a lo donado y aplica la subida de nivel. Devuelve el nivel nuevo (0 si no subió).
static func _add(player: PlayerData, amount: int) -> int:
	var d: Dictionary = data(player)
	var before: int = int(d.get("level", 1))
	d["donated"] = int(d.get("donated", 0)) + amount
	var lv: int = level_for(int(d["donated"]))
	d["level"] = lv
	player.active_effects[KEY] = d
	if lv <= before:
		return 0
	var c: Dictionary = cause(String(d.get("cause", "")))
	player.reputation = clampi(player.reputation + int(round(LEVEL_REP * float(c["rep"]))), 0, 100)
	player.mood = clampi(player.mood + int(round(LEVEL_MOOD * float(c["mood"]))), 0, 100)
	return lv

## Tick semanal (con el sueldo). Devuelve {donated, level_up}.
static func weekly_tick(player: PlayerData) -> Dictionary:
	var amount: int = mini(weekly_donation(player), maxi(player.balance, 0))
	if amount <= 0:
		return {"donated": 0, "level_up": 0}
	player.balance -= amount
	if int(data(player).get("pct", 0)) >= WEEKLY_MOOD_PCT:
		player.mood = clampi(player.mood + 1, 0, 100)
	return {"donated": amount, "level_up": _add(player, amount)}

## Gala benéfica: "" si se puede hoy; si no, el motivo.
static func gala_blocker(player: PlayerData, today: int) -> String:
	var d: Dictionary = data(player)
	if d.is_empty():
		return "Primero crea tu fundación."
	var wait: int = GALA_COOLDOWN - (today - int(d.get("last_gala", -9999)))
	if wait > 0:
		return "La próxima gala, en %d días." % wait
	if player.balance < GALA_COST:
		return "Organizarla cuesta %s." % CurrencyFormat.format(GALA_COST)
	return ""

## Lo que recauda una gala: crece con tu fama y el nivel de la fundación.
static func gala_raise(player: PlayerData, rng: RandomNumberGenerator) -> int:
	var lv: int = int(data(player).get("level", 1))
	var base: float = 40.0 + float(player.reputation * player.reputation) * 0.08
	return int(round(base * (1.0 + 0.25 * float(lv - 1)) * rng.randf_range(0.8, 1.2)))

static func hold_gala(player: PlayerData, today: int, rng: RandomNumberGenerator) -> Dictionary:
	var b: String = gala_blocker(player, today)
	if b != "":
		return {"ok": false, "message": b}
	player.balance -= GALA_COST
	var raised: int = gala_raise(player, rng)
	var d: Dictionary = data(player)
	d["last_gala"] = today
	player.active_effects[KEY] = d
	player.reputation = clampi(player.reputation + 1, 0, 100)
	var lv: int = _add(player, raised)
	return {"ok": true, "raised": raised, "level_up": lv,
		"message": "La gala recauda %s para la %s." % [CurrencyFormat.format(raised), String(d.get("name", ""))]}

## Seguidores extra que te da la fundación (SocialEngine.followers).
static func followers_bonus(player: PlayerData) -> int:
	var d: Dictionary = data(player)
	if d.is_empty():
		return 0
	var lv: int = int(d.get("level", 1))
	return int(float(lv * lv * FOLLOWERS_PER_LEVEL2) * float(cause(String(d.get("cause", "")))["fans"]))

## Puntos de legado (LegacyEngine.tier): nivel 3-4 → 1, nivel 5 → 2.
static func legacy_points(player: PlayerData) -> int:
	var lv: int = int(data(player).get("level", 0))
	if lv >= 5:
		return 2
	return 1 if lv >= 3 else 0

## Titular de una subida de nivel.
static func level_up_press(player: PlayerData, level: int) -> Dictionary:
	var d: Dictionary = data(player)
	return {
		"headline": "La %s ya es de alcance %s" % [String(d.get("name", "")), String(LEVEL_NAMES[clampi(level, 1, 5)]).to_lower()],
		"body": "%s: ya lleva %s donados. +reputación, +ánimo." % [String(cause(String(d.get("cause", "")))["name"]), CurrencyFormat.format(int(d.get("donated", 0)))],
		"source": "SOCIEDAD", "sentiment": "POSITIVE",
	}
