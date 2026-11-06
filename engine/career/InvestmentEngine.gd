extends RefCounted
class_name InvestmentEngine

## Inversiones personales (sección de Vida personal) — metés plata ahora,
## se resuelve sola al vencer con un rendimiento aleatorio dentro del
## rango del tipo. El azar es DETERMINISTA (semilla = id de la inversión ^
## world_seed): la misma inversión da siempre el mismo resultado, no se
## puede "recargar" para cambiarlo. Estado en `PlayerData.investments`
## (schema v17). Toda la matemática vive acá.

const TYPES := [
	{
		"id": "fixed", "name": "Plazo fijo", "days": 120,
		"lo": 1.08, "hi": 1.08, "risk": "Sin riesgo",
		"desc": "Rinde un 8% fijo al vencer. Lo seguro.",
	},
	{
		"id": "fund", "name": "Fondo indexado", "days": 200,
		"lo": 0.88, "hi": 1.32, "risk": "Riesgo medio",
		"desc": "Puede bajar hasta un 12% o subir hasta un 32%.",
	},
	{
		"id": "business", "name": "Negocio propio", "days": 300,
		"lo": 0.55, "hi": 2.05, "risk": "Riesgo alto",
		"desc": "Desde perder casi la mitad hasta más que duplicar.",
	},
	{
		# Bug real de la auditoría de balance (ronda 6): con lo=0.20/hi=3.40,
		# "Cripto" tenía MEJOR retorno esperado Y MENOR probabilidad de
		# pérdida que "Fondo indexado" (etiquetado "riesgo medio") — nunca
		# convenía elegir el fondo. Recalibrado para que el riesgo real
		# corresponda a la etiqueta "muy volátil": más probabilidad de
		# pérdida que el fondo, a cambio de más upside esperado.
		"id": "crypto", "name": "Cripto", "days": 150,
		"lo": 0.15, "hi": 2.20, "risk": "Muy volátil",
		"desc": "Puede perder hasta un 85% o más que duplicarse.",
	},
]

const AMOUNTS := [10000, 25000, 50000, 100000, 250000]

static func type_by_id(type_id: String) -> Dictionary:
	for t in TYPES:
		if t["id"] == type_id:
			return t
	return {}

static func min_amount() -> int:
	return AMOUNTS[0]

## Abre una inversión. Devuelve {ok: bool, reason: String}.
static func open(player: PlayerData, type_id: String, amount: int, today: int) -> Dictionary:
	var t: Dictionary = type_by_id(type_id)
	if t.is_empty():
		return {"ok": false, "reason": "Tipo de inversión desconocido."}
	if amount <= 0:
		return {"ok": false, "reason": "Monto inválido."}
	if player.balance < amount:
		return {"ok": false, "reason": "No te alcanza el dinero líquido."}
	player.balance -= amount
	player.investments.append({
		"id": "%d_%d_%d" % [today, amount, player.investments.size()],
		"type_id": type_id,
		"name": String(t["name"]),
		"amount": amount,
		"open_day": today,
		"matures_day": today + int(t["days"]),
	})
	return {"ok": true, "reason": ""}

## 0.0-1.0 — cuánto le falta para vencer.
static func progress(inv: Dictionary, today: int) -> float:
	var total: float = float(int(inv["matures_day"]) - int(inv["open_day"]))
	if total <= 0.0:
		return 1.0
	return clampf(float(today - int(inv["open_day"])) / total, 0.0, 1.0)

## Resuelve todas las inversiones vencidas: acredita el pago en el balance
## y las saca de la lista. Devuelve [{name, amount, payout, gain}] para
## que quien llama arme titulares de prensa.
static func resolve_due(player: PlayerData, today: int, world_seed: int) -> Array:
	var matured: Array = []
	var still_open: Array = []
	for inv in player.investments:
		if int(inv["matures_day"]) > today:
			still_open.append(inv)
			continue
		var t: Dictionary = type_by_id(String(inv["type_id"]))
		var lo: float = float(t.get("lo", 1.0))
		var hi: float = float(t.get("hi", 1.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("invest:%s" % String(inv["id"])) ^ world_seed
		var mult: float = lo + (hi - lo) * rng.randf()
		var amount: int = int(inv["amount"])
		var payout: int = int(round(amount * mult))
		player.balance += payout
		matured.append({
			"name": String(inv["name"]), "amount": amount,
			"payout": payout, "gain": payout - amount,
		})
	player.investments = still_open
	return matured
