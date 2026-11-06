extends RefCounted
class_name Icons

## Un solo lugar para los iconos del addon @icons (addons/at-icons/,
## carpeta `node/` — gris claro, se tiñe bien con `modulate`). Nunca
## escribas una ruta a un SVG del addon a mano en una escena: referencia
## esta lista, así cambiar de set de iconos el día de mañana es un
## archivo, no una búsqueda por todo el proyecto.

const _BASE := "res://addons/at-icons/node/"

const HOME := _BASE + "house.svg"
const SQUAD := _BASE + "person_body.svg"
const TROPHY := _BASE + "trophy.svg"
const CAREER := _BASE + "briefcase.svg"
const CLUB := _BASE + "shield.svg"
const MENU := _BASE + "list_unordered.svg"
const CALENDAR := _BASE + "calendar.svg"
const NEWS := _BASE + "notepad.svg"
const TRANSFER := _BASE + "arrow_right_arrow_left.svg"
const NATIONAL_TEAM := _BASE + "flag_triangular.svg"
const SETTINGS := _BASE + "cog.svg"
const EXIT := _BASE + "doorway_exit.svg"
const PLAY := _BASE + "play.svg"
const FAST_FORWARD := _BASE + "fast_forward.svg"
const FOOTBALL := _BASE + "football.svg"
const TRAINING := _BASE + "dumbbell.svg"
const SPONSOR := _BASE + "coins.svg"
const STANDINGS := _BASE + "list_ordered.svg"
const EXPLORE := _BASE + "globe.svg"
const BACK := _BASE + "arrow_left.svg"
const STAR := _BASE + "star.svg"
const TRASH := _BASE + "trash_can.svg"
const MICROPHONE := _BASE + "microphone.svg"
const BRAIN := _BASE + "brain.svg"
const CHECKMARK := _BASE + "checkmark.svg"
const CROSS := _BASE + "cross.svg"
const INFO := _BASE + "info.svg"
const COLLECTION := _BASE + "book.svg"
const IMPORT := _BASE + "arrow_up_from_bracket.svg"
const CARD := _BASE + "playing_card.svg"
const MEDAL := _BASE + "medal.svg"
const HEART := _BASE + "heart.svg"
const WAGE_UP := _BASE + "arrow_up_right.svg"
const DICE := _BASE + "dice.svg"
const SOCIAL := _BASE + "bird.svg"
const LIKE := _BASE + "thumbs_up.svg"
const REPLY := _BASE + "speech_bubble.svg"
const SEARCH := _BASE + "magnifying_glass.svg"

## Set alterno: Kenney "game-icons" (assets/icons/PNG/White/1x/, PNG 50×50
## blancos, se tiñen con modulate). Para donde un ícono "de juego"
## (audioOn/Off, gamepad, gear, home, medal…) queda mejor que el at-icon.
const _GAME_DIR := "res://assets/icons/PNG/White/1x/"

static func game(name: String) -> Texture2D:
	var p := _GAME_DIR + name + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## TextureRect ya dimensionado (mismo criterio que make_rect).
static func game_rect(name: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	var t := game(name)
	if t != null:
		r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	return r

## Íconos de sección en PIXEL ART (PixelLab, 9-oct): a color, 48×48 — NO
## se tiñen (modulate los ensuciaría) y van con filtro NEAREST a escala
## entera. Para tarjetas/menús grandes; los at-icons siguen para botones
## chicos y monocromos.
const _PX_DIR := "res://assets/icons_px/"
const PX_TRAINING := _PX_DIR + "training.png"
const PX_LIFESTYLE := _PX_DIR + "lifestyle.png"
const PX_AGENT := _PX_DIR + "agent.png"
const PX_PROFILE := _PX_DIR + "profile.png"
const PX_SHOP := _PX_DIR + "shop.png"
const PX_SOCIAL := _PX_DIR + "social.png"
const PX_STANDINGS := _PX_DIR + "standings.png"
const PX_CUP := _PX_DIR + "collection.png"
const PX_NEWS := _PX_DIR + "news.png"
const PX_TRANSFERS := _PX_DIR + "transfers.png"
const PX_AWARDS := _PX_DIR + "awards.png"
const PX_WORLD := _PX_DIR + "world.png"
const PX_SETTINGS := _PX_DIR + "settings.png"
const PX_COLLECTION := _PX_DIR + "collection.png"
const PX_NATIONAL := _PX_DIR + "national.png"
const PX_CALENDAR := _PX_DIR + "calendar.png"
const PX_SPONSORS := _PX_DIR + "sponsors.png"

## Set CHICO (32×32, 9-oct) para barra inferior y menú lateral — misma
## paleta que los de 48. Se muestran a 32 (escala 1:1, nítidos).
const _PXS_DIR := "res://assets/icons_s/"
const PXS_HOME := _PXS_DIR + "home.png"
const PXS_SQUAD := _PXS_DIR + "squad.png"
const PXS_TROPHY := _PXS_DIR + "trophy.png"
const PXS_CAREER := _PXS_DIR + "career.png"
const PXS_CLUB := _PXS_DIR + "club.png"
const PXS_TRANSFERS := _PXS_DIR + "transfers.png"
const PXS_CALENDAR := _PXS_DIR + "calendar.png"
const PXS_NEWS := _PXS_DIR + "news.png"
const PXS_EXPLORE := _PXS_DIR + "explore.png"
const PXS_SEARCH := _PXS_DIR + "search.png"
const PXS_NATIONAL := _PXS_DIR + "national.png"
const PXS_SETTINGS := _PXS_DIR + "settings.png"
const PXS_EXIT := _PXS_DIR + "exit.png"

static func is_pixel(path: String) -> bool:
	return path.begins_with(_PX_DIR) or path.begins_with(_PXS_DIR)

## Un botón con ícono pixel art: sin tinte (los colores del arte), filtro
## NEAREST. `dim` < 1 apaga un poco los inactivos.
static func pixel_button_icon(b: Button, path: String, px: int, dim: float = 1.0) -> void:
	if not ResourceLoader.exists(path):
		return
	b.icon = load(path) as Texture2D
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_constant_override("icon_max_width", px)
	var c := Color(1, 1, 1, dim)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(k, c)
	b.add_theme_color_override("icon_disabled_color", Color.WHITE)

## Ícono pixel art a `px` (redondeado a múltiplo entero de 48 si se puede).
static func px_rect(path: String, px: int) -> TextureRect:
	var r := make_rect(path, px)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r

static func load_icon(path: String) -> Texture2D:
	return load(path) as Texture2D

## TextureRect ya configurado para mostrar un icono a un tamaño EXACTO
## dentro de una insignia/botón. CLAVE: `svg/scale=4.0` en el import del
## addon → los iconos pesan 64×64 nativos; sin `EXPAND_IGNORE_SIZE` ese
## 64 se vuelve el tamaño MÍNIMO del TextureRect y el icono se sale del
## recuadro que lo contiene (bug que reportó Wilber: "los iconos se salen
## de los botones"). Con este helper el `px` manda.
static func make_rect(icon_path: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		r.texture = load(icon_path) as Texture2D
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	return r
