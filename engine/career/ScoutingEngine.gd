extends RefCounted
class_name ScoutingEngine

## Informe de scouting del rival para la previa. Todo DERIVADO del estado
## del mundo — nada se persiste.
##   {danger_name, danger_pos, danger_ovr, form (String tipo "V E D V V"),
##    tactic (String), position (int, en su liga), threat (String)}

static func report(wte, fixture: Dictionary, user_is_home: bool) -> Dictionary:
	if wte == null or wte.world.is_empty():
		return {}
	var opp_id: String = String(fixture.get("away_club_id" if user_is_home else "home_club_id", ""))
	var opp := WorldFactory.find_club(wte.world, opp_id)
	if opp == null:
		return {}
	var meta: Dictionary = wte.world.get("club_meta_by_id", {}).get(opp_id, {})
	var season_start: int = int(wte.season.get("season_start_epoch_day", 0))
	var squad: Array[PlayerData] = WorldFactory.make_squad_with_transfers(wte.world, opp_id, wte.world_seed, season_start)

	# Hombre peligroso = mejor jugador de campo del rival.
	var danger: PlayerData = null
	for p in squad:
		if p.position == "GK":
			continue
		if danger == null or p.overall > danger.overall:
			danger = p

	# Forma reciente (5) determinista.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("scout|%s|%d" % [opp_id, int(fixture.get("epoch_day", fixture.get("matchday", 0)))]) ^ wte.world_seed
	var str_opp: float = float(wte._strength_by_club.get(opp_id, 55))
	var form_parts: Array = []
	for i in range(5):
		var r: float = rng.randf() + (str_opp - 55.0) * 0.006
		form_parts.append("V" if r > 0.62 else ("E" if r > 0.42 else "D"))

	# Posición del rival en su liga.
	var table: Array = wte.table_for_league(opp.league_id)
	var pos: int = 0
	for row in table:
		if String(row.get("club_id", "")) == opp_id:
			pos = int(row.get("pos", 0))
			break

	# Nota táctica según su DT.
	var coach := WorldFactory.find_coach(wte.world, opp_id)
	var tactic: String = "Bloque medio, sin grandes riesgos."
	if coach != null:
		match coach.play_style:
			"Posesión": tactic = "Te van a quitar la pelota. Paciencia y aprovechá las transiciones."
			"Contraataque": tactic = "Te ceden la pelota y salen rápido. Ojo con los espacios a la espalda."
			"Presión alta": tactic = "Presionan arriba desde el minuto uno. Salida limpia y a correr."
			_: tactic = "Equipo ordenado, %s. Va a costar generar." % coach.play_style.to_lower()

	var vs_us: float = str_opp - float(wte._strength_by_club.get(fixture.get("home_club_id" if user_is_home else "away_club_id", ""), 55))
	var threat: String = "Favorito claro" if vs_us > 8 else ("Rival duro" if vs_us > 2 else ("Parejo" if vs_us > -3 else "Podés con ellos"))

	return {
		"club_name": opp.club_name,
		"danger_name": danger.player_name if danger != null else "?",
		"danger_pos": Positions.label_of(danger.detailed_position) if danger != null else "",
		"danger_ovr": danger.overall if danger != null else 0,
		"danger_country": danger.country if danger != null else "",
		"form": " ".join(form_parts),
		"tactic": tactic,
		"position": pos,
		"threat": threat,
	}
