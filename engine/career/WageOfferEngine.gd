extends RefCounted
class_name WageOfferEngine

## Renegociación de sueldo A MITAD de contrato — pedido explícito: "que
## llegue sola" (nunca un botón para pedirla), el club premia una buena
## racha con una mejora y el jugador solo decide aceptar o no. Separado a
## propósito de ContractDecision/_begin_season_rollover, que solo dispara
## al VENCER el contrato — esto puede pasar con años de contrato de sobra.
##
## Misma fórmula que la renovación real (ContractEngine.renewal_wage +
## AgentEngine.wage_multiplier) — nunca una segunda matemática de sueldo,
## mismo criterio que SponsorEngine/CoachRelations/PlayerDevelopment.
## Estado persistente (PlayerData.pending_wage_offer, ver SaveManager
## schema v13), no un popup efímero — mismo patrón que SponsorEngine.

## No hay historial de nota propio persistido (solo el de la temporada
## actual, que se resetea) — coach_trust YA es la señal acumulada de
## rendimiento que usa el resto del juego (CoachRelations.apply_match_result
## lo sube/baja con cada partido), así que "buena racha" se reutiliza de
## ahí en vez de inventar una segunda métrica.
const TRUST_THRESHOLD := 65
const BASE_CHANCE := 0.06 # probabilidad SEMANAL una vez elegible

## Bug real reportado por Wilber: "pasan muy seguido y no tiene sentido,
## y menos en mi primera temporada" — con coach_trust arrancando en 50 y
## subiendo ~3-5 por partido ganado, el umbral de 65 se cruzaba en apenas
## 4-5 partidos, así que un jugador podía recibir su primera mejora
## espontánea de sueldo a semanas de firmar su PRIMER contrato
## profesional — no había ningún piso de "todavía sos nuevo acá". Un
## jugador necesita mostrar prácticamente una temporada entera de forma
## (30 partidos de carrera) antes de ser elegible, sin importar qué tan
## rápido suba coach_trust.
const MIN_CAREER_MATCHES := 30

## 0.0 si el jugador no es elegible esta semana (mal momento con el DT,
## contrato ya vencido/sin años —eso lo resuelve ContractDecision, no
## esto—, o todavía muy nuevo en su carrera). Quien llama ya filtra "sin
## oferta pendiente" antes de rolear.
static func offer_chance(coach_trust: int, contract_years_remaining: int, career_matches: int) -> float:
	if coach_trust < TRUST_THRESHOLD or contract_years_remaining <= 0 or career_matches < MIN_CAREER_MATCHES:
		return 0.0
	return BASE_CHANCE

## {} si la mejora calculada no supera el sueldo actual — un jugador ya
## bien pagado para su nivel no recibe una "mejora" que en los hechos
## sería una baja o quedaría igual (eso lo cubre ContractDecision al
## vencer, con su propio piso).
static func generate_offer(player: PlayerData, league_position_ratio: float) -> Dictionary:
	var base_new_wage: int = ContractEngine.renewal_wage(player.wage, player.coach_trust, league_position_ratio, player.overall)
	# El multiplicador del agente se aplica DESPUÉS del techo (bug real
	# encontrado en la auditoría: renewal_wage() ya clampea a wage_ceiling,
	# pero multiplicar el resultado por AgentEngine.wage_multiplier podía
	# volver a pasarse — un agente de 5 estrellas esquivaba el techo hasta
	# un 15%). Se re-clampea acá, después del multiplicador.
	var new_wage: int = mini(int(round(base_new_wage * AgentEngine.wage_multiplier(player.agent_stars))), ContractEngine.wage_ceiling(player.overall))
	if new_wage <= player.wage:
		return {}
	return {"club_id": player.club_id, "old_wage": player.wage, "new_wage": new_wage}

## --- Negociación (pedido de Wilber: "debería ser más una propuesta y
## sentarnos a negociar" — antes era aceptar/rechazar un número fijo, sin
## vuelta). UN solo pedido, no una ida y vuelta infinita: mantiene la
## pantalla simple (2 botones + "Pedir más") en vez de un regateo sin fin. ---

const COUNTER_ASK_PCT := 0.12 # cuánto de más pedís sobre lo ya ofrecido

## Probabilidad de que el club CEDA al pedido — más alta con mejor agente
## (regatea mejor en tu nombre) y más confianza con el DT (te quieren
## contento). Nunca certeza: negociar de verdad implica poder perder.
static func counter_accept_chance(agent_stars: int, coach_trust: int) -> float:
	var agent_factor: float = clampf(float(agent_stars) / 5.0, 0.0, 1.0)
	var trust_factor: float = clampf(float(coach_trust - 50) / 50.0, 0.0, 1.0)
	return clampf(0.25 + agent_factor * 0.35 + trust_factor * 0.25, 0.1, 0.85)

## Resultado de pedir más sobre una oferta ya generada (`offer`, ver
## generate_offer). "accepted"=true: el club cede a `counter_wage`.
## "accepted"=false: el club se PLANTA — la oferta original de `offer`
## sigue en pie tal cual, plantarse no es un castigo (mismo criterio que
## "rechazar no tiene castigo" de resolve_wage_offer), solo un límite
## real a cuánto se puede estirar la cuerda.
static func negotiate_counter(offer: Dictionary, agent_stars: int, coach_trust: int, rng: RandomNumberGenerator, overall: int) -> Dictionary:
	if offer.is_empty():
		return {}
	# Mismo techo que generate_offer() — "Pedir más" no tenía NINGÚN clamp
	# (bug real de la auditoría).
	var counter_wage: int = mini(int(round(float(offer["new_wage"]) * (1.0 + COUNTER_ASK_PCT))), ContractEngine.wage_ceiling(overall))
	var accepted: bool = rng.randf() < counter_accept_chance(agent_stars, coach_trust)
	return {"accepted": accepted, "counter_wage": counter_wage}
