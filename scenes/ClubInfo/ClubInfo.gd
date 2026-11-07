extends Control

## Pestaña "Club" de la barra inferior: ficha del club del usuario —
## escudo (color), liga, plantel, entrenador, ambiciones de temporada.
## Solo lectura, generado en vivo desde WorldFactory (mismo principio de
## "mundo vivo" que el resto de pantallas de solo-consulta).
##
## Restyle sobre el prototipo de Football Legacy (capturas de Android
## Studio): insignia grande, chip de prestigio, tarjetas por sección.
## Secciones: plantel, VITRINA histórica (ClubHonorsEngine — derivada del
## prestigio + world_seed, coherente con el tamaño del club, no persiste),
## cuerpo técnico, ambiciones de liga y copa, finanzas
## (TransferMarketEngine) y rivalidades (RivalryEngine).

@onready var vbox: VBoxContainer = $Root/Scroll/Margin/VBox

const Match3DBridge = preload("res://engine/match/m3d/Match3DBridge.gd")

func _ready() -> void:
	WorldTickEngine.load_runtime()
	# Sin esto, cualquier hijo un pelín más ancho que la pantalla saca una
	# barra de scroll horizontal (bug que reportó Wilber: "scroll bar abajo").
	var scroll := $Root/Scroll as ScrollContainer
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Bug visual real encontrado en el barrido: esta pantalla nunca llamaba
	# UiScroll.make_touch() (a diferencia de otras 6 pantallas que sí) — sin
	# el deadzone alto que arma esa función, arrastrar el dedo sobre
	# cualquiera de las tarjetas (Vitrina/Cuerpo técnico/Presidencia/...)
	# no scrolleaba, así que Finanzas y Rivalidad quedaban inalcanzables
	# debajo del pliegue.
	UiScroll.make_touch(scroll)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var player: PlayerData = SaveManager.load_player()
	if player == null or player.club_id == "":
		vbox.add_child(_title_label("Sin club"))
		return

	var world: Dictionary = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	var club := WorldFactory.find_club(world, player.club_id)
	if club == null:
		vbox.add_child(_title_label("Sin club"))
		return

	var league: LeagueData = null
	for l in world.get("leagues", []):
		if l.league_id == club.league_id:
			league = l
			break

	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		var bd := UiKit.club_backdrop(Color(club.primary_color_hex) if club.primary_color_hex != "" else Styles.GREEN)
		add_child(bd)
		move_child(bd, 0)
	_build_banner(club, league)

	var meta: Dictionary = world.get("club_meta_by_id", {})
	var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	# El plantel se arma UNA sola vez acá y se reusa en la tarjeta de plantel
	# Y en rivalidades — antes _build_rivalry_card() lo reconstruía entero
	# de nuevo para el mismo club (pulido de rendimiento, hallazgo de
	# auditoría general: un make_squad_with_transfers() de más en cada
	# apertura de esta pantalla).
	var squad: Array[PlayerData] = []
	if meta.has(club.club_id):
		squad = WorldFactory.make_squad_with_transfers(world, club.club_id, WorldTickEngine.world_seed, season_start)
		_build_squad_card(squad, Color(club.primary_color_hex))

	_build_cabinet_card(club)

	var coach := WorldFactory.find_coach(world, club.club_id)
	if coach != null:
		_build_coach_card(coach, player)

	_build_president_card(club)
	_build_ambitions_card(club)
	_build_finance_card(club, league, meta)
	_build_rivalry_card(club, world, squad, player)
	UiScroll.pad_bottom(vbox, 76)  # deja aire bajo la última tarjeta (hay BottomNav fijo)
	Styles.land_columns_later(vbox, 1)  # horizontal: 2 columnas

func _title_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	return lbl

