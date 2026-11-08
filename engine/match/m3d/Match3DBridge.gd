extends RefCounted
## Puente JUEGO <-> partido 3D (MiniSoccer3D, copiado en res://match3d/ con
## tools/sync_to_footballcareer.sh de aquel proyecto). 31-oct, Wilber:
## "integrarlo con football career (generacion de jugadores, creacion de mi
## jugador, edicion de mi jugador y los partidos)".
##
## Entrada: lo que MatchLauncher.prepare() dejó en MatchState (los dos
## MatchTeam reales, el usuario, el fixture y el MatchEngine YA construido
## pero sin correr).
##   - tu jugador 3D = tu PlayerData (stats, puesto, pierna) con la cara de tu
##     editor de avatar (piel, pelo, peinado, barba, guayos).
##   - los otros 21 = los titulares reales, cada uno con la cara de su ficha.
##   - camisetas = las de la previa (misma regla de choque que el clásico).
##   - goles del resto del partido = la xG que YA calculó MatchEngine
##     (DecisionResolver.m3d_goal_rates): ninguna fórmula nueva de fuerza.
## Salida: to_match_result() devuelve el MISMO diccionario que
## MatchEngine.run_match(), así MatchSummary funciona sin enterarse.
##
## Sin cambio de esquema: nada de esto se guarda.

## Kit.PATTERNS → diseño del shader 3D (0 lisa, 1 rayas, 2 aros, 3 mitades, 4 banda,
## 5 pecho en V, 6 raya fina, 7 hombros/mangas, 10 cuadros, 11 franja en el pecho,
## 12 raya central, 13 paneles laterales, 14 V ancha).
const PATTERN_3D := {
	"solid": 0, "stripes": 1, "triple_stripe": 12, "stripe_offcenter": 1, "hoops": 2, "hpinstripe": 2,
	"chest_band": 11, "halves": 3, "half_top": 19, "half_bottom": 19, "sash": 4, "diag_wide": 15,
	"diag_shoulder": 4, "chevron": 14, "zigzag": 28, "pinstripe": 17, "yoke": 25, "raglan_shoulder": 7,
	"shoulder_yoke2": 25, "placket": 23, "gradient": 16, "vgradient": 26, "checker": 10, "argyle": 18,
	"cross": 27,
}
## Plantillas de Wilber (KitTemplates.LIST, índice w) → su diseño 3D más parecido
## (Croacia = cuadros, Boca = franja, Celtic = aros...; los estampados abstractos, lisa).
const W_PATTERN_3D := [4, 14, 3, 1, 1, 2, 0, 11, 7, 0, 12, 6, 13, 6, 10, 0,
		1, 2, 4, 14, 3, 6, 10, 0, 0, 14, 7, 4, 0, 13, 0, 0]
const FOOT := {"Derecho": 0, "Izquierdo": 1, "Ambidiestro": 2}
const SetPieceTakers = preload("res://engine/match/m3d/SetPieceTakers.gd")
const POS_INDEX := {"GK": 0, "DF": 1, "MF": 2, "ST": 3}

## ¿Este partido se juega en 3D? Convocado (titular o en el banco), de club o
## de selección (país en vez de club: bandera de escudo, sin patrocinio); con
## sanción va al partido de siempre.
static func supported() -> bool:
	if not Preferences.match_3d:
		return false
	var p: PlayerData = MatchState.user_player
	if p == null or MatchState.engine == null or MatchState.user_suspended:
		return false
	var ht: MatchTeam = MatchState.home_team
	var at: MatchTeam = MatchState.away_team
	return ht != null and at != null and (ht.starting_xi.has(p) or at.starting_xi.has(p) or ht.bench.has(p) or at.bench.has(p))

static func _world() -> Dictionary:
	return WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())

## Cara de un jugador real para el modelo 3D (la de su ficha / tu editor).
static func look_for(pl: PlayerData, wseed: int) -> Dictionary:
	var cfg: Dictionary = Avatar.config_for_player(pl, wseed)
	return {
		"skin": String(cfg.get("tint_base", "#eec1a3")),
		"hair": String(cfg.get("tint_hair", "#2b2320")),
		"hair_style": String(cfg.get("hair", "rapado")),
		"face": String(cfg.get("face", "")),
	}

