extends RefCounted
class_name LegacyEngine

## LEGADO AL RETIRARSE (10-oct, Wilber: "Modo leyenda al retirarte, sería
## solo ceremonia de despedida y si fui muy bueno, retirada de camiseta").
## Única fuente de las reglas: cuánto "pesó" la carrera y si el club donde
## te retirás cuelga tu número. Puro cálculo sobre datos YA guardados
## (club_seniority, career_*, career_titles) — nada nuevo en el esquema.

## Nivel de legado: 0 normal · 1 respetado · 2 ídolo · 3 leyenda.
static func tier(p: PlayerData) -> int:
	var pts: int = 0
	pts += mini(p.career_matches / 100, 5)
	pts += mini(p.career_goals / 60, 4)
	pts += mini(p.trophies_won, 6)
	pts += _count(p, "ballon_dor") * 3 + _count(p, "world_cup") * 3
	pts += mini(p.club_seniority / 3, 3)
	if pts >= 14:
		return 3
	if pts >= 9:
		return 2
	if pts >= 5:
		return 1
	return 0

const TIER_NAMES := ["Profesional", "Respetado", "Ídolo", "Leyenda"]

## ¿El club donde te retirás retira tu camiseta? Hace falta HISTORIA en
## ese club (años) y peso de carrera — o un Balón de Oro / Mundial con
## varios años en la casa.
static func jersey_retired(p: PlayerData) -> bool:
	if p.club_id == "":
		return false
	if p.club_seniority >= 10:
		return true
	var big: bool = _count(p, "ballon_dor") > 0 or _count(p, "world_cup") > 0
	if big and p.club_seniority >= 4:
		return true
	return p.club_seniority >= 6 and (p.trophies_won >= 3 or p.career_goals >= 120 or tier(p) >= 2)

static func _count(p: PlayerData, id: String) -> int:
	var n: int = 0
	for t in p.career_titles:
		if String(t.get("id", "")) == id:
			n += 1
	return n

## Palabras del DT en la despedida, según el nivel.
static func coach_words(p: PlayerData) -> String:
	match tier(p):
		3: return "\"Dirigí a muchos, pero como vos, ninguno. El fútbol te va a extrañar.\""
		2: return "\"La gente vino hoy por vos. Te ganaste cada aplauso.\""
		1: return "\"Profesional de punta a punta. Fue un honor tenerte en el vestuario.\""
	return "\"Gracias por dejar todo en cada entrenamiento. Suerte en lo que venga.\""
