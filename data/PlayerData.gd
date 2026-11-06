extends Resource
class_name PlayerData

## Equivalente a PlayerEntity (Room) en Football Legacy V11.
## Se guarda dentro del archivo de slot vía SaveManager (ver SaveManager.gd).
## IMPORTANTE: cualquier campo nuevo aquí = cambio de "esquema" de guardado.
## Ver nota de migraciones en SaveManager.gd antes de tocar esta clase
## en un proyecto que ya tenga partidas guardadas.

@export var player_name: String = ""
@export var country: String = ""
@export var position: String = "ST" # categoría amplia que usa el motor: GK, DF, MF, ST
@export var detailed_position: String = "DC" # código fino (POR, DFC, MCO, ...), ver Positions.gd
@export var secondary_detailed_position: String = "" # código fino opcional; "" = ninguna
@export var dominant_foot: String = "Derecho" # "Derecho" | "Izquierdo" | "Ambidiestro"
@export var origin: String = "" # "Barrio humilde", "Cantera de club grande", ... — modificador narrativo de arranque
@export var age: int = 16
@export var birth_epoch_day: int = 0 # espejo de epochDay en V11: evita bugs de año calendario

# --- Atributos ---
@export var overall: int = 45
@export var potential: int = 65 # invariante: potential >= overall, SIEMPRE
@export var speed: int = 50
@export var stamina: int = 50
@export var strength: int = 50
@export var control: int = 50
@export var passing: int = 50
@export var shooting: int = 50
@export var dribbling: int = 50
@export var decision_making: int = 50
@export var composure: int = 50
@export var leadership: int = 30

# --- Personalidad (test inicial de 20 preguntas, 5 mostradas al azar) ---
@export var personality_traits: Dictionary = {} # {"ambition": 0-100, "loyalty": 0-100, ...}

# --- Estado de carrera ---
@export var club_id: String = ""
@export var club_seniority: int = 0 # temporadas completas en el club actual
@export var coach_trust: int = 50 # 0-100, relación con el entrenador ACTUAL (ver CoachRelations.gd)
@export var career_matches: int = 0
@export var fatigue_physical: float = 0.0
@export var fatigue_mental: float = 0.0
@export var injury_days_remaining: int = 0 # 0 = sano; ver PlayerDevelopment.roll_injury_days()
@export var reputation: int = 0
@export var market_value: int = 0
@export var wage: int = 0 # sueldo de temporada, unidades de juego (ver ContractEngine.gd)
@export var contract_years_remaining: int = 0
@export var balance: int = 0 # ahorros acumulados del jugador
@export var sponsor: Dictionary = {} # patrocinio activo: {name, weekly_income, weeks_remaining}. {} = ninguno
@export var pending_sponsor_offer: Dictionary = {} # oferta esperando decisión (ver SponsorEngine.gd)
@export var pending_wage_offer: Dictionary = {} # mejora de sueldo A MITAD de contrato esperando decisión (ver WageOfferEngine.gd). {} = ninguna
@export var pending_season_event: Dictionary = {} # evento inesperado de temporada esperando decisión (ver SeasonEventEngine.gd). {} = ninguno
@export var consumables: Dictionary = {} # {item_id: cantidad} — comprados en la Tienda, sin usar todavía (ver ShopEngine.gd)
@export var active_effects: Dictionary = {} # efectos de un solo uso ya armados: {"injury_shield_matches": int, "match_boost_matches": int, "training_boost": bool}

# --- Contadores de TEMPORADA (se resetean en cada rollover, ver ObjectivesEngine.gd) ---
@export var season_appearances: int = 0 # TITULARIDADES — solo cuenta si arrancaste (ver MatchEngine.run_match()["user_started"]). Objetivo "titularidades" y el chip del Hub leen ESTE.
@export var season_matches_played: int = 0 # v28: partidos jugados de verdad (titular O suplente) — "Partidos" en la UI lee ESTE, no season_appearances (bug real: Wilber, "aparecí con 12 partidos en vez de 30+ que jugué")
@export var season_goals: int = 0
@export var season_key_passes: int = 0

