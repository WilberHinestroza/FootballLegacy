extends Control
class_name Transfers

## Pantalla de Fichajes (pedido explícito). 3 viñetas:
##   Mis ofertas — ofertas de otros clubes por vos (pueden llegar FUERA de
##     la ventana). Aceptás/rechazás; la aceptada se concreta sola al abrir
##     la ventana más cercana (ver TransferOfferEngine.gd).
##   Mercado — los traspasos del mundo esta temporada (TransferMarketEngine).
##   Cesiones — los préstamos del mundo esta temporada.
## Solo lectura salvo aceptar/rechazar tus ofertas. Nada se simula acá.

@onready var window_label: Label = $Margin/VBox/WindowLabel
@onready var offers_tab_button: Button = $Margin/VBox/TabsRow/OffersTabButton
@onready var market_tab_button: Button = $Margin/VBox/TabsRow/MarketTabButton
@onready var loans_tab_button: Button = $Margin/VBox/TabsRow/LoansTabButton
@onready var detail_box: VBoxContainer = $Margin/VBox/Scroll/DetailBox
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var back_button: Button = $Margin/VBox/BackButton

## Pestaña a abrir al entrar, fijada por el caller ANTES de cambiar de
## escena (ej. Agent.gd: "Explorar mercados internacionales") — mismo
## patrón de una sola dirección que Placeholder.gd. Se consume y
## resetea en _ready() para no quedar pegada en visitas futuras.
static var open_tab: String = ""

var _player: PlayerData = null
var _world: Dictionary = {}
var _tab: String = "offers"
var _show_loan_picker: bool = false   # forzado tras un veredicto "loan"
var _last_verdict: Dictionary = {}    # respuesta del club al último pedido
## FILTROS del mercado (11-oct, Wilber: "agregar un filtro de edad, valor y
## así"). Se recuerdan mientras la pantalla esté abierta.
var _f_pos: String = ""       # "" = todas | GK | DF | MF | ST
var _f_age: String = ""       # "" | "u21" | "prime" | "vet"
var _f_fee: String = ""       # "" | "low" | "mid" | "high" | "top"
var _f_sort: String = "recent"  # recent | fee | overall
const _F_POS := [["Posición", ""], ["Arqueros", "GK"], ["Defensas", "DF"], ["Medios", "MF"], ["Delanteros", "ST"]]
const _F_AGE := [["Edad", ""], ["Hasta 21", "u21"], ["22 a 28", "prime"], ["29 o más", "vet"]]
const _F_FEE := [["Valor", ""], ["Menos de 1M", "low"], ["1M a 10M", "mid"], ["10M a 50M", "high"], ["Más de 50M", "top"]]
const _F_SORT := [["Recientes", "recent"], ["Más caros", "fee"], ["Mejor media", "overall"]]

