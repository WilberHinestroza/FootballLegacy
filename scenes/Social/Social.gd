extends Control
const _M3D = preload("res://engine/match/m3d/Match3DBridge.gd")  # retrato 3D

## Redes sociales (clon de Twitter) — pedido explícito con capturas de
## Football Legacy. Tres pestañas:
##   Para ti  — feed generado en vivo (SocialEngine.generate_feed), NADA se
##              persiste, mismo criterio "mundo vivo" que WorldExplorer.
##   Publicar — hasta 2 posts por semana; mueven reputación y suman
##              seguidores por engagement (SocialEngine.publish). El efecto
##              SÍ persiste: reputación (campo existente) + contador en el
##              dict de temporada (aditivo, sin cambio de esquema).
##   Perfil   — seguidores (derivados), handle y resumen de carrera.
## Se entra desde CareerMenu ("Redes sociales").

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var sub_label: Label = $Margin/VBox/SubLabel
@onready var feed_tab_button: Button = $Margin/VBox/TabsRow/FeedTabButton
@onready var post_tab_button: Button = $Margin/VBox/TabsRow/PostTabButton
@onready var messages_tab_button: Button = $Margin/VBox/TabsRow/MessagesTabButton
@onready var profile_tab_button: Button = $Margin/VBox/TabsRow/ProfileTabButton
@onready var detail_box: VBoxContainer = $Margin/VBox/Scroll/DetailBox
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var back_button: Button = $Margin/VBox/BackButton

var _player: PlayerData = null
var _world: Dictionary = {}
var _seed: int = 0
var _day: int = 0
var _tab: String = "feed"
var _feed_mode: String = "parati"   # "parati" | "mundo" (10-oct, mundo vivo)
var _ctx_cache: Dictionary = {}

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_player = SaveManager.load_player()
	_world = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	_seed = SaveManager.load_world_seed()
	_day = WorldTickEngine.current_epoch_day

	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(_on_back_pressed)

	feed_tab_button.pressed.connect(_on_tab_pressed.bind("feed"))
	post_tab_button.pressed.connect(_on_tab_pressed.bind("post"))
	messages_tab_button.pressed.connect(_on_tab_pressed.bind("messages"))
	profile_tab_button.pressed.connect(_on_tab_pressed.bind("profile"))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	if _player == null:
		title_label.text = "Sin jugador"
		sub_label.text = ""
		return

	# Polémica sin respuesta pasado el plazo: cuenta como "ignorar".
	var crng := RandomNumberGenerator.new()
	crng.randomize()
	if ControversyEngine.expire_if_due(_player, WorldTickEngine.season, _day, crng) != "":
		SaveManager.save_player(_player)
		SaveManager.save_season(WorldTickEngine.season)

	_landscape_app()
	_refresh_header()
	_render()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/CareerMenu/CareerMenu.tscn")

func _on_tab_pressed(tab: String) -> void:
	_tab = tab
	_render()

func _refresh_header() -> void:
	var bonus: int = int(WorldTickEngine.season.get("social", {}).get("bonus_followers", 0))
	var n: int = SocialEngine.followers(_player, bonus)
	title_label.text = _player.player_name
	sub_label.text = "%s  ·  %s seguidores  ·  energía %d/100" % [
		SocialEngine.handle_for(_player), SocialEngine.followers_label(n), SocialEngine.energy(_player),
	]
	if _side_card != null:
		_fill_side_card(n)

func _refresh_tabs() -> void:
	var buttons: Dictionary = {"feed": feed_tab_button, "post": post_tab_button, "messages": messages_tab_button, "profile": profile_tab_button}
	for key in buttons:
		var b: Button = buttons[key]
		if key == _tab:
			Styles.tab(b, true)
		else:
			Styles.tab(b, false)

func _render() -> void:
	_refresh_tabs()
	for child in detail_box.get_children():
		child.queue_free()
	if _player == null:
		return
	match _tab:
		"post":
			_render_post()
		"messages":
			_render_messages()
		"profile":
			_render_profile()
		_:
			_render_feed()
	UiScroll.pad_bottom(detail_box)

# --- Para ti ---

