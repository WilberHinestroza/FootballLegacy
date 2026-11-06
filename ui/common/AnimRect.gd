extends TextureRect
class_name AnimRect

## TextureRect que reproduce una lista de cuadros (animaciones de PixelLab
## del jugador / árbitro). `loop = false` se queda en el último cuadro.
## Pixel art: siempre TEXTURE_FILTER_NEAREST.

var frames: Array = []
var fps: float = 10.0
var loop: bool = false
var _t: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not frames.is_empty():
		texture = frames[0]

func restart() -> void:
	_t = 0.0
	if not frames.is_empty():
		texture = frames[0]

func _process(delta: float) -> void:
	if frames.is_empty():
		return
	_t += delta
	var idx: int = int(_t * fps)
	idx = idx % frames.size() if loop else mini(idx, frames.size() - 1)
	texture = frames[idx]
