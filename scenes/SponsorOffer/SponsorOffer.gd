extends Control

## Oferta de patrocinio pendiente (backlog de FL: "estado persistente, no
## popup efímero" — por eso vive en PlayerData.pending_sponsor_offer y
## sobrevive a cerrar/reabrir el juego, no es un diálogo que desaparece
## solo). Aceptar/rechazar vía WorldTickEngine.resolve_sponsor_offer().

@onready var detail_card: PanelContainer = $VBoxContainer/DetailCard
@onready var detail_label: Label = $VBoxContainer/DetailCard/DetailMargin/DetailLabel
@onready var accept_button: Button = $VBoxContainer/AcceptButton
@onready var decline_button: Button = $VBoxContainer/DeclineButton

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	accept_button.pressed.connect(_on_accept_pressed)
	decline_button.pressed.connect(_on_decline_pressed)
	detail_card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GOLD))
	Styles.styled_button(accept_button, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	Styles.styled_button(decline_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	accept_button.icon = Icons.load_icon(Icons.CHECKMARK)
	accept_button.add_theme_constant_override("icon_max_width", 26)
	decline_button.icon = Icons.load_icon(Icons.CROSS)
	decline_button.add_theme_constant_override("icon_max_width", 22)
	_render()

func _render() -> void:
	var player := SaveManager.load_player()
	var offer: Dictionary = player.pending_sponsor_offer if player != null else {}
	if offer.is_empty():
		detail_label.text = "No hay ninguna oferta pendiente."
		accept_button.disabled = true
		decline_button.disabled = true
		return
	var brand: String = String(offer.get("name", "?"))
	UiKit.put_anim_above($VBoxContainer/TitleLabel, player, "llamada", Styles.GOLD, 260 if get_viewport_rect().size.x > get_viewport_rect().size.y else 130)
	detail_label.text = "%s te ofrece patrocinarte:\n%s por semana, durante %d semanas." % [
		brand, CurrencyFormat.format(int(offer.get("weekly_income", 0))), int(offer.get("weeks_remaining", 0)),
	]
	# El logo va ENCIMA de la tarjeta, no adentro: la tarjeta es un
	# MarginContainer y lo dibujaba superpuesto al texto.
	var col := $VBoxContainer as VBoxContainer
	var wrap: Control = col.get_node_or_null("SponsorBrand")
	if wrap == null and has_node("LandLeft/SponsorBrand"):
		wrap = get_node("LandLeft/SponsorBrand")
	if wrap == null:
		wrap = CenterContainer.new()
		wrap.name = "SponsorBrand"
		wrap.add_child(BrandMark.build(brand, 120 if get_viewport_rect().size.x > get_viewport_rect().size.y else 64))
		col.add_child(wrap)
		col.move_child(wrap, $VBoxContainer/DetailCard.get_index())
	UiKit.land_modal(col, wrap)

func _on_accept_pressed() -> void:
	WorldTickEngine.resolve_sponsor_offer(true)
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _on_decline_pressed() -> void:
	WorldTickEngine.resolve_sponsor_offer(false)
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
