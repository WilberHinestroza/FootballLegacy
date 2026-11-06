extends RefCounted
class_name SeasonReportEngine

## Resumen de fin de temporada del jugador y de su club, con nota 0-10 —
## pedido explícito de Wilber. Se calcula UNA VEZ al rollover (con los
## contadores de la temporada que TERMINA, todavía sin resetear) y se
## muestra en la ceremonia (scenes/SeasonCeremony/) — nunca se persiste
## aparte, es un cálculo de un solo uso que se descarta después.

## Cuánto gol/asistencia se espera de cada puesto por partido — un DF que
## mete 3 goles en la temporada rindió mejor relativo a lo suyo que un ST
## con esos mismos 3.
const _ATTACKING_FACTOR := {"GK": 0.15, "DF": 0.45, "MF": 0.75, "ST": 1.0}

## 0-10. Ninguna variable sola alcanza ni hunde la nota: mezcla
## implicación en gol relativa al puesto, posición final del EQUIPO,
## confianza del entrenador y si cumplió su objetivo de temporada.
static func player_rating(player: PlayerData, table: Array, objective_progress: Dictionary) -> float:
	# BUG REAL (Wilber: "me dieron un 10 cuando mi rendimiento fue de
	# 7.6"): season_appearances son TITULARIDADES nada más (a propósito,
	# lo usa el objetivo "titularidades") — usarlo acá como denominador de
	# "goles+asistencias por partido" inflaba la nota de cualquiera con
	# muchos minutos de suplente: los mismos goles repartidos entre menos
	# partidos "vistos" por la fórmula suben el promedio artificialmente.
	# season_matches_played (v28) es el conteo real de partidos jugados.
	var appearances: int = maxi(player.season_matches_played, 0)
	var involvement: float = float(player.season_goals + player.season_key_passes) / float(maxi(appearances, 1))
	var factor: float = float(_ATTACKING_FACTOR.get(player.position, 0.6))
	var performance: float = involvement / maxf(factor, 0.05) # ~1.0 = cumplió lo esperable de su puesto

	var team_bonus: float = 0.0
	var row: Dictionary = LeagueTable.row_for(table, player.club_id)
	if not row.is_empty() and table.size() > 1:
		var pos_ratio: float = float(int(row["pos"]) - 1) / float(table.size() - 1) # 0=campeón, 1=último
		team_bonus = (1.0 - pos_ratio) * 0.8 - 0.2 # entre -0.2 y +0.6

	var trust_bonus: float = (float(player.coach_trust) - 50.0) / 100.0 # entre -0.5 y +0.5
	var objective_bonus: float = 0.6 if objective_progress.get("met", false) else 0.0
	var appearance_penalty: float = 0.0
	if appearances < 10:
		appearance_penalty = -0.5 * (1.0 - float(appearances) / 10.0) # muy pocos partidos, nota más prudente

	var rating: float = 5.0 + (performance - 1.0) * 2.5 + team_bonus + trust_bonus + objective_bonus + appearance_penalty
	return clampf(rating, 0.0, 10.0)

## Texto corto de resumen del jugador para la ceremonia.
static func player_summary_text(player: PlayerData, table: Array) -> String:
	var row: Dictionary = LeagueTable.row_for(table, player.club_id)
	var pos_txt: String = " · %d° en la liga" % int(row["pos"]) if not row.is_empty() else ""
	return "%d partidos · %d goles · %d asistencias%s" % [
		player.season_matches_played, player.season_goals, player.season_key_passes, pos_txt,
	]

## Resumen corto del CLUB (posición final + títulos) para la ceremonia.
static func club_summary_text(club: ClubData, table: Array, domestic_cup: Dictionary) -> String:
	if club == null:
		return "Sin datos de la temporada."
	var lines: Array = []
	var row: Dictionary = LeagueTable.row_for(table, club.club_id)
	if not row.is_empty():
		var pos: int = int(row["pos"])
		lines.append("%d° en la liga (%d pts)" % [pos, int(row["pts"])])
		if pos == 1:
			lines.append("¡CAMPEÓN DE LIGA!")
	if _final_winner(domestic_cup) == club.club_id:
		lines.append("¡CAMPEÓN DE COPA!")
	return " · ".join(lines) if not lines.is_empty() else "Sin datos de la temporada."

## Wrapper público de _final_winner — lo usa además WorldTickEngine para
## saber si el club del usuario ganó la copa doméstica al acumular
## trophies_won (ver PlayerData.trophies_won).
static func cup_champion_club_id(bracket: Dictionary) -> String:
	return _final_winner(bracket)

static func _final_winner(bracket: Dictionary) -> String:
	for rnd in bracket.get("rounds", []):
		if String(rnd.get("round_name", "")) == "Final" and rnd.get("decided", false):
			var matches: Array = rnd.get("matches", [])
			if not matches.is_empty():
				return String(matches[0].get("winner_club_id", ""))
	return ""