## Retrato 3D de un jugador con el modelo del partido y la camiseta de su club, para las
## pantallas de la carrera (carta, perfil, redes...). Sustituye al avatar pixel art.
## Con el 3D apagado en Ajustes vuelve al pixel art (móviles flojos).
## full_body: cuerpo entero con fondo transparente (cartas); si no, busto con fondo `bg`.
## away: con la equipación de visitante (mismos colores que Kit.build_for_club_kit).
## stamp: false para clubes "de mentira" (selecciones), que no tienen escudo propio.
static func portrait(p: PlayerData, club: ClubData, px: int, full_body := false, bg := Color(0.09, 0.13, 0.11),
		away := false, stamp := true) -> Control:
	var wseed: int = SaveManager.load_world_seed()
	if not Preferences.match_3d:
		var cfg: Dictionary = Avatar.config_for_player(p, wseed)
		return Avatar.build_full(cfg, px) if full_body else Avatar.build(cfg, px)
	if club == null and p.club_id != "":
		club = WorldFactory.find_club(_world(), p.club_id)
	var shirt := Color(club.primary_color_hex) if club != null and club.primary_color_hex != "" else Color("#2a6ad9")
	var sec := Color(club.secondary_color_hex) if club != null and club.secondary_color_hex != "" else Color.WHITE
	if away:
		var cc: Array = Kit._club_colors(club)
		var body: Color = cc[1]
		if body.is_equal_approx(cc[0]) or absf(body.get_luminance() - Color(cc[0]).get_luminance()) < 0.12:
			body = Color.WHITE if Color(cc[0]).get_luminance() < 0.5 else Color("#1a1a1a")
		sec = cc[0]
		shirt = body
	var face := PlayerPortrait.new(px, Color(0, 0, 0, 0) if full_body else bg, full_body)
	face.set_profile(profile_for(p, wseed, shirt, sec, shirt),
		{"shirt_pattern": _pattern(club, WorldTickEngine.get_season_start_year(), away), "shirt_color2": sec})
	# Escudo, patrocinio, dorsal y apellido en la camiseta (los mismos del partido)
	if club != null and stamp:
		var words: PackedStringArray = p.player_name.split(" ", false)
		Avatar3D.stamp_kit(face, club.club_id, ShirtNumberEngine.number_for(p, wseed),
			words[words.size() - 1] if words.size() > 0 else "", shirt, sec)
	return face

static func _stats(pl: PlayerData) -> Dictionary:
	return {"speed": pl.speed, "stamina": pl.stamina, "strength": pl.strength, "control": pl.control,
		"passing": pl.passing, "shooting": pl.shooting, "dribbling": pl.dribbling,
		"decision_making": pl.decision_making, "composure": pl.composure}

## Tu jugador para el partido 3D: datos de tu carrera + la cara de tu avatar.
static func profile_for(p: PlayerData, wseed: int, shirt: Color, shorts: Color, socks: Color) -> PlayerProfile:
	var prof := PlayerProfile.new()
	prof.player_name = p.player_name
	# Mismo dorsal que el perfil y la camiseta del RPG (PlayerProfile, Avatar)
	prof.number = ShirtNumberEngine.number_for(p, wseed)
	prof.position = int(POS_INDEX.get(p.position, 2))
	prof.foot = int(FOOT.get(p.dominant_foot, 0))
	var lk: Dictionary = look_for(p, wseed)
	prof.skin = Color(String(lk.skin))
	prof.hair = Color(String(lk.hair))
	prof.hair_style = String(lk.hair_style) if ItemCatalog.hair_available(String(lk.hair_style)) else "rapado"
	prof.face = String(lk.face)
	# Guayos de la tienda (cosmetics_equipped): solo los que tienes.
	for slot in ["acc_feet", "acc_shoes", "boots"]:
		var id: String = String(p.cosmetics_equipped.get(slot, ""))
		if ItemCatalog.GUAYOS.has(id) and (id == "" or p.cosmetics_owned.has(id)):
			prof.guayos = id
			break
	# La cinta de la tienda también se lleva jugando (los gorros no)
	var head: String = String(p.cosmetics_equipped.get("acc_head", ""))
	if PlayerProfile.MATCH_HEADWEAR.has(head) and p.cosmetics_owned.has(head):
		prof.headband = head
	prof.stats = _stats(p)
	# La energía del Hub pesa en el partido (DecisionResolver.m3d_energy_stats)
	var en: Dictionary = DecisionResolver.m3d_energy_stats(prof.stats, clampf(100.0 - p.fatigue_physical, 0.0, 100.0))
	prof.stats = en.stats
	prof.set_meta("energy_note", String(en.note))
	prof.shirt = shirt
	prof.shorts = shorts
	prof.socks = socks
	return prof

static func _roster(xi: Array, skip: PlayerData, wseed: int) -> Array:
	var out: Array = []
	for x in xi:
		var pl: PlayerData = x
		if pl == skip:
			continue
		out.append({"name": pl.player_name, "position": pl.position, "stats": _stats(pl), "look": look_for(pl, wseed)})
	return out

static func _pattern(club: ClubData, season_year: int, away: bool) -> int:
	if club == null:
		return 0
	var cfg: Dictionary = Kit.for_club_kit(club, season_year, away)
	var w: int = int(cfg.get("w", -1))
	if w >= 0:
		return int(W_PATTERN_3D[w % W_PATTERN_3D.size()])
	var name: String = String(Kit.PATTERNS[int(cfg.get("pattern", 0)) % Kit.PATTERNS.size()])
	return int(PATTERN_3D.get(name, 0))

