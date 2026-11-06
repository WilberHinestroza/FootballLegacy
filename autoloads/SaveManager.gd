extends Node
## Autoload. Equivalente al rol que jugaba Room + Migrations.kt en FL.
##
## ⚠️ REGLA HEREDADA DE FOOTBALL LEGACY (no negociable):
## Todo cambio a la ESTRUCTURA de un archivo de guardado (nuevos campos
## en PlayerData/ClubData/ContractData, cambio de tipo de un campo,
## renombrar una clave) es un cambio de "esquema" y DEBE:
##   1) Anunciarse explícita y claramente antes de aplicarse.
##   2) Tener una función de migración real en `migrations/` que
##      transforme el JSON viejo al nuevo formato.
## Godot no tiene un ORM con migraciones automáticas como Room, así que
## esta disciplina hay que mantenerla a mano — es aún más fácil romper
## partidas guardadas aquí que en FL si no se respeta esto.

const SAVE_DIR := "user://saves/"
## Historial de esquema:
##   v1 -> { schema_version, player }
##   v2 -> + world_seed (int): semilla del mundo determinista (WorldFactory).
##   v3 -> + season (dict): calendario de liga + copa de la temporada actual
##         (SeasonCalendar). Vacío hasta que se elige club.
##   v4 -> + player.detailed_position (String): código fino de posición
##         (POR, DFC, MCO, ...). `position` sigue siendo la categoría amplia.
##   v5 -> + player.coach_trust (int, 0-100): relación con el entrenador
##         actual del club (ver CoachRelations.gd). Neutral = 50.
##   v6 -> + player.injury_days_remaining (int): días de baja pendientes
##         (ver PlayerDevelopment.roll_injury_days()). 0 = sano.
##   v7 -> + player.wage, contract_years_remaining, balance (int):
##         contrato y finanzas personales (ver ContractEngine.gd).
##   v8 -> + player.sponsor, pending_sponsor_offer (Dictionary):
##         patrocinio como estado persistente (ver SponsorEngine.gd).
##   v9 -> + player.season_appearances, season_goals, season_key_passes
##         (int): contadores de temporada para objetivos (ver
##         ObjectivesEngine.gd). Se resetean en cada rollover.
##   v10 -> + player.press_feed (Array): titulares de prensa persistentes
##         de carrera (ver PressGenerator.gd). NO se resetea con la
##         temporada.
##   v11 -> + player.agent_name, agent_stars (int, 1-5): representante del
##         jugador (ver AgentEngine.gd). home_type/car_type ya existían
##         desde v1 — ahora se usan de verdad (ver LifestyleEngine.gd).
##   v12 -> + player.career_goals, career_assists, trophies_won (int):
##         totales de CARRERA (nunca se resetean), para la pantalla de
##         perfil/stats del jugador (pestaña "Historia"). Se acumulan a
##         partir de esta versión — saves viejos arrancan en 0 aunque ya
##         tengan partidos jugados, no hay forma de reconstruir el
##         histórico previo a que existiera el contador.
##   v13 -> + player.pending_wage_offer (Dictionary): mejora de sueldo A
##         MITAD de contrato que el club propone solo ("que llegue sola",
##         pedido explícito — ver WageOfferEngine.gd), separado del flujo
##         de ContractDecision (que solo dispara al VENCER el contrato).
##         {} = ninguna oferta pendiente.
##   v14 -> + player.pending_season_event (Dictionary): evento inesperado
##         de temporada (0-3 veces por temporada, pedido explícito) que
##         puede beneficiar o perjudicar al jugador — de aviso simple o de
##         decisión con 2+ opciones (ver SeasonEventEngine.gd). {} =
##         ninguno pendiente.
##   v15 -> + player.consumables (Dictionary {id: cantidad}) y
##         player.active_effects (Dictionary): la Tienda (pedido explícito,
##         porte de Football Legacy) — botiquín, energizante, vendaje,
##         suplementos... ver ShopEngine.gd. {} / {} para saves viejos.
##   v16 -> + player.staff (Dictionary): staff personal contratado
##         (nutricionista, psicólogo, fisio, asesor financiero, community
##         manager) con nivel 1-5, bono pasivo y sueldo por temporada —
##         ver StaffEngine.gd. + player.secondary_detailed_position,
##         dominant_foot ("Derecho" por defecto), origin: campos de la
##         creación de personaje ampliada. {} / "" / "Derecho" para saves
##         viejos.
##   v17 -> + player.investments (Array): inversiones abiertas del jugador
##         (plazo fijo, fondo, negocio...) que se resuelven solas al
##         vencer — ver InvestmentEngine.gd. [] para saves viejos.
##   v18 -> + player.partner (Dictionary): vida familiar — {} sin pareja,
##         {name, since_day} en pareja (ver RelationshipEngine.gd). {}
##         para saves viejos.
##   v19 -> + player.avatar (Dictionary): avatar por capas del jugador
##         (Kenney Avatar Mixer, ver Avatar.gd). {} = usar el determinista
##         por nombre. {} para saves viejos.
##   v20 -> + player.career_titles (Array): gabinete de trofeos —
##         una entrada {id, name, kind, season, metal} por título/honor
##         ganado (equipo, continental, mundial, individual: Balón de Oro,
##         Bota de Oro, MVP, 11 ideal...). NUNCA se resetea. [] para saves
##         viejos; los títulos previos solo quedan en el contador
##         `trophies_won`, no se puede reconstruir el detalle.
##   v21 -> + player.traits (Array de ids String): rasgos de jugador
##         (ver Traits.gd). Se desbloquean por hitos de carrera
##         (TraitEngine.check_unlocks en el rollover). [] para saves
##         viejos; se van ganando de acá en más.
##   v22 -> + player.equipped_traits (Array de ids String): subconjunto de
##         `traits` que el jugador lleva EQUIPADO al partido. Máximo
##         Traits.slots_for(overall) (1-4, se abren al subir de media).
##         [] = auto (primeros N desbloqueados). [] para saves viejos.
##   v23 -> + player.attribute_xp (Dictionary {attr_name: float}): XP
##         acumulada hacia el siguiente +1 de cada atributo entrenable.
##         Sube entrenando el foco correspondiente y jugando partidos
##         (más XP cuanto mejor la nota). {} para saves viejos.
##   v24 -> + market_salt (int, NIVEL SLOT, no PlayerData): sal por CARRERA
##         que se mezcla en la semilla del mercado de fichajes IA-a-IA
##         (TransferMarketEngine). Sin esto, todas las carreras nuevas
##         sobre el MISMO mundo importado (world_seed == -1) daban EXACTA-
##         mente los mismos fichajes a los mismos clubes (Wilber: "siempre
##         salen los mismos movimientos"). Carreras nuevas: randi() != 0.
##         Saves viejos: 0 → `world_seed ^ 0`, mercado IDÉNTICO al de
##         antes (migración sin efecto sobre partidas en curso).
##   v25 -> + player.growth_difficulty (String "easy"|"normal"|"hard"):
##         dificultad de PROGRESIÓN elegida en creación de personaje —
##         escala la velocidad de subida de atributos/overall (ver
##         PlayerDevelopment.gd). "normal" para saves viejos = el ritmo de
##         SIEMPRE, sin cambios.
##   v26 -> + "international" (Dictionary, NIVEL SLOT — hermana de "player"/
##         "season", NUNCA dentro de "season"): estado de selecciones
##         nacionales (eliminatorias al Mundial/Mundial/copas continentales
##         — ver QualifyingEngine.gd). No cabe en `season` porque una
##         eliminatoria dura ~2 años de calendario, varias temporadas de
##         club (que SÍ se reconstruyen enteras cada 365 días). Mismo
##         patrón "mundo vivo" que season["cont_draw"]/["cont_results"]:
##         solo un pool congelado por ciclo + los resultados que el usuario
##         jugó de verdad; todo lo demás (posiciones de tabla, resultados
##         IA-vs-IA) es función pura de world_seed+día, nunca se guarda.
##         {} para saves viejos y para saves nuevos hasta Fase 2 (todavía
##         no hay convocatoria de usuario — Fase 1 es solo el motor de
##         fondo, consultado bajo demanda).
##   v27 -> + player.caps, international_goals, international_assists (int):
##         estadísticas de CARRERA con la selección, contador APARTE de
##         career_goals/career_assists (de club) — nunca se resetean. +
##         player.national_team_status (String "" | "fringe" | "regular" |
##         "captain" | "left_out"): se RECALCULA cada ventana FIFA por
##         mérito (NationalCallUpEngine.gd), nunca se acumula. 0/0/0/"" para
##         saves viejos — no hay forma de reconstruir caps previos.
##   v28 -> + player.season_matches_played (int): partidos de club jugados
##         de VERDAD esta temporada (titular O suplente) -- BUG REAL
##         corregido (Wilber: "solo cuenta los partidos como titular y no
##         los partidos jugados en la temporada, aparecí con 12 partidos
##         en vez de 30+"). season_appearances (v9) en realidad solo
##         cuenta TITULARIDADES (así lo lee el objetivo "titularidades" y
##         el chip del Hub, con ese nombre puesto a propósito), pero varias
##         pantallas lo mostraban bajo la etiqueta genérica "Partidos" -- de
##         ahí el desajuste. career_matches (existe desde antes) pasa a
##         acumularse desde ESTE contador nuevo en vez de desde
##         season_appearances -- mismo bug de fondo también a nivel
##         carrera. Backfill de saves viejos: arranca del valor actual de
##         season_appearances (lo mejor posible sin datos históricos de
##         partidos ya jugados de suplente esta temporada).
##   v29 -> + "league_tiers" (Dictionary, NIVEL SLOT -- hermana de "player"/
##         "season"/"international"): ascensos y descensos entre categorías
##         (ver PromotionRelegationEngine.gd). club_id -> league_id ACTUAL,
##         solo para clubes que se movieron de la categoría con la que
##         nació su mundo -- se reaplica sobre `world` (nunca persistido,
##         siempre reconstruido desde world_seed) en cada carga. {} = ningún
##         club se movió todavía, igual para un save viejo que para uno
##         nuevo hasta que termine la primera temporada con el sistema
##         activo. Pedido explícito de Wilber.
##   v30 -> + "coefficient_history" (Dictionary, NIVEL SLOT -- hermana de
##         "player"/"season"/"league_tiers"): confederation -> (String
##         league_id -> puntaje CRUDO de coeficiente de la temporada que
##         acaba de terminar, ver CoefficientEngine.compute_scores). Antes
##         el ranking de coeficiente (que decide el orden de clasificación
##         continental de la temporada siguiente, ver
##         WorldTickEngine._finish_season_rollover) se recalculaba de CERO
##         cada temporada -- un solo torneo bueno/malo podía reordenar el
##         ranking completo de una confederación de un año a otro. Pedido
##         explícito de Wilber: ventana de 2 temporadas (la que acaba de
##         terminar + esto, la anterior) para que el ranking sea más
##         estable. Se reemplaza entero en cada rollover con el puntaje
##         CRUDO de la temporada que recién terminó (nunca se le suma
##         encima -- así la ventana es siempre de exactamente 2
##         temporadas, ni más ni menos). {} para saves viejos y hasta que
##         termine la primera temporada con el sistema activo.
##   v31 -> + player.cosmetics_owned (Array de ids) y
##         player.cosmetics_equipped (Dictionary slot -> id): ropa y
##         accesorios en pixel art que se compran en la Tienda (ver
##         ShopEngine.buy_cosmetic / Avatar.OUTFITS). Además player.avatar
##         pasa del formato Kenney (índices de archivo por capa) al pixel
##         art {"v": 2, "hair": id, ...} vía Avatar.from_legacy — se
##         conservan los tintes de piel/pelo/ropa/fondo. Pedido explícito
##         de Wilber (9-oct): reemplazar los avatares Kenney por el pixel
##         art de PixelLab. [] / {} para saves viejos.
##   v32 -> + player.boot_deal y player.pending_boot_offer (Dictionary):
##         patrocinio de una marca de GUAYOS (BootBrands / BootDealEngine),
##         aparte del patrocinio general. Pedido de Wilber (9-oct),
##         anunciado y confirmado ("procede"). {} para saves viejos.
##   v33 -> + player.level / career_xp / skill_points / skills /
##         recent_ratings (evolución + árbol de habilidades, ProgressionEngine
##         y SkillTree) y player.mood / dating / affinities (vida social,
##         SocialLifeEngine). Pedido de Wilber (9-oct), anunciado y
##         confirmado ("procede"). Saves viejos: nivel según la media actual
##         y esos niveles ya como puntos para gastar; lo demás vacío.
##   v34 -> + player.former_clubs (Array) y player.nemesis_log (Array):
##         memoria de carrera para la inmersión (ex clubes y rival
##         personal, ImmersionEngine). Pedido de Wilber (10-oct), anunciado
##         y confirmado ("esquema v34... sí"). Saves viejos: ambos vacíos;
##         el historial del rival de la temporada en curso (que vivía en
##         season["nemesis_log"]) se copia al jugador. Misma versión:
##         + player.achievements (Array) y player.mastery (Dictionary) del
##         RPG ampliado (CareerRpgEngine) — vacíos en saves viejos.
##   v35 -> + market_v2_from_day (int, NIVEL SLOT, no PlayerData): desde qué
##         temporada (día de inicio) rigen las reglas nuevas del mercado
##         IA-a-IA (los "bombazos": estrellas que SÍ se mueven). Pedido de
##         Wilber (11-oct: "las estrellas no se mueven nunca... los bombazos
##         parece que no suceden"), anunciado y confirmado ("procede").
##         El mercado es una función pura de la semilla y NO se guarda: si
##         la regla nueva valiera para todo, la temporada EN CURSO de una
##         carrera ya empezada cambiaría hacia atrás (planteles y resultados
##         ya jugados). Saves viejos: = inicio de su temporada actual + 1 →
##         esa temporada queda EXACTAMENTE igual y los bombazos empiezan en
##         la siguiente. Carreras nuevas: 0 (siempre).
const CURRENT_SCHEMA_VERSION := 35

