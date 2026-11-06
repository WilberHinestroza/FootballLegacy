extends Node

## Prueba dirigida de 2 pedidos de Wilber sobre WageOfferEngine:
##   1. "pasan muy seguido y no tiene sentido, y menos en mi primera
##      temporada" — offer_chance() ahora exige career_matches >= 30,
##      sin importar qué tan alto esté coach_trust.
##   2. "debería ser una propuesta para negociar" — negotiate_counter()
##      (WageOfferEngine) + WorldTickEngine.negotiate_wage_offer() (UN
##      solo pedido, el club cede o se planta, nunca empeora, nunca se
##      puede pedir dos veces).
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/WageNegotiationProbe.tscn

func _ready() -> void:
	var ok: bool = true

	# --- 1) Piso de partidos de carrera ---
	var chance_rookie: float = WageOfferEngine.offer_chance(90, 3, 5) # trust altísimo, pero recién arrancando
	var chance_veteran: float = WageOfferEngine.offer_chance(90, 3, 40)
	print("offer_chance(trust=90, 5 partidos de carrera) = %.2f (esperado 0.0)" % chance_rookie)
	print("offer_chance(trust=90, 40 partidos de carrera) = %.2f (esperado > 0.0)" % chance_veteran)
	if chance_rookie != 0.0:
		print("FALLA: un jugador con 5 partidos de carrera no debería ser elegible nunca")
		ok = false
	if chance_veteran <= 0.0:
		print("FALLA: un jugador con 40 partidos y trust alto debería ser elegible")
		ok = false

	# --- 2) negotiate_counter(): determinista con rng sembrado, las 2 ramas ---
	var offer: Dictionary = {"club_id": "c_1_0", "old_wage": 1000, "new_wage": 1200}
	var accepted_seed: int = -1
	var held_seed: int = -1
	for seed_val in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var r: Dictionary = WageOfferEngine.negotiate_counter(offer, 5, 90, rng, 70) # agente 5 estrellas + trust 90: chance alta
		if bool(r.get("accepted", false)) and accepted_seed < 0:
			accepted_seed = seed_val
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = seed_val
		var r2: Dictionary = WageOfferEngine.negotiate_counter(offer, 0, 50, rng2, 70) # sin agente + trust neutro: chance baja
		if not bool(r2.get("accepted", false)) and held_seed < 0:
			held_seed = seed_val
		if accepted_seed >= 0 and held_seed >= 0:
			break
	print("semilla que da 'el club cede' (agente 5, trust 90): %d" % accepted_seed)
	print("semilla que da 'el club se planta' (sin agente, trust 50): %d" % held_seed)
	if accepted_seed < 0 or held_seed < 0:
		print("FALLA: no se encontraron ambas ramas en 200 semillas (¿counter_accept_chance rota?)")
		ok = false
	var rng_a := RandomNumberGenerator.new(); rng_a.seed = accepted_seed
	var ra: Dictionary = WageOfferEngine.negotiate_counter(offer, 5, 90, rng_a, 70)
	if int(ra.get("counter_wage", 0)) <= int(offer["new_wage"]):
		print("FALLA: counter_wage debería ser MAYOR que la oferta original")
		ok = false
	print("counter_wage pedido: %d (original %d)" % [int(ra.get("counter_wage", 0)), int(offer["new_wage"])])

	# --- 3) WorldTickEngine.negotiate_wage_offer(): ronda completa, real ---
	SaveManager.active_slot_id = "slot_3"
	var p := PlayerData.new()
	p.player_name = "Probe Negociación"
	p.club_id = "c_1_0"
	p.wage = 1000
	# Atributos reales en 70 (no solo p.overall) — SaveManager.load_player()
	# recalcula overall desde los atributos vía sync_overall() al cargar, así
	# que fijar solo overall sin sus atributos quedaría pisado por el default
	# de 50 apenas se guarda/carga (gap de validez del probe hallado en
	# auto-auditoría; no rompía ninguna aserción con los números de esta
	# prueba, pero mejor no depender de eso).
	p.speed = 70
	p.shooting = 70
	p.passing = 70
	p.dribbling = 70
	p.control = 70
	p.decision_making = 70
	p.strength = 70
	p.stamina = 70
	p.overall = 70
	p.potential = 70 # invariante potential >= overall (default de PlayerData es 65)
	p.agent_stars = 5
	p.coach_trust = 95
	p.pending_wage_offer = {"club_id": "c_1_0", "old_wage": 1000, "new_wage": 1200}
	SaveManager.save_player(p)

	WorldTickEngine.negotiate_wage_offer()
	var after1 := SaveManager.load_player()
	print("tras pedir más: negotiated=%s club_held_firm=%s new_wage=%d" % [
		after1.pending_wage_offer.get("negotiated", false),
		after1.pending_wage_offer.get("club_held_firm", "?"),
		int(after1.pending_wage_offer.get("new_wage", 0))])
	if not bool(after1.pending_wage_offer.get("negotiated", false)):
		print("FALLA: negotiate_wage_offer() debería marcar negotiated=true")
		ok = false
	if int(after1.pending_wage_offer.get("new_wage", 0)) < 1200:
		print("FALLA: new_wage nunca debería quedar por DEBAJO de la oferta original")
		ok = false

	# Segundo pedido: no debe hacer NADA (ya negociado) — ni cambiar el monto.
	var wage_before_second: int = int(after1.pending_wage_offer.get("new_wage", 0))
	WorldTickEngine.negotiate_wage_offer()
	var after2 := SaveManager.load_player()
	print("tras un SEGUNDO pedido (no debería hacer nada): new_wage=%d" % int(after2.pending_wage_offer.get("new_wage", 0)))
	if int(after2.pending_wage_offer.get("new_wage", 0)) != wage_before_second:
		print("FALLA: un segundo pedido no debería volver a rolear ni cambiar el monto")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