# --- Contadores de CARRERA (nunca se resetean; acumulan lo de cada temporada
# justo antes de resetear los de arriba, ver WorldTickEngine._reset_season_stats_and_objective()) ---
@export var career_goals: int = 0
@export var career_assists: int = 0
@export var trophies_won: int = 0 # ligas + copas domésticas ganadas como titular del club

## Gabinete de trofeos (schema v20). Una entrada por título/honor ganado,
## NUNCA se reinicia. Cada entrada:
##   {"id": String, "name": String, "kind": String, "season": int, "metal": int}
## kind ∈ team|continental|world|individual (decide la silueta del trofeo).
## metal 1/2/3 = oro/plata/bronce. `season` = CalendarUtils.season_start_year.
@export var career_titles: Array = []

## Rasgos de jugador (schema v21). Array de ids de String (ver Traits.gd):
## se DESBLOQUEAN por hitos de carrera (TraitEngine.check_unlocks) y no se
## pierden. Cada rasgo aplica un modificador concreto y centralizado
## (finalización en DecisionResolver, penales en Match, fatiga en el tick).
@export var traits: Array = []

## Prensa: estado persistente de carrera (ver PressGenerator.gd), NUNCA se
## reinicia con la temporada. Cada entrada: {headline, body, source,
## sentiment, day}. Más reciente primero, tope PressGenerator.MAX_ENTRIES.
@export var press_feed: Array = []

# --- Vida personal (ligero, opcional) ---
@export var home_type: String = "shared_apartment"
@export var car_type: String = "none"
@export var agent_name: String = ""
@export var agent_stars: int = 3 # 1-5, ver AgentEngine.gd

## Staff personal contratado (ver StaffEngine.gd). Por rol:
## {"nutritionist": {"level": 1-5}, ...}. Sin la clave = no contratado.
## Persiste POR CARRERA (no en el dict `season`, que se reconstruye en el
## rollover). Schema v16.
@export var staff: Dictionary = {}

## Inversiones abiertas (ver InvestmentEngine.gd). Cada una:
## {id, type_id, name, amount, open_day, matures_day}. Se resuelven solas
## al vencer. Persiste POR CARRERA. Schema v17.
@export var investments: Array = []

## Vida familiar (ver RelationshipEngine.gd). {} = sin pareja;
## {name, since_day} = en pareja. Persiste POR CARRERA. Schema v18.
@export var partner: Dictionary = {}

## Avatar del jugador por capas (ver Avatar.gd). {} = usar el determinista
## por nombre; {"v": 2, "hair": id, "tint_base": hex, ...} = personalizado
## en la creación. Persiste POR CARRERA. Schema v19 (v31: pasa del formato
## Kenney de índices al pixel art, ver Avatar.from_legacy).
@export var avatar: Dictionary = {}

## Ropa y accesorios de la Tienda (pixel art, ver Avatar.OUTFITS /
## Avatar.ACCESSORIES y ShopEngine.buy_cosmetic). Schema v31.
##  - cosmetics_owned: ids comprados (no se gastan, son permanentes).
##  - cosmetics_equipped: {slot: id} — slot "outfit" o "acc_*". Sin clave =
##    nada puesto en ese slot (outfit vacío = el kit del club).
@export var cosmetics_owned: Array = []
@export var cosmetics_equipped: Dictionary = {}

## Patrocinio de GUAYOS (schema v32, 9-oct, pedido de Wilber: "4 marcas de
## guayos que puedan patrocinar al jugador"): aparte del patrocinio general
## (`sponsor`). {brand, weekly_income, weeks_remaining} — {} = sin marca.
## Mientras dura, sus modelos son gratis (ver BootDealEngine).
@export var boot_deal: Dictionary = {}
@export var pending_boot_offer: Dictionary = {}

