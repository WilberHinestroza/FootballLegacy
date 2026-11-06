extends Control

## Cuadro de copa del usuario, ronda por ronda. Lectura pura sobre el
## cuadro RESUELTO de WorldTickEngine (WorldTickEngine.cup, ver
## SeasonEngine.resolve_cup) — nada se muta aquí. El render de cada
## partido vive en BracketView (compartido con WorldExplorer).

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var rounds_box: VBoxContainer = $Margin/VBox/Scroll/RoundsBox
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
	WorldTickEngine.load_runtime() # idempotente; por si se entra directo a esta escena
	back_button.pressed.connect(_on_back_pressed)
	back_button.icon = Icons.load_icon(Icons.BACK)
	back_button.add_theme_constant_override("icon_max_width", 22)
	Styles.styled_button(back_button, Styles.pill_outlined(Styles.GRAY_TEXT), Color.WHITE)
	_render()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")

func _render() -> void:
	title_label.text = WorldTickEngine.cup.get("cup_name", "Copa")
	_place_logo()

	for child in rounds_box.get_children():
		child.queue_free()

	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		# HORIZONTAL: rondas en columnas, de izquierda a la final.
		var sc := rounds_box.get_parent() as ScrollContainer
		if sc != null:
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		BracketView.render_columns(rounds_box, WorldTickEngine.cup, WorldTickEngine.user_club_id, "Este club no tiene copa activa.", _club_short)
		return
	BracketView.render(rounds_box, WorldTickEngine.cup, WorldTickEngine.user_club_id, "Este club no tiene copa activa.", _club_name)
	UiScroll.pad_bottom(rounds_box)

var _logo_row: HBoxContainer = null

## Logo de la copa a la izquierda del título (envuelve el Label una vez).
func _place_logo() -> void:
	var country: String = ""
	var cup_id: String = String(WorldTickEngine.cup.get("cup_id", ""))
	if cup_id.begins_with("cup_"):
		country = cup_id.substr(4)
	if country == "":
		return
	if _logo_row == null:
		var parent := title_label.get_parent()
		var idx := title_label.get_index()
		_logo_row = HBoxContainer.new()
		_logo_row.add_theme_constant_override("separation", 8)
		parent.remove_child(title_label)
		_logo_row.add_child(title_label)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(_logo_row)
		parent.move_child(_logo_row, idx)
	for c in _logo_row.get_children():
		if c != title_label:
			c.queue_free()
	var logo := Competition.domestic_cup_node(country, 34)
	logo.custom_minimum_size = Vector2(34, 34)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_logo_row.add_child(logo)
	_logo_row.move_child(logo, 0)

func _club_name(club_id: String) -> String:
	if club_id == "":
		return "?"
	var club := WorldFactory.find_club(WorldTickEngine.world, club_id)
	return club.club_name if club != null else club_id


## Nombre corto para el cuadro horizontal (los largos se cortaban: "Sporting R…").
func _club_short(club_id: String) -> String:
	if club_id == "":
		return "Por definir"
	var club := WorldFactory.find_club(WorldTickEngine.world, club_id)
	if club == null:
		return club_id
	# Sin la palabra genérica de adelante: "Sporting Rquena" → "Rquena".
	var words: PackedStringArray = club.club_name.split(" ", false)
	const GENERIC := ["Sporting", "Racing", "Atlético", "Athletic", "Club", "Real", "Unión", "Deportivo", "CD", "CF", "FC", "SC", "AC", "Inter"]
	if words.size() >= 2 and GENERIC.has(words[0]):
		words.remove_at(0)
	return " ".join(words)