## Cabecera "héroe" (9-oct, rediseño): escudo grande, nombre, liga y chips
## sobre una franja con el color del club; titular y visitante a la derecha.
func _build_banner(club: ClubData, league: LeagueData) -> void:
	var accent := Color(club.primary_color_hex) if club.primary_color_hex != "" else Styles.BLUE
	if accent.get_luminance() > 0.8:
		accent = Color(club.secondary_color_hex) if club.secondary_color_hex != "" else Styles.BLUE
	var crest := Styles.club_crest(club.club_id, 84)
	var subtitle: String = ""
	var chips: Array = []
	if league != null:
		subtitle = "%s · %s" % [league.league_name, league.country]
		chips.append([ObjectivesEngine.reputation_tier_label(league.reputation), Styles.GOLD])
		chips.append(["División %d" % league.tier, Color(0.6, 0.75, 1.0)])
	var kits := HBoxContainer.new()
	kits.add_theme_constant_override("separation", 4)
	var yr: int = WorldTickEngine.get_season_start_year()
	for away in [false, true]:
		var kcol := VBoxContainer.new()
		kcol.add_theme_constant_override("separation", 0)
		# 8-nov: con el 3D, tú modelando cada equipación (como en la previa)
		var me: PlayerData = SaveManager.load_player()
		var k: Control
		if Preferences.match_3d and me != null:
			k = Match3DBridge.portrait(me, club, 118, true, Color(0, 0, 0, 0), away)
			k.custom_minimum_size = Vector2(92, 118)
		else:
			k = Kit.build_for_club_kit(club, yr, away, 52)
		k.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		kcol.add_child(k)
		var kl := Label.new()
		kl.text = "Visitante" if away else "Titular"
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.add_theme_font_size_override("font_size", 10)
		kl.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
		kcol.add_child(kl)
		kits.add_child(kcol)
	vbox.add_child(UiKit.hero(accent, crest, club.club_name, subtitle, chips, kits))

func _build_squad_card(squad: Array[PlayerData], club_color: Color) -> void:
	var total: int = 0
	var best: int = 0
	for p in squad:
		total += p.overall
		best = maxi(best, p.overall)
	var avg: float = float(total) / maxi(squad.size(), 1)
	vbox.add_child(UiKit.stat_strip([
		[str(squad.size()), "Jugadores", Color.WHITE],
		["%.0f" % avg, "Media", PlayerCard.tier_color(int(avg))],
		[str(best), "Mejor jugador", PlayerCard.tier_color(best)],
	]))

func _stat_column(value: String, label: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 22)
	col.add_child(value_lbl)
	var caption_lbl := Label.new()
	caption_lbl.text = label
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	caption_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(caption_lbl)
	return col

## Vitrina histórica del club (ClubHonorsEngine — derivada del prestigio +
## world_seed, nada se persiste). Pedido de Wilber.
func _build_cabinet_card(club: ClubData) -> void:
	var entries: Array = WorldTickEngine.club_trophy_cabinet(club.club_id)
	vbox.add_child(Styles.section_label("VITRINA"))
	var panel := _card(Styles.GOLD)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	content.add_child(TrophyCabinet.build(entries, club.club_name))
	vbox.add_child(panel)

func _build_coach_card(coach: CoachData, player: PlayerData) -> void:
	vbox.add_child(Styles.section_label("CUERPO TÉCNICO"))
	var panel := _card(Styles.BLUE)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	content.add_child(_person_head(coach.coach_name, "coach", coach.style, Styles.BLUE))
	content.add_child(_row_label("Tu confianza con él", "%d/100" % player.coach_trust))
	vbox.add_child(panel)

func _build_president_card(club: ClubData) -> void:
	var seed_int: int = hash("president:" + club.club_id) ^ WorldTickEngine.world_seed
	var pres_name: String = WorldFactory.synthetic_person_name(seed_int)
	vbox.add_child(Styles.section_label("PRESIDENCIA"))
	var panel := _card(Styles.GOLD)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	content.add_child(_person_head(pres_name, "president", "Presidente del club", Styles.GOLD))
	vbox.add_child(panel)