var active_slot_id: String = ""

## Tres slots fijos — la pantalla de selección (MainMenu) siempre los
## muestra los tres, vacíos o no. Reemplaza el esquema viejo de "un
## slot_<timestamp> nuevo por cada Nueva carrera", que dejaba slots
## sueltos sin límite y no tenía ninguna UI para elegir entre ellos.
const SLOT_IDS := ["slot_1", "slot_2", "slot_3"]

func get_slot_path(slot_id: String) -> String:
	return SAVE_DIR + slot_id + ".json"

func _slot_backup_path(slot_id: String) -> String:
	return get_slot_path(slot_id) + ".bak"

func _slot_temp_path(slot_id: String) -> String:
	return get_slot_path(slot_id) + ".tmp"

## Guardado ATÓMICO (P0-12): se escribe el .tmp completo, se rota el
## principal sano a .bak y recién ahí el .tmp pasa a ser el principal.
## Un cierre en cualquier punto deja O BIEN el save anterior + su respaldo,
## O BIEN el nuevo save completo — nunca un .json truncado.
func save_slot(slot_id: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	data["schema_version"] = CURRENT_SCHEMA_VERSION
	var text := JSON.stringify(data, "\t")
	var main_path := get_slot_path(slot_id)
	var tmp_path := _slot_temp_path(slot_id)
	var bak_path := _slot_backup_path(slot_id)
	if not _write_slot_text(tmp_path, text):
		# Sin temporal no hay atomicidad posible: último recurso directo.
		push_error("SaveManager: no se pudo abrir el temporal de " + slot_id)
		_write_slot_text(main_path, text)
		return
	# Respaldo: copiamos el principal SOLO si se puede releer. Si ya estaba
	# corrupto, el .bak anterior es la última copia buena y NO debe pisarse.
	var main_text := _read_slot_text(main_path)
	if _parse_slot_text(main_text) != null:
		_write_slot_text(bak_path, main_text)
	elif FileAccess.file_exists(main_path):
		DirAccess.remove_absolute(main_path)
	# Recién ahora el temporal pasa a ser el principal. Si el proceso muere
	# en el hueco, load_slot() encuentra el .tmp completo o el .bak.
	if FileAccess.file_exists(main_path):
		DirAccess.remove_absolute(main_path)
	var err := DirAccess.rename_absolute(tmp_path, main_path)
	if err != OK and FileAccess.file_exists(main_path):
		# Otro proceso pudo recrear el destino justo ahora: reintentamos.
		DirAccess.remove_absolute(main_path)
		err = DirAccess.rename_absolute(tmp_path, main_path)
	if err != OK:
		# Algunos sistemas de archivos de Android no permiten rename sobre
		# el destino: copiamos el temporal ya completo y limpiamos.
		push_warning("SaveManager: rename atómico falló, copiando directo: " + slot_id)
		if _write_slot_text(main_path, text) and FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)