## Selección: [nombre, siglas, color de camiseta, segundo color] como _club_info.
static func _country_info(country: String) -> Array:
	var c: Color = CountryFlags.team_color(country)
	var sec := Color("#f2f2f2") if c.get_luminance() < 0.6 else Color("#141414")
	var code: String = CountryFlags.code_for(country)
	var short: String = code.to_upper() if code.length() == 3 else country.substr(0, 3).to_upper()
	return [country, short, "#" + c.to_html(false), "#" + sec.to_html(false)]


## [nombre, siglas, color primario, color secundario] de un club.
static func _club_info(club_id: String) -> Array:
	var world: Dictionary = _world()
	var c: ClubData = WorldFactory.find_club(world, club_id)
	if c == null:
		return [club_id, club_id.substr(0, 3).to_upper(), "#1B5E20", "#FFD54F"]
	var short: String = c.short_name if c.short_name != "" else c.club_name.substr(0, 3)
	return [c.club_name, short.to_upper(), c.primary_color_hex, c.secondary_color_hex]

## "Escudo" de una selección: su bandera dentro de un recuadro de 112 px.
static func _flag_crest(country: String) -> Control:
	var box := Control.new()
	box.size = Vector2(112, 112)
	box.custom_minimum_size = box.size
	var r := TextureRect.new()
	r.texture = CountryFlags.flag_or_proc(country)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = box.size
	box.add_child(r)
	return box