func _filter_pick(options: Array, current: String, on_pick: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.custom_minimum_size = Vector2(0, 40)
	ob.clip_text = true
	ob.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	for i in range(options.size()):
		ob.add_item(String(options[i][0]), i)
		if String(options[i][1]) == current:
			ob.select(i)
	ob.item_selected.connect(func(idx: int):
		on_pick.call(String(options[idx][1]))
		_render())
	return ob

## ¿El fichaje pasa los filtros? (fee/valor en MILES de euro.)
func _passes_filters(t: Dictionary) -> bool:
	if _f_pos != "" and String(t.get("position", "")) != _f_pos:
		return false
	var age: int = int(t.get("age", 0))
	match _f_age:
		"u21":
			if age > 21: return false
		"prime":
			if age < 22 or age > 28: return false
		"vet":
			if age < 29: return false
	var worth: int = int(t.get("value", t.get("fee", 0)))
	match _f_fee:
		"low":
			if worth >= 1000: return false
		"mid":
			if worth < 1000 or worth >= 10000: return false
		"high":
			if worth < 10000 or worth >= 50000: return false
		"top":
			if worth < 50000: return false
	return true

func _ready() -> void:
	WorldTickEngine.load_runtime()
	_player = SaveManager.load_player()
	_world = WorldTickEngine.world if not WorldTickEngine.world.is_empty() else WorldFactory.build(SaveManager.load_world_seed())
	if open_tab != "":
		_tab = open_tab
		open_tab = ""

	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/CareerMenu/CareerMenu.tscn"))

	offers_tab_button.pressed.connect(_on_tab.bind("offers"))
	market_tab_button.pressed.connect(_on_tab.bind("market"))
	loans_tab_button.pressed.connect(_on_tab.bind("loans"))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	var open: bool = WorldTickEngine.is_transfer_window_open()
	if open:
		window_label.text = "Ventana de fichajes ABIERTA"
		window_label.add_theme_color_override("font_color", Styles.GREEN)
	else:
		var d: int = WorldTickEngine.next_transfer_window_day() - WorldTickEngine.current_epoch_day
		window_label.text = "Ventana cerrada · abre en %d días" % maxi(d, 0)
	_build_hero(open)

	_render()

## Cabecera héroe con el emblema del mercado (P1b, 9-oct: logos de
## fichajes). Reemplaza título + renglón de ventana sueltos.
func _build_hero(open: bool) -> void:
	var title := get_node_or_null("Margin/VBox/TitleLabel") as Label
	var emblem := Icons.make_rect("res://assets/ui/transfer_market.png", 64)
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var chips: Array = [["VENTANA ABIERTA", Styles.GREEN] if open else ["VENTANA CERRADA", Styles.GRAY_TEXT]]
	if DeadlineDayEngine.is_deadline_day(WorldTickEngine.current_epoch_day, WorldTickEngine.season):
		chips.append(["DEADLINE DAY", Styles.RED])
	if not _player.boot_deal.is_empty() or not _player.sponsor.is_empty():
		chips.append(["CON PATROCINIO", Styles.GOLD])
	var hero := UiKit.hero(Styles.GOLD, emblem, "Mercado de fichajes", window_label.text, chips)
	var vb := window_label.get_parent()
	vb.add_child(hero)
	vb.move_child(hero, window_label.get_index())
	window_label.visible = false
	if title != null:
		title.visible = false
	(func():
		UiKit.hero_sidebar(hero, 280.0)
		_land_sidebar(hero)).call_deferred()

## Horizontal: fondo del club y, debajo del emblema, tu situación y el pulso
## del mercado (antes la barra izquierda quedaba medio vacía).
func _land_sidebar(hero: Control) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y or hero.get_parent() == null:
		return
	var left := hero.get_parent() as VBoxContainer
	var club := WorldFactory.find_club(_world, _player.club_id)
	var base: Color = Color(club.primary_color_hex) if club != null and club.primary_color_hex != "" else Styles.GREEN
	var bd := UiKit.club_backdrop(base)
	add_child(bd)
	move_child(bd, 0)
	# Tu situación
	var me := VBoxContainer.new()
	me.add_theme_constant_override("separation", 3)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	if club != null:
		var cr := Styles.club_crest(_player.club_id, 30)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(cr)
	var cn := UiKit.tile_text(club.club_name if club != null else "Sin club", 14, Color.WHITE, true)
	cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cn)
	me.add_child(top)
	for kv in [["Contrato", "%d temporada%s" % [_player.contract_years_remaining, "" if _player.contract_years_remaining == 1 else "s"]],
			["Sueldo", CurrencyFormat.format(_player.wage)],
			["Valor", CurrencyFormat.format(_player.market_value)]]:
		me.add_child(_side_kv(String(kv[0]), String(kv[1])))
	left.add_child(UiKit.tile("Tu situación", base.lightened(0.2), me, Callable(), 96))
	# El mercado esta temporada
	var ss: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var today: int = WorldTickEngine.current_epoch_day
	var moved: Array = TransferMarketEngine.season_transfers_cached(_world, WorldTickEngine.world_seed, ss).filter(func(t): return int(t.get("day", 0)) <= today)
	var buys := 0
	var top_t: Dictionary = {}
	for t in moved:
		if String(t.get("kind", "compra")) != "cesión":
			buys += 1
			if top_t.is_empty() or int(t.get("fee", 0)) > int(top_t.get("fee", 0)):
				top_t = t
	var mk := VBoxContainer.new()
	mk.add_theme_constant_override("separation", 3)
	mk.add_child(_side_kv("Traspasos", str(buys)))
	mk.add_child(_side_kv("Cesiones", str(moved.size() - buys)))
	if not top_t.is_empty():
		mk.add_child(UiKit.tile_text("El más caro", 11, Styles.GRAY_TEXT))
		mk.add_child(UiKit.tile_text("%s · %s" % [String(top_t.get("player_name", "?")), CurrencyFormat.format(int(top_t.get("fee", 0)))], 13, Styles.GOLD, true))
	left.add_child(UiKit.tile("El mercado", Styles.GOLD, mk, func(): _on_tab("market"), 96))

