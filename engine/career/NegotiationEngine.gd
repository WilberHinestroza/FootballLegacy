extends RefCounted
class_name NegotiationEngine

## Regateo de contrato con el presidente del club. Estado puro (Dictionary)
## que la UI (ui/common/ContractNegotiation.gd) muestra y va pasando de
## vuelta. NO es un "momento clave" de partido → la matemática vive acá,
## no en DecisionResolver (ese es solo para el MatchEngine).
##
## state = {
##   wage, years, goal_bonus, release_clause,   # términos en la mesa
##   base_wage, base_years,                      # oferta original (para topes)
##   patience,                                   # 0-100, baja con cada pedido
##   locked,                                     # true = ya no se puede pedir más
##   last_response, last_message,                # feedback del presidente
##   agent_stars,
## }

const ASKS := {
	"wage_up":     "Pedir más sueldo",
	"years_down":  "Contrato más corto",
	"bonus_up":    "Más prima por gol",
	"clause_down": "Bajar la cláusula",
}

## `overall`: nivel ACTUAL del jugador — techo real de "Pedir más sueldo"
## (bug real de la auditoría: este regateo no conocía wage_ceiling en
## absoluto, a diferencia de WageOfferEngine; con suficientes pedidos el
## sueldo final podía terminar muy por encima de lo que el nivel del
## jugador sostiene).
static func start(base_wage: int, base_years: int, agent_stars: int, overall: int = 60) -> Dictionary:
	base_wage = maxi(base_wage, 1)
	return {
		"wage": base_wage,
		"years": base_years,
		"goal_bonus": maxi(5000, int(base_wage * 0.006)),
		"release_clause": maxi(1000000, base_wage * 25),
		"base_wage": base_wage,
		"base_years": base_years,
		"patience": clampi(52 + agent_stars * 6, 40, 90),
		"locked": false,
		"last_response": "opening",
		"last_message": _opening_line(agent_stars),
		"agent_stars": agent_stars,
		"overall": overall,
	}

## Aplica un pedido. Devuelve el state MUTADO (nuevo dict) con la respuesta
## del presidente en `last_response` / `last_message`.
static func apply_ask(state: Dictionary, ask: String) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	if s.get("locked", false) or not ASKS.has(ask):
		return s

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stars: int = int(s.get("agent_stars", 3))
	var drop: int = rng.randi_range(12, 22) - stars
	s["patience"] = int(s["patience"]) - maxi(6, drop)
	var pat: int = int(s["patience"])

	# Concesión: llena si hay margen, parcial si el presidente se cansa.
	var full: bool = pat > 24
	var factor: float = 1.0 if full else 0.35

	match ask:
		"wage_up":
			var cap: int = mini(int(round(int(s["base_wage"]) * (1.55 + stars * 0.07))), ContractEngine.wage_ceiling(int(s.get("overall", 60))))
			var bump: int = int(round(int(s["wage"]) * rng.randf_range(0.06, 0.13) * factor))
			s["wage"] = mini(int(s["wage"]) + bump, cap)
		"years_down":
			if int(s["years"]) > 1 and full:
				s["years"] = int(s["years"]) - 1
		"bonus_up":
			var bcap: int = int(s["base_wage"]) * 4
			s["goal_bonus"] = mini(int(round(int(s["goal_bonus"]) * (1.0 + 0.5 * factor))), bcap)
		"clause_down":
			var floor_c: int = int(s["wage"]) * 12
			s["release_clause"] = maxi(int(round(int(s["release_clause"]) * (1.0 - 0.22 * factor))), floor_c)

	if pat <= 0:
		s["locked"] = true
		s["last_response"] = "walk"
		s["last_message"] = "\"Hasta acá llegamos. Es esto o nada — decidí.\""
	elif pat <= 24:
		s["locked"] = true
		s["last_response"] = "final"
		s["last_message"] = "\"Te doy un último gesto y cerramos. No hay más margen.\""
	else:
		s["last_response"] = "countered" if full else "partial"
		s["last_message"] = _counter_line(ask, full)
	return s

static func summary_line(state: Dictionary) -> String:
	return "Sueldo %s/temp · %d año%s · prima %s · cláusula %s" % [
		CurrencyFormat.format(int(state["wage"])),
		int(state["years"]), "" if int(state["years"]) == 1 else "s",
		CurrencyFormat.format(int(state["goal_bonus"])),
		CurrencyFormat.format(int(state["release_clause"])),
	]

static func _opening_line(stars: int) -> String:
	if stars >= 4:
		return "\"Tu representante ya me adelantó lo que buscan. Escucho.\""
	return "\"Esta es nuestra propuesta. Contame qué te gustaría ajustar.\""

static func _counter_line(ask: String, full: bool) -> String:
	if full:
		match ask:
			"wage_up": return "\"El club puede hacer un esfuerzo con el sueldo. Hecho.\""
			"years_down": return "\"Acepto un año menos, pero te quiero comprometido.\""
			"bonus_up": return "\"Las primas por gol no son problema. Subámoslas.\""
			"clause_down": return "\"Bajo la cláusula, pero no mucho más de esto.\""
	return "\"Puedo moverme un poco en eso, no todo lo que pedís.\""