## Config para SoccerMatch (res://match3d/scripts/match.gd). En el 3D tu equipo
## es SIEMPRE el 0 ("home"); `user_home` dice si de verdad eres local.
static func build_config(on_finish: Callable) -> Dictionary:
	var p: PlayerData = MatchState.user_player
	var eng: MatchEngine = MatchState.engine
	var fixture: Dictionary = MatchState.fixture
	var user_home: bool = MatchState.home_team.starting_xi.has(p) or MatchState.home_team.bench.has(p)
	var on_bench: bool = not (MatchState.home_team.starting_xi.has(p) or MatchState.away_team.starting_xi.has(p))
	var rb := RandomNumberGenerator.new()
	rb.randomize()
	var bench_until: float = DecisionResolver.m3d_bench_entry_minute(p.coach_trust, rb.randf(), rb.randf()) if on_bench else 0.0
	var us: MatchTeam = MatchState.home_team if user_home else MatchState.away_team
	var them: MatchTeam = MatchState.away_team if user_home else MatchState.home_team
	var us_id: String = String(fixture.get("home_club_id" if user_home else "away_club_id", p.club_id))
	var them_id: String = String(fixture.get("away_club_id" if user_home else "home_club_id", ""))
	var national: bool = fixture.has("home_country")
	if national:
		us_id = String(fixture.get("home_country" if user_home else "away_country", p.country))
		them_id = String(fixture.get("away_country" if user_home else "home_country", ""))
	var us_c: Array = _country_info(us_id) if national else _club_info(us_id)
	var them_c: Array = _country_info(them_id) if national else _club_info(them_id)
	var world: Dictionary = _world()
	var us_club: ClubData = WorldFactory.find_club(world, us_id)
	var them_club: ClubData = WorldFactory.find_club(world, them_id)
	var season_year: int = WorldTickEngine.get_season_start_year()

	# --- xG real del MatchEngine (formación, capitanía, afición...)
	var xg_h: float = eng._home_xg * float(eng._xg_mult.get("home", 1.0))
	var xg_a: float = eng._away_xg * float(eng._xg_mult.get("away", 1.0))
	var xg_us: float = xg_h if user_home else xg_a
	var xg_them: float = xg_a if user_home else xg_h
	var rates: Array = DecisionResolver.m3d_goal_rates(xg_us, xg_them, p.position == "GK")

	# --- Camisetas: las elegidas en la previa, con la regla de choque de siempre.
	var us_alt: bool = MatchState.kit_home_away if user_home else MatchState.kit_away_away
	var them_alt: bool = MatchState.kit_away_away if user_home else MatchState.kit_home_away
	var us_col := Color(us_c[3] if us_alt else us_c[2])
	var us_sec := Color(us_c[2] if us_alt else us_c[3])
	var them_col := Color(them_c[3] if them_alt else them_c[2])
	var them_sec := Color(them_c[2] if them_alt else them_c[3])
	if Kit.colors_clash(us_col, them_col):
		them_col = Kit.alt_color_against(them_club, us_col)
		them_sec = Color("#f2f2f2") if them_col.get_luminance() < 0.6 else Color("#141414")
	# Selecciones: equipación completa como las de verdad (NationalKits); si chocan,
	# el rival se pone la otra.
	var us_shorts := us_sec
	var us_socks := us_col
	var them_shorts := them_sec
	var them_socks := them_col
	var us_pat: int = _pattern(us_club, season_year, us_alt)
	var them_pat: int = _pattern(them_club, season_year, them_alt)
	var us_center: bool = Kit.crest_centered(us_id, season_year)
	var them_center: bool = Kit.crest_centered(them_id, season_year)
	if national:
		# Camiseta elegida en la previa (local/visitante); si chocan, el rival se cambia.
		var uk: Dictionary = NationalKits.kit(us_id, us_alt)
		var tk: Dictionary = NationalKits.kit(them_id, them_alt)
		if Kit.colors_clash(uk.shirt, tk.shirt):
			tk = NationalKits.kit(them_id, not them_alt)
		us_col = uk.shirt
		us_sec = uk.c2
		us_shorts = uk.shorts
		us_socks = uk.socks
		us_pat = uk.pattern
		us_center = uk.center
		them_col = tk.shirt
		them_sec = tk.c2
		them_shorts = tk.shorts
		them_socks = tk.socks
		them_pat = tk.pattern
		them_center = tk.center
		if Kit.colors_clash(us_col, them_col):
			them_col = Kit.alt_color_against(null, us_col)
			them_sec = Color("#f2f2f2") if them_col.get_luminance() < 0.6 else Color("#141414")
			them_shorts = them_sec
			them_socks = them_col

	var wseed: int = SaveManager.load_world_seed()
	var coach_us: CoachData = WorldFactory.find_coach(world, us_id)
	var coach_them: CoachData = WorldFactory.find_coach(world, them_id)
	var home_club: ClubData = WorldFactory.find_club(world, String(fixture.get("home_club_id", "")))
	var ball_idx: int = MatchState.ball_design if MatchState.ball_design >= 0 else BallDesign.default_for("%s|%s" % [fixture.get("home_club_id", ""), fixture.get("away_club_id", "")])
	# Acarreo de la ida: el del partido (tie_agg, fuente única) o, si no, el del motor
	var tie: Dictionary = eng._tie_carry
	if fixture.get("tie_agg") is Dictionary:
		tie = fixture["tie_agg"]
	var prof: PlayerProfile = profile_for(p, wseed, us_col, us_shorts, us_socks)
	# Puesto sin adaptar (cambio de posición o el DT te pone fuera de sitio).
	var slot: String = us.deployed_code(p)
	var pos_fx: Dictionary = DecisionResolver.m3d_position_stats(prof.stats, PositionChangeEngine.familiarity(p, slot), Positions.label_of(slot))
	prof.stats = pos_fx.stats
	if String(pos_fx.note) != "":
		var prev: String = String(prof.get_meta("energy_note", ""))
		prof.set_meta("energy_note", String(pos_fx.note) if prev == "" else prev + " · " + String(pos_fx.note))
	return {
		"profile": prof,
		"traits": Traits.active(p), # rasgos equipados: efecto real en tus jugadas (TraitEffects)
		# Lesiones en el 3D (InjuryRisk): recaída si apuraste la vuelta, vendaje de la Tienda.
		"reinjury_risk": PlayerDevelopment.reinjury_active(p),
		"injury_shield": int(p.active_effects.get("injury_shield_matches", 0)) > 0,
		"user_detailed": us.deployed_code(p), # puesto fino: banda, hueco y jugadas propias
		"energy_note": String(prof.get_meta("energy_note", "")),
		"home_name": String(us_c[0]), "away_name": String(them_c[0]),
		"away_shirt": "#" + them_col.to_html(false), "away_shorts": "#" + them_shorts.to_html(false),
		"away_socks": "#" + them_socks.to_html(false),
		"home_color2": "#" + us_sec.to_html(false), "away_color2": "#" + them_sec.to_html(false),
		"home_pattern": us_pat, "away_pattern": them_pat,
		"home_crest_center": us_center, "away_crest_center": them_center,
		# Escudos del RPG para la camiseta, la presentación y los marcadores (se dibujan en el 3D)
		"home_crest": func() -> Control: return _flag_crest(us_id) if national else Styles.club_crest(us_id, 112),
		"away_crest": func() -> Control: return _flag_crest(them_id) if national else Styles.club_crest(them_id, 112),
		# Las selecciones no llevan patrocinio en la camiseta
		"home_sponsor": "" if national else KitDecals.sponsor_for(String(us_c[0])),
		"away_sponsor": "" if national else KitDecals.sponsor_for(String(them_c[0])),
		"national": national,
		"home_coach": coach_us.coach_name if coach_us != null else "",
		"away_coach": coach_them.coach_name if coach_them != null else "",
		"stadium": Venue.stadium_name(home_club) if home_club != null else ("Estadio Nacional · %s" % String(fixture.get("home_country", "")) if national else ""),
		# Estadio del LOCAL (puede ser el rival): estrellas, colores y lleno
		"stadium_stars": Venue.stars(home_club) if home_club != null else 3,
		"stadium_design": Venue.design(home_club) if home_club != null else "",
		"stadium_home_color": "#" + (us_col if user_home else them_col).to_html(false) if home_club == null else home_club.primary_color_hex.trim_prefix("#").insert(0, "#"),
		"stadium_home_color2": "#" + (us_sec if user_home else them_sec).to_html(false) if home_club == null else home_club.secondary_color_hex.trim_prefix("#").insert(0, "#"),
		"stadium_away_color": "#" + (them_col if user_home else us_col).to_html(false),
		"crowd_fill": float(Venue.attendance(home_club, WorldFactory.find_club(world, String(fixture.get("away_club_id", ""))), bool(fixture.get("derby", false)),
				"%s|%s" % [fixture.get("home_club_id", ""), fixture.get("away_club_id", "")], wseed)) / float(Venue.capacity(home_club)) if home_club != null else 0.8,
		"ball_design": ball_idx,
		"home_players": _roster(us.starting_xi, p, wseed),
		# Lanzadores designados por el DT y capitán de cada once (SetPieceTakers)
		"home_set_pieces": SetPieceTakers.for_xi(us.starting_xi, p),
		"away_set_pieces": SetPieceTakers.for_xi(them.starting_xi, null),
		"home_bench": _roster(us.bench, p, wseed),   # suplentes: el que entra si pides salir
		"start_energy": clampf((100.0 - p.fatigue_physical) / 100.0, 0.3, 1.0),
		"away_players": _roster(them.starting_xi, null, wseed),
		"goal_rate_home": float(rates[0]), "goal_rate_away": float(rates[1]),
		"on_finish": on_finish,
		"bench_until": bench_until,
		"attack_share": DecisionResolver.m3d_attack_share(xg_us, xg_them),
		"walkout": true, "walkout_skip": true,    # tocar la pantalla puede saltar la presentación
		"sent_off_rates": DecisionResolver.M3D_SENT_OFF_RATES,
		# Árbitro del partido (misma personalidad que usa MatchEngine): el 3D
		# ajusta con ella las faltas y las tarjetas.
		"referee_foul_mult": float(eng.referee_foul_mult),
		"referee_card_mult": float(eng.referee_card_mult),
		"referee_var_mult": float(eng.referee_var_mult),
		"final_trophy": _final_trophy(fixture), # final: si la ganas, ceremonia con la copa
		"competition": _comp_label(fixture), # cinta del cartel de la salida
		"final_trophy_id": _final_trophy_id(fixture, home_club), # qué trofeo 3D se levanta
		# --- para to_match_result (el 3D no los lee)
		"user_home": user_home, "us_team": us, "them_team": them,
		"xg_us": xg_us, "xg_them": xg_them, "knockout": eng.is_knockout,
		"has_tie_carry": fixture.has("tie_agg") or fixture.has("tie_key"),
		"two_leg_first_leg": fixture.has("tie_key") and int(fixture.get("leg", 0)) == 1,
		"carry_us": int(tie.get("home" if user_home else "away", 0)),
		"carry_them": int(tie.get("away" if user_home else "home", 0)),
		"user_look": Avatar.config_for_player(p, wseed),
		# Pancartas de la grada con tu nombre (o silbidos): las mismas de
		# ImmersionEngine que dibujaba el partido 2D. {} en selección.
		"crowd": {} if national else _crowd_banners(p, fixture, user_home, wseed, world),
	}