func _side_kv(k: String, v: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	var a := UiKit.tile_text(k, 12, Styles.GRAY_TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	var b := UiKit.tile_text(v, 13, Color.WHITE, true)
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	r.add_child(b)
	return r

func _on_tab(t: String) -> void:
	_tab = t
	_render()

func _refresh_tabs() -> void:
	for pair in [[offers_tab_button, "offers"], [market_tab_button, "market"], [loans_tab_button, "loans"]]:
		if pair[1] == _tab:
			Styles.tab(pair[0], true)
		else:
			Styles.tab(pair[0], false)

func _render() -> void:
	# Horizontal: el héroe va en la barra izquierda (UiKit.hero_sidebar) y el
	# detalle ocupa la derecha en una sola columna ancha.
	_refresh_tabs()
	for c in detail_box.get_children():
		c.queue_free()
	match _tab:
		"market":
			_render_world(false)
		"loans":
			_render_world(true)
		_:
			_render_offers()
	UiScroll.pad_bottom(detail_box)

# --- Mis ofertas ---

func _render_offers() -> void:
	_render_precontract()
	var pending: Dictionary = TransferOfferEngine.pending(WorldTickEngine.season)
	if not pending.is_empty():
		detail_box.add_child(Styles.section_label("ACORDADO — SE CONCRETA EN LA VENTANA"))
		detail_box.add_child(_offer_card(pending, true))

	# Cesión activa: aviso de vuelta.
	var lr: Dictionary = LoanEngine.return_target(WorldTickEngine.season)
	if not lr.is_empty():
		var back := Label.new()
		back.text = "Estás cedido. Al final de la temporada volvés a %s." % String(lr.get("parent_club_name", "tu club"))
		back.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		back.add_theme_color_override("font_color", Styles.PURPLE)
		detail_box.add_child(back)

	# Pedir salida del club — presidente + técnico lo evalúan (pedido de
	# Wilber). Si el club abre la veda, empiezan a llegar ofertas seguido.
	if _player != null:
		var req_active: Dictionary = TransferRequestEngine.active(WorldTickEngine.season, WorldTickEngine.current_epoch_day)
		if not req_active.is_empty():
			detail_box.add_child(_request_status_block(req_active))
		elif TransferRequestEngine.can_request(_player, WorldTickEngine.season, WorldTickEngine.current_epoch_day):
			detail_box.add_child(_request_exit_block())

	# Elegir club para la cesión (tras un veredicto "loan", o el pedido
	# clásico de juvenil que no juega — salvo que lo hayas descartado).
	var loan_hidden: bool = int(WorldTickEngine.current_epoch_day / 7.0) < int(WorldTickEngine.season.get("loan_offer_hidden_until_week", -999))
	var club_wants_loan: bool = WorldTickEngine.season.has("club_loan_offer")
	if _player != null and (club_wants_loan or _show_loan_picker or (not loan_hidden and LoanEngine.can_request(_player, WorldTickEngine.season, WorldTickEngine.current_epoch_day))):
		detail_box.add_child(_loan_request_block(club_wants_loan))

	var inbox: Array = TransferOfferEngine.inbox(WorldTickEngine.season)
	if inbox.is_empty() and pending.is_empty():
		var e := Label.new()
		e.text = "No tenés ofertas de otros clubes ahora mismo."
		UiKit.empty_icon(e, Icons.PX_TRANSFERS)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)
		return
	if not inbox.is_empty():
		detail_box.add_child(Styles.section_label("OFERTAS RECIBIDAS"))
		for o in inbox:
			detail_box.add_child(_offer_card(o, false))

## Precontrato (PreContractEngine): la oferta para irte libre a final de
## temporada, o el aviso de que ya lo firmaste.
func _render_precontract() -> void:
	var season: Dictionary = WorldTickEngine.season
	var today: int = WorldTickEngine.current_epoch_day
	var signed_pc: Dictionary = PreContractEngine.signed(season)
	var o: Dictionary = signed_pc if not signed_pc.is_empty() else PreContractEngine.offer(season)
	if o.is_empty():
		return
	var is_signed: bool = not signed_pc.is_empty()
	detail_box.add_child(Styles.section_label("PRECONTRATO FIRMADO" if is_signed else "OFERTA DE PRECONTRATO"))
	var accent: Color = Styles.GREEN if is_signed else Styles.BLUE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var m := MarginContainer.new()
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]: m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	var cid: String = String(o.get("from_club_id", ""))
	if cid != "":
		var crest := Styles.club_crest(cid, 24)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head_row.add_child(crest)
	var head := Label.new()
	head.text = "%s  ·  Llegas libre en verano" % String(o.get("from_club_name", "?"))
	head.add_theme_font_override("font", Styles.font_semibold())
	head.add_theme_color_override("font_color", accent)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	v.add_child(head_row)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 3)
	_term_kv(g, "Sueldo", "%s / temporada" % CurrencyFormat.format(int(o.get("wage", 0))))
	_term_kv(g, "Contrato", "%d años" % int(o.get("contract_years", 3)))
	_term_kv(g, "Rol", String(o.get("role", "-")).capitalize())
	_term_kv(g, "Traspaso", "Ninguno (libre)")
	_term_kv(g, "Prima de fichaje", CurrencyFormat.format(int(o.get("signing_bonus", 0))))
	v.add_child(g)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	if is_signed:
		note.text = "Al terminar la temporada se acaba tu contrato y te vas a %s. Hasta entonces no llegan más ofertas." % String(o.get("from_club_name", "tu nuevo club"))
		note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		v.add_child(note)
	else:
		note.text = "Tu club se enterará: %d de confianza del DT y la afición se enfría (%d). Las demás ofertas se caen." % [PreContractEngine.TRUST_COST, PreContractEngine.FAN_COST]
		note.add_theme_color_override("font_color", Styles.AMBER)
		v.add_child(note)
		var dl: int = PreContractEngine.days_left(o, today)
		var chips := HFlowContainer.new()
		chips.add_child(UiKit.chip("Vence en %d día%s" % [maxi(dl, 0), "" if dl == 1 else "s"], Styles.RED if dl <= 3 else Styles.GRAY_TEXT))
		v.add_child(chips)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var acc := Button.new()
		acc.custom_minimum_size = Vector2(0, 44)
		acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		acc.text = "Firmar precontrato"
		Styles.styled_button(acc, Styles.pill_filled(Styles.GREEN), Color.BLACK)
		acc.pressed.connect(func():
			PreContractEngine.accept(_player, WorldTickEngine.season)
			SaveManager.save_player(_player)
			SaveManager.save_season(WorldTickEngine.season)
			Nav.toast("Precontrato firmado. En verano te vas libre.")
			_render())
		var rej := Button.new()
		rej.custom_minimum_size = Vector2(0, 44)
		rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rej.text = "Rechazar"
		Styles.styled_button(rej, Styles.pill_outlined(Styles.RED), Styles.RED)
		rej.pressed.connect(func():
			PreContractEngine.reject(WorldTickEngine.season)
			SaveManager.save_season(WorldTickEngine.season)
			_render())
		row.add_child(acc)
		row.add_child(rej)
		v.add_child(row)
	m.add_child(v)
	panel.add_child(m)
	detail_box.add_child(panel)

