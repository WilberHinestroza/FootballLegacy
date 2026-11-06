extends Control
class_name SpinRing

## Aro decorativo que GIRA alrededor de algo (pedido de Wilber para el
## círculo de la media en el Hub). Dibuja N segmentos de arco alternando
## colores (dorado / colores del club) y rota lento en bucle.
## Uso: instanciar, setear colors/segments, meter como hermano DETRÁS del
## nodo a adornar dentro de un contenedor de tamaño fijo.

var colors: PackedColorArray = PackedColorArray([Color("#e6c454"), Color("#8a6d1d")])
var segments: int = 14
var thickness: float = 4.0
var speed: float = 0.9            # rad/s
var gap_ratio: float = 0.35      # hueco entre segmentos (0..1 del paso)
var inset_px: float = 2.0        # separación respecto al borde

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	pivot_offset = size * 0.5
	rotation += speed * delta

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - thickness * 0.5 - inset_px
	if r <= 1.0 or colors.is_empty():
		return
	var step: float = TAU / float(maxi(segments, 1))
	var gap: float = step * clampf(gap_ratio, 0.0, 0.9) * 0.5
	for i in range(segments):
		var a0: float = float(i) * step + gap
		var a1: float = float(i + 1) * step - gap
		draw_arc(c, r, a0, a1, 10, colors[i % colors.size()], thickness, true)