func _render_feed() -> void:
	# Para ti | Mundo (10-oct, Wilber: "más inmersivo y mundo vivo de
	# clubes, jugadores y selecciones").
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 8)
	for m in [["parati", "Tu feed"], ["mundo", "Mundo"]]:
		var b := Button.new()
		b.text = String(m[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Styles.tab(b, _feed_mode == String(m[0]))
		var mode: String = String(m[0])
		b.pressed.connect(func():
			_feed_mode = mode
			_render())
		pills.add_child(b)
	detail_box.add_child(pills)
	var ctx: Dictionary = _world_ctx(_feed_mode == "mundo")
	# Tendencias.
	var trends := HFlowContainer.new()
	trends.add_theme_constant_override("h_separation", 6)
	trends.add_theme_constant_override("v_separation", 6)
	var tl := Label.new()
	tl.text = "Tendencias"
	tl.add_theme_font_override("font", Styles.font_semibold())
	tl.add_theme_color_override("font_color", Styles.GOLD)
	trends.add_child(tl)
	for h in WorldPulseEngine.trends(ctx, _seed, _day):
		trends.add_child(UiKit.chip(String(h), Color(0.45, 0.75, 1.0)))
	detail_box.add_child(trends)
	if _feed_mode != "mundo":
		var cblock := _controversy_block()
		if cblock != null:
			detail_box.add_child(cblock)

	var feed: Array
	if _feed_mode == "mundo":
		feed = WorldPulseEngine.feed(ctx, _seed, _day)
	else:
		feed = SocialEngine.generate_feed(_player, _world, _seed, _day, WorldTickEngine.season)
		# Un par de posts del mundo también en "Para ti": la red no gira
		# solo alrededor tuyo.
		var wp: Array = WorldPulseEngine.feed(ctx, _seed, _day)
		var at: int = 1 if (not feed.is_empty() and bool(feed[0].get("mine", false))) else 0
		for i in range(mini(2, wp.size())):
			feed.insert(mini(at + i * 3, feed.size()), wp[i])
		# SEMANA DE CLÁSICO (10-oct): la previa calienta la red, con el pique
		# de tu rival personal arriba de todo.
		var dctx: Dictionary = _rivalry_ctx()
		if bool(dctx.get("derby_week", false)):
			var dposts: Array = ImmersionEngine.derby_week_posts(dctx, _seed, _day)
			for i in range(dposts.size()):
				feed.insert(mini(at + i, feed.size()), dposts[i])
		elif String(dctx.get("nemesis", "")) != "":
			feed.insert(mini(at, feed.size()), {"author": dctx["nemesis"], "handle": "@" + ImmersionEngine._tag(String(dctx["nemesis"])).to_lower(),
				"verified": true, "text": dctx["nem_line"], "likes": 4200, "rts": 610, "tint": "RED", "mine": false, "nemesis": true})
	if feed.is_empty():
		return
	var pager := Pager.new()
	detail_box.add_child(pager)
	pager.show_items(feed, 4, _post_card)

## Rivalidad de la semana: ¿el próximo partido es el clásico (≤ 6 días)?
## ¿o es contra el club de tu rival personal? → ctx para ImmersionEngine.
## {} si nada de eso. Cacheado: arma un plantel ajeno.
var _rivalry_cache: Dictionary = {}
var _rivalry_done: bool = false
func _rivalry_ctx() -> Dictionary:
	if _rivalry_done:
		return _rivalry_cache
	_rivalry_done = true
	if _player == null or _player.club_id == "" or _world.is_empty():
		return {}
	var nxt: Dictionary = WorldTickEngine.next_user_fixture(_player.club_id)
	if nxt.is_empty() or nxt.has("opponent"):
		return {}
	var rival_id: String = RivalryEngine.club_rival_for(_world, _player.club_id, _seed)
	var dw: Dictionary = ImmersionEngine.derby_week(nxt, _player.club_id, rival_id, _day)
	var nem_club: String = ImmersionEngine.nemesis_club_id(_world, _player.club_id, _seed)
	var opp: String = String(nxt.get("away_club_id", "")) if String(nxt.get("home_club_id", "")) == _player.club_id else String(nxt.get("home_club_id", ""))
	var days_left: int = int(nxt.get("epoch_day", _day)) - _day
	if dw.is_empty() and not (opp == nem_club and days_left <= ImmersionEngine.DERBY_WEEK_DAYS):
		return {}
	var club: ClubData = WorldFactory.find_club(_world, _player.club_id)
	var rc: ClubData = WorldFactory.find_club(_world, opp)
	var ctx := {
		"derby_week": not dw.is_empty(), "days_left": days_left,
		"club": club.club_name if club != null else "", "club_id": _player.club_id,
		"rival": rc.club_name if rc != null else "", "you": Nickname.press_name(_player, _seed),
	}
	if opp == nem_club:
		var squad: Array = WorldFactory.make_squad_with_transfers(_world, nem_club, WorldTickEngine.world_seed, int(WorldTickEngine.season.get("season_start_epoch_day", 0)))
		var nem: Dictionary = ImmersionEngine.pick_nemesis(squad, _player.position)
		if not nem.is_empty():
			var rec: Dictionary = ImmersionEngine.nemesis_record(_player.nemesis_log)
			ctx["nemesis"] = String(nem["name"])
			ctx["record"] = rec
			ctx["nem_line"] = ImmersionEngine.nemesis_pre_line(String(nem["name"]), String(ctx["you"]), rec, "%s|%d" % [_player.player_name, int(nxt.get("epoch_day", 0))])
	_rivalry_cache = ctx
	return ctx

## Datos del mundo vivo para WorldPulseEngine (la escena los junta; el
## motor es puro). `full` suma lo caro (goleadores, Balón de Oro).
func _world_ctx(full: bool) -> Dictionary:
	var key: String = "full" if full else "lite"
	if _ctx_cache.has(key):
		return _ctx_cache[key]
	var ctx: Dictionary = {}
	var club: ClubData = WorldFactory.find_club(_world, _player.club_id) if _player.club_id != "" else null
	if club != null:
		var lid: int = club.league_id
		var lg = _world.get("league_by_id", {}).get(lid, null)
		if lg != null:
			ctx["league_name"] = String(lg.league_name)
			ctx["league_hashtag"] = WorldPulseEngine._tag(String(lg.league_name)).capitalize()
		ctx["table"] = WorldTickEngine.table_for_league(lid)
		var names: Dictionary = {}
		for c in _world.get("clubs_by_league", {}).get(lid, []):
			names[c.club_id] = c.club_name
		var last: Array = []
		for rd in WorldTickEngine.league_fixture_rounds(lid):
			var played: Array = (rd["matches"] as Array).filter(func(m): return bool(m["played"]))
			if not played.is_empty():
				last = played
		var lr: Array = []
		for m in last:
			lr.append({"home_id": m["home_id"], "home": names.get(m["home_id"], "?"), "away_id": m["away_id"], "away": names.get(m["away_id"], "?"), "gh": m["gh"], "ga": m["ga"]})
		ctx["last_round"] = lr
		if full:
			ctx["scorers"] = (WorldTickEngine.top_performers_for_league(lid).get("scorers", []) as Array).slice(0, 3)
	if full:
		var bd: Array = WorldTickEngine.ballon_dor_ranking().slice(0, 10)
		ctx["ballon"] = bd
		var rich: Array = []
		for r in bd:
			if not rich.has(String(r["club_name"])):
				rich.append(String(r["club_name"]))
		ctx["rich_clubs"] = rich
	ctx["user_country"] = _player.country
	ctx["intl_days"] = WorldTickEngine.days_until_next_international_window(10)
	ctx["in_window"] = WorldTickEngine.is_day_in_international_window(_day)
	ctx["wc_year"] = WorldCupEngine.is_wc_year(WorldTickEngine.get_season_start_year())
	_ctx_cache[key] = ctx
	return ctx

## Avatar del autor: escudo (club), logo (medio), bandera (selección),
## trofeo (liga), tu cara o la de un hincha.
func _post_avatar(post: Dictionary) -> Control:
	var av: Dictionary = post.get("av", {})
	var px := 40
	match String(av.get("kind", "")):
		"club":
			return Styles.club_crest(String(av.get("id", "")), px)
		"media":
			return MediaOutlets.logo(String(av.get("name", "")), px)
		"nation":
			var cc := CenterContainer.new()
			cc.custom_minimum_size = Vector2(px, px)
			cc.add_child(CountryFlags.flag_rect(String(av.get("country", "")), 24))
			return cc
		"league":
			var club: ClubData = WorldFactory.find_club(_world, _player.club_id) if _player.club_id != "" else null
			if club != null:
				return Trophy.for_title("league_%d" % club.league_id, px)
	if bool(post.get("mine", false)):
		return Avatar.for_player(_player, _seed, px)
	if bool(post.get("nemesis", false)):
		return Avatar.for_npc(String(post.get("author", "?")), "player", _seed, px)   # misma cara que en Mensajes
	return Avatar.for_npc(String(post.get("author", "?")), "fan", _seed, px)

## Adjunto del post: marcador (resultado) o mini tabla.
func _post_attachment(card: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := Styles.card_flat(Color(1, 1, 1, 0.05), 10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	if String(card.get("kind", "")) == "score":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		var hn := Label.new()
		hn.text = String(card["home"])
		hn.clip_text = true
		hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(hn)
		row.add_child(Styles.club_crest(String(card["home_id"]), 28))
		var sc := Label.new()
		sc.text = " %d - %d " % [int(card["gh"]), int(card["ga"])]
		sc.add_theme_font_override("font", Styles.font_black())
		sc.add_theme_font_size_override("font_size", 20)
		row.add_child(sc)
		row.add_child(Styles.club_crest(String(card["away_id"]), 28))
		var an := Label.new()
		an.text = String(card["away"])
		an.clip_text = true
		an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(an)
		panel.add_child(row)
	else:
		var v := VBoxContainer.new()
		for r in card.get("rows", []):
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 8)
			var pl := Label.new()
			pl.text = "%d." % int(r.get("pos", 0))
			pl.custom_minimum_size = Vector2(24, 0)
			row2.add_child(pl)
			row2.add_child(Styles.club_crest(String(r["club_id"]), 22))
			var nl := Label.new()
			nl.text = String(r["name"])
			nl.clip_text = true
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(nl)
			var pt := Label.new()
			pt.text = "%d pts" % int(r["pts"])
			pt.add_theme_color_override("font_color", Styles.GOLD)
			row2.add_child(pt)
			v.add_child(row2)
		panel.add_child(v)
	return panel

func _post_card(post: Dictionary) -> PanelContainer:
	var mine: bool = bool(post.get("mine", false))
	var accent: Color = Styles.GOLD if mine else _tint(String(post.get("tint", "BLUE")))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)

	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	var avc := _post_avatar(post)
	avc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(avc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var author_lbl := Label.new()
	author_lbl.text = String(post.get("author", ""))
	author_lbl.add_theme_font_override("font", Styles.font_semibold())
	var handle_lbl := Label.new()
	handle_lbl.text = String(post.get("handle", ""))
	handle_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	handle_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	head.add_child(author_lbl)
	if bool(post.get("verified", false)):
		var ver := Label.new()
		ver.text = "✔"
		ver.add_theme_color_override("font_color", Color(0.35, 0.7, 1.0))
		head.add_child(ver)
	handle_lbl.clip_text = true
	handle_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(handle_lbl)
	if mine:
		var you_lbl := Label.new()
		you_lbl.text = "  · TÚ"
		you_lbl.add_theme_color_override("font_color", Styles.GOLD)
		you_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		head.add_child(you_lbl)
	vb.add_child(head)

	var body_lbl := Label.new()
	body_lbl.text = String(post.get("text", ""))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(body_lbl)

	if post.has("card"):
		vb.add_child(_post_attachment(post["card"]))

	var likes: int = int(post.get("likes", 0))
	var likes_lbl := Label.new()
	likes_lbl.text = "Resp. %s     RT %s     ♥ %s" % [_compact(int(post.get("replies", int(likes * 0.05)))), _compact(int(post.get("rts", int(likes * 0.15)))), _compact(likes)]
	likes_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	likes_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	vb.add_child(likes_lbl)

	margin.add_child(outer)
	panel.add_child(margin)
	return panel

# --- Publicar ---

func _render_post() -> void:
	var left: int = SocialEngine.posts_left_this_week(WorldTickEngine.season, _day)
	detail_box.add_child(Styles.section_label("PUBLICAR ESTA SEMANA — %d/%d" % [left, SocialEngine.MAX_POSTS_PER_WEEK]))

	if left <= 0:
		var note := Label.new()
		note.text = "Ya publicaste bastante esta semana. Deja que baje el ruido."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(note)

	for opt in SocialEngine.POST_OPTIONS:
		detail_box.add_child(_post_option_card(opt, left > 0))

func _post_option_card(opt: Dictionary, enabled: bool) -> Control:
	var accent: Color = _tint(String(opt.get("tint", "BLUE")))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 110)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not enabled
	Styles.styled_button(btn, Styles.card_accent(accent))
	if enabled:
		btn.pressed.connect(_on_publish.bind(String(opt["id"])))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)

	var label_lbl := Label.new()
	label_lbl.text = String(opt["label"])
	label_lbl.add_theme_font_override("font", Styles.font_semibold())
	label_lbl.add_theme_color_override("font_color", accent)
	label_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(label_lbl)

	var text_lbl := Label.new()
	text_lbl.text = "\"%s\"" % String(opt["text"])
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(text_lbl)

	var effect_lbl := Label.new()
	var rep: int = int(opt["rep"])
	effect_lbl.text = "Reputación %s%d  ·  alcance %d%%" % ["+" if rep >= 0 else "", rep, int(float(opt["fans_pct"]) * 100.0)]
	effect_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	effect_lbl.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	effect_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(effect_lbl)

	margin.add_child(vb)
	btn.add_child(margin)
	return btn

func _on_publish(option_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var res: Dictionary = SocialEngine.publish(_player, WorldTickEngine.season, option_id, _day, rng)
	if not res.get("ok", false):
		return
	ControversyEngine.check_post(_player, WorldTickEngine.season, option_id, _day, rng)
	SaveManager.save_player(_player)
	SaveManager.save_season(WorldTickEngine.season)
	_refresh_header()
	_tab = "feed"
	_render()


# --- Polémica (ControversyEngine) ---

## Tarjeta de la polémica: la tendencia, lo que dice la gente y tus 3 respuestas;
## ya respondida, el desenlace unos días. null si no hay nada que mostrar.
func _controversy_block() -> Control:
	var season: Dictionary = WorldTickEngine.season
	var c: Dictionary = ControversyEngine.active(season)
	var resolved := false
	if c.is_empty():
		c = ControversyEngine.recent_outcome(season, _day)
		resolved = true
	if c.is_empty():
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var card := _card(Styles.AMBER if resolved else Styles.RED)
	var vb: VBoxContainer = card.get_child(0).get_child(0)
	var head := Label.new()
	head.text = ("🔥 TENDENCIA · " if not resolved else "DESENLACE · ") + String(c.get("title", ""))
	head.add_theme_font_override("font", Styles.font_semibold())
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Styles.AMBER if resolved else Styles.RED.lightened(0.2))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(head)
	var body := Label.new()
	body.text = String(c.get("outcome", "")) if resolved else String(c.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(body)
	if not resolved:
		var left := ControversyEngine.days_left(season, _day)
		var hint := Label.new()
		hint.text = "Tienes %d día%s para responder; si no, cuenta como ignorarlo." % [left, "" if left == 1 else "s"]
		hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(hint)
		for opt: Dictionary in ControversyEngine.CHOICES:
			var b := Button.new()
			b.text = "%s — %s" % [opt["label"], opt["hint"]]
			b.focus_mode = Control.FOCUS_NONE
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(0, 44)
			var col: Color = {"apologize": Styles.GREEN, "ignore": Styles.GRAY_TEXT, "double_down": Styles.RED}[String(opt["id"])]
			Styles.styled_button(b, Styles.pill_outlined(col), Color.WHITE)
			b.pressed.connect(_on_controversy_choice.bind(String(opt["id"])))
			vb.add_child(b)
	box.add_child(card)
	if not resolved:
		for post: Dictionary in ControversyEngine.reactions(c, _player, _seed, _day):
			box.add_child(_post_card(post))
	return box


func _on_controversy_choice(choice: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if ControversyEngine.respond(_player, WorldTickEngine.season, choice, _day, rng) == "":
		return
	SaveManager.save_player(_player)
	SaveManager.save_season(WorldTickEngine.season)
	_refresh_header()
	_render()

# --- Mensajes (DMs) ---

func _render_messages() -> void:
	if not SocialEngine.dm_seen_this_week(WorldTickEngine.season, _day):
		SocialEngine.mark_dm_seen(WorldTickEngine.season, _day)
		SaveManager.save_season(WorldTickEngine.season)
	detail_box.add_child(Styles.section_label("ENERGÍA %d/100" % SocialEngine.energy(_player)))
	var hint := Label.new()
	hint.text = "Los eventos consumen energía; se recupera con los días de descanso. Ir cansado a un partido baja tu rendimiento."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	hint.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	detail_box.add_child(hint)

	var threads: Array = SocialEngine.generate_threads(_player, _world, _seed, _day, WorldTickEngine.season)
	# Tu rival personal te escribe antes de cruzarse (10-oct).
	var rctx: Dictionary = _rivalry_ctx()
	if String(rctx.get("nemesis", "")) != "":
		threads.insert(0, {"contact_name": String(rctx["nemesis"]), "role": "rival", "invite": {},
			"messages": ImmersionEngine.nemesis_dm(String(rctx["nemesis"]), String(rctx["you"]), rctx.get("record", {}), "%s|%d" % [_player.player_name, _day])})
	if threads.is_empty():
		return
	detail_box.add_child(Styles.section_label("MENSAJES"))
	var pager := Pager.new()
	detail_box.add_child(pager)
	pager.show_items(threads, 6, _thread_preview_card)

## Fila-preview de un hilo: contacto + último mensaje + badge si hay
## invitación. Al tocar, ABRE el chat en su propia vista (pedido de Wilber:
## "entrar al chat a responder y no responder ahí encima").
func _thread_preview_card(th: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 58)
	btn.focus_mode = Control.FOCUS_NONE
	var has_invite: bool = not th.get("invite", {}).is_empty()
	Styles.styled_button(btn, Styles.card_accent(Styles.GOLD if has_invite else Styles.CARD_DARK, Styles.CARD_DARK, 12))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 8)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var face := Avatar.for_npc(String(th.get("contact_name", "?")), _npc_role(String(th.get("role", ""))), _seed, 36)
	row.add_child(Styles.portrait_frame(face, 36, Styles.GRAY_TEXT))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	var nm := Label.new()
	nm.text = String(th.get("contact_name", "?"))
	nm.add_theme_font_override("font", Styles.font_semibold())
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var last := Label.new()
	var msgs: Array = th.get("messages", [])
	last.text = String(msgs[msgs.size() - 1].get("text", "")) if not msgs.is_empty() else ""
	last.clip_text = true
	last.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	last.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	last.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(last)
	row.add_child(col)
	if has_invite:
		var b := Label.new()
		b.text = "🎁" if String(th["invite"].get("kind", "")) == "benefit" else "🤝"
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(b)
	m.add_child(row)
	btn.add_child(m)
	btn.pressed.connect(_open_thread.bind(th))
	return btn

func _npc_role(role: String) -> String:
	match role:
		"agent": return "agent"
		"coach": return "coach"
		"teammate": return "player"
		_: return "player"

## Overlay con el chat completo + la invitación (aceptar/rechazar acá) +
## botón para volver a la lista.
func _open_thread(th: Dictionary) -> void:
	var ov := ColorRect.new()
	ov.name = "ThreadOverlay"
	ov.color = Color(0.06, 0.07, 0.09, 0.98)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.z_index = 120
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 16)
	# Debajo de la barra del equipo + franja "‹ Volver" (TopBar), si no el
	# botón de arriba del chat quedaba tapado (reporte de Wilber).
	m.add_theme_constant_override("margin_top", 152)
	m.add_theme_constant_override("margin_bottom", 16)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 44)
	back.text = "‹  Volver a mensajes"
	back.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(back, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back.pressed.connect(func():
		if is_instance_valid(ov): ov.queue_free())
	vb.add_child(back)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chat := ChatThread.new()
	chat.setup(th, _player, _seed)
	var invite: Dictionary = th.get("invite", {})
	if not invite.is_empty():
		chat.ready.connect(func():
			var blk := _invite_block(invite)
			blk.tree_exiting.connect(func(): pass)
			chat.footer.add_child(blk), CONNECT_ONE_SHOT)
	inner.add_child(chat)
	sc.add_child(inner)
	vb.add_child(sc)
	m.add_child(vb)
	ov.add_child(m)
	add_child(ov)
	# Bug visual real (auditoría ronda 3): el scroll del chat nunca tenía el
	# arrastre táctil arreglado — una conversación larga podía no scrollear
	# al arrastrar sobre una burbuja de mensaje.
	UiScroll.make_touch(sc)

func _invite_block(invite: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var sep := HSeparator.new()
	box.add_child(sep)

	var is_benefit: bool = String(invite.get("kind", "social")) == "benefit"
	var title := Label.new()
	title.text = "%s  Te invita a: %s" % ["🎁" if is_benefit else "🤝", String(invite.get("title", ""))]
	title.add_theme_font_override("font", Styles.font_semibold())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	var desc := Label.new()
	desc.text = String(invite.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	desc.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	box.add_child(desc)

	var cost := Label.new()
	cost.text = "Cuesta %d de energía" % int(invite.get("stamina", 0))
	cost.add_theme_color_override("font_color", Styles.AMBER)
	cost.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	box.add_child(cost)

	var done: bool = SocialEngine.event_done(WorldTickEngine.season, String(invite["id"]), _day)
	var can: bool = SocialEngine.can_accept(_player, invite)
	if done:
		var d := Button.new()
		d.custom_minimum_size = Vector2(0, 46)
		d.text = "Ya respondiste esta semana"
		d.disabled = true
		Styles.styled_button(d, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
		box.add_child(d)
		return box
	# Fila con ACEPTAR y RECHAZAR (pedido de Wilber: siempre las dos).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var acc := Button.new()
	acc.custom_minimum_size = Vector2(0, 46)
	acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not can:
		acc.text = "Sin energía"
		acc.disabled = true
		Styles.styled_button(acc, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
	else:
		acc.text = "Aceptar"
		Styles.styled_button(acc, Styles.pill_filled(Styles.GREEN), Color.BLACK)
		acc.pressed.connect(_on_accept_event.bind(String(invite["id"])))
	row.add_child(acc)
	var rej := Button.new()
	rej.custom_minimum_size = Vector2(0, 46)
	rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rej.text = "Rechazar"
	rej.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(rej, Styles.pill_outlined(Styles.RED), Styles.RED)
	rej.pressed.connect(_on_reject_event.bind(String(invite["id"])))
	row.add_child(rej)
	box.add_child(row)
	return box

func _close_thread_overlay() -> void:
	var ov := get_node_or_null("ThreadOverlay")
	if ov != null and is_instance_valid(ov):
		ov.queue_free()

func _on_accept_event(event_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var res: Dictionary = SocialEngine.accept_event(_player, WorldTickEngine.season, event_id, _day, rng)
	if not res.get("ok", false):
		return
	SaveManager.save_player(_player)
	SaveManager.save_season(WorldTickEngine.season)
	_close_thread_overlay()
	_refresh_header()
	_render()
	# El mensaje de accept_event() dice EXACTO qué recibiste (plata,
	# reputación, ítem...) pero se descartaba sin mostrarlo en ningún lado
	# -- aceptabas un "regalo" y nunca te enterabas de qué era. Reportado
	# por Wilber.
	var msg: String = String(res.get("message", ""))
	if msg != "":
		var dlg := AcceptDialog.new()
		dlg.dialog_text = msg
		dlg.title = "Listo"
		add_child(dlg)
		dlg.confirmed.connect(dlg.queue_free)
		dlg.canceled.connect(dlg.queue_free)
		dlg.popup_centered()

func _on_reject_event(event_id: String) -> void:
	SocialEngine.reject_event(WorldTickEngine.season, event_id, _day)
	SaveManager.save_season(WorldTickEngine.season)
	_close_thread_overlay()
	_refresh_header()
	_render()

func _role_tint(role: String) -> Color:
	match role:
		"agent": return Styles.GOLD
		"coach": return Styles.BLUE
		"teammate": return Styles.GREEN
		"sponsor": return Styles.PURPLE
		"rival": return Styles.RED
		_: return Styles.BLUE

func _role_label(role: String) -> String:
	match role:
		"agent": return "Representante"
		"coach": return "Entrenador"
		"teammate": return "Compañero"
		"sponsor": return "Patrocinador"
		"rival": return "Tu rival"
		_: return "Contacto"

# --- Perfil ---

func _render_profile() -> void:
	var bonus: int = int(WorldTickEngine.season.get("social", {}).get("bonus_followers", 0))
	detail_box.add_child(Styles.section_label("CUENTA"))
	var acc := _card(Styles.BLUE)
	var acc_c: VBoxContainer = acc.get_child(0).get_child(0)
	acc_c.add_child(_row("Usuario", SocialEngine.handle_for(_player)))
	acc_c.add_child(_row("Seguidores", SocialEngine.followers_label(SocialEngine.followers(_player, bonus))))
	acc_c.add_child(_row("Reputación", "%d/100" % _player.reputation))
	detail_box.add_child(acc)

	detail_box.add_child(Styles.section_label("LO QUE TE HACE TENDENCIA"))
	var hi := _card(Styles.GOLD)
	var hi_c: VBoxContainer = hi.get_child(0).get_child(0)
	hi_c.add_child(_row("Goles de carrera", str(_player.career_goals)))
	hi_c.add_child(_row("Asistencias de carrera", str(_player.career_assists)))
	hi_c.add_child(_row("Títulos", str(_player.trophies_won)))
	hi_c.add_child(_row("Partidos", str(_player.career_matches)))
	detail_box.add_child(hi)

# --- helpers ---

func _tint(key: String) -> Color:
	match key:
		"GREEN": return Styles.GREEN
		"RED": return Styles.RED
		"GOLD": return Styles.GOLD
		"AMBER": return Styles.AMBER
		"PURPLE": return Styles.PURPLE
		_: return Styles.BLUE

func _compact(n: int) -> String:
	if n >= 1000:
		return "%.1f k" % (n / 1000.0)
	return str(n)

func _card(accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)
	panel.add_child(margin)
	return panel

func _row(label: String, value: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", Styles.font_semibold())
	hb.add_child(l)
	hb.add_child(v)
	return hb


# ---------------------------------------------------------------- horizontal
## HORIZONTAL: como una app de verdad. Izquierda tu perfil (cara, @usuario,
## seguidores, energía) y el menú; derecha el feed.
var _side_card: PanelContainer = null

func _landscape_app() -> void:
	if get_viewport_rect().size.x <= get_viewport_rect().size.y or _player == null:
		return
	var vbox := $Margin/VBox as VBoxContainer
	var tabs := feed_tab_button.get_parent() as Control
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)
	vbox.move_child(body, tabs.get_index())
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 270
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	_side_card = PanelContainer.new()
	side.add_child(_side_card)
	var names := {"feed": "  Para ti", "post": "  Publicar", "messages": "  Mensajes", "profile": "  Perfil"}
	for key in ["feed", "post", "messages", "profile"]:
		var b: Button = {"feed": feed_tab_button, "post": post_tab_button, "messages": messages_tab_button, "profile": profile_tab_button}[key]
		b.reparent(side)
		b.size_flags_horizontal = Control.SIZE_FILL
		b.custom_minimum_size = Vector2(0, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tabs.visible = false
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(sp)
	back_button.reparent(side)
	back_button.custom_minimum_size = Vector2(0, 40)
	scroll.reparent(body)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_label.visible = false
	sub_label.visible = false

func _fill_side_card(followers: int) -> void:
	for c in _side_card.get_children():
		c.queue_free()
	var sb := Styles.card_flat(Color(0.1, 0.11, 0.14, 0.95), 14)
	sb.border_width_top = 4
	sb.border_color = Color("#1d9bf0")
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_side_card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(Styles.portrait_frame(_M3D.portrait(_player, null, 48), 48, Color("#1d9bf0")))
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := Label.new()
	nm.text = _player.player_name
	nm.clip_text = true
	nm.add_theme_font_override("font", Styles.font_semibold())
	nm.add_theme_font_size_override("font_size", 16)
	nv.add_child(nm)
	var hd := Label.new()
	hd.text = SocialEngine.handle_for(_player)
	hd.add_theme_font_size_override("font_size", 12)
	hd.add_theme_color_override("font_color", Color("#7cc4ff"))
	nv.add_child(hd)
	top.add_child(nv)
	v.add_child(top)
	var fl := Label.new()
	fl.text = "%s seguidores" % SocialEngine.followers_label(followers)
	fl.add_theme_font_override("font", Styles.font_black())
	fl.add_theme_font_size_override("font_size", 20)
	v.add_child(fl)
	var en: int = SocialEngine.energy(_player)
	var el := Label.new()
	el.text = "Energía para publicar  %d/100" % en
	el.add_theme_font_size_override("font_size", 11)
	el.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	v.add_child(el)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = en
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#1d9bf0")
	fill.set_corner_radius_all(3)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.08)
	bgs.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bgs)
	v.add_child(bar)
	_side_card.add_child(v)
