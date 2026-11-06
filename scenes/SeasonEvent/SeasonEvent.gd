extends Control

## Evento inesperado de temporada pendiente (ver SeasonEventEngine.gd) —
## pedido explícito: "eventos que ocurran entre 0 a 3 veces por temporada
## que nos beneficien o nos afecten, también eventos de decisiones".
## Mismo patrón que SponsorOffer/WageOffer (estado persistente en
## PlayerData, no un popup efímero), pero con un número VARIABLE de
## opciones — un aviso simple trae una sola ("Entendido"), una decisión
## trae 2+, dibujadas dinámicamente (ver ContractDecision.gd, mismo criterio).

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var detail_card: PanelContainer = $VBoxContainer/DetailCard
@onready var detail_label: Label = $VBoxContainer/DetailCard/DetailMargin/DetailLabel
@onready var options_box: VBoxContainer = $VBoxContainer/OptionsBox

const _FIELD_LABEL := {"balance": "balance", "coach_trust": "confianza DT", "reputation": "reputación"}
## Color por categoría (ver SeasonEventEngine._POOL) — mismo criterio que
## el resto de la app: cada tarjeta lleva el color de lo que representa,
## nunca un gris plano genérico.
const _CATEGORY_COLOR := {"economic": Styles.GREEN, "performance": Styles.BLUE, "media": Styles.PURPLE, "club": Styles.GOLD}

## Animación de tu jugador por evento (assets/pixelplayer/anim/<anim>).
const _EVENT_ANIM := {
	"sponsor_bonus": "puno", "fine": "lamento", "streaming_gig": "llamada",
	"form_high": "puno", "minor_knock": "lamento", "extra_recovery": "puno",
	"good_press": "puno", "scandal": "sorpresa", "risky_interview": "pensar",
	"public_praise": "puno", "locker_room_friction": "pensar", "teammate_favor": "pensar",
}

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	_render()

## Ilustración del evento (P6, 10-oct): assets/events/<id>.png arriba del
## título, con el borde del color de la categoría.
var _illus: Control = null
func _set_illustration(id: String) -> void:
	if _illus != null and is_instance_valid(_illus):
		_illus.queue_free()
	var path: String = "res://assets/events/%s.png" % id
	if id == "" or not ResourceLoader.exists(path):
		return
	var pic := TextureRect.new()
	pic.texture = load(path)
	pic.custom_minimum_size = Vector2(0, 220)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.clip_contents = true
	_illus = pic
	var vb := title_label.get_parent()
	vb.add_child(pic)
	vb.move_child(pic, title_label.get_index())
	pic.modulate.a = 0.0
	pic.create_tween().tween_property(pic, "modulate:a", 1.0, 0.4)

func _render() -> void:
	for child in options_box.get_children():
		child.queue_free()

	var player := SaveManager.load_player()
	var event: Dictionary = player.pending_season_event if player != null else {}
	if event.is_empty():
		title_label.text = "Sin novedades"
		detail_label.text = "No hay ningún evento pendiente."
		detail_card.add_theme_stylebox_override("panel", Styles.card())
		return

	title_label.text = String(event.get("title", ""))
	detail_label.text = String(event.get("body", ""))
	_set_illustration(String(event.get("id", "")))
	var accent: Color = _CATEGORY_COLOR.get(String(event.get("category", "")), Styles.GOLD)
	detail_card.add_theme_stylebox_override("panel", Styles.card_accent(accent))
	# Tu jugador reacciona (10-oct): según el tipo de evento.
	var anim: String = String(_EVENT_ANIM.get(String(event.get("id", "")), "pensar" if (event.get("options", []) as Array).size() > 1 else "sorpresa"))
	UiKit.put_anim_above(title_label, player, anim, accent, 260 if get_viewport_rect().size.x > get_viewport_rect().size.y else 104)
	UiKit.land_modal($VBoxContainer)

	var options: Array = event.get("options", [])
	for i in range(options.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 68)
		btn.text = _option_text(options[i])
		if options.size() == 1:
			Styles.styled_button(btn, Styles.pill_filled(Styles.GOLD), Color.BLACK)
		elif i == 0:
			Styles.styled_button(btn, Styles.pill_filled(Styles.GREEN), Color.BLACK)
		else:
			Styles.styled_button(btn, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
		btn.pressed.connect(_on_option_pressed.bind(i))
		options_box.add_child(btn)

## "Aceptar (+80 balance, -5 confianza DT)" — transparencia total del
## efecto antes de elegir, mismo criterio que WageOffer mostrando el
## sueldo de antes/después.
func _option_text(opt: Dictionary) -> String:
	var label: String = String(opt.get("label", "Continuar"))
	var effects: Dictionary = opt.get("resolved_effects", {})
	if effects.is_empty():
		return label
	var parts: PackedStringArray = []
	for key in effects:
		var delta: int = int(effects[key])
		parts.append("%s%d %s" % ["+" if delta >= 0 else "", delta, _FIELD_LABEL.get(key, key)])
	return "%s (%s)" % [label, ", ".join(parts)]

func _on_option_pressed(index: int) -> void:
	WorldTickEngine.resolve_season_event(index)
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
