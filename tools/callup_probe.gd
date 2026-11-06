extends Node

## Diagnóstico de Fase 2 (selecciones nacionales): ejercita
## NationalTeamFactory.squad_for()/team_strength() y
## NationalCallUpEngine.resolve() de punta a punta con jugadores de prueba
## construidos a mano (NUNCA toca un save real) — cubre un caso elite, uno
## mediocre y uno de un país sin jugadores reales generados (relleno
## sintético). El FiveSeasonSim de verificación solo ejercitó el caso
## elite (su jugador de prueba es un crack); este probe cubre lo que ese
## camino no llega a probar.
##   godot --headless res://tools/CallupProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))
	var season_start: int = 0
	var bad: int = 0

	bad += _probe_player(world, world_seed, season_start, "elite", "Argentina", 95, 95, 0.9)
	bad += _probe_player(world, world_seed, season_start, "mediocre", "Argentina", 60, 30, 0.3)
	bad += _probe_player(world, world_seed, season_start, "pais_chico_sin_jugadores", "Bután", 70, 50, 0.5)

	print("PROBE ", "OK" if bad == 0 else "FAIL (%d)" % bad)
	get_tree().quit(1 if bad > 0 else 0)

func _probe_player(world: Dictionary, world_seed: int, season_start: int, label: String, country: String, overall: int, reputation: int, recent_form: float) -> int:
	var problems: int = 0
	var p := PlayerData.new()
	p.player_name = "Probe %s" % label
	p.country = country
	p.position = "MF"
	p.detailed_position = "MC"
	p.overall = overall
	p.potential = maxi(overall, 60)
	p.reputation = reputation
	p.age = 24

	var squad: Array[PlayerData] = NationalTeamFactory.squad_for(world, world_seed, season_start, country, p)
	var ok_size: bool = squad.size() == NationalTeamFactory.SQUAD_SIZE
	var ok_user: bool = squad.has(p)
	var ok_gk: bool = false
	for m in squad:
		if m.position == Positions.BROAD_GK:
			ok_gk = true
			break
	var strength: int = NationalTeamFactory.team_strength(squad)
	var ok_strength: bool = strength >= 30 and strength <= 99

	if not (ok_size and ok_user and ok_gk and ok_strength):
		problems += 1
	print("[%s] pais=%s squad=%d(user=%s,gk=%s) strength=%d" % [label, country, squad.size(), ok_user, ok_gk, strength])

	var rank: int = NationalCallUpEngine.rank_in_position(p, squad)
	var results: Array = []
	for seed_i in [1, 2, 3, 4, 5]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var res: Dictionary = NationalCallUpEngine.resolve(p, squad, recent_form, rng)
		var prob: float = float(res["probability"])
		if prob < 0.0 or prob > 1.0:
			problems += 1
		if not (String(res["status"]) in ["captain", "regular", "fringe", "left_out"]):
			problems += 1
		results.append("%s(p=%.2f)" % [String(res["status"]), prob])
	print("    rank=%d resultados=%s" % [rank, ", ".join(results)])
	return problems