## v33 (9-oct, Wilber: "mejorar la evolución del jugador y todo el sistema
## RPG"): NIVEL de carrera 1-50 con XP propia (ProgressionEngine), puntos
## de habilidad para el árbol por posición (SkillTree), y las últimas notas
## oficiales para la FORMA (1-5).
@export var level: int = 1
@export var career_xp: int = 0
@export var skill_points: int = 0
@export var skills: Array = []          # ids de SkillTree desbloqueados
@export var recent_ratings: Array = []  # últimas 5 notas oficiales (más nueva al final)
## v33 vida social: ánimo 0-100, cita en curso {id, stage, since_day} y
## afinidad con cada chica conocida {npc_id: 0-100} (ver SocialLifeEngine).
@export var mood: int = 60
## v34 (10-oct, Wilber aprobó "esquema v34"): memoria de carrera para la
## inmersión (ImmersionEngine).
##  - former_clubs: clubes de los que te fuiste por traspaso o fin de
##    contrato (NO cesiones). Cada uno {club_id, name, left_season,
##    seniority, to_club_id}. Sirve para que la hinchada de tu ex club te
##    reciba (silbidos si te fuiste a su clásico, aplausos si fuiste ídolo).
##  - nemesis_log: historial contra tu rival personal de TODA la carrera.
##    Cada partido {day, season, sign, goals, rating, club_id}.
@export var former_clubs: Array = []
@export var nemesis_log: Array = []
## v34 también (RPG ampliado, CareerRpgEngine):
##  - achievements: ids de LOGROS ya cobrados (su XP se da una sola vez).
##  - mastery: {"finish"|"playmk"|"defense": acciones acumuladas} — sube
##    con lo que hacés en los partidos y da un bonus chico permanente.
@export var achievements: Array = []
@export var mastery: Dictionary = {}
@export var dating: Dictionary = {}
@export var affinities: Dictionary = {}

## Rasgos EQUIPADOS para el partido (subconjunto de `traits`). Máximo
## `Traits.slots_for(overall)` (1-4, se abren slots al subir de media). []
## = auto (los primeros N desbloqueados). Persiste POR CARRERA. Schema v22.
@export var equipped_traits: Array = []
## v23: XP acumulada por atributo entrenable. {attr_name: float}. Cuando
## llega al umbral (PlayerDevelopment.xp_needed) el atributo sube +1 y se
## resta el umbral. La subes entrenando el foco correspondiente y jugando
## partidos (más XP cuanto mejor rindas). Ausente / {} = sin progreso.
@export var attribute_xp: Dictionary = {}
## v25: dificultad de PROGRESIÓN elegida en creación de personaje —
## "easy" | "normal" | "hard". Escala la velocidad de subida de atributos
## (PlayerDevelopment.xp_needed) y el declive por edad (weekly_decline_chance).
## Ver PlayerDevelopment.gd para el detalle (incluye el fix del 12-sep que
## sacó el doble conteo de progresión).
@export var growth_difficulty: String = "normal"

## v27 (selecciones nacionales, Fase 2): estadísticas de CARRERA con la
## selección — nunca se resetean, mismo criterio que career_goals/
## career_assists de club, pero un contador APARTE (un partido de club
## nunca suma acá y viceversa). Ver NationalCallUpEngine.gd.
@export var caps: int = 0
@export var international_goals: int = 0
@export var international_assists: int = 0
## Estado narrativo de tu lugar en la selección — se RECALCULA cada
## ventana FIFA a partir del mérito actual (media/reputación/forma), NUNCA
## se acumula ni persiste una "relación" (a propósito: la convocatoria es
## por mérito, no una amistad con un DT nacional, ver NationalCallUpEngine
## .gd). "" = nunca convocado. "fringe" | "regular" | "captain" | "left_out".
@export var national_team_status: String = ""

