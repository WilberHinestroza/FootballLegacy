extends Node

## Pila de navegación de la app. "Volver" ahora regresa a la pantalla
## ANTERIOR real (de dónde entraste), no a una fija — pedido de Wilber.
##
## Se auto-alimenta observando `current_scene` cada frame: cualquier
## `change_scene_to_file(...)` queda registrado sin tener que tocar los
## ~75 sitios que navegan. El Hub es "casa": llegar ahí VACÍA el historial.
## Las pantallas de FLUJO forzado (partido, ceremonia, decisiones de
## contrato, ofertas modales, arranque) no entran a la pila.

const HOME := "res://scenes/Hub/Hub.tscn"

## Pantallas que NO son destinos de "volver": ni se apilan ni se apila lo
## que había antes de entrar en ellas.
const IGNORE := {
	"res://scenes/Match3D/Match3D.tscn": true,
	"res://scenes/MatchSummary/MatchSummary.tscn": true,
	"res://scenes/NationalMatchSummary/NationalMatchSummary.tscn": true,
	"res://scenes/PreMatch/PreMatch.tscn": true,
	"res://scenes/PostMatchInterview/PostMatchInterview.tscn": true,
	"res://scenes/SeasonCeremony/SeasonCeremony.tscn": true,
	"res://scenes/SeasonLoading/SeasonLoading.tscn": true,
	"res://scenes/Awards/Awards.tscn": true,
	"res://scenes/ContractDecision/ContractDecision.tscn": true,
	"res://scenes/Retirement/Retirement.tscn": true,
	"res://scenes/SponsorOffer/SponsorOffer.tscn": true,
	"res://scenes/WageOffer/WageOffer.tscn": true,
	"res://scenes/SeasonEvent/SeasonEvent.tscn": true,
	"res://scenes/Start/Start.tscn": true,
	"res://scenes/CharacterCreation/CharacterCreation.tscn": true,
	"res://scenes/ImportWorld/ImportWorld.tscn": true,
	# Editor de apariencia: es un "modal" (entra y sale a la pantalla que lo
	# abrió). Si se apilaba, volver de él empujaba el EDITOR a la pila y el
	# "Volver" siguiente desde el perfil lo REABRÍA — y como edit_mode ya
	# estaba en false, en modo CREACIÓN de personaje (bug que reportó
	# Wilber al cambiar la apariencia).
	"res://scenes/AvatarCreator/AvatarCreator.tscn": true,
}

## Pantallas "casa": atrás del sistema ahí no navega, pide confirmar salir.
const ROOTS := {HOME: true, "res://scenes/Start/Start.tscn": true}

var _stack: Array[String] = []

func _ready() -> void:
	# Táctil de listas parejo en todo el juego (ver UiScroll.touch_friendly).
	get_tree().node_added.connect(UiScroll.on_node_added)
	get_tree().node_added.connect(_on_node_min_font)
var _last_path: String = ""
var _going_back: bool = false

func _process(_delta: float) -> void:
	var cs: Node = get_tree().current_scene
	if cs == null:
		return
	var p: String = cs.scene_file_path
	if p == "" or p == _last_path:
		return
	# La escena cambió respecto al frame anterior.
	if p == HOME:
		_stack.clear()
	elif _going_back:
		pass # acabamos de hacer pop; no re-apilar
	elif _stack.has(p):
		# Volver a una pantalla que YA está en la pila (con un
		# change_scene directo, como hacen muchas pantallas al "volver") es
		# volver, no avanzar: se corta la pila hasta ella. Antes se apilaba
		# la pantalla de la que venías → A→B→A dejaba [A, B] y el "Volver"
		# de A te mandaba otra vez a B (ida y vuelta infinito).
		_stack.resize(_stack.find(p))
	elif _last_path != "" and not IGNORE.has(_last_path) and not IGNORE.has(p):
		if _stack.is_empty() or _stack.back() != _last_path:
			_stack.append(_last_path)
			if _stack.size() > 20:
				_stack.pop_front()
	_going_back = false
	_last_path = p
	# P0-12: cada cambio de pantalla es un punto de autoguardado barato
	# (volcado de temporada; el throttle vive en SaveManager.autosave).
	SaveManager.autosave("scene")
	_fade_in()

## Vuelve a la pantalla anterior de la pila; si está vacía, al Hub. Si la
## pantalla actual tiene niveles internos (un overlay abierto, una
## sub-vista) y define `nav_back() -> bool`, primero cierra ESO.
func back() -> void:
	if _consume_back():
		return
	var dest: String = HOME
	if not _stack.is_empty():
		dest = _stack.pop_back()
	_going_back = true
	get_tree().change_scene_to_file(dest)

func can_go_back() -> bool:
	return not _stack.is_empty()

