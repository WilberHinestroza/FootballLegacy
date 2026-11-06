extends PanelContainer
class_name ChatThread

## Un hilo de DM renderizado como CHAT DE VERDAD: cara del contacto,
## burbujas izquierda (ellos) / derecha (vos), hora relativa, indicador
## "escribiendo…" animado y respuestas rápidas por opción (cosméticas —
## no tocan balance ni esquema). Reutilizable: hoy lo usa Social→Mensajes.
##
## Uso:
##   var t := ChatThread.new()
##   t.setup(thread_dict, player, world_seed)
##   parent.add_child(t)               # arranca la animación al entrar al árbol
##   t.footer.add_child(mi_bloque_invitacion)   # opcional

var _thread: Dictionary = {}
var _player: PlayerData = null
var _seed: int = 0
var _role: String = ""
var _accent: Color = Color.WHITE

var _log: VBoxContainer
var _typing: Control
var _reply_row: HFlowContainer
var footer: VBoxContainer

func setup(thread: Dictionary, player: PlayerData, world_seed: int) -> ChatThread:
	_thread = thread
	_player = player
	_seed = world_seed
	_role = String(thread.get("role", ""))
	_accent = _role_tint(_role)
	return self

func _ready() -> void:
	add_theme_stylebox_override("panel", Styles.card_accent(_accent))
	var margin := MarginContainer.new()
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 12)
	for s in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	# --- Cabecera: cara + nombre + rol + "en línea" ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var contact_name: String = String(_thread.get("contact_name", "Contacto"))
	head.add_child(Styles.portrait_frame(
		Avatar.for_npc(contact_name, _npc_role(_role), _seed, 38), 38, _accent))
	var head_col := VBoxContainer.new()
	head_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_col.add_theme_constant_override("separation", 0)
	var nm := Label.new()
	nm.text = contact_name
	nm.add_theme_font_override("font", Styles.font_semibold())
	head_col.add_child(nm)
	var rl := Label.new()
	rl.text = "%s · en línea" % _role_label(_role)
	rl.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	rl.add_theme_font_size_override("font_size", 11)
	head_col.add_child(rl)
	head.add_child(head_col)
	col.add_child(head)
	col.add_child(HSeparator.new())

	# --- Registro de burbujas ---
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 6)
	col.add_child(_log)

	# --- Indicador "escribiendo…" (se muestra durante la animación) ---
	_typing = _make_typing()
	col.add_child(_typing)

	# --- Respuestas rápidas ---
	_reply_row = HFlowContainer.new()
	_reply_row.add_theme_constant_override("h_separation", 6)
	_reply_row.add_theme_constant_override("v_separation", 6)
	_reply_row.visible = false
	col.add_child(_reply_row)

	# --- Pie (bloque de invitación, lo llena el llamador) ---
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", 4)
	col.add_child(footer)

	_play_intro()

# ---------------------------------------------------------------------------

func _play_intro() -> void:
	var msgs: Array = _thread.get("messages", [])
	var base_min: int = 6 * 60 + (absi(hash(String(_thread.get("contact_name", "")))) % 400)
	for i in range(msgs.size()):
		_typing.visible = true
		await get_tree().create_timer(0.5 + 0.28 * float(i)).timeout
		if not is_inside_tree():
			return
		_typing.visible = false
		var mins_ago: int = maxi(1, base_min - i * 47)
		_log.add_child(_bubble(String(msgs[i].get("text", "")), false, _rel_time(mins_ago)))
	_show_replies()

func _show_replies() -> void:
	var opts: Array = _reply_options(_role)
	for o in opts:
		var b := Button.new()
		b.text = o
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", Styles.SIZE_LABEL)
		Styles.styled_button(b, Styles.pill_outlined(_accent), _accent)
		b.pressed.connect(_on_reply.bind(o))
		_reply_row.add_child(b)
	_reply_row.visible = true

