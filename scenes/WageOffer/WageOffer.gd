extends Control

## Mejora de sueldo pendiente A MITAD de contrato — pedido explícito ("que
## llegue sola"): el club la propone solo tras una buena racha
## (WageOfferEngine.gd), el jugador solo decide aceptar o no. Mismo
## patrón que SponsorOffer.gd (estado persistente en PlayerData, no un
## popup efímero): sobrevive a cerrar/reabrir el juego.
##
## "Pedir más" (pedido de Wilber: "debería ser una propuesta para
## negociar", antes aceptar/rechazar un número fijo sin vuelta) — UN solo
## pedido (WageOfferEngine.negotiate_counter): el club cede a un monto
## mayor o se planta con lo ya ofrecido, nunca empeora. Una vez pedido,
## el botón desaparece (offer["negotiated"]=true) — no es un regateo sin fin.

@onready var detail_card: PanelContainer = $VBoxContainer/DetailCard
@onready var detail_label: Label = $VBoxContainer/DetailCard/DetailMargin/DetailLabel
@onready var negotiate_button: Button = $VBoxContainer/NegotiateButton
@onready var accept_button: Button = $VBoxContainer/AcceptButton
@onready var decline_button: Button = $VBoxContainer/DeclineButton

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	negotiate_button.pressed.connect(_on_negotiate_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	decline_button.pressed.connect(_on_decline_pressed)
	detail_card.add_theme_stylebox_override("panel", Styles.card_accent(Styles.GREEN))
	Styles.styled_button(negotiate_button, Styles.pill_outlined(Styles.GOLD), Styles.GOLD)
	Styles.styled_button(accept_button, Styles.pill_filled(Styles.GREEN), Color.BLACK)
	Styles.styled_button(decline_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	accept_button.icon = Icons.load_icon(Icons.CHECKMARK)
	accept_button.add_theme_constant_override("icon_max_width", 26)
	decline_button.icon = Icons.load_icon(Icons.CROSS)
	decline_button.add_theme_constant_override("icon_max_width", 22)
	_render()

func _render() -> void:
	var player := SaveManager.load_player()
	var offer: Dictionary = player.pending_wage_offer if player != null else {}
	if offer.is_empty():
		detail_label.text = "No hay ninguna oferta pendiente."
		negotiate_button.visible = false
		accept_button.disabled = true
		decline_button.disabled = true
		return

	UiKit.put_anim_above($VBoxContainer/TitleLabel, player, "firma", Styles.GREEN, 260 if get_viewport_rect().size.x > get_viewport_rect().size.y else 130)
	var club := WorldFactory.find_club(WorldTickEngine.world, String(offer.get("club_id", "")))
	var club_name: String = club.club_name if club != null else "Tu club"
	var intro: String = "%s quiere premiar tu buen momento:" % club_name
	if String(offer.get("reason", "")) == "counter_interest":
		intro = "%s se interesó en vos, pero %s NO te deja salir y te ofrece mejorar el contrato:" % [
			String(offer.get("suitor_name", "Otro club")), club_name]

	var negotiated: bool = bool(offer.get("negotiated", false))
	var body: String = "%s\nSueldo de %s a %s por temporada." % [
		intro,
		CurrencyFormat.format(int(offer.get("old_wage", 0))),
		CurrencyFormat.format(int(offer.get("new_wage", 0))),
	]
	if negotiated:
		if bool(offer.get("club_held_firm", false)):
			body += "\n\nPediste más, pero el club se plantó — esto es lo máximo que ofrecen."
		else:
			body += "\n\nNegociaste bien: el club cedió a esta cifra."
	detail_label.text = body
	negotiate_button.visible = not negotiated
	accept_button.disabled = false
	decline_button.disabled = false
	UiKit.land_modal($VBoxContainer)

func _on_negotiate_pressed() -> void:
	WorldTickEngine.negotiate_wage_offer()
	_render()

func _on_accept_pressed() -> void:
	WorldTickEngine.resolve_wage_offer(true)
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _on_decline_pressed() -> void:
	WorldTickEngine.resolve_wage_offer(false)
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