## PRÁCTICA (8-nov, PracticeEngine): el partido 3D en el estadio de tu club, vacío y
## de día, sin calendario ni consecuencias (no se llama a to_match_result).
##   mode "free":  sesión con tus jugadas de siempre (las de tu puesto)
##   mode "facet": solo las jugadas de la faceta `facet` (PracticeEngine.FACETS)
##   mode "scrim": partido completo, titulares (tú) contra suplentes con peto
## Devuelve {} si no hay jugador o club.
const PRACTICE_BIBS := ["#c8ff1e", "#ff6d1a", "#1ec8ff"] # petos de los suplentes
const PRACTICE_GOAL_RATE := 0.012 # gol por minuto simulado en titulares vs suplentes

static func practice_config(mode: String, facet: String, on_finish: Callable) -> Dictionary:
	var p: PlayerData = SaveManager.load_player()
	if p == null:
		return {}
	var world: Dictionary = _world()
	var club: ClubData = WorldFactory.find_club(world, p.club_id)
	if club == null:
		return {}
	var wseed: int = SaveManager.load_world_seed()
	var season_year: int = WorldTickEngine.get_season_start_year()
	var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var squad := WorldFactory.make_squad_with_transfers(world, p.club_id, wseed, season_start)
	# Tú vas aparte (MatchTeam te mete siempre en el once con chance 1.0)
	var keep: Array[PlayerData] = []
	for x: PlayerData in squad:
		if x != p and x.player_name != p.player_name:
			keep.append(x)
	squad = keep
	var coach: CoachData = WorldFactory.find_coach(world, p.club_id)
	var form: String = coach.formation if coach != null else ""
	var starters := MatchTeam.from_club(club, squad, p, 1.0, form)
	var rest: Array[PlayerData] = []
	for x: PlayerData in squad:
		if not starters.starting_xi.has(x):
			rest.append(x)
	# Los suplentes: el resto de la plantilla (si faltan, completan los titulares)
	for x: PlayerData in starters.starting_xi:
		if rest.size() >= 11:
			break
		if x != p:
			rest.append(x)
	var subs := MatchTeam.assemble("Suplentes", rest, null, 0.0, form)
	var c: Array = _club_info(p.club_id)
	var shirt := Color(String(c[2]))
	var sec := Color(String(c[3]))
	var bib := Color(PRACTICE_BIBS[0])
	for b: String in PRACTICE_BIBS:
		if not Kit.colors_clash(shirt, Color(b)):
			bib = Color(b)
			break
	var prof: PlayerProfile = profile_for(p, wseed, shirt, sec, shirt)
	var takers: Dictionary = SetPieceTakers.for_xi(starters.starting_xi, p)
	if mode != "scrim":
		# Practicando, los balones parados los cobras tú
		for k: String in SetPieceTakers.KINDS:
			takers[k] = p.player_name
	var fams: Array = PracticeEngine.families(facet) if mode == "facet" else []
	var scrim := mode == "scrim"
	return {
		"practice": mode, "practice_facet": facet, "practice_families": fams,
		"practice_moments": PracticeEngine.SESSION_MOMENTS,
		"profile": prof,
		"user_detailed": starters.deployed_code(p),
		"home_name": "Titulares", "away_name": "Suplentes",
		"away_shirt": "#" + bib.to_html(false), "away_shorts": "#" + sec.to_html(false),
		"away_socks": "#" + shirt.to_html(false),
		"home_color2": "#" + sec.to_html(false), "away_color2": "#" + bib.darkened(0.25).to_html(false),
		"home_pattern": _pattern(club, season_year, false), "away_pattern": 0,
		"home_crest_center": Kit.crest_centered(p.club_id, season_year), "away_crest_center": false,
		"home_crest": func() -> Control: return Styles.club_crest(p.club_id, 112),
		"away_crest": func() -> Control: return Styles.club_crest(p.club_id, 112),
		"home_sponsor": KitDecals.sponsor_for(String(c[0])), "away_sponsor": "",
		"home_coach": coach.coach_name if coach != null else "", "away_coach": "",
		"stadium": Venue.stadium_name(club),
		"stadium_stars": Venue.stars(club),
		"stadium_design": Venue.design(club),
		"stadium_home_color": club.primary_color_hex if club.primary_color_hex.begins_with("#") else "#" + club.primary_color_hex,
		"stadium_home_color2": club.secondary_color_hex if club.secondary_color_hex.begins_with("#") else "#" + club.secondary_color_hex,
		"stadium_away_color": "#" + bib.to_html(false),
		"crowd_fill": 0.0, "crowd": {}, "time_of_day": 0, "weather": 0,
		"competition": "Práctica",
		"ball_design": 0,
		"home_players": _roster(starters.starting_xi, p, wseed),
		"away_players": _roster(subs.starting_xi, null, wseed),
		"home_bench": [],
		"home_set_pieces": takers,
		"away_set_pieces": SetPieceTakers.for_xi(subs.starting_xi, null),
		"start_energy": 1.0,
		"goal_rate_home": PRACTICE_GOAL_RATE if scrim else 0.0,
		"goal_rate_away": PRACTICE_GOAL_RATE if scrim else 0.0,
		"attack_share": 0.55,
		"on_finish": on_finish,
		"bench_until": 0.0,
		"walkout": false, "halftime_locker": false,
		"sent_off_rates": DecisionResolver.M3D_SENT_OFF_RATES,
		"user_look": Avatar.config_for_player(p, wseed),
	}