func _write_slot_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true

func _read_slot_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

## `json.data` SIN tipar a propósito: un JSON válido puede ser null, número,
## array o diccionario; solo el diccionario es un save legible.
## `JSON.parse()` devuelve el error en vez de imprimirlo como
## `JSON.parse_string()` (un .json truncado es esperable y no debe asustar
## en el log: lo recuperamos enseguida desde .bak/.tmp).
func _parse_slot_text(text: String):
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data

## Devuelve el Dictionary del archivo, o null si no existe / no se puede
## abrir / está vacío / no es JSON de objeto. Sin migrar.
func _read_slot_file(path: String):
	return _parse_slot_text(_read_slot_text(path))

func load_slot(slot_id: String) -> Dictionary:
	var main_path := get_slot_path(slot_id)
	var raw = _read_slot_file(main_path)
	if raw != null:
		return _migrate_if_needed(raw as Dictionary)
	# El principal no existe o quedó corrupto/truncado (cierre a mitad de
	# escritura). Recuperamos la última copia buena: el .bak de la rotación
	# anterior o, si el cierre fue justo entre el temporal y el rename, el
	# .tmp que ya estaba completo.
	var bak_path := _slot_backup_path(slot_id)
	var recovered = _read_slot_file(bak_path)
	var source := bak_path
	if recovered == null:
		var tmp_path := _slot_temp_path(slot_id)
		recovered = _read_slot_file(tmp_path)
		source = tmp_path
	if recovered == null:
		if FileAccess.file_exists(main_path):
			push_error("SaveManager: slot corrupto o vacío: " + slot_id)
		return {}
	push_warning("SaveManager: slot %s recuperado desde %s" % [slot_id, source.get_file()])
	# La copia buena vuelve a ser el principal para que la próxima escritura
	# rote desde un archivo sano.
	_write_slot_text(main_path, JSON.stringify(recovered, "\t"))
	return _migrate_if_needed(recovered as Dictionary)