func is_potential_valid() -> bool:
	return potential >= overall

func ensure_potential_floor() -> void:
	# Aprendizaje directo de FL: el potential SIEMPRE debe ser >= overall.
	if potential < overall:
		potential = overall

# --- Serialización de guardado ---
# SaveManager es el ÚNICO dueño de la forma del archivo de slot. Estos dos
# métodos son la única traducción PlayerData <-> Dictionary. Añadir un
# campo aquí = cambio de esquema: anunciarlo y migrar en SaveManager
# (ver la nota de la cabecera y SaveManager._migrate_if_needed()).

func to_save_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"country": country,
		"position": position,
		"detailed_position": detailed_position,
		"secondary_detailed_position": secondary_detailed_position,
		"dominant_foot": dominant_foot,
		"origin": origin,
		"age": age,
		"birth_epoch_day": birth_epoch_day,
		"overall": overall,
		"potential": potential,
		"speed": speed,
		"stamina": stamina,
		"strength": strength,
		"control": control,
		"passing": passing,
		"shooting": shooting,
		"dribbling": dribbling,
		"decision_making": decision_making,
		"composure": composure,
		"leadership": leadership,
		"personality_traits": personality_traits.duplicate(true),
		"club_id": club_id,
		"club_seniority": club_seniority,
		"coach_trust": coach_trust,
		"career_matches": career_matches,
		"fatigue_physical": fatigue_physical,
		"fatigue_mental": fatigue_mental,
		"injury_days_remaining": injury_days_remaining,
		"reputation": reputation,
		"market_value": market_value,
		"wage": wage,
		"contract_years_remaining": contract_years_remaining,
		"balance": balance,
		"sponsor": sponsor.duplicate(true),
		"pending_sponsor_offer": pending_sponsor_offer.duplicate(true),
		"pending_wage_offer": pending_wage_offer.duplicate(true),
		"pending_season_event": pending_season_event.duplicate(true),
		"consumables": consumables.duplicate(true),
		"active_effects": active_effects.duplicate(true),
		"season_appearances": season_appearances,
		"season_matches_played": season_matches_played,
		"season_goals": season_goals,
		"season_key_passes": season_key_passes,
		"career_goals": career_goals,
		"career_assists": career_assists,
		"trophies_won": trophies_won,
		"career_titles": career_titles.duplicate(true),
		"traits": traits.duplicate(true),
		"equipped_traits": equipped_traits.duplicate(true),
		"attribute_xp": attribute_xp.duplicate(true),
		"growth_difficulty": growth_difficulty,
		"caps": caps,
		"international_goals": international_goals,
		"international_assists": international_assists,
		"national_team_status": national_team_status,
		"press_feed": press_feed.duplicate(true),
		"home_type": home_type,
		"car_type": car_type,
		"agent_name": agent_name,
		"agent_stars": agent_stars,
		"staff": staff.duplicate(true),
		"investments": investments.duplicate(true),
		"partner": partner.duplicate(true),
		"avatar": avatar.duplicate(true),
		"cosmetics_owned": cosmetics_owned.duplicate(),
		"cosmetics_equipped": cosmetics_equipped.duplicate(true),
		"boot_deal": boot_deal.duplicate(true),
		"pending_boot_offer": pending_boot_offer.duplicate(true),
		"level": level,
		"career_xp": career_xp,
		"skill_points": skill_points,
		"skills": skills.duplicate(),
		"recent_ratings": recent_ratings.duplicate(),
		"mood": mood,
		"former_clubs": former_clubs.duplicate(true),
		"nemesis_log": nemesis_log.duplicate(true),
		"achievements": achievements.duplicate(),
		"mastery": mastery.duplicate(true),
		"dating": dating.duplicate(true),
		"affinities": affinities.duplicate(true),
	}