## Pancartas de la hinchada (6-nov): misma entrada que usaba el partido 2D.
static func _crowd_banners(p: PlayerData, fixture: Dictionary, user_home: bool, wseed: int, world: Dictionary) -> Dictionary:
	var fs: int = int(WorldTickEngine.season.get("fan_sentiment", InterviewEngine.FAN_DEFAULT))
	var num: int = ShirtNumberEngine.number_for(p, wseed)
	# Ex club (v34): de visitante en una cancha donde jugaste.
	var ex_rec: String = "" if user_home else ImmersionEngine.ex_club_reception(p, world, String(fixture.get("home_club_id", "")), wseed)
	return ImmersionEngine.crowd_banners(p, wseed, fs, user_home, bool(fixture.get("derby", false)), num, ex_rec)

## Resultado en el formato de MatchEngine.run_match() (lo consume MatchSummary).
## `res` = SoccerMatch.result(): score [tu equipo, rival] y stats.
## Nombre del título si el partido es una final ("" si no lo es).
## Id del trofeo (el de Trophy.gd / TrophyBuilder) que se levanta si la final se gana.
static func _final_trophy_id(fixture: Dictionary, home_club: ClubData) -> String:
	var comp: String = String(fixture.get("competition", ""))
	match comp:
		"cwc": return "mundial_clubes"
		"world_cup": return "mundial_seleccion"
		"continental":
			var conf: String = String(fixture.get("cont_conf", ""))
			return "cont_%s_%d" % [conf, int(fixture.get("cont_tier", 1))] if conf != "" else "continental_cup"
		"supercup":
			return "supercopa_cont" if String(fixture.get("supercup_kind", "domestic")) == "continental" else "supercopa"
		"cup", "national_cup":
			return "dcup_%d" % home_club.league_id if home_club != null else "cup"
	return comp