## Bloque "¿Querés salir del club?": botón para pedirlo + la respuesta del
## presidente y el técnico (si ya se pidió esta sesión de pantalla).
func _request_exit_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Styles.section_label("¿QUERÉS SALIR DEL CLUB?"))
	var intro := Label.new()
	intro.text = "Podés pedirle al club que te deje salir. El presidente y el técnico lo evalúan: puede que abran la puerta a ofertas, que te dejen salir cedido, o que prefieran retenerte."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	intro.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	box.add_child(intro)

	if not _last_verdict.is_empty():
		var panel := PanelContainer.new()
		var vcol: String = "listen"
		var accent: Color = Styles.GOLD
		match String(_last_verdict.get("decision", "")):
			"stay": accent = Styles.RED
			"loan": accent = Styles.PURPLE
			_: accent = Styles.GREEN
		panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
		var m := MarginContainer.new()
		for s in ["left", "right"]:
			m.add_theme_constant_override("margin_" + s, 12)
		for s in ["top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 10)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.add_child(_verdict_line("Técnico", String(_last_verdict.get("coach", "")), accent))
		col.add_child(_verdict_line("Presidente", String(_last_verdict.get("president", "")), accent))
		var sm := Label.new()
		sm.text = String(_last_verdict.get("summary", ""))
		sm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sm.add_theme_font_override("font", Styles.font_semibold())
		sm.add_theme_color_override("font_color", accent)
		col.add_child(sm)
		m.add_child(col)
		panel.add_child(m)
		box.add_child(panel)
		return box

	var btn := Button.new()
	btn.text = "Pedir salir del club"
	btn.custom_minimum_size = Vector2(0, 46)
	btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(btn, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	btn.pressed.connect(_on_request_exit)
	box.add_child(btn)
	return box

func _verdict_line(who: String, text: String, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = who
	k.custom_minimum_size = Vector2(78, 0)
	k.add_theme_font_size_override("font_size", 11)
	k.add_theme_color_override("font_color", accent)
	row.add_child(k)
	var v := Label.new()
	v.text = text
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	row.add_child(v)
	return row

func _on_request_exit() -> void:
	if _player == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var club_bo: int = int(_world.get("club_meta_by_id", {}).get(_player.club_id, {}).get("base_overall", 60))
	var v: Dictionary = TransferRequestEngine.evaluate(_player, club_bo, WorldTickEngine.season, WorldTickEngine.current_epoch_day, rng)
	_last_verdict = v
	match String(v.get("decision", "")):
		"listen":
			TransferRequestEngine.grant_listen(WorldTickEngine.season, WorldTickEngine.current_epoch_day)
			# Una primera oferta al toque para que se note.
			_try_generate_offer()
			SaveManager.save_season(WorldTickEngine.season)
		"loan":
			_show_loan_picker = true
		"stay":
			TransferRequestEngine.mark_denied(WorldTickEngine.season, WorldTickEngine.current_epoch_day)
			if bool(v.get("offer_improvement", false)) and _player.pending_wage_offer.is_empty():
				var wo: Dictionary = WageOfferEngine.generate_offer(_player, WorldTickEngine.user_league_position_ratio())
				if not wo.is_empty():
					wo["reason"] = "retention"
					_player.pending_wage_offer = wo
					SaveManager.save_player(_player)
			SaveManager.save_season(WorldTickEngine.season)
	_render()

## Estado del pedido en curso: cuántas semanas de "veda abierta" quedan +
## botón para retirarlo.
func _request_status_block(req: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(Styles.section_label("PEDISTE SALIR — VEDA ABIERTA"))
	var wk_now: int = int(WorldTickEngine.current_epoch_day / 7.0)
	var weeks_left: int = maxi(0, int(req.get("expires_week", 0)) - wk_now)
	var l := Label.new()
	l.text = "El club dejó que lleguen ofertas. Quedan ~%d semana%s de puerta abierta; van a llegar propuestas más seguido." % [
		weeks_left, "" if weeks_left == 1 else "s"]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Styles.GREEN)
	l.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	box.add_child(l)
	var btn := Button.new()
	btn.text = "Retirar el pedido"
	btn.custom_minimum_size = Vector2(0, 42)
	btn.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(btn, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
	btn.pressed.connect(func():
		TransferRequestEngine.withdraw(WorldTickEngine.season)
		SaveManager.save_season(WorldTickEngine.season)
		_last_verdict = {}
		_render())
	box.add_child(btn)
	return box

## Genera UNA oferta ya (usada al conceder el pedido, y al vaciar el inbox
## con la veda abierta) — mismo canal que el tick semanal.
func _try_generate_offer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var offer: Dictionary = TransferOfferEngine.generate_offer(
		_player, _world, WorldTickEngine.world_seed, WorldTickEngine.current_epoch_day,
		WorldTickEngine.next_transfer_window_day(), rng, WorldTickEngine.season)
	if not offer.is_empty():
		TransferOfferEngine.add_to_inbox(WorldTickEngine.season, offer, WorldTickEngine.current_epoch_day)

## Bloque "Pedir salir a préstamo": 3 clubes candidatos, elegís uno y se
## pacta la cesión para la próxima ventana.
func _loan_request_block(club_initiated: bool = false) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head_row := HBoxContainer.new()
	var head_lbl := Styles.section_label("TU CLUB QUIERE CEDERTE" if club_initiated else "PEDIR SALIR A PRÉSTAMO")
	head_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head_lbl)
	# X roja para descartar de un toque, sin tener que bajar hasta el
	# final de la lista de candidatos — pedido de Wilber.
	head_row.add_child(_small_reject_button(_dismiss_loan_offer.bind(club_initiated)))
	box.add_child(head_row)
	var intro := Label.new()
	intro.text = ("El club quiere que salgas cedido una temporada para sumar minutos. Elegí el destino (o quedate):" if club_initiated \
		else "Sos joven y no estás jugando. Podés salir cedido una temporada para sumar minutos. Elegí el club:")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	intro.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	box.add_child(intro)

	var cands: Array = LoanEngine.candidates(_player, _world, WorldTickEngine.world_seed, WorldTickEngine.current_epoch_day)
	if cands.is_empty():
		var none := Label.new()
		none.text = "Ningún club encaja ahora mismo. Probá más adelante."
		none.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		box.add_child(none)
		return box

	for c in cands:
		var cid: String = String(c["club_id"])
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.PURPLE))
		var m := MarginContainer.new()
		for s in ["left", "right"]:
			m.add_theme_constant_override("margin_" + s, 12)
		for s in ["top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 10)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var crest := Styles.club_crest(cid, 30)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crest)
		var c_ctry: String = _club_country(WorldFactory.find_club(_world, cid))
		var c_fr: TextureRect = CountryFlags.flag_rect(c_ctry, 16) if c_ctry != "" else null
		if c_fr != null:
			c_fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(c_fr)
		var nm := Label.new()
		nm.text = "%s  ·  nivel %d%s" % [String(c["club_name"]), int(c["ovr"]), ("  ·  " + c_ctry) if c_ctry != "" else ""]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nm)
		var pick := Button.new()
		pick.text = "Elegir"
		pick.custom_minimum_size = Vector2(84, 40)
		pick.focus_mode = Control.FOCUS_NONE
		Styles.styled_button(pick, Styles.pill_filled(Styles.PURPLE), Color.WHITE)
		pick.pressed.connect(_on_loan_pick.bind(cid, String(c["club_name"])))
		row.add_child(pick)
		m.add_child(row)
		panel.add_child(m)
		box.add_child(panel)

	# Salida: no salir cedido ahora. Si lo propuso el club, rechazarlo
	# cuesta un poco de confianza del DT.
	var dismiss := Button.new()
	dismiss.text = "Prefiero quedarme" if club_initiated else "No quiero salir cedido ahora"
	dismiss.custom_minimum_size = Vector2(0, 40)
	dismiss.focus_mode = Control.FOCUS_NONE
	Styles.styled_button(dismiss, Styles.pill_outlined(Styles.GRAY_TEXT), Styles.GRAY_TEXT)
	dismiss.pressed.connect(_dismiss_loan_offer.bind(club_initiated))
	box.add_child(dismiss)
	return box

## Descartar la oferta/pedido de cesión — comparte el botón de texto de
## siempre y la X roja de la esquina (_loan_request_block).
func _dismiss_loan_offer(club_initiated: bool) -> void:
	var wk: int = int(WorldTickEngine.current_epoch_day / 7.0)
	WorldTickEngine.season["loan_offer_hidden_until_week"] = wk + 6
	if WorldTickEngine.season.has("club_loan_offer"):
		WorldTickEngine.season.erase("club_loan_offer")
		WorldTickEngine.season["club_loan_cooldown_week"] = wk + 8
		if _player != null:
			_player.coach_trust = clampi(_player.coach_trust - 2, 0, 100)
			SaveManager.save_player(_player)
	SaveManager.save_season(WorldTickEngine.season)
	_show_loan_picker = false
	# Bug real de la auditoría: sin esto, el panel de veredicto ("Te dejan
	# salir a préstamo...") quedaba pegado en pantalla para siempre — ya sin
	# selector de club (se acaba de ocultar arriba) y sin forma de volver a
	# pedir salida (el botón para eso solo aparece si _last_verdict está
	# vacío, ver _request_exit_block).
	_last_verdict = {}
	_render()

func _on_loan_pick(club_id: String, club_name: String) -> void:
	var res: Dictionary = LoanEngine.request(
		_player, WorldTickEngine.season, club_id, club_name,
		WorldTickEngine.current_epoch_day, WorldTickEngine.next_transfer_window_day())
	if bool(res.get("ok", false)):
		WorldTickEngine.season.erase("club_loan_offer")
		SaveManager.save_season(WorldTickEngine.season)
	_show_loan_picker = false
	_last_verdict = {}  # mismo fix que _dismiss_loan_offer: no dejar el panel atascado
	_render()

## Fila "etiqueta gris → valor" para la ficha de la oferta.
func _term_kv(grid: GridContainer, key: String, value: String) -> void:
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 10)
	k.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	grid.add_child(k)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	grid.add_child(val)

