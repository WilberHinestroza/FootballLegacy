extends RefCounted
class_name SponsorEngine

## Ofertas de patrocinio como ESTADO PERSISTENTE (backlog heredado de FL:
## "no popup efímero"). Toda la matemática vive aquí — mismo principio que
## CoachRelations / PlayerDevelopment / ContractEngine.
##
## PLACEHOLDER: nombres de marcas inventadas (sin licencias reales),
## reemplazables cuando exista el pipeline de import.

const SPONSOR_NAMES := [
	"Vortex Sport", "Aurea Bebidas", "Nimbus Gear", "Solmar Energía",
	"Rocamar Auto", "Prisma Telecom", "Ándico Café", "Ferro Nutrition",
]

## Prenda que la marca te REGALA mientras dure el contrato (P3, 9-oct —
## "ropa del patrocinador gratis"). Se guarda en sponsor["granted"] y se va
## al vencer (lo que ya tenías comprado queda).
const GIFT := {
	"Vortex Sport": "chandal", "Aurea Bebidas": "polo", "Nimbus Gear": "bomber",
	"Solmar Energía": "hawaiana", "Rocamar Auto": "cuero", "Prisma Telecom": "cuello_alto",
	"Ándico Café": "lino", "Ferro Nutrition": "hoodie",
}

static func grant_gift(player: PlayerData) -> String:
	var item: String = String(GIFT.get(String(player.sponsor.get("name", "")), ""))
	if item == "" or player.cosmetics_owned.has(item):
		return ""
	player.cosmetics_owned.append(item)
	player.sponsor["granted"] = [item]
	return item

static func remove_gift(player: PlayerData) -> void:
	for item in player.sponsor.get("granted", []):
		player.cosmetics_owned.erase(item)
		if String(player.cosmetics_equipped.get("outfit", "")) == String(item):
			player.cosmetics_equipped.erase("outfit")
		# También sus mitades sueltas, si ya no las tiene por otra vía.
		for half in ["top", "bottom"]:
			var hid: String = String(player.cosmetics_equipped.get(half, ""))
			if hid != "" and not Avatar.owns(player, hid):
				player.cosmetics_equipped.erase(half)

## Probabilidad semanal de que llegue una oferta, según cuánto "se te vea":
## fuerza del club actual + tu propio overall. Sin sponsor activo ni oferta
## pendiente ya guarda esa condición — esto solo calcula el ROLL.
static func offer_chance(club_strength: int, player_overall: int) -> float:
	var visibility: float = float(club_strength + player_overall) / 2.0
	return clampf((visibility - 35.0) / 550.0, 0.0, 0.10)

## Genera una oferta concreta: {name, weekly_income, weeks_remaining}.
## `weekly_income` en miles de EUR (igual que sueldos): un suplente ronda
## 5-12/sem (~0,3-0,6 M€/año), un titular 25-60, una estrella 150-240.
## Curva potencia sobre el overall + factor de reputación.
static func generate_offer(player: PlayerData, rng: RandomNumberGenerator) -> Dictionary:
	var name: String = SPONSOR_NAMES[rng.randi() % SPONSOR_NAMES.size()]
	var t: float = clampf((float(player.overall) - 52.0) / 36.0, 0.0, 1.0)
	var base: float = pow(t, 2.4) * 240.0
	var rep_factor: float = 0.70 + float(player.reputation) / 100.0 * 0.6
	var weekly_income: int = maxi(int(round(base * rep_factor * rng.randf_range(0.75, 1.3))), 3)
	var weeks: int = rng.randi_range(12, 30)
	return {"name": name, "weekly_income": weekly_income, "weeks_remaining": weeks}
