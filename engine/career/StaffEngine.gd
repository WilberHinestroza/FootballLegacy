extends RefCounted
class_name StaffEngine

## Staff personal (Vida personal) — pedido explícito de Wilber:
##   - bono PASIVO por semana según nivel,
##   - SUELDO por temporada (se descuenta en el rollover; si no alcanza,
##     ese miembro se va),
##   - sube de nivel 1→5 pagando.
## Estado en `PlayerData.staff` (schema v16): {role: {"level": 1-5}}.
## Sin la clave = no contratado. Persiste POR CARRERA (no en `season`).
##
## Toda la matemática del efecto vive ACÁ (un solo lugar, igual criterio
## que ContractEngine/AgentEngine); los otros sistemas solo multiplican
## por el factor que expone este engine.

const ROLES := ["nutritionist", "psychologist", "physio", "financial_advisor", "community_manager"]
const MAX_LEVEL := 5

const META := {
	"nutritionist": {
		"name": "Nutricionista", "icon": "res://addons/at-icons/node/apple.svg",
		"hire": 2500, "salary": 400,
		"effect": "Recuperás energía física más rápido cada día.",
	},
	"psychologist": {
		"name": "Psicólogo deportivo", "icon": "res://addons/at-icons/node/brain.svg",
		"hire": 2500, "salary": 400,
		"effect": "Bajás el estrés mental más rápido cada día.",
	},
	"physio": {
		"name": "Fisioterapeuta", "icon": "res://addons/at-icons/node/cross.svg",
		"hire": 3500, "salary": 550,
		"effect": "Menos días de baja cuando te lesionás.",
	},
	"financial_advisor": {
		"name": "Asesor financiero", "icon": "res://addons/at-icons/node/coins.svg",
		"hire": 4000, "salary": 300,
		"effect": "Más ingresos semanales por tu sueldo.",
	},
	"community_manager": {
		"name": "Community manager", "icon": "res://addons/at-icons/node/bird.svg",
		"hire": 2000, "salary": 250,
		"effect": "Tus publicaciones ganan más seguidores.",
	},
}

# --- consultas ---

static func level_of(player: PlayerData, role: String) -> int:
	var entry = player.staff.get(role, {})
	return int(entry.get("level", 0)) if entry is Dictionary else 0

static func hire_cost(role: String) -> int:
	return int(META[role]["hire"])

## Costo para subir de `from_level` a `from_level + 1`.
static func upgrade_cost(role: String, from_level: int) -> int:
	return int(META[role]["hire"] * (0.55 + from_level * 0.35))

## Sueldo por temporada a un nivel dado.
static func season_salary(role: String, level: int) -> int:
	if level <= 0:
		return 0
	return int(META[role]["salary"] * (0.7 + level * 0.3))

static func total_season_salaries(player: PlayerData) -> int:
	var total: int = 0
	for role in ROLES:
		total += season_salary(role, level_of(player, role))
	return total

# --- mutaciones (devuelven true si se aplicó) ---

static func hire(player: PlayerData, role: String) -> bool:
	if not META.has(role) or level_of(player, role) > 0:
		return false
	var cost: int = hire_cost(role)
	if player.balance < cost:
		return false
	player.balance -= cost
	player.staff[role] = {"level": 1}
	return true

static func upgrade(player: PlayerData, role: String) -> bool:
	var lvl: int = level_of(player, role)
	if lvl <= 0 or lvl >= MAX_LEVEL:
		return false
	var cost: int = upgrade_cost(role, lvl)
	if player.balance < cost:
		return false
	player.balance -= cost
	player.staff[role] = {"level": lvl + 1}
	return true

static func dismiss(player: PlayerData, role: String) -> bool:
	if level_of(player, role) <= 0:
		return false
	player.staff.erase(role)
	return true

## Cobro de sueldos al cerrar la temporada (llamado desde
## WorldTickEngine._reset_season_stats_and_objective). Paga lo que pueda;
## a quien no puede pagar, lo despide. Devuelve los roles despedidos.
static func pay_season_salaries(player: PlayerData) -> Array:
	var dropped: Array = []
	for role in ROLES:
		var lvl: int = level_of(player, role)
		if lvl <= 0:
			continue
		var sal: int = season_salary(role, lvl)
		if player.balance >= sal:
			player.balance -= sal
		else:
			player.staff.erase(role)
			dropped.append(role)
	return dropped

# --- factores de efecto (los consumen otros sistemas) ---

## Puntos EXTRA de recuperación de energía física por día.
static func energy_recovery_bonus(player: PlayerData) -> float:
	return level_of(player, "nutritionist") * 1.6

## Puntos EXTRA de recuperación de tensión mental por día.
static func mental_recovery_bonus(player: PlayerData) -> float:
	return level_of(player, "psychologist") * 1.3

## Multiplicador sobre los DÍAS de lesión (<= 1.0).
static func injury_factor(player: PlayerData) -> float:
	return clampf(1.0 - level_of(player, "physio") * 0.07, 0.55, 1.0)

## Multiplicador sobre los ingresos semanales (>= 1.0).
## Bug real de la auditoría de balance (ronda 6): con +4.5%/nivel, el
## asesor financiero NO se autofinanciaba a nivel 1 (el ingreso extra no
## alcanzaba a pagar su propio sueldo) y tardaba ~32 temporadas en
## recuperar la inversión incluso al nivel máximo — un "beneficio" que en
## la práctica nunca convenía contratar. Subido a +12%/nivel para que el
## payback ronde las 8 temporadas al nivel máximo (y sea positivo desde
## el nivel 1), en línea con el resto del staff.
static func income_factor(player: PlayerData) -> float:
	return 1.0 + level_of(player, "financial_advisor") * 0.12

## Multiplicador sobre los seguidores ganados por publicación (>= 1.0).
static func follower_factor(player: PlayerData) -> float:
	return 1.0 + level_of(player, "community_manager") * 0.12