## "LIGA · JORNADA 12", "COPA · FINAL"... para el cartel de la tele en la salida.
static func _comp_label(fixture: Dictionary) -> String:
	var comp: String = String(fixture.get("competition", ""))
	var name: String = String(fixture.get("competition_name", "")) if fixture.has("competition_name") else String({
		"league": "Liga", "cup": "Copa", "national_cup": "Copa", "continental": "Copa Continental",
		"supercup": "Supercopa", "cwc": "Mundial de Clubes", "world_cup": "Copa del Mundo",
		"friendly": "Amistoso", "qualifying": "Eliminatorias"}.get(comp, ""))
	var rn: String = String(fixture.get("round_name", ""))
	if rn == "" and fixture.has("matchday"):
		rn = "Jornada %d" % int(fixture.matchday)
	return name + ("  ·  " + rn if rn != "" and name != "" else rn)


static func _final_trophy(fixture: Dictionary) -> String:
	var rn: String = String(fixture.get("round_name", ""))
	var comp: String = String(fixture.get("competition", ""))
	if comp == "friendly" or not (rn == "Final" or rn.ends_with(" Final") or comp == "supercup"):
		return ""
	if fixture.has("competition_name"):
		return String(fixture.competition_name)
	return String({"cup": "Copa", "national_cup": "Copa", "continental": "Copa Continental", "supercup": "Supercopa",
		"cwc": "Mundial de Clubes", "world_cup": "Copa del Mundo"}.get(comp, "Copa"))


static func to_match_result(res: Dictionary, cfg: Dictionary) -> Dictionary:
	var p: PlayerData = MatchState.user_player
	var uh: bool = bool(cfg.user_home)
	var sc: Array = res.score
	var st: Dictionary = res.stats
	var me: Dictionary = st.me
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var score := {"home": int(sc[0] if uh else sc[1]), "away": int(sc[1] if uh else sc[0])}
	var carry_us := int(cfg.get("carry_us", 0))
	var carry_them := int(cfg.get("carry_them", 0))
	var agg_us := int(sc[0]) + carry_us
	var agg_them := int(sc[1]) + carry_them
	var shootout_winner: String = ""
	var shootout_team: int = int(res.get("shootout_winner_team", -1))
	if shootout_team >= 0:
		shootout_winner = ("home" if uh else "away") if shootout_team == 0 else ("away" if uh else "home")
	var winner_team: int = int(res.get("tie_winner_team", -1))
	if winner_team < 0:
		if shootout_team >= 0:
			winner_team = shootout_team
		elif agg_us != agg_them:
			winner_team = 0 if agg_us > agg_them else 1
		elif shootout_winner != "":
			winner_team = 0 if ((shootout_winner == "home") == uh) else 1
	var tie_winner := ""
	if bool(cfg.knockout) and not bool(cfg.get("two_leg_first_leg", false)) and winner_team >= 0:
		tie_winner = ("home" if uh else "away") if winner_team == 0 else ("away" if uh else "home")
	var shootout_score: Array = res.get("shootout_score", [])
	if shootout_score.size() == 2 and not uh:
		shootout_score = [shootout_score[1], shootout_score[0]]
	var rating: float = DecisionResolver.m3d_user_rating(me)
	var yellows: int = int(me.get("yellows", 0))
	var red: bool = bool(me.get("red", false))
	_fill_gesture_stats(st.get("moment_log", []))
	var ev: Array[Dictionary] = []
	for i in int(me.goals):
		ev.append({"type": "goal", "delta": DecisionResolver.RATING_GOAL})
	for i in int(me.assists):
		ev.append({"type": "key_pass_success", "delta": DecisionResolver.RATING_ASSIST})
	for i in int(me.recov):
		ev.append({"type": "tackle_success", "delta": DecisionResolver.M3D_R_RECOV})
	var pos_us: int = DecisionResolver.m3d_possession(float(cfg.xg_us), float(cfg.xg_them), rng.randf())
	var side := func(i: int) -> Dictionary:
		return {"shots": int(st.shots[i]), "on_target": int(st.sot[i]), "corners": int(st.corners[i]), "fouls": int(st.fouls[i])}
	return {
		"score": score,
		"user_player": p,
		"user_rating": rating,
		"rating_events": ev,
		"user_injured": bool(res.get("injured", false)),
		"user_red_carded": red,
		"user_double_yellow": red,
		"shootout_winner": shootout_winner,
		"tie_winner": tie_winner,
		"extra_time_played": bool(res.get("extra_time_played", false)),
		"aggregate_score": {"home": agg_us if uh else agg_them, "away": agg_them if uh else agg_us},
		"has_tie_carry": bool(cfg.get("has_tie_carry", false)),
		"shootout_score": shootout_score,
		"player_ratings": _player_ratings(res, cfg, rating),
		"match_stats": {
			"possession_home": pos_us if uh else 100 - pos_us,
			"possession_away": 100 - pos_us if uh else pos_us,
			"home": side.call(0 if uh else 1),
			"away": side.call(1 if uh else 0),
		},
		"user_goals": int(me.goals),
		"user_assists": int(me.assists),
		"user_started": not bool(res.get("bench", false)),
		"user_played": bool(res.get("entered", true)),
		"user_subbed_off": bool(res.get("subbed_off", false)),
		"user_exit_minute": int(res.get("exit_minute", 0)),
		"user_yellows": mini(yellows, 2),
		"user_detailed": String(cfg.get("user_detailed", "")),
		"user_goal_plays": _goal_plays(st.get("moment_log", [])),
		"user_best_moment": String((res.get("best_moment", {}) as Dictionary).get("label", "")),
		"halftime_order": res.get("halftime_order", {}),
		"user_data": res.get("data", {}), # km, sprints, xG y mapa de calor (MatchData)
		"m3d": true,
	}