## Abre el regateo (ContractNegotiation) para una oferta de traspaso. Al
## acordar, se actualizan los términos y la oferta pasa a PENDIENTE.
func _open_offer_negotiation(o: Dictionary) -> void:
	var from_club := WorldFactory.find_club(_world, String(o.get("from_club_id", "")))
	var neg := ContractNegotiation.new()
	neg.setup({
		"club_id": String(o.get("from_club_id", "")),
		"club_name": String(o.get("from_club_name", "?")),
		"pres_name": (from_club.club_name + " · dirección deportiva") if from_club != null else "El club",
		"base_wage": int(o.get("wage", 0)),
		"base_years": int(o.get("contract_years", 3)),
		"agent_stars": _player.agent_stars if _player != null else 3,
		"allow_reject": true,
		"player": _player,
	})
	neg.agreed.connect(func(terms: Dictionary):
		TransferOfferEngine.update_offer_terms(WorldTickEngine.season, String(o.get("id", "")), terms)
		TransferOfferEngine.accept(WorldTickEngine.season, String(o.get("id", "")))
		SaveManager.save_season(WorldTickEngine.season)
		if is_instance_valid(neg): neg.queue_free()
		_tab = "offers"
		_render())
	neg.rejected.connect(func():
		if is_instance_valid(neg): neg.queue_free()
		# Bug real de la auditoría: acá solo se cerraba el overlay y se
		# volvía a renderizar — la oferta seguía intacta en el inbox, como
		# si "Rechazar la oferta" no hubiera hecho nada.
		_reject_offer(o))
	add_child(neg)

## País de un club (vía la liga a la que pertenece) — para mostrar de
## dónde viene cada oferta (pedido de Wilber).
func _club_country(club: ClubData) -> String:
	if club == null:
		return ""
	for lg in _world.get("leagues", []):
		if lg.league_id == club.league_id:
			return String(lg.country)
	return ""

