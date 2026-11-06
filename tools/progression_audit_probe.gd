extends Node
## AUDITORÍA de progresión (10-oct, Wilber: "revisa la progresión del jugador
## si funciona de manera óptima"). Corre carreras de 17 a 36 años con las
## funciones REALES (match_xp_gains, training_session, tick semanal) para 3
## perfiles de jugador humano y 4 posiciones. Solo lectura, no toca slots.
##   godot --headless --path . res://tools/ProgressionAuditProbe.tscn
const PROFILES := {"casual (0 entrenos)": 0, "normal (2/sem)": 80, "dedicado (5/sem)": 200}
const MATCHES := 42

func _career(pos: String, trainings: int, focus_mode: String, seed_i: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var p := PlayerData.new()
	p.position = pos
	p.age = 17
	p.potential = 84
	for s in PlayerDevelopment.ALL_TRAINABLE:
		p.set(s, 56)
	PlayerDevelopment.sync_overall(p)
	p.level = 1
	var out: Array = []
	for age in range(17, 37):
		p.age = age
		var foci: Array = ["physical", "technical", "mental"]
		for w in range(46):
			# partidos de la semana (~0.9)
			if w < MATCHES:
				var rating: float = clampf(rng.randfn(6.8, 0.7), 4.5, 9.6)
				var goals: int = (1 if rng.randf() < (0.45 if pos == "ST" else (0.15 if pos == "MF" else 0.03)) else 0)
				var assists: int = (1 if rng.randf() < (0.2 if pos != "GK" else 0.0) else 0)
				PlayerDevelopment.grant_attribute_xp(p, PlayerDevelopment.match_xp_gains(p, rating, goals, assists))
				ProgressionEngine.add_xp(p, ProgressionEngine.match_xp(rating, goals, assists, rng.randf() < 0.45, true, false))
			# entrenos de la semana
			var per_week: float = float(trainings) / 46.0
			var n: int = int(per_week) + (1 if rng.randf() < fmod(per_week, 1.0) else 0)
			for t in range(n):
				var focus: String = "balanced" if focus_mode == "balanced" else String(foci[(w + t) % 3])
				PlayerDevelopment.training_session(p, focus, rng, 1.0)
				ProgressionEngine.add_xp(p, ProgressionEngine.training_xp("normal"))
			PlayerDevelopment.apply_weekly_development(p, "balanced", rng, false)
		out.append([age, p.overall, p.level])
	return out

func _ready() -> void:
	for pos in ["ST", "MF", "DF", "GK"]:
		print("\n=== %s  (arranca 17 años, media 56, potencial 84) ===" % pos)
		for name in PROFILES:
			var c: Array = _career(pos, int(PROFILES[name]), "rotate", 11)
			var line: String = "%-22s" % name
			var peak: int = 0
			var peak_age: int = 0
			for row in c:
				if int(row[1]) > peak:
					peak = int(row[1]); peak_age = int(row[0])
			for a in [18, 20, 22, 24, 26, 28, 30, 32, 34, 36]:
				line += " %d:%d" % [a, int(c[a - 17][1])]
			print(line, "  | pico %d a los %d | nivel 22a=%d 30a=%d" % [peak, peak_age, int(c[5][2]), int(c[13][2])])
	# XP necesaria por punto (para ver la pared del final).
	print("\nXP por +1 de atributo:  56→57: %d · 70→71: %d · 80→81: %d · 88→89: %d" % [
		PlayerDevelopment.xp_needed(56), PlayerDevelopment.xp_needed(70), PlayerDevelopment.xp_needed(80), PlayerDevelopment.xp_needed(88)])
	get_tree().quit(0)
