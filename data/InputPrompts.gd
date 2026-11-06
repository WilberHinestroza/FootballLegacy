extends RefCounted
class_name InputPrompts

## Iconos de gesto táctil / marcadores del pack Kenney "Input Prompts"
## (Wilber lo puso en assets/inputs/ — quedan solo Touch/ y Flairs/, el
## resto —mandos de consola/VR— se borró: es un juego móvil). Un único
## lugar para pedirlos por nombre semántico, como Icons.gd.

const _TOUCH := "res://assets/inputs/Touch/Default/"
const _FLAIR := "res://assets/inputs/Flairs/Default/"

const MAP := {
	"tap": _TOUCH + "touch_tap.png",
	"tap_hold": _TOUCH + "touch_tap_hold.png",
	"tap_double": _TOUCH + "touch_tap_double.png",
	"swipe_up": _TOUCH + "touch_swipe_up.png",
	"swipe_down": _TOUCH + "touch_swipe_down.png",
	"swipe_left": _TOUCH + "touch_swipe_left.png",
	"swipe_right": _TOUCH + "touch_swipe_right.png",
	"swipe": _TOUCH + "touch_swipe_move.png",
	"hand_open": _TOUCH + "touch_hand_open.png",
	"hand_closed": _TOUCH + "touch_hand_closed.png",
	# marcadores
	"target": _FLAIR + "flair_circle_target_a.png",
	"target_b": _FLAIR + "flair_circle_target_b.png",
	"joy_ring": _FLAIR + "flair_circle_2.png",
	"joy_knob": _FLAIR + "flair_circle_6.png",
	"btn_face": _FLAIR + "flair_circle_red_4.png",
	"arrow_up": _FLAIR + "flair_arrows_up.png",
	"arrow_down": _FLAIR + "flair_arrows_down.png",
	"arrow_left": _FLAIR + "flair_arrows_left.png",
	"arrow_right": _FLAIR + "flair_arrows_right.png",
}

static func path(name: String) -> String:
	return String(MAP.get(name, ""))

static func has(name: String) -> bool:
	var p: String = path(name)
	return p != "" and ResourceLoader.exists(p)

## TextureRect cuadrado con el gesto `name`, `px` de lado. null si no está.
static func rect(name: String, px: int = 28, tint: Color = Color.WHITE) -> TextureRect:
	var p: String = path(name)
	if p == "" or not ResourceLoader.exists(p):
		return null
	var tr := TextureRect.new()
	tr.texture = load(p)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