## X roja chiquita, icono solo — pedido de Wilber: rechazar una oferta (de
## fichaje o de cesión) sin tener que ir a buscar el botón de texto entero.
func _small_reject_button(on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(30, 30)
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = Icons.load_icon(Icons.CROSS)
	btn.add_theme_constant_override("icon_max_width", 14)
	btn.tooltip_text = "Rechazar"
	Styles.styled_button(btn, Styles.pill_outlined(Styles.RED), Styles.RED)
	btn.pressed.connect(on_pressed)
	return btn

## Rechazo de una oferta del inbox — extraído para que lo compartan el
## botón "Rechazar" de siempre y la X roja de la esquina.
func _reject_offer(o: Dictionary) -> void:
	TransferOfferEngine.reject(WorldTickEngine.season, String(o.get("id", "")))
	# Con la veda abierta, si te quedás sin ofertas te llega otra ya (así
	# "rechazar y que lleguen otras" se siente inmediato).
	if TransferOfferEngine.inbox(WorldTickEngine.season).is_empty() \
			and not TransferRequestEngine.active(WorldTickEngine.season, WorldTickEngine.current_epoch_day).is_empty():
		_try_generate_offer()
	SaveManager.save_season(WorldTickEngine.season)
	_render()

func _offer_card(o: Dictionary, is_pending: bool) -> PanelContainer:
	var accent: Color = Styles.GREEN if is_pending else (Styles.PURPLE if String(o.get("kind", "")) == "cesión" else Styles.GOLD)
	var is_gulf: bool = bool(o.get("gulf", false))
	var is_deadline: bool = bool(o.get("deadline", false))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 14)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	var from_id: String = String(o.get("from_club_id", ""))
	var from_country: String = ""
	if from_id != "":
		var crest := Styles.club_crest(from_id, 24)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head_row.add_child(crest)
		var from_club := WorldFactory.find_club(_world, from_id)
		if from_club != null:
			var kit := Kit.build_for_club_kit(from_club, WorldTickEngine.get_season_start_year(), false, 24)
			kit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head_row.add_child(kit)
			from_country = _club_country(from_club)
			var fr: TextureRect = CountryFlags.flag_rect(from_country, 18)
			if fr != null:
				fr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				head_row.add_child(fr)
	var head := Label.new()
	var ctry_txt: String = ("  ·  %s" % from_country) if from_country != "" else ""
	head.text = "%s%s  ·  %s" % [String(o.get("from_club_name", "?")), ctry_txt, String(o.get("kind", "traspaso")).capitalize()]
	head.add_theme_font_override("font", Styles.font_semibold())
	head.add_theme_color_override("font_color", accent)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	# X roja para rechazar de un toque, sin tener que bajar a buscar el
	# botón "Rechazar" — pedido de Wilber (mismo criterio para la oferta
	# de cesión, ver _loan_request_block()).
	if not is_pending:
		head_row.add_child(_small_reject_button(_reject_offer.bind(o)))
	v.add_child(head_row)

	# Ficha de la oferta: sueldo, años, rol, cláusula, traspaso.
	var is_loan_o: bool = String(o.get("kind", "")) == "cesión"
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 3)
	_term_kv(g, "Sueldo", "%s / temporada" % CurrencyFormat.format(int(o.get("wage", 0))))
	_term_kv(g, "Contrato", "%d año%s" % [int(o.get("contract_years", 0)), "" if int(o.get("contract_years", 0)) == 1 else "s"])
	if o.has("role"):
		_term_kv(g, "Rol", String(o.get("role", "-")).capitalize())
	if not is_loan_o:
		_term_kv(g, "Traspaso", CurrencyFormat.format(int(o.get("fee", 0))))
		if int(o.get("release_clause", 0)) > 0:
			_term_kv(g, "Cláusula de rescisión", CurrencyFormat.format(int(o.get("release_clause", 0))))
	else:
		_term_kv(g, "Tipo", "Cesión (sin traspaso)")
	if is_gulf and int(o.get("signing_bonus", 0)) > 0:
		_term_kv(g, "Prima de fichaje", CurrencyFormat.format(int(o.get("signing_bonus", 0))))
	v.add_child(g)
	if is_gulf or is_deadline:
		var tags := HFlowContainer.new()
		tags.add_theme_constant_override("h_separation", 6)
		if is_deadline:
			tags.add_child(UiKit.chip("ÚLTIMO DÍA DE MERCADO", Styles.RED))
		if is_gulf:
			tags.add_child(UiKit.chip("OFERTA MILLONARIA", Styles.GOLD))
		v.add_child(tags)
	if is_gulf:
		var warn := Label.new()
		warn.text = "Cobras como nunca, pero la prensa deportiva lo verá como elegir el dinero: -%d de reputación al firmar. No se negocia: lo tomas o lo dejas." % DeadlineDayEngine.GULF_REP_COST
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_color_override("font_color", Styles.AMBER)
		warn.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(warn)

	if is_pending:
		var note := Label.new()
		note.text = "Se firma al cerrar el día, sobre la bocina." if is_deadline else "Se hará efectivo el día %d (próxima ventana)." % int(o.get("window_day", 0))
		note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		note.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(note)
		var cancel := Button.new()
		cancel.custom_minimum_size = Vector2(0, 44)
		cancel.text = "Cancelar el acuerdo"
		Styles.styled_button(cancel, Styles.pill_outlined(Styles.RED), Styles.RED)
		cancel.pressed.connect(func():
			WorldTickEngine.season.erase("pending_transfer")
			SaveManager.save_season(WorldTickEngine.season)
			_render())
		v.add_child(cancel)
	else:
		var win_note := Label.new()
		win_note.text = "Hay que responder HOY: si aceptas, se firma esta misma noche." if is_deadline else "Si aceptás, se concreta el día %d (próxima ventana)." % int(o.get("window_day", 0))
		win_note.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		win_note.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		v.add_child(win_note)
		# Plazo + contraoferta (P5).
		var today: int = WorldTickEngine.current_epoch_day
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 6)
		if o.has("counter"):
			var rd: int = int(o["counter"].get("respond_day", today)) - today
			chips.add_child(UiKit.chip("Contraoferta enviada (%s) · responden en %d día%s" % [CurrencyFormat.format(int(o["counter"]["wage"])), maxi(rd, 0), "" if rd == 1 else "s"], Styles.BLUE))
		elif is_deadline:
			chips.add_child(UiKit.chip("Vence hoy", Styles.RED))
		else:
			var dl: int = TransferOfferEngine.days_left(o, today)
			chips.add_child(UiKit.chip("Vence en %d día%s" % [maxi(dl, 0), "" if dl == 1 else "s"], Styles.RED if dl <= 3 else Styles.GRAY_TEXT))
		match String(o.get("counter_result", "")):
			"accepted": chips.add_child(UiKit.chip("Aceptaron tu contraoferta", Styles.GREEN))
			"halfway": chips.add_child(UiKit.chip("Se quedaron a mitad de camino", Styles.AMBER))
		v.add_child(chips)
		if TransferOfferEngine.can_counter(o):
			var ctr := Button.new()
			ctr.custom_minimum_size = Vector2(0, 42)
			ctr.focus_mode = Control.FOCUS_NONE
			ctr.text = "  Contraoferta: pedir +%d%% de sueldo" % int(TransferOfferEngine.COUNTER_RAISE * 100.0)
			if ResourceLoader.exists("res://assets/ui/counteroffer.png"):
				ctr.icon = load("res://assets/ui/counteroffer.png")
				ctr.add_theme_constant_override("icon_max_width", 28)
			Styles.styled_button(ctr, Styles.pill_outlined(Styles.BLUE), Styles.BLUE)
			ctr.pressed.connect(func():
				TransferOfferEngine.send_counter(WorldTickEngine.season, String(o.get("id", "")), WorldTickEngine.current_epoch_day)
				SaveManager.save_season(WorldTickEngine.season)
				Nav.toast("Contraoferta enviada. Responden en %d días." % TransferOfferEngine.COUNTER_DAYS)
				_render())
			v.add_child(ctr)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var acc := Button.new()
		acc.custom_minimum_size = Vector2(0, 44)
		acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		acc.text = "Aceptar oferta"
		Styles.styled_button(acc, Styles.pill_filled(Styles.GREEN), Color.BLACK)
		acc.pressed.connect(func():
			TransferOfferEngine.accept(WorldTickEngine.season, String(o.get("id", "")))
			SaveManager.save_season(WorldTickEngine.season)
			_tab = "offers"
			_render())
		var rej := Button.new()
		rej.custom_minimum_size = Vector2(0, 44)
		rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rej.text = "Rechazar"
		Styles.styled_button(rej, Styles.pill_outlined(Styles.RED), Styles.RED)
		rej.pressed.connect(_reject_offer.bind(o))
		row.add_child(acc)
		row.add_child(rej)
		v.add_child(row)
		if not String(o.get("kind", "")) == "cesión" and not is_gulf and not is_deadline:
			var neg := Button.new()
			neg.custom_minimum_size = Vector2(0, 44)
			neg.text = "Rechazar y negociar los términos"
			Styles.styled_button(neg, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
			neg.pressed.connect(_open_offer_negotiation.bind(o))
			v.add_child(neg)

	m.add_child(v)
	panel.add_child(m)
	return panel

# --- Mercado / Cesiones del mundo ---

func _render_world(loans_only: bool) -> void:
	var ss: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	var transfers: Array = TransferMarketEngine.season_transfers_cached(_world, WorldTickEngine.world_seed, ss)
	# Van "pasando" día a día — pedido de Wilber: "en el mercado deben ir
	# pasando fichajes cada día, no que al primer día pase de una todo, y
	# hasta puede haber un bombazo el último día". Cada fichaje ya trae su
	# propio "day" (TransferMarketEngine.generate_season_transfers) — acá
	# solo se ocultan los que todavía no llegaron a su día, y se muestran
	# del más reciente al más viejo.
	var today: int = WorldTickEngine.current_epoch_day
	var all_rows: Array = transfers.filter(func(t): return (String(t.get("kind", "compra")) == "cesión") == loans_only and int(t.get("day", 0)) <= today)
	# Barra de filtros: posición · edad · valor, y el orden.
	if not all_rows.is_empty():
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 6)
		bar.add_child(_filter_pick(_F_POS, _f_pos, func(v): _f_pos = v))
		bar.add_child(_filter_pick(_F_AGE, _f_age, func(v): _f_age = v))
		bar.add_child(_filter_pick(_F_FEE, _f_fee, func(v): _f_fee = v))
		detail_box.add_child(bar)
		var bar2 := HBoxContainer.new()
		bar2.add_theme_constant_override("separation", 6)
		var ol := Label.new()
		ol.text = "Ordenar:"
		ol.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		ol.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
		bar2.add_child(ol)
		bar2.add_child(_filter_pick(_F_SORT, _f_sort, func(v): _f_sort = v))
		detail_box.add_child(bar2)
	var rows: Array = all_rows.filter(_passes_filters)
	match _f_sort:
		"fee":
			rows.sort_custom(func(a, b): return int(a.get("fee", 0)) > int(b.get("fee", 0)))
		"overall":
			rows.sort_custom(func(a, b): return int(a.get("overall", 0)) > int(b.get("overall", 0)))
		_:
			rows.sort_custom(func(a, b): return int(a.get("day", 0)) > int(b.get("day", 0)))
	if rows.is_empty() and not all_rows.is_empty():
		var e2 := Label.new()
		e2.text = "Ningún movimiento coincide con esos filtros (%d en total)." % all_rows.size()
		e2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e2.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e2)
		return
	if rows.is_empty():
		var e := Label.new()
		e.text = "Todavía no hay movimientos para mostrar esta ventana."
		UiKit.empty_icon(e, Icons.PX_TRANSFERS)
		e.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		detail_box.add_child(e)
		return
	var title: String = "CESIONES DEL MUNDO" if loans_only else "TRASPASOS DEL MUNDO"
	if rows.size() != all_rows.size():
		title += "  ·  %d de %d" % [rows.size(), all_rows.size()]
	detail_box.add_child(Styles.section_label(title))
	# 4/hoja (pedido de Wilber): 5 cortaba la última; 3 era muy poco.
	var pager := Pager.new()
	detail_box.add_child(pager)
	pager.show_items(rows, 4, _world_row)