## Las jugadas del 3D cuentan como tus "toques" de la carrera (MatchState.gesture_stats):
## dan XP de carrera (ProgressionEngine.gesture_xp) y sirven para los retos del DT.
static func _fill_gesture_stats(log: Array) -> void:
	var gs: Dictionary = MatchState.gesture_stats
	for k in ["perfecto", "bueno", "regular", "flojo", "streak", "best_streak"]:
		if not gs.has(k):
			gs[k] = 0
	for e in log:
		var g: String = String(e.get("grade", "bueno" if bool(e.get("ok", false)) else "flojo"))
		gs[g] = int(gs.get(g, 0)) + 1
		if g == "perfecto" or g == "bueno":
			gs["streak"] = int(gs["streak"]) + 1
			gs["best_streak"] = maxi(int(gs["best_streak"]), int(gs["streak"]))
		else:
			gs["streak"] = 0

## Cómo marcaste/asististe en las jugadas: [{play, flair, goal, assist}] — lo
## usa la zona mixta para preguntarte por TU jugada (chilena, diagonal, pared…).
static func _goal_plays(log: Array) -> Array:
	var out: Array = []
	for e in log:
		if bool(e.get("my_goal", false)) or bool(e.get("my_assist", false)):
			out.append({"play": String(e.get("play", "")), "flair": String(e.get("flair", "")),
				"goal": bool(e.get("my_goal", false)), "assist": bool(e.get("my_assist", false))})
	return out

## Notas de los 22: base por resultado + goles de cada uno (por nombre).
static func _player_ratings(res: Dictionary, cfg: Dictionary, user_rating: float) -> Array:
	var sc: Array = res.score
	var goals := {}
	for g in res.stats.goals_log:
		var key: String = "%d|%s" % [int(g.team), String(g.name)]
		goals[key] = int(goals.get(key, 0)) + 1
	var agg_us := int(sc[0]) + int(cfg.get("carry_us", 0))
	var agg_them := int(sc[1]) + int(cfg.get("carry_them", 0))
	var won: bool = agg_us > agg_them or int(res.get("shootout_winner_team", -1)) == 0
	var lost: bool = agg_us < agg_them or int(res.get("shootout_winner_team", -1)) == 1
	var uh: bool = bool(cfg.user_home)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rows: Array = []
	for side in [0, 1]:
		var team: MatchTeam = cfg.us_team if side == 0 else cfg.them_team
		var listed: Array = team.starting_xi.duplicate()
		if side == 0 and bool(res.get("bench", false)) and bool(res.get("entered", false)):
			listed.append(MatchState.user_player)   # entraste desde el banco
		for x in listed:
			var pl: PlayerData = x
			var is_u: bool = pl == MatchState.user_player
			var r: float = user_rating
			if not is_u:
				r = 6.3 + rng.randf_range(-0.6, 0.9) + 0.8 * int(goals.get("%d|%s" % [side, pl.player_name], 0))
				if (won and side == 0) or (lost and side == 1):
					r += 0.4
				elif (lost and side == 0) or (won and side == 1):
					r -= 0.4
			var on_home: bool = (side == 0) == uh
			rows.append({"name": pl.player_name, "position": pl.position, "team": "home" if on_home else "away",
				"is_user": is_u, "rating": clampf(r, 3.0, 10.0)})
	rows.sort_custom(func(a, b): return a["rating"] > b["rating"])
	return rows