static func from_save_dict(d: Dictionary) -> PlayerData:
	var p := PlayerData.new()
	# JSON de Godot devuelve todo número como float: castear a int/float explícito.
	p.player_name = d.get("player_name", "")
	p.country = d.get("country", "")
	p.position = d.get("position", "ST")
	p.detailed_position = d.get("detailed_position", Positions.default_detailed_for_broad(p.position))
	p.secondary_detailed_position = d.get("secondary_detailed_position", "")
	p.dominant_foot = d.get("dominant_foot", "Derecho")
	p.origin = d.get("origin", "")
	p.age = int(d.get("age", 16))
	p.birth_epoch_day = int(d.get("birth_epoch_day", 0))
	p.overall = int(d.get("overall", 45))
	p.potential = int(d.get("potential", 65))
	p.speed = int(d.get("speed", 50))
	p.stamina = int(d.get("stamina", 50))
	p.strength = int(d.get("strength", 50))
	p.control = int(d.get("control", 50))
	p.passing = int(d.get("passing", 50))
	p.shooting = int(d.get("shooting", 50))
	p.dribbling = int(d.get("dribbling", 50))
	p.decision_making = int(d.get("decision_making", 50))
	p.composure = int(d.get("composure", 50))
	p.leadership = int(d.get("leadership", 30))
	var traits_in = d.get("personality_traits", {})
	var traits_dict: Dictionary = traits_in if traits_in is Dictionary else {}
	p.personality_traits = traits_dict.duplicate(true)
	p.club_id = d.get("club_id", "")
	p.club_seniority = int(d.get("club_seniority", 0))
	p.coach_trust = clampi(int(d.get("coach_trust", 50)), 0, 100)
	p.career_matches = int(d.get("career_matches", 0))
	p.fatigue_physical = float(d.get("fatigue_physical", 0.0))
	p.fatigue_mental = float(d.get("fatigue_mental", 0.0))
	p.injury_days_remaining = maxi(int(d.get("injury_days_remaining", 0)), 0)
	p.reputation = int(d.get("reputation", 0))
	p.market_value = int(d.get("market_value", 0))
	p.wage = maxi(int(d.get("wage", 0)), 0)
	p.contract_years_remaining = maxi(int(d.get("contract_years_remaining", 0)), 0)
	p.balance = int(d.get("balance", 0))
	var sponsor_in = d.get("sponsor", {})
	p.sponsor = (sponsor_in if sponsor_in is Dictionary else {}).duplicate(true)
	var pending_in = d.get("pending_sponsor_offer", {})
	p.pending_sponsor_offer = (pending_in if pending_in is Dictionary else {}).duplicate(true)
	var pending_wage_in = d.get("pending_wage_offer", {})
	p.pending_wage_offer = (pending_wage_in if pending_wage_in is Dictionary else {}).duplicate(true)
	var pending_event_in = d.get("pending_season_event", {})
	p.pending_season_event = (pending_event_in if pending_event_in is Dictionary else {}).duplicate(true)
	var consumables_in = d.get("consumables", {})
	p.consumables = (consumables_in if consumables_in is Dictionary else {}).duplicate(true)
	var effects_in = d.get("active_effects", {})
	p.active_effects = (effects_in if effects_in is Dictionary else {}).duplicate(true)
	p.season_appearances = maxi(int(d.get("season_appearances", 0)), 0)
	p.season_matches_played = maxi(int(d.get("season_matches_played", 0)), 0)
	p.season_goals = maxi(int(d.get("season_goals", 0)), 0)
	p.season_key_passes = maxi(int(d.get("season_key_passes", 0)), 0)
	p.career_goals = maxi(int(d.get("career_goals", 0)), 0)
	p.career_assists = maxi(int(d.get("career_assists", 0)), 0)
	p.trophies_won = maxi(int(d.get("trophies_won", 0)), 0)
	var titles_in = d.get("career_titles", [])
	p.career_titles = (titles_in if titles_in is Array else []).duplicate(true)
	var player_traits_in = d.get("traits", [])
	p.traits = (player_traits_in if player_traits_in is Array else []).duplicate(true)
	var equipped_in = d.get("equipped_traits", [])
	p.equipped_traits = (equipped_in if equipped_in is Array else []).duplicate(true)
	var attr_xp_in = d.get("attribute_xp", {})
	p.attribute_xp = (attr_xp_in if attr_xp_in is Dictionary else {}).duplicate(true)
	var diff_in: String = String(d.get("growth_difficulty", "normal"))
	p.growth_difficulty = diff_in if diff_in in ["easy", "normal", "hard"] else "normal"
	p.caps = maxi(int(d.get("caps", 0)), 0)
	p.international_goals = maxi(int(d.get("international_goals", 0)), 0)
	p.international_assists = maxi(int(d.get("international_assists", 0)), 0)
	var nt_status_in: String = String(d.get("national_team_status", ""))
	p.national_team_status = nt_status_in if nt_status_in in ["", "fringe", "regular", "captain", "left_out"] else ""
	var press_in = d.get("press_feed", [])
	p.press_feed = (press_in if press_in is Array else []).duplicate(true)
	p.home_type = d.get("home_type", "shared_apartment")
	p.car_type = d.get("car_type", "none")
	p.agent_name = d.get("agent_name", "")
	p.agent_stars = clampi(int(d.get("agent_stars", 3)), 1, 5)
	var staff_in = d.get("staff", {})
	p.staff = (staff_in if staff_in is Dictionary else {}).duplicate(true)
	var inv_in = d.get("investments", [])
	p.investments = (inv_in if inv_in is Array else []).duplicate(true)
	var partner_in = d.get("partner", {})
	p.partner = (partner_in if partner_in is Dictionary else {}).duplicate(true)
	var avatar_in = d.get("avatar", {})
	p.avatar = (avatar_in if avatar_in is Dictionary else {}).duplicate(true)
	var owned_in = d.get("cosmetics_owned", [])
	p.cosmetics_owned = (owned_in if owned_in is Array else []).duplicate()
	var cosm_equipped_in = d.get("cosmetics_equipped", {})
	p.cosmetics_equipped = (cosm_equipped_in if cosm_equipped_in is Dictionary else {}).duplicate(true)
	var boot_in = d.get("boot_deal", {})
	p.boot_deal = (boot_in if boot_in is Dictionary else {}).duplicate(true)
	var boot_off_in = d.get("pending_boot_offer", {})
	p.pending_boot_offer = (boot_off_in if boot_off_in is Dictionary else {}).duplicate(true)
	p.level = int(d.get("level", 1))
	p.career_xp = int(d.get("career_xp", 0))
	p.skill_points = int(d.get("skill_points", 0))
	var skills_in = d.get("skills", [])
	p.skills = (skills_in if skills_in is Array else []).duplicate()
	var rr_in = d.get("recent_ratings", [])
	p.recent_ratings = (rr_in if rr_in is Array else []).duplicate()
	p.mood = int(d.get("mood", 60))
	var fc_in = d.get("former_clubs", [])
	p.former_clubs = (fc_in if fc_in is Array else []).duplicate(true)
	var nl_in = d.get("nemesis_log", [])
	p.nemesis_log = (nl_in if nl_in is Array else []).duplicate(true)
	var ach_in = d.get("achievements", [])
	p.achievements = (ach_in if ach_in is Array else []).duplicate()
	var mas_in = d.get("mastery", {})
	p.mastery = (mas_in if mas_in is Dictionary else {}).duplicate(true)
	var dating_in = d.get("dating", {})
	p.dating = (dating_in if dating_in is Dictionary else {}).duplicate(true)
	var aff_in = d.get("affinities", {})
	p.affinities = (aff_in if aff_in is Dictionary else {}).duplicate(true)
	p.ensure_potential_floor()
	return p