func _migrate_if_needed(data: Dictionary) -> Dictionary:
	var version: int = data.get("schema_version", 0)
	if version == CURRENT_SCHEMA_VERSION:
		return data
	if version == 0:
		# Slot vacío / recién creado: no hay nada que migrar, nace ya en la
		# versión actual cuando se guarde.
		return data

	if version == 1:
		data = _migrate_v1_to_v2(data)
		version = 2

	if version == 2:
		data = _migrate_v2_to_v3(data)
		version = 3

	if version == 3:
		data = _migrate_v3_to_v4(data)
		version = 4

	if version == 4:
		data = _migrate_v4_to_v5(data)
		version = 5

	if version == 5:
		data = _migrate_v5_to_v6(data)
		version = 6

	if version == 6:
		data = _migrate_v6_to_v7(data)
		version = 7

	if version == 7:
		data = _migrate_v7_to_v8(data)
		version = 8

	if version == 8:
		data = _migrate_v8_to_v9(data)
		version = 9

	if version == 9:
		data = _migrate_v9_to_v10(data)
		version = 10

	if version == 10:
		data = _migrate_v10_to_v11(data)
		version = 11

	if version == 11:
		data = _migrate_v11_to_v12(data)
		version = 12

	if version == 12:
		data = _migrate_v12_to_v13(data)
		version = 13

	if version == 13:
		data = _migrate_v13_to_v14(data)
		version = 14

	if version == 14:
		data = _migrate_v14_to_v15(data)
		version = 15

	if version == 15:
		data = _migrate_v15_to_v16(data)
		version = 16

	if version == 16:
		data = _migrate_v16_to_v17(data)
		version = 17

	if version == 17:
		data = _migrate_v17_to_v18(data)
		version = 18

	if version == 18:
		data = _migrate_v18_to_v19(data)
		version = 19

	if version == 19:
		data = _migrate_v19_to_v20(data)
		version = 20

	if version == 20:
		data = _migrate_v20_to_v21(data)
		version = 21

	if version == 21:
		data = _migrate_v21_to_v22(data)
		version = 22

	if version == 22:
		data = _migrate_v22_to_v23(data)
		version = 23

	if version == 23:
		data = _migrate_v23_to_v24(data)
		version = 24

	if version == 24:
		data = _migrate_v24_to_v25(data)
		version = 25

	if version == 25:
		data = _migrate_v25_to_v26(data)
		version = 26

	if version == 26:
		data = _migrate_v26_to_v27(data)
		version = 27

	if version == 27:
		data = _migrate_v27_to_v28(data)
		version = 28

	if version == 28:
		data = _migrate_v28_to_v29(data)
		version = 29

	if version == 29:
		data = _migrate_v29_to_v30(data)
		version = 30

	if version == 30:
		data = _migrate_v30_to_v31(data)
		version = 31

	if version == 31:
		data = _migrate_v31_to_v32(data)
		version = 32

	if version == 32:
		data = _migrate_v32_to_v33(data)
		version = 33
	if version == 33:
		data = _migrate_v33_to_v34(data)
		version = 34
	if version == 34:
		data = _migrate_v34_to_v35(data)
		version = 35

	if version != CURRENT_SCHEMA_VERSION:
		push_warning("SaveManager: slot en versión %d, esperada %d. Falta migración." % [version, CURRENT_SCHEMA_VERSION])
	return data

func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	# v2 introduce world_seed. Los saves v1 no lo tenían: se les asigna una
	# semilla ESTABLE derivada del id del slot, para que su mundo sea el
	# mismo en cada carga.
	if not data.has("world_seed"):
		var derived: int = absi(hash(active_slot_id)) if not active_slot_id.is_empty() else 20260904
		data["world_seed"] = derived
	data["schema_version"] = 2
	return data

func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	# v3 introduce `season`. Los saves v2 no tenían calendario: se deja
	# vacío y se generará al elegir club / entrar a la carrera.
	if not data.has("season"):
		data["season"] = {}
	data["schema_version"] = 3
	return data

func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	# v4 introduce player.detailed_position. Se deriva de la categoría
	# amplia `position` que ya tenía el save.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("detailed_position"):
		var broad: String = player.get("position", "ST")
		player["detailed_position"] = Positions.default_detailed_for_broad(broad)
		data["player"] = player
	data["schema_version"] = 4
	return data

func _migrate_v4_to_v5(data: Dictionary) -> Dictionary:
	# v5 introduce player.coach_trust. Saves v4 empiezan en confianza
	# neutral (50) con el entrenador actual de su club.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("coach_trust"):
		player["coach_trust"] = 50
		data["player"] = player
	data["schema_version"] = 5
	return data

func _migrate_v5_to_v6(data: Dictionary) -> Dictionary:
	# v6 introduce player.injury_days_remaining. Saves v5 empiezan sanos.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("injury_days_remaining"):
		player["injury_days_remaining"] = 0
		data["player"] = player
	data["schema_version"] = 6
	return data

func _migrate_v6_to_v7(data: Dictionary) -> Dictionary:
	# v7 introduce contrato y finanzas. No hay forma de reconstruir el
	# sueldo real del club de un save viejo: se le da un valor de arranque
	# genérico y un año de contrato, para que entre pronto en el ciclo de
	# renovación normal (WorldTickEngine._rollover_season).
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("wage"):
			player["wage"] = 150
		if not player.has("contract_years_remaining"):
			player["contract_years_remaining"] = 1
		if not player.has("balance"):
			player["balance"] = 0
		data["player"] = player
	data["schema_version"] = 7
	return data

func _migrate_v7_to_v8(data: Dictionary) -> Dictionary:
	# v8 introduce patrocinios. Saves v7 empiezan sin patrocinio activo ni
	# oferta pendiente — entran al ciclo normal de SponsorEngine.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("sponsor"):
			player["sponsor"] = {}
		if not player.has("pending_sponsor_offer"):
			player["pending_sponsor_offer"] = {}
		data["player"] = player
	data["schema_version"] = 8
	return data

func _migrate_v8_to_v9(data: Dictionary) -> Dictionary:
	# v9 introduce los contadores de temporada. Saves v8 arrancan en 0 —
	# no hay forma de reconstruir su historial de goles/titularidades.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		for field in ["season_appearances", "season_goals", "season_key_passes"]:
			if not player.has(field):
				player[field] = 0
		data["player"] = player
	data["schema_version"] = 9
	return data

func _migrate_v9_to_v10(data: Dictionary) -> Dictionary:
	# v10 introduce press_feed. Saves v9 arrancan sin titulares previos.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("press_feed"):
		player["press_feed"] = []
		data["player"] = player
	data["schema_version"] = 10
	return data

func _migrate_v10_to_v11(data: Dictionary) -> Dictionary:
	# v11 introduce el agente. Saves v10 reciben uno genérico (3 estrellas,
	# neutral) generado en el momento de migrar.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("agent_name"):
			var generated: Dictionary = AgentEngine.generate_agent()
			player["agent_name"] = generated["name"]
			player["agent_stars"] = generated["stars"]
		data["player"] = player
	data["schema_version"] = 11
	return data

func _migrate_v11_to_v12(data: Dictionary) -> Dictionary:
	# v12 introduce los totales de carrera. No hay histórico que reconstruir
	# (nunca se trackearon goles/asistencias/títulos acumulados antes de
	# esto) — saves viejos simplemente arrancan en 0 y acumulan de acá en
	# adelante, como si el contador se hubiera empezado a llevar hoy.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("career_goals"):
			player["career_goals"] = 0
			player["career_assists"] = 0
			player["trophies_won"] = 0
		data["player"] = player
	data["schema_version"] = 12
	return data