## "8 jul" — mismo criterio compacto que Calendar.gd._short_date, sin
## depender de esa escena.
const _MES_ABBR := ["", "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
func _short_date(epoch_day: int) -> String:
	var d := CalendarUtils.epoch_day_to_date(epoch_day)
	return "%d %s" % [int(d["day"]), _MES_ABBR[int(d["month"])]]

## Carta de fichaje (pedido de Wilber): cara del jugador al centro, club
## de origen a la izquierda y club de destino a la derecha, con flechas
## origen → jugador → destino. Debajo: traspaso y datos del jugador.
func _world_row(t: Dictionary) -> PanelContainer:
	var is_loan: bool = String(t.get("kind", "compra")) == "cesión"
	var accent: Color = Styles.PURPLE if is_loan else Styles.GOLD
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)

	var ovr: int = int(t.get("overall", 0))
	var is_bombazo: bool = not is_loan and ovr >= 84
	if is_bombazo:
		panel.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD, Color(0.16, 0.13, 0.03), 12))
		var hdr := Label.new()
		hdr.text = "★  BOMBAZO DEL MERCADO"
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_override("font", Styles.font_black())
		hdr.add_theme_font_size_override("font_size", 13)
		hdr.add_theme_color_override("font_color", Styles.GOLD)
		v.add_child(hdr)

	var from_c := WorldFactory.find_club(_world, String(t.get("origin_club_id", "")))
	var to_c := WorldFactory.find_club(_world, String(t.get("destination_club_id", "")))
	var pname: String = String(t.get("player_name", "?"))

	var lane := HBoxContainer.new()
	lane.add_theme_constant_override("separation", 6)
	lane.alignment = BoxContainer.ALIGNMENT_CENTER
	lane.add_child(_club_end(from_c, String(t.get("origin_club_id", ""))))
	lane.add_child(_arrow())
	lane.add_child(_player_end(pname, String(t.get("position", "")), int(t.get("overall", 0)), String(t.get("country", ""))))
	lane.add_child(_arrow())
	lane.add_child(_club_end(to_c, String(t.get("destination_club_id", ""))))
	v.add_child(lane)

	var terms := Label.new()
	terms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_loan:
		terms.text = "Cesión de temporada"
	else:
		terms.text = "Traspaso  ·  %s" % CurrencyFormat.format(int(t.get("fee", 0)))
	if int(t.get("age", 0)) > 0:
		terms.text += "  ·  %d años" % int(t["age"])
	terms.add_theme_font_override("font", Styles.font_semibold())
	terms.add_theme_color_override("font_color", accent)
	terms.add_theme_font_size_override("font_size", Styles.SIZE_CAPTION)
	v.add_child(terms)

	if t.has("day"):
		var date_lbl := Label.new()
		date_lbl.text = _short_date(int(t["day"]))
		date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		date_lbl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
		date_lbl.add_theme_font_size_override("font_size", 10)
		v.add_child(date_lbl)

	m.add_child(v)
	panel.add_child(m)
	if is_bombazo:
		# Estrella dorada en la esquina — PanelContainer estira el Label a
		# todo el panel, así que la alineamos arriba-derecha.
		var star := Label.new()
		star.text = "⭐"
		star.add_theme_font_size_override("font_size", 20)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		star.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(star)
	return panel