# --- Botón/gesto ATRÁS de Android -------------------------------------
# Antes NINGUNA pantalla (salvo el editor de avatar) lo manejaba y el
# proyecto tenía quit_on_go_back = true (default de Godot): el gesto atrás
# CERRABA la app desde cualquier lado. Ahora: atrás del sistema = el mismo
# "Volver" de la franja de arriba; en pantallas de flujo forzado (partido,
# ceremonias, ofertas) no hace nada; en Inicio pide un segundo toque.
var _exit_armed_until: int = 0
signal exit_hint

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var cs: Node = get_tree().current_scene
	if cs == null:
		return
	if cs.has_method("handles_system_back"):
		return   # la pantalla lo maneja ella misma (editor de avatar)
	var p: String = cs.scene_file_path
	if ROOTS.has(p):
		if _consume_back():
			return
		if Time.get_ticks_msec() < _exit_armed_until:
			get_tree().quit()
		else:
			_exit_armed_until = Time.get_ticks_msec() + 2000
			_toast("Tocá atrás otra vez para salir")
		return
	if IGNORE.has(p) and not (cs.has_method("nav_back")):
		return
	back()

## Transición: la pantalla nueva aparece con un fundido corto desde el
## fondo oscuro (antes era un corte seco). Sin animación si el jugador
## pidió "reducir movimiento".
func _fade_in() -> void:
	if Preferences.reduce_motion:
		return
	_stagger_scene.call_deferred()
	var layer := CanvasLayer.new()
	layer.layer = 110
	var r := ColorRect.new()
	r.color = Color(0.03, 0.035, 0.05, 1.0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	get_tree().root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)

## Entrada escalonada del contenido de la pantalla nueva (P1b #13): las
## tarjetas del primer ScrollContainer aparecen una tras otra. Solo toca la
## transparencia (nunca el layout), y solo las primeras 10.
func _stagger_scene() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var cs: Node = get_tree().current_scene
	if cs == null:
		return
	var sc: ScrollContainer = _find_scroll(cs)
	if sc == null or sc.get_child_count() == 0:
		return
	var box := sc.get_child(0) as Container
	if box == null:
		return
	var i := 0
	for c in box.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		if i >= 10:
			break
		var cc: Control = c
		cc.modulate.a = 0.0
		var tw := cc.create_tween()
		tw.tween_interval(0.035 * i)
		tw.tween_property(cc, "modulate:a", 1.0, 0.2)
		i += 1

func _find_scroll(n: Node) -> ScrollContainer:
	for c in n.get_children():
		if c is ScrollContainer and (c as ScrollContainer).visible:
			return c
	for c in n.get_children():
		var r := _find_scroll(c)
		if r != null:
			return r
	return null

## Algo abierto DENTRO de la pantalla (cajón del menú, ficha, overlay) se
## cierra antes de salir de ella. true = ya se consumió el "atrás".
func _consume_back() -> bool:
	for n in get_tree().get_nodes_in_group("nav_back_handlers"):
		if n.has_method("nav_back") and bool(n.call("nav_back")):
			return true
	var cs: Node = get_tree().current_scene
	return cs != null and cs.has_method("nav_back") and bool(cs.call("nav_back"))

## Aviso corto abajo (sobrevive al cambio de escena: va en la raíz).
func toast(text: String) -> void:
	_toast(text)

func _toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	l.add_theme_stylebox_override("normal", sb)
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_bottom = -110
	layer.add_child(l)
	get_tree().root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)

## Para flujos que quieren cortar el historial explícitamente.
func clear() -> void:
	_stack.clear()


## LETRA MÍNIMA (FootballLegacy H): en el celular acostado los textos de
## 9-11 pt no se leían. Todo texto de la interfaz queda en 12 pt como
## mínimo. La cancha en vivo (dentro de un SubViewport) tiene su propia
## escala y no se toca.
const MIN_FONT := 12

func _on_node_min_font(n: Node) -> void:
	if n is Label or n is Button or n is RichTextLabel or n is LineEdit:
		# Pasar el Object directamente por el MessageQueue falla en algunos
		# SubViewport/escenas dinámicas ("Cannot convert Object to Object").
		call_deferred("_bump_font_instance", n.get_instance_id())


func _bump_font_instance(instance_id: int) -> void:
	var n := instance_from_id(instance_id) as Node
	if n != null:
		_bump_font(n)

func _bump_font(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	if n.get_viewport() != get_tree().root:
		return
	var c := n as Control
	if n is RichTextLabel:
		if c.has_theme_font_size_override("normal_font_size") and c.get_theme_font_size("normal_font_size") < MIN_FONT:
			c.add_theme_font_size_override("normal_font_size", MIN_FONT)
		return
	if c.get_theme_font_size("font_size") < MIN_FONT:
		c.add_theme_font_size_override("font_size", MIN_FONT)
