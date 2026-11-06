extends Control

## Aviso de convocatoria (o no) a la selección, con la cara de invitación
## que pedía Wilber: "cuando me convoquen que salga un popup con la
## invitación o algo parecido" — antes lo único que dejaba esto era una
## nota de prensa que había que ir a buscar. Mismo patrón que
## WageOffer.tscn/SponsorOffer.tscn: estado persistente
## (SaveManager.load_international()["user_callup_status"]), no un popup
## efímero — sobrevive a cerrar/reabrir el juego, y desaparece solo (el
## botón de Hub.gd deja de mostrarse) una vez que se marca `seen=true` acá.

@onready var flag_box: CenterContainer = $VBoxContainer/FlagBox
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var detail_card: PanelContainer = $VBoxContainer/DetailCard
@onready var detail_label: Label = $VBoxContainer/DetailCard/DetailMargin/DetailLabel
@onready var dismiss_button: Button = $VBoxContainer/DismissButton

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	dismiss_button.pressed.connect(_on_dismiss_pressed)
	_render()

func _render() -> void:
	var player := SaveManager.load_player()
	var callup: Dictionary = SaveManager.load_international().get("user_callup_status", {})
	if player == null or player.country == "" or callup.is_empty():
		title_label.text = "Sin novedades"
		detail_label.text = "No hay ninguna convocatoria pendiente."
		Styles.styled_button(dismiss_button, Styles.pill_filled(Styles.GRAY_TEXT), Color.WHITE)
		return

	var called_up: bool = bool(callup.get("called_up", false))
	var status: String = String(callup.get("status", ""))
	var flag: Control = CountryFlags.flag_rect(player.country, 44)
	if flag != null:
		flag_box.add_child(flag)

	var accent: Color = Styles.GOLD if called_up else Styles.GRAY_TEXT
	if called_up:
		title_label.text = "¡Convocado como capitán!" if status == "captain" else "¡Convocado a la selección!"
		var role_txt: String = "titular con muchas chances de jugar" if status == "captain" \
			else ("con chances reales de jugar" if status == "regular" else "en el plantel, aunque no asegura minutos")
		detail_label.text = "%s recibe el llamado de %s para esta fecha FIFA — vas %s." % [
			player.player_name, player.country, role_txt]
	else:
		title_label.text = "Te quedaste afuera esta vez"
		detail_label.text = "El cuerpo técnico de %s no incluyó a %s en la nómina para esta fecha FIFA. Seguí sumando buenos partidos: la convocatoria es por mérito, no hay lugares fijos." % [
			player.country, player.player_name]

	title_label.add_theme_color_override("font_color", accent)
	# Convocado: mano al pecho, como en el himno. Afuera: se lamenta.
	UiKit.put_anim_above(title_label, player, "himno" if called_up else "lamento", accent, 260 if get_viewport_rect().size.x > get_viewport_rect().size.y else 150)
	UiKit.land_modal($VBoxContainer, $VBoxContainer/FlagBox)
	var style := Styles.card_accent(accent)
	detail_card.add_theme_stylebox_override("panel", style)
	Styles.styled_button(dismiss_button, Styles.pill_filled(accent), Styles.contrasting_text_color(accent))

func _on_dismiss_pressed() -> void:
	var intl: Dictionary = SaveManager.load_international()
	var callup: Dictionary = intl.get("user_callup_status", {})
	if not callup.is_empty():
		callup["seen"] = true
		intl["user_callup_status"] = callup
		SaveManager.save_international(intl)
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