## Un extremo con escudo + nombre de club (o "Libre" si no hay club).
func _club_end(club, club_id: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(84, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	var cc := CenterContainer.new()
	if club_id != "":
		cc.add_child(Styles.club_crest(club_id, 60))
	else:
		var q := Label.new()
		q.text = "🆓"
		q.add_theme_font_size_override("font_size", 30)
		cc.add_child(q)
	col.add_child(cc)
	var l := Label.new()
	l.text = club.club_name if club != null else "Libre"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	l.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	col.add_child(l)
	return col

## Extremo central: cara Kenney del jugador + nombre + pos/ovr.
func _player_end(pname: String, pos: String, ovr: int, country: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(104, 0)
	col.add_theme_constant_override("separation", 3)
	col.add_child(Styles.portrait_frame(
		Avatar.for_npc(pname, "player", SaveManager.load_world_seed(), 54), 54, Styles.GOLD))
	var n := Label.new()
	n.text = pname
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_override("font", Styles.font_semibold())
	n.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	col.add_child(n)
	var sub := Label.new()
	var pos_es: String = Positions.broad_label(pos) if pos != "" else ""
	sub.text = "%s · %d" % [pos_es, ovr] if pos_es != "" else str(ovr)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	sub.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
	col.add_child(sub)
	return col

func _arrow() -> Label:
	var a := Label.new()
	a.text = "→"
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a.add_theme_color_override("font_color", Styles.GOLD)
	a.add_theme_font_size_override("font_size", 20)
	return a