func _migrate_v12_to_v13(data: Dictionary) -> Dictionary:
	# v13 introduce la oferta de mejora de sueldo a mitad de contrato — un
	# save viejo simplemente no tiene ninguna pendiente todavía.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("pending_wage_offer"):
			player["pending_wage_offer"] = {}
		data["player"] = player
	data["schema_version"] = 13
	return data

func _migrate_v13_to_v14(data: Dictionary) -> Dictionary:
	# v14 introduce el evento inesperado de temporada — un save viejo
	# simplemente no tiene ninguno pendiente todavía.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("pending_season_event"):
			player["pending_season_event"] = {}
		data["player"] = player
	data["schema_version"] = 14
	return data

func _migrate_v14_to_v15(data: Dictionary) -> Dictionary:
	# v15 introduce la Tienda — un save viejo arranca sin consumibles ni
	# efectos armados.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("consumables"):
			player["consumables"] = {}
		if not player.has("active_effects"):
			player["active_effects"] = {}
		data["player"] = player
	data["schema_version"] = 15
	return data

func _migrate_v15_to_v16(data: Dictionary) -> Dictionary:
	# v16 introduce el Staff personal (PlayerData.staff) y los campos
	# nuevos de creación de personaje (posición secundaria, pie dominante,
	# origen). Un save viejo: sin staff contratado, pie derecho por
	# defecto, sin posición secundaria ni origen (from_save_dict ya aplica
	# esos defaults; acá solo se asientan las claves y se sube la versión).
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("staff"):
			player["staff"] = {}
		if not player.has("secondary_detailed_position"):
			player["secondary_detailed_position"] = ""
		if not player.has("dominant_foot"):
			player["dominant_foot"] = "Derecho"
		if not player.has("origin"):
			player["origin"] = ""
		data["player"] = player
	data["schema_version"] = 16
	return data

func _migrate_v16_to_v17(data: Dictionary) -> Dictionary:
	# v17 introduce las inversiones — un save viejo simplemente no tiene
	# ninguna abierta.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("investments"):
		player["investments"] = []
		data["player"] = player
	data["schema_version"] = 17
	return data

func _migrate_v17_to_v18(data: Dictionary) -> Dictionary:
	# v18 introduce la vida familiar — un save viejo arranca sin pareja.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("partner"):
		player["partner"] = {}
		data["player"] = player
	data["schema_version"] = 18
	return data

func _migrate_v18_to_v19(data: Dictionary) -> Dictionary:
	# v19 introduce el avatar por capas — {} = se usa el determinista por
	# nombre, así que un save viejo no necesita nada más.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("avatar"):
		player["avatar"] = {}
		data["player"] = player
	data["schema_version"] = 19
	return data

func _migrate_v19_to_v20(data: Dictionary) -> Dictionary:
	# v20 introduce el gabinete de trofeos (PlayerData.career_titles). Un
	# save viejo arranca con la vitrina vacía; los títulos previos solo
	# quedan como el contador agregado `trophies_won` (no se puede
	# reconstruir el detalle histórico). De acá en más se registran.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("career_titles"):
		player["career_titles"] = []
		data["player"] = player
	data["schema_version"] = 20
	return data

func _migrate_v20_to_v21(data: Dictionary) -> Dictionary:
	# v21 introduce los rasgos de jugador (PlayerData.traits). Un save
	# viejo arranca sin rasgos; se desbloquean de acá en más por hitos
	# (TraitEngine.check_unlocks en el rollover de temporada).
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("traits"):
		player["traits"] = []
		data["player"] = player
	data["schema_version"] = 21
	return data

func _migrate_v21_to_v22(data: Dictionary) -> Dictionary:
	# v22 introduce los rasgos EQUIPADOS al partido (subconjunto de traits,
	# tope por slots según media). Un save viejo arranca en [] = auto: el
	# juego usa los primeros N rasgos desbloqueados hasta que el jugador
	# elija en Mi Perfil.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("equipped_traits"):
		player["equipped_traits"] = []
		data["player"] = player
	data["schema_version"] = 22
	return data

func _migrate_v22_to_v23(data: Dictionary) -> Dictionary:
	# v23 introduce PlayerData.attribute_xp: XP por atributo hacia el
	# siguiente +1. Un save viejo arranca en {} = sin progreso acumulado;
	# el jugador la va llenando entrenando el foco y jugando partidos.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("attribute_xp"):
		player["attribute_xp"] = {}
		data["player"] = player
	data["schema_version"] = 23
	return data

func _migrate_v23_to_v24(data: Dictionary) -> Dictionary:
	# v24 introduce market_salt (nivel slot). Los saves viejos arrancan en 0:
	# la semilla del mercado queda `world_seed ^ 0`, IDÉNTICA a la de antes,
	# así una carrera en curso no ve su mercado reorganizado de golpe. Solo
	# las carreras NUEVAS reciben un salt != 0 (ver CharacterCreation).
	if not data.has("market_salt"):
		data["market_salt"] = 0
	data["schema_version"] = 24
	return data

func _migrate_v24_to_v25(data: Dictionary) -> Dictionary:
	# v25 introduce player.growth_difficulty. Saves viejos arrancan en
	# "normal" — el ritmo de progresión de SIEMPRE, sin ningún cambio para
	# una carrera en curso. Solo las carreras NUEVAS eligen dificultad en
	# creación de personaje.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty() and not player.has("growth_difficulty"):
		player["growth_difficulty"] = "normal"
		data["player"] = player
	data["schema_version"] = 25
	return data

func _migrate_v25_to_v26(data: Dictionary) -> Dictionary:
	# v26 introduce la clave de nivel slot "international" (selecciones
	# nacionales — ver cabecera). {} = sin ciclo de eliminatorias en curso,
	# igual para un save viejo que para uno nuevo hasta que Fase 2 empiece
	# a llenarlo.
	if not data.has("international"):
		data["international"] = {}
	data["schema_version"] = 26
	return data

func _migrate_v26_to_v27(data: Dictionary) -> Dictionary:
	# v27 introduce player.caps/international_goals/international_assists/
	# national_team_status. Saves viejos arrancan en 0/0/0/"" — no hay
	# forma de reconstruir convocatorias antes de que existiera el contador.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("caps"):
			player["caps"] = 0
		if not player.has("international_goals"):
			player["international_goals"] = 0
		if not player.has("international_assists"):
			player["international_assists"] = 0
		if not player.has("national_team_status"):
			player["national_team_status"] = ""
		data["player"] = player
	data["schema_version"] = 27
	return data

