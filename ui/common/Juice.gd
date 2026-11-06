extends RefCounted
class_name Juice

## Kit de ANIMACIONES chicas reutilizables (P1b #13, 9-oct — Wilber: "más
## animaciones, todo lo que se pueda animar"). Todo con Tweens sobre el
## propio nodo: si el nodo se libera, el tween muere con él.

## "Pop": crece y vuelve (para algo que acaba de cambiar).
static func pop(node: Control, amount: float = 1.25, secs: float = 0.28) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(amount, amount), secs * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, secs * 0.6).set_trans(Tween.TRANS_QUAD)

## Número que cuenta de `from` a `to` en un Label (`fmt` con un %d o un
## Callable(int) -> String).
static func count_up(label: Label, from: int, to: int, secs: float = 0.8, fmt = "%d") -> void:
	if label == null:
		return
	var f := func(v: float):
		if fmt is Callable:
			label.text = String((fmt as Callable).call(int(round(v))))
		else:
			label.text = String(fmt) % int(round(v))
	f.call(float(from))
	var tw := label.create_tween()
	tw.tween_method(f, float(from), float(to), secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Entrada escalonada de los hijos de un contenedor (aparecen de abajo).
static func stagger_in(container: Control, step: float = 0.04, rise: float = 14.0) -> void:
	if container == null:
		return
	var i := 0
	for c in container.get_children():
		if not (c is Control):
			continue
		var cc: Control = c
		cc.modulate.a = 0.0
		var tw := cc.create_tween()
		tw.tween_interval(step * i)
		tw.tween_property(cc, "modulate:a", 1.0, 0.22)
		i += 1
	if rise > 0.0:
		container.modulate.a = 1.0

## Latido infinito suave (llamar la atención sobre un botón).
static func pulse(node: Control, amount: float = 1.05, secs: float = 0.9) -> void:
	if node == null:
		return
	var tw := node.create_tween().set_loops()
	# El centro se recalcula en cada vuelta: dentro de un contenedor el
	# tamaño real recién se conoce después del primer layout.
	tw.tween_callback(func(): node.pivot_offset = node.size * 0.5)
	tw.tween_property(node, "scale", Vector2(amount, amount), secs * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2.ONE, secs * 0.5).set_trans(Tween.TRANS_SINE)

## Flotar arriba-abajo infinito (íconos, trofeos).
static func bob(node: Control, px: float = 4.0, secs: float = 1.6) -> void:
	if node == null:
		return
	var y0: float = node.position.y
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "position:y", y0 - px, secs * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "position:y", y0, secs * 0.5).set_trans(Tween.TRANS_SINE)

## Texto que sube y se desvanece desde un punto (p. ej. "+€20K").
static func float_text(parent: Control, text: String, at: Vector2, col: Color = Color(1, 0.85, 0.3), size: int = 20) -> void:
	if parent == null:
		return
	var l := Label.new()
	l.text = text
	l.position = at
	l.z_index = 50
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Styles.font_black())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", at.y - 46.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

## Brillo que cruza un control (trofeos, tarjetas doradas).
static func shine(node: Control, secs: float = 0.9, every: float = 3.0) -> void:
	if node == null:
		return
	node.clip_contents = true
	var band := ColorRect.new()
	band.color = Color(1, 1, 1, 0.28)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(18, 400)
	band.rotation = 0.35
	band.position = Vector2(-60, -60)
	node.add_child(band)
	var tw := band.create_tween().set_loops()
	tw.tween_callback(func(): band.position = Vector2(-60, -60))
	tw.tween_property(band, "position:x", 520.0, secs)
	tw.tween_interval(every)