## Fila-cabecera con la cara del NPC + nombre + subtítulo.
func _person_head(person_name: String, role: String, subtitle: String, ring: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var face := Avatar.for_npc(person_name, role, WorldTickEngine.world_seed, 44)
	row.add_child(Styles.portrait_frame(face, 44, ring))
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = person_name
	name_lbl.add_theme_font_override("font", Styles.font_semibold())
	col.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sub_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(sub_lbl)
	row.add_child(col)
	return row

func _build_ambitions_card(club: ClubData) -> void:
	vbox.add_child(Styles.section_label("AMBICIONES DE TEMPORADA"))
	var panel := _card(Styles.GOLD)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	content.add_child(_row_label("Liga", ObjectivesEngine.club_league_objective(club)))
	content.add_child(_row_label("Copa", ObjectivesEngine.club_cup_objective(club)))
	vbox.add_child(panel)

## Presupuesto de fichajes REAL (TransferMarketEngine.budget_for_club) —
## antes esta sección no existía a propósito ("nada de inventar cifras",
## ver cabecera del archivo); ahora hay una fórmula determinista de
## verdad detrás, así que ya no aplica esa restricción.
func _build_finance_card(club: ClubData, league: LeagueData, meta: Dictionary) -> void:
	if league == null or not meta.has(club.club_id):
		return
	vbox.add_child(Styles.section_label("FINANZAS"))
	var panel := _card(Styles.GREEN)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	var base_overall: int = int(meta[club.club_id].get("base_overall", 55))
	var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var budget: int = TransferMarketEngine.budget_for_club(base_overall, league.reputation, WorldTickEngine.world_seed, club.club_id, season_start)
	content.add_child(_row_label("Presupuesto de fichajes", CurrencyFormat.format(budget)))
	vbox.add_child(panel)

## Rival de club (clásico/derbi) + con quién compite el usuario por su
## puesto en el plantel — dos de las 3 rivalidades pedidas (la tercera,
## pujas cruzadas por un fichaje, vive en la prensa de TransferMarket).
func _build_rivalry_card(club: ClubData, world: Dictionary, squad: Array[PlayerData], player: PlayerData) -> void:
	var rival_id: String = RivalryEngine.club_rival_for(world, club.club_id, WorldTickEngine.world_seed)
	var rival_club: ClubData = WorldFactory.find_club(world, rival_id) if rival_id != "" else null

	var position_rival: Dictionary = {}
	if not squad.is_empty():
		position_rival = RivalryEngine.position_rival_for(player, squad)

	if rival_club == null and position_rival.is_empty():
		return
	vbox.add_child(Styles.section_label("RIVALIDADES"))
	var panel := _card(Styles.RED)
	var content: VBoxContainer = panel.get_child(0).get_child(0)
	if rival_club != null:
		content.add_child(_row_label("Clásico", rival_club.club_name))
	if not position_rival.is_empty():
		content.add_child(_row_label(
			"%s (%d/100)" % [String(position_rival["reason"]), int(position_rival["intensity"])],
			"%s — OVR %d" % [String(position_rival["name"]), int(position_rival["overall"])],
		))
	vbox.add_child(panel)


## Tarjeta base: PanelContainer > Margin > VBox de contenido. Los llamadores
## agregan filas/columnas dentro del VBox devuelto vía panel.get_child(0).get_child(0).
## `accent`: franja de color del borde (ver Styles.card_accent) — cada
## sección tiene la suya (plantel=color del club, técnico=azul, ambiciones=
## dorado, finanzas=verde, rivalidades=rojo), {} = sin franja (Color.TRANSPARENT).
func _card(accent: Color = Color.TRANSPARENT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card() if accent.a <= 0 else Styles.card_accent(accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	panel.add_child(margin)
	return panel

func _row_label(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)
	var value_lbl := Label.new()
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)
	return row