func _migrate_v27_to_v28(data: Dictionary) -> Dictionary:
	# v28 introduce player.season_matches_played (partidos de club de
	# verdad, titular o suplente). Backfill: arranca del valor actual de
	# season_appearances — no hay forma de reconstruir partidos ya jugados
	# de suplente esta temporada antes de que existiera el contador nuevo.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("season_matches_played"):
			player["season_matches_played"] = int(player.get("season_appearances", 0))
		data["player"] = player
	data["schema_version"] = 28
	return data

func _migrate_v28_to_v29(data: Dictionary) -> Dictionary:
	# v29 introduce la clave de nivel slot "league_tiers" (ascensos y
	# descensos -- ver cabecera y PromotionRelegationEngine.gd). {} = ningún
	# club se movió todavía de la categoría con la que nació su mundo --
	# igual para un save viejo que para uno nuevo hasta que termine la
	# primera temporada con el sistema activo.
	if not data.has("league_tiers"):
		data["league_tiers"] = {}
	data["schema_version"] = 29
	return data

func _migrate_v29_to_v30(data: Dictionary) -> Dictionary:
	# v30 introduce "coefficient_history" (ver cabecera) -- {} para
	# saves viejos, igual que league_tiers en su momento.
	if not data.has("coefficient_history"):
		data["coefficient_history"] = {}
	data["schema_version"] = 30
	return data

func _migrate_v30_to_v31(data: Dictionary) -> Dictionary:
	# v31: guardarropa de la Tienda + avatar Kenney -> pixel art (ver
	# cabecera). Un avatar {} o solo {"skin": N} (import) no se toca: ya
	# lo resuelve Avatar.config_for_player igual que antes.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("cosmetics_owned"):
			player["cosmetics_owned"] = []
		if not player.has("cosmetics_equipped"):
			player["cosmetics_equipped"] = {}
		var av = player.get("avatar", {})
		if av is Dictionary and (av.has("base") or av.has("hair")) and int(av.get("v", 1)) < 2:
			player["avatar"] = Avatar.from_legacy(av)
		data["player"] = player
	data["schema_version"] = 31
	return data

func _migrate_v31_to_v32(data: Dictionary) -> Dictionary:
	# v32: patrocinio de guayos — arranca vacío (nadie tenía marca).
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("boot_deal"):
			player["boot_deal"] = {}
		if not player.has("pending_boot_offer"):
			player["pending_boot_offer"] = {}
		data["player"] = player
	data["schema_version"] = 32
	return data

func _migrate_v32_to_v33(data: Dictionary) -> Dictionary:
	# v33: nivel de carrera desde la media actual (una carrera avanzada no
	# arranca en nivel 1) y esos niveles ya como puntos de habilidad.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("level"):
			var lv: int = ProgressionEngine.initial_level(int(player.get("overall", 45)))
			player["level"] = lv
			player["career_xp"] = 0
			player["skill_points"] = ProgressionEngine.points_up_to(lv)
			player["skills"] = []
			player["recent_ratings"] = []
		if not player.has("mood"):
			player["mood"] = 60
			player["dating"] = {}
			player["affinities"] = {}
		data["player"] = player
	data["schema_version"] = 33
	return data

func _migrate_v34_to_v35(data: Dictionary) -> Dictionary:
	# v35: market_v2_from_day (ver cabecera). Una carrera en curso conserva
	# su temporada actual tal cual; lo nuevo arranca en la próxima.
	if not data.has("market_v2_from_day"):
		var season = data.get("season", {})
		var ss: int = int((season as Dictionary).get("season_start_epoch_day", 0)) if season is Dictionary else 0
		data["market_v2_from_day"] = ss + 1 if ss > 0 else 0
	data["schema_version"] = 35
	return data

func _migrate_v33_to_v34(data: Dictionary) -> Dictionary:
	# v34: memoria de carrera. No hay forma de reconstruir los clubes
	# anteriores de una carrera ya empezada (nunca se guardaron), así que
	# arranca vacío; sí se rescata el historial del rival de esta temporada.
	var player: Dictionary = data.get("player", {})
	if player is Dictionary and not player.is_empty():
		if not player.has("former_clubs"):
			player["former_clubs"] = []
		if not player.has("nemesis_log"):
			var season = data.get("season", {})
			var old_log = (season as Dictionary).get("nemesis_log", []) if season is Dictionary else []
			player["nemesis_log"] = (old_log if old_log is Array else []).duplicate(true)
		# RPG ampliado: logros sin cobrar (los ya cumplidos se cobran solos la
		# primera vez que se abre el Hub) y maestrías en cero.
		if not player.has("achievements"):
			player["achievements"] = []
		if not player.has("mastery"):
			player["mastery"] = {}
		data["player"] = player
	data["schema_version"] = 34
	return data

## --- Jugador del slot activo ---
## Forma en disco del slot: { "schema_version": N, "player": {<PlayerData>} }.
## Estos helpers son la única puerta para leer/escribir ese "player";
## ninguna pantalla debe armar el dict a mano.

func save_player(player: PlayerData) -> void:
	if active_slot_id.is_empty():
		push_error("SaveManager: no hay slot activo al guardar el jugador")
		return
	var data := load_slot(active_slot_id) # conserva otras claves ya guardadas
	data["player"] = player.to_save_dict()
	save_slot(active_slot_id, data)

func load_player() -> PlayerData:
	if active_slot_id.is_empty():
		return null
	var data := load_slot(active_slot_id)
	if not data.has("player"):
		return null
	var p := PlayerData.from_save_dict(data["player"])
	# Auto-corrección: partidas guardadas ANTES del fix de "media
	# desincronizada" (Parte 93, PlayerDevelopment.compute_overall) pueden
	# traer un `overall` viejo, inflado por el banco 4:1 anterior. Se
	# resincroniza en CADA carga (barato, idempotente) — así la carrera de
	# Wilber queda corregida ya en la próxima vez que abra el juego, sin
	# esperar al próximo entrenamiento/partido para que se note.
	PlayerDevelopment.sync_overall(p)
	# market_value es OTRO campo cacheado (bug real reportado por Wilber
	# apenas se corrigió overall: "tengo media 61 y hay equipos ofreciendo
	# 30-60 millones, eso no es normal") — antes solo se recalculaba al
	# cierre de temporada (WorldTickEngine.gd), así que quedaba fiel a la
	# media INFLADA de antes durante toda la temporada en curso, y
	# TransferOfferEngine.generate_offer() usa este campo DIRECTO para el
	# monto de la oferta. Mismo criterio que overall: nunca un valor
	# cacheado que se pueda desincronizar, siempre la fórmula única
	# (TransferMarketEngine.market_value) recalculada en cada carga.
	p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
	# El sueldo (a diferencia de overall/market_value) es un valor
	# NEGOCIADO, no una fórmula pura — pero ContractEngine.renewal_wage()
	# no tenía NINGÚN techo, solo subía/bajaba en % relativo a sí mismo
	# según confianza del DT/posición en la tabla, sin relación con el
	# nivel real del jugador. Una racha larga de confianza alta (como la
	# que dejó la media inflada de antes) podía inflar el sueldo muy por
	# encima de lo que cualquier club pagaría por ese nivel de verdad
	# (Wilber, Parte 93c: "revisa también los sueldos"). Ahora
	# renewal_wage() ya respeta un techo realista para el overall ACTUAL
	# (ContractEngine.wage_ceiling) en toda renovación/oferta NUEVA; esto
	# solo repara un sueldo que YA quedó inflado de antes del fix.
	p.wage = mini(p.wage, ContractEngine.wage_ceiling(p.overall))
	return p

