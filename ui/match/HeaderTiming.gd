extends Control
class_name HeaderTiming

## Minijuego del CABEZAZO (P4, 9-oct — "tocar cuando cae la pelota, sombra
## que crece"): la pelota baja hacia tu jugador; su sombra en el pasto
## crece hasta llenar el aro dorado. Tocá cuando la sombra llena el aro.
## Emite `tapped(err_ms)` = cuánto te adelantaste (<0) o atrasaste (>0)
## respecto del momento justo; sin toque, err_ms = 9999. La nota del toque
## la calcula DecisionResolver.header_timing_precision (acá solo se mide).

signal tapped(err_ms: float)

var duration: float = 1.2     # segundos hasta el momento justo
var player_cfg: Dictionary = {}
var _t: float = 0.0
var _done: bool = false
var _jumper: Control = null
var _overlay: Control = null

func _ready() -> void:
	custom_minimum_size = Vector2(0, 230)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not player_cfg.is_empty() and Avatar.has_anim("cabezazo"):
		# Tu jugador de frente, quieto hasta el toque (después salta).
		_jumper = Avatar.build_full(player_cfg, 120)
		add_child(_jumper)
	# Aro y sombra ENCIMA del jugador (si no, el cuerpo los tapa).
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	resized.connect(_place)
	_place()

func _place() -> void:
	if _jumper != null:
		_jumper.position = Vector2(size.x * 0.5 - 60.0, size.y - 124.0)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t > duration + 0.4:
		_finish(9999.0)
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if _done:
		return
	var pressed: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if pressed:
		accept_event()
		_finish((_t - duration) * 1000.0)

func _finish(err_ms: float) -> void:
	_done = true
	if _jumper != null and Avatar.has_anim("cabezazo") and err_ms < 9000.0:
		_jumper.queue_free()
		# Lienzo de animación 68 vs pose 48: misma escala → 120 × 68/48.
		_jumper = Avatar.build_anim(player_cfg, "cabezazo", 170, false, 14.0)
		_jumper.custom_minimum_size = Vector2(170, 170)
		_jumper.position = Vector2(size.x * 0.5 - 85.0, size.y - 151.0)
		add_child(_jumper)
		move_child(_overlay, get_child_count() - 1)
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()
	tapped.emit(err_ms)

func _draw_overlay() -> void:
	var c := Vector2(size.x * 0.5, size.y - 18.0)
	var k: float = clampf(_t / duration, 0.0, 1.25)
	var ring_r: float = 34.0
	var sr: float = lerpf(4.0, ring_r, minf(k, 1.0)) + maxf(0.0, k - 1.0) * 30.0
	var sh_col := Color(0, 0, 0, 0.42)
	if _done:
		sh_col = Color(0.3, 1.0, 0.45, 0.5) if absf((_t - duration) * 1000.0) < 120.0 else Color(1, 0.35, 0.3, 0.5)
	_overlay.draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
	_overlay.draw_circle(Vector2.ZERO, sr, sh_col)
	_overlay.draw_arc(Vector2.ZERO, ring_r, 0, TAU, 40, Color(1, 0.84, 0.25), 3.0)
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Pelota bajando hacia la cabeza (al tocar, la animación trae la suya).
	if not _done:
		var by: float = lerpf(-20.0, size.y - 118.0, minf(k, 1.0))
		_overlay.draw_circle(Vector2(c.x, by), 11.0, Color.WHITE)
		_overlay.draw_arc(Vector2(c.x, by), 11.0, 0, TAU, 20, Color(0.1, 0.1, 0.1), 1.5)

func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y - 22.0)
	# Pasto.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.17, 0.42, 0.2))
	draw_rect(Rect2(0, size.y * 0.5, size.x, size.y * 0.5), Color(0.15, 0.38, 0.18))
	var f: Font = Styles.font_black()
	var txt := "¡Tocá cuando la sombra llena el aro!" if not _done else ""
	var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(f, Vector2(size.x * 0.5 - tw * 0.5, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.9))
