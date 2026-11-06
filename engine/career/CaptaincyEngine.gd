extends RefCounted
class_name CaptaincyEngine

## Capitanía — te ganás la cinta con el tiempo en el club, buena relación
## con el DT y reputación. Se REEVALÚA cada temporada en el rollover
## (WorldTickEngine): estado no-schema en `season["is_captain"]`. Un
## fichaje nuevo arranca sin cinta hasta el primer cierre de temporada.
##
## Efecto (centralizado en MatchEngine._setup):
##   - +2 plano a TUS acciones (via _match_attr_bonus, como el suplemento)
##   - +3% al xG de tu equipo (liderazgo / moral del grupo)

const MATCH_ATTR_BONUS := 2
const TEAM_XG_FACTOR := 1.03
## ARENGA de capitán en el entretiempo (P4, 9-oct): una por partido, empuja
## el ataque del equipo y tus acciones en el segundo tiempo.
const TALK_XG_FACTOR := 1.06
const TALK_ATTR_BONUS := 1

const MIN_COACH_TRUST := 68
const MIN_REPUTATION := 52
const MIN_CAREER_MATCHES := 30
const MIN_AGE := 23
# Bug real de la auditoría de balance (ronda 6): `leadership` (entrenable,
# foco Mental) no afectaba NADA en todo el juego — ni la media/overall
# (por diseño, como composure, ver PlayerDevelopment.compute_overall), ni
# ninguna fórmula de DecisionResolver, ni la capitanía — un tercio del
# presupuesto de XP del foco Mental se iba a un atributo sin ningún
# consumidor real. La cinta de capitán es el candidato obvio (ya la
# decide "confianza/reputación/experiencia", liderazgo encaja de lleno).
const MIN_LEADERSHIP := 45

static func evaluate(player: PlayerData) -> bool:
	if player == null or player.club_id == "":
		return false
	return player.coach_trust >= MIN_COACH_TRUST \
		and player.reputation >= MIN_REPUTATION \
		and player.career_matches >= MIN_CAREER_MATCHES \
		and player.age >= MIN_AGE \
		and player.leadership >= MIN_LEADERSHIP

## Titular de prensa al ganar la cinta.
static func headline() -> Dictionary:
	return {
		"headline": "El vestuario te elige capitán",
		"body": "El cuerpo técnico te confía el brazalete. Liderás al equipo dentro y fuera de la cancha.",
		"source": "CUERPO TÉCNICO", "sentiment": "POSITIVE",
	}