## world_seed se fija UNA vez al arrancar la carrera y no cambia nunca
## (define el mundo entero, ver WorldFactory).
func save_world_seed(seed_value: int) -> void:
	if active_slot_id.is_empty():
		push_error("SaveManager: no hay slot activo al guardar world_seed")
		return
	var data := load_slot(active_slot_id)
	data["world_seed"] = seed_value
	save_slot(active_slot_id, data)

func load_world_seed() -> int:
	if active_slot_id.is_empty():
		return 0
	return int(load_slot(active_slot_id).get("world_seed", 0))

## market_salt: sal por CARRERA (nivel slot) que varía la semilla del
## mercado de fichajes IA-a-IA entre partidas nuevas del MISMO mundo
## importado. Se fija UNA vez al crear la carrera. 0 = save viejo (mercado
## legacy, igual que antes de v24).
func save_market_salt(salt_value: int) -> void:
	if active_slot_id.is_empty():
		push_error("SaveManager: no hay slot activo al guardar market_salt")
		return
	var data := load_slot(active_slot_id)
	data["market_salt"] = salt_value
	save_slot(active_slot_id, data)

## market_v2_from_day (v35): desde qué temporada hay bombazos. 0 = siempre.
func load_market_v2_from() -> int:
	if active_slot_id.is_empty():
		return 0
	return int(load_slot(active_slot_id).get("market_v2_from_day", 0))

func load_market_salt() -> int:
	if active_slot_id.is_empty():
		return 0
	return int(load_slot(active_slot_id).get("market_salt", 0))

## season: calendario de la temporada actual (ver SeasonCalendar).
func save_season(season_dict: Dictionary) -> void:
	if active_slot_id.is_empty():
		push_error("SaveManager: no hay slot activo al guardar season")
		return
	var data := load_slot(active_slot_id)
	data["season"] = season_dict
	save_slot(active_slot_id, data)

func load_season() -> Dictionary:
	if active_slot_id.is_empty():
		return {}
	var raw = load_slot(active_slot_id).get("season", {})
	return raw if raw is Dictionary else {}

## international: ciclo de eliminatorias/Mundial/copas de selecciones en
## curso (ver QualifyingEngine.gd y la nota de v26 arriba) — a diferencia
## de `season`, NUNCA se reconstruye por el paso del tiempo solo, dura
## varios años de calendario.
func save_international(international_dict: Dictionary) -> void:
	if active_slot_id.is_empty():
		push_error("SaveManager: no hay slot activo al guardar international")
		return
	var data := load_slot(active_slot_id)
	data["international"] = international_dict
	save_slot(active_slot_id, data)

func load_international() -> Dictionary:
	if active_slot_id.is_empty():
		return {}
	var raw = load_slot(active_slot_id).get("international", {})
	return raw if raw is Dictionary else {}

## league_tiers: overrides de ascenso/descenso (club_id -> league_id
## ACTUAL, ver nota de v29 arriba) -- se reaplica sobre `world` en cada
## carga (WorldFactory.apply_league_overrides), nunca se reconstruye solo.
func save_league_tiers(overrides: Dictionary) -> void:
	if active_slot_id.is_empty():
		push_error("SaveManager: no hay slot activo al guardar league_tiers")
		return
	var data := load_slot(active_slot_id)
	data["league_tiers"] = overrides
	save_slot(active_slot_id, data)

func load_league_tiers() -> Dictionary:
	if active_slot_id.is_empty():
		return {}
	var raw = load_slot(active_slot_id).get("league_tiers", {})
	return raw if raw is Dictionary else {}

## coefficient_history: confederation -> (String league_id -> puntaje crudo
## de la temporada que acaba de terminar) -- ver nota de v30 arriba.
func save_coefficient_history(history: Dictionary) -> void:
	if active_slot_id.is_empty():
		push_error("SaveManager: no hay slot activo al guardar coefficient_history")
		return
	var data := load_slot(active_slot_id)
	data["coefficient_history"] = history
	save_slot(active_slot_id, data)

func load_coefficient_history() -> Dictionary:
	if active_slot_id.is_empty():
		return {}
	var raw = load_slot(active_slot_id).get("coefficient_history", {})
	return raw if raw is Dictionary else {}

## --- Autoguardado a prueba de cierres (P0-12) ---
## El jugador se persiste en cada acción (partido, entrenamiento, ficha…),
## pero el día/fixtures viven en WorldTickEngine.season: advance_day() lo
## guarda al final, y esto cubre el hueco de un cierre forzado en medio de
## un tick o de un cambio de pantalla. Es barato e idempotente.
const AUTOSAVE_MIN_INTERVAL_MS := 1500
var _last_autosave_ms: int = 0
var _autosave_running: bool = false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			autosave("cierre")

## `reason` = "scene" se llama en cada cambio de pantalla (ver Nav.gd) y se
## limita con throttle; "cierre" (pausa/atrás/salir) siempre escribe.
func autosave(reason: String = "") -> void:
	if active_slot_id.is_empty() or _autosave_running:
		return
	var now := Time.get_ticks_msec()
	if reason == "scene" and now - _last_autosave_ms < AUTOSAVE_MIN_INTERVAL_MS:
		return
	_autosave_running = true
	_last_autosave_ms = now
	var wte := get_node_or_null("/root/WorldTickEngine")
	if wte != null:
		var season_data = wte.get("season")
		if season_data is Dictionary and not (season_data as Dictionary).is_empty():
			# save_season() ya pasa por load_slot(): si el principal estaba
			# corrupto, lo reconstruye desde .bak/.tmp antes de escribir.
			save_season(season_data as Dictionary)
	if reason != "scene" and FileAccess.file_exists(get_slot_path(active_slot_id)) \
			and load_slot(active_slot_id).is_empty():
		push_error("SaveManager: el autoguardado no dejó un slot legible: " + active_slot_id)
	_autosave_running = false

