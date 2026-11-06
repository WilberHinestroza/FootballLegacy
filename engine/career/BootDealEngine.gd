extends RefCounted
class_name BootDealEngine

## Patrocinio de GUAYOS (schema v32, 9-oct, pedido de Wilber: "4 marcas de
## guayos que puedan patrocinar al jugador en su carrera, que pueda cambiar
## de guayos, con logos"). Aparte del patrocinio general (SponsorEngine):
## se pueden tener los dos. Toda la matemática vive acá.
##
## player.boot_deal = {brand, weekly_income, weeks_remaining, granted:[ids]}
## `granted` = modelos que la marca te REGALÓ (no los que ya tenías): se van
## al vencer el contrato; lo que compraste vos queda.

## Probabilidad semanal de oferta: hace falta algo de nivel (media 60+) y se
## dispara con la fama.
static func offer_chance(overall: int, reputation: int) -> float:
	if overall < 60:
		return 0.0
	var v: float = float(overall - 60) / 30.0 * 0.6 + float(reputation) / 100.0 * 0.4
	return clampf(0.02 + v * 0.10, 0.0, 0.10)

## Oferta concreta. Paga menos que un sponsor general (~40% de su curva) pero
## dura más y viene con los guayos. `exclude` = marca actual (para que al
## vencer te llegue OTRA).
static func generate_offer(player: PlayerData, rng: RandomNumberGenerator, exclude: String = "") -> Dictionary:
	var pool: Array = BootBrands.BRANDS.filter(func(b): return b["id"] != exclude)
	var brand: Dictionary = pool[rng.randi() % pool.size()]
	var t: float = clampf((float(player.overall) - 55.0) / 35.0, 0.0, 1.0)
	var base: float = pow(t, 2.2) * 100.0
	var rep_factor: float = 0.70 + float(player.reputation) / 100.0 * 0.6
	var weekly: int = maxi(int(round(base * rep_factor * rng.randf_range(0.8, 1.25))), 2)
	return {"brand": brand["id"], "weekly_income": weekly, "weeks_remaining": rng.randi_range(26, 52)}

## Aceptar: contrato + modelos de la marca gratis (el primero, puesto).
static func accept(player: PlayerData, offer: Dictionary) -> void:
	var brand: Dictionary = BootBrands.by_id(String(offer.get("brand", "")))
	if brand.is_empty():
		return
	var granted: Array = []
	for m in brand["models"]:
		if not player.cosmetics_owned.has(m):
			player.cosmetics_owned.append(m)
			granted.append(m)
	var deal: Dictionary = offer.duplicate(true)
	deal["granted"] = granted
	player.boot_deal = deal
	player.cosmetics_equipped["acc_feet"] = String(brand["models"][0])

## Vence el contrato: se van los modelos regalados (y se saca el que tenías
## puesto si era uno de esos).
static func expire(player: PlayerData) -> void:
	var granted: Array = player.boot_deal.get("granted", [])
	for m in granted:
		player.cosmetics_owned.erase(m)
	if granted.has(String(player.cosmetics_equipped.get("acc_feet", ""))):
		player.cosmetics_equipped.erase("acc_feet")
	player.boot_deal = {}

## Tick semanal (lo llama WorldTickEngine._tick_life_events). Devuelve un
## titular de prensa si pasó algo ("" si no).
static func weekly_tick(player: PlayerData, rng: RandomNumberGenerator) -> String:
	if not player.boot_deal.is_empty():
		player.balance += int(player.boot_deal.get("weekly_income", 0))
		var left: int = int(player.boot_deal.get("weeks_remaining", 0)) - 1
		if left <= 0:
			var bname: String = String(BootBrands.by_id(String(player.boot_deal.get("brand", ""))).get("name", "La marca"))
			expire(player)
			return "Termina tu contrato de guayos con %s" % bname
		player.boot_deal["weeks_remaining"] = left
		return ""
	if not player.pending_boot_offer.is_empty():
		return ""
	if rng.randf() < offer_chance(player.overall, player.reputation):
		player.pending_boot_offer = generate_offer(player, rng)
		var b: Dictionary = BootBrands.by_id(String(player.pending_boot_offer["brand"]))
		return "%s te quiere con sus guayos" % String(b.get("name", "Una marca"))
	return ""
