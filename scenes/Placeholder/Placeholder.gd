extends Control
class_name Placeholder

## Pantalla stub reutilizable (Colección, Ajustes, Acerca de) — todavía
## sin contenido propio. Quien navega hacia acá fija `title`/`body` (vars
## static: la forma más simple de pasar dos strings entre escenas sin
## crear un autoload solo para esto) justo antes del change_scene_to_file.

static var title: String = ""
static var body: String = ""

@onready var title_label: Label = $Root/Margin/VBox/TitleLabel
@onready var body_label: Label = $Root/Margin/VBox/BodyLabel
@onready var back_button: Button = $Root/Margin/VBox/BackButton

func _ready() -> void:
	title_label.text = title
	body_label.text = body
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Start/Start.tscn")