func list_slots() -> Array[String]:
	var slots: Array[String] = []
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return slots
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			slots.append(file_name.trim_suffix(".json"))
		file_name = dir.get_next()
	dir.list_dir_end()
	return slots

## El slot más reciente entre los que pasen — NUNCA `slots[0]`: el orden
## que devuelve list_dir_begin() es el que le dé la gana al sistema de
## archivos, no orden de fecha.
func _newest_by_mtime(slot_ids: Array) -> String:
	if slot_ids.is_empty():
		return ""
	var best_slot: String = slot_ids[0]
	var best_time: int = FileAccess.get_modified_time(get_slot_path(best_slot))
	for slot_id in slot_ids.slice(1):
		var t: int = FileAccess.get_modified_time(get_slot_path(slot_id))
		if t > best_time:
			best_time = t
			best_slot = slot_id
	return best_slot

## Resumen de un slot para la pantalla de selección: {} si está vacío O SI
## QUEDÓ A MEDIAS (personaje creado pero sin club — se salió antes de
## terminar Offers). Un slot a medias se trata igual que uno vacío: no
## hay nada coherente que "continuar" ahí (la nota de la prueba y las
## ofertas eran efímeras, nunca se persistieron), así que se ofrece de
## nuevo para una carrera nueva en su lugar — esto es justo lo que
## reportó Wilber como "aparece sin partidos y sin club".
func slot_summary(slot_id: String) -> Dictionary:
	var data := load_slot(slot_id)
	if data.is_empty():
		return {}
	var player_dict: Dictionary = data.get("player", {})
	var season_dict: Dictionary = data.get("season", {})
	if player_dict.is_empty() or String(player_dict.get("club_id", "")).is_empty() or season_dict.is_empty():
		return {}
	return {
		"player_name": String(player_dict.get("player_name", "?")),
		"club_id": String(player_dict.get("club_id", "")),
		"world_seed": int(data.get("world_seed", 0)),
		"current_epoch_day": int(season_dict.get("current_epoch_day", 0)),
		"start_year": int(season_dict.get("start_year", CalendarUtils.season_start_year(int(season_dict.get("current_epoch_day", 0))))),
	}

func delete_slot(slot_id: String) -> void:
	# También los respaldos: si quedara el .bak, load_slot() "reviviría" un
	# slot borrado al recuperar desde él.
	for path in [get_slot_path(slot_id), _slot_backup_path(slot_id), _slot_temp_path(slot_id)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

## Archivo de carreras RETIRADAS ("Colección") — fuera de SAVE_DIR a
## propósito: list_slots()/migrate_legacy_slots_if_needed() tratan
## cualquier .json de esa carpeta como un slot candidato, y esto no es un
## slot (es un Array, no un Dictionary con "player"/"season"). Sobrevive
## aunque slot_1/2/3 se reutilicen para una carrera nueva — sin esto, el
## palmarés de una carrera terminada se perdía en cuanto pisabas el slot.
const RETIRED_CAREERS_PATH := "user://retired_careers.json"

func load_retired_careers() -> Array:
	if not FileAccess.file_exists(RETIRED_CAREERS_PATH):
		return []
	var file := FileAccess.open(RETIRED_CAREERS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	return data if data is Array else []

## Guarda (o actualiza, si ya existía una para ESTA carrera) el palmarés
## final de la carrera que se retira ACÁ — active_slot_id, no un
## parámetro. "Upsert" por slot_id + world_seed (NUNCA solo slot_id): si
## solo fuera por slot_id, una carrera NUEVA que reutiliza el mismo slot y
## también se retira más tarde BORRARÍA el palmarés de la anterior en vez
## de sumar una entrada — world_seed identifica la carrera de verdad,
## slot_id solo dice dónde vivía. Si el jugador vuelve a "Continuar" la
## MISMA carrera (mismo slot_id + mismo world_seed) y se retira de nuevo,
## sí actualiza la misma entrada en vez de duplicarla.
func archive_retired_career(player: PlayerData) -> void:
	if active_slot_id.is_empty() or player == null:
		return
	var careers: Array = load_retired_careers()
	var seed_val: int = load_world_seed()
	var entry: Dictionary = {
		"slot_id": active_slot_id,
		"world_seed": seed_val,
		"player_name": player.player_name,
		"country": player.country,
		"club_id": player.club_id,
		"career_titles": player.career_titles,
		"career_goals": player.career_goals,
		"career_assists": player.career_assists,
		"trophies_won": player.trophies_won,
		"age_at_retirement": player.age,
		# Parte 91 (récords cross-save en "Colección"): overall pico, y
		# stats de selección — antes no se archivaban, así que una carrera
		# retirada perdía esta info para siempre en cuanto se pisaba el
		# slot con una nueva.
		"overall": player.overall,
		"caps": player.caps,
		"international_goals": player.international_goals,
		"international_assists": player.international_assists,
	}
	var replaced: bool = false
	for i in range(careers.size()):
		var c: Dictionary = careers[i]
		if String(c.get("slot_id", "")) == active_slot_id and int(c.get("world_seed", -1)) == seed_val:
			careers[i] = entry
			replaced = true
			break
	if not replaced:
		careers.append(entry)
	var file := FileAccess.open(RETIRED_CAREERS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(careers, "\t"))
	file.close()

## Migración única del esquema viejo (slots sueltos "slot_<timestamp>",
## sin límite) al de 3 slots fijos: si NINGUNO de slot_1/2/3 tiene ya una
## carrera válida, adopta el slot viejo más reciente (por fecha de
## modificación real, no por nombre) como slot_1. Copia, no mueve — el
## archivo viejo queda intacto por si hace falta mirarlo.
func migrate_legacy_slots_if_needed() -> void:
	for slot_id in SLOT_IDS:
		if not slot_summary(slot_id).is_empty():
			return
	var legacy: Array = []
	var legacy_valid: Array = []
	for slot_id in list_slots():
		if slot_id in SLOT_IDS:
			continue
		legacy.append(slot_id)
		if not slot_summary(slot_id).is_empty():
			legacy_valid.append(slot_id)
	if legacy.is_empty():
		return
	# Preferir el más reciente que de verdad tenga club + temporada — un
	# intento a medias más nuevo no debe tapar una carrera real más vieja.
	var newest := _newest_by_mtime(legacy_valid if not legacy_valid.is_empty() else legacy)
	var data := load_slot(newest)
	if not data.is_empty():
		save_slot("slot_1", data)