func _on_reply(text: String) -> void:
	for c in _reply_row.get_children():
		(c as Button).disabled = true
	_reply_row.visible = false
	_log.add_child(_bubble(text, true, "ahora"))
	_typing.visible = true
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	_typing.visible = false
	_log.add_child(_bubble(_reply_ack(_role), false, "ahora"))

# ---------------------------------------------------------------------------

func _bubble(text: String, mine: bool, time_text: String) -> Control:
	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN

	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(0, 0)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	var bg: Color = _accent.darkened(0.15) if mine else Styles.CARD_DARK_2
	var sb := Styles.card_flat(bg, 12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	bubble.add_theme_stylebox_override("panel", sb)

	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 2)
	var msg := Label.new()
	msg.text = text
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(180, 0)
	msg.max_lines_visible = -1
	if mine:
		msg.add_theme_color_override("font_color", Styles.contrasting_text_color(bg))
	bcol.add_child(msg)
	var tl := Label.new()
	tl.text = time_text
	tl.add_theme_font_size_override("font_size", 9)
	tl.add_theme_color_override("font_color", Styles.GRAY_TEXT if not mine else Color(1, 1, 1, 0.6))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bcol.add_child(tl)
	bubble.add_child(bcol)

	# Aparición: leve fade + slide.
	bubble.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(bubble, "modulate", Color(1, 1, 1, 1), 0.18)

	line.add_child(bubble)
	return line

func _make_typing() -> Control:
	var wrap := HBoxContainer.new()
	wrap.visible = false
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", Styles.card_flat(Styles.CARD_DARK_2, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	var dots: Array[ColorRect] = []
	for i in range(3):
		var d := ColorRect.new()
		d.color = Styles.GRAY_TEXT
		d.custom_minimum_size = Vector2(5, 5)
		row.add_child(d)
		dots.append(d)
	m.add_child(row)
	pill.add_child(m)
	wrap.add_child(pill)

	# Animación de los 3 puntos (loop mientras el nodo exista).
	var tw := wrap.create_tween().set_loops()
	for i in range(3):
		tw.tween_property(dots[i], "modulate:a", 0.25, 0.18)
		tw.tween_property(dots[i], "modulate:a", 1.0, 0.18)
	return wrap

# ---------------------------------------------------------------------------

func _rel_time(mins_ago: int) -> String:
	if mins_ago < 60:
		return "hace %d min" % mins_ago
	var h: int = int(mins_ago / 60.0)
	if h < 24:
		return "hace %d h" % h
	return "hace %d d" % int(h / 24.0)

func _npc_role(role: String) -> String:
	match role:
		"coach": return "coach"
		"agent": return "agent"
		"sponsor": return "director"
		_: return "staff"

func _role_tint(role: String) -> Color:
	match role:
		"agent": return Styles.GOLD
		"coach": return Styles.BLUE
		"teammate": return Styles.GREEN
		"sponsor": return Styles.PURPLE
		_: return Styles.BLUE

func _role_label(role: String) -> String:
	match role:
		"agent": return "Representante"
		"coach": return "Entrenador"
		"teammate": return "Compañero"
		"sponsor": return "Patrocinador"
		_: return "Contacto"

func _reply_options(role: String) -> Array:
	match role:
		"agent": return ["Gracias, hablamos.", "Necesito que muevas algo.", "Todo tranquilo."]
		"coach": return ["A la orden, profe.", "Voy a dar más.", "Gracias por la confianza."]
		"teammate": return ["Jajaja de una.", "Nos vemos en el entreno.", "Vamos con todo."]
		"sponsor": return ["Me interesa.", "Lo veo con mi agente.", "Gracias por escribir."]
		_: return ["Dale.", "Gracias.", "Hablamos."]

func _reply_ack(role: String) -> String:
	match role:
		"agent": return "Perfecto. Cualquier cosa te escribo."
		"coach": return "Bien. Nos vemos mañana temprano."
		"teammate": return "De una, crack. Un abrazo."
		"sponsor": return "Genial, coordinamos por mail."
		_: return "Listo. Buen día."
