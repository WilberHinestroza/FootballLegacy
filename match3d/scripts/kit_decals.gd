class_name KitDecals
extends RefCounted
## Estampados de la camiseta: escudo y patrocinio delante, apellido y dorsal detrás.
## Se "imprimen" una vez por jugador en una textura 256² (atlas que lee player_body:
## escudo arriba izq., dorsal arriba der., patrocinio en la franja media, apellido abajo)
## con un SubViewport que se reutiliza, y luego el viewport se libera.
## El escudo es el del RPG si el partido lo trae (config "home_crest": Callable -> Control);
## si no, un escudo dibujado con los colores y las iniciales (KitDecals.Shield).

const SIZE := 256

## Patrocinadores inventados: uno fijo por club (según su nombre).
const SPONSORS := ["VOLTA", "NEXO", "AIRSUR", "KRONOS", "MOVIX", "BANCO SOL", "ÓRBITA", "TERRA",
	"PULSO", "VERTEX", "COSMO", "ANDES", "NOVA", "FLYMAX", "MAREA", "ZENIT"]


static func sponsor_for(club: String) -> String:
	return SPONSORS[absi(hash("sponsor:" + club)) % SPONSORS.size()]


## Escudo de un club: el que da `maker` (Callable -> Control) o uno dibujado.
static func crest_control(team_name: String, c1: Color, c2: Color, maker: Variant = null) -> Control:
	if maker is Callable and (maker as Callable).is_valid():
		var c: Variant = (maker as Callable).call()
		if c is Control:
			return c
	var sh := Shield.new()
	sh.c1 = c1
	sh.c2 = c2
	var ini := ""
	for w: String in team_name.split(" ", false):
		if ini.length() < 2 and not w.to_lower() in ["de", "del", "la", "el", "los", "las", "fc", "cf", "cd", "sc"]:
			ini += w.left(1)
	sh.initials = ini.to_upper()
	return sh


## Hornea los estampados de varios jugadores, uno por cuadro. jobs = [{target: Callable(Texture2D),
## crest: Callable -> Control, crest_key, sponsor, number, name, ink: Color}]. Devuelve al acabar.
static func bake_all(host: Node, jobs: Array) -> void:
	if DisplayServer.get_name() == "headless" or jobs.is_empty():
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var crest_cache: Dictionary = {}
	for job: Dictionary in jobs:
		for ch in vp.get_children():
			vp.remove_child(ch)
			if not crest_cache.values().has(ch):
				ch.queue_free()
		var key: Variant = job.get("crest_key", null)
		var crest: Control
		if key != null and crest_cache.has(key):
			crest = crest_cache[key]
		else:
			crest = (job.crest as Callable).call()
			if key != null:
				crest_cache[key] = crest
		_layout(vp, crest, String(job.get("sponsor", "")), int(job.get("number", 0)), String(job.get("name", "")),
				job.get("ink", Color.WHITE), job.get("edge", Color(0, 0, 0, 0)))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(host):
			return
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			(job.target as Callable).call(ImageTexture.create_from_image(img))
	for ch in vp.get_children():
		vp.remove_child(ch)
		if not crest_cache.values().has(ch):
			ch.queue_free()
	for c in crest_cache.values():
		if is_instance_valid(c):
			(c as Node).queue_free()
	vp.queue_free()


## edge: color del contorno de las letras (el de la camiseta, para que se lean sobre rayas
## o cuadros); con alfa 0, una sombra suave.
static func _layout(vp: SubViewport, crest: Control, sponsor: String, number: int, surname: String, ink: Color,
		edge := Color(0, 0, 0, 0)) -> void:
	var outline := edge if edge.a > 0.0 else (Color(0, 0, 0, 0.55) if ink.get_luminance() > 0.5 else Color(1, 1, 1, 0.45))
	var thick := 2 if edge.a > 0.0 else 1
	# Escudo: cuadrante de arriba a la izquierda (se escala a 112 px desde su tamaño propio)
	vp.add_child(crest)
	var base := crest.size
	if base.x < 1.0:
		base = crest.custom_minimum_size
	if base.x < 1.0:
		base = Vector2(76, 76)
		crest.size = base
	crest.position = Vector2(8, 8)
	crest.scale = Vector2.ONE * (112.0 / maxf(base.x, base.y))
	# Dorsal grande arriba a la derecha
	if number > 0:
		var n := _text(vp, str(number), 100, ink, outline, 8 * thick)
		n.position = Vector2(128, 4)
		n.size = Vector2(128, 120)
	# Patrocinio en la franja media
	if sponsor != "":
		var s := _text(vp, sponsor, 58 if sponsor.length() <= 6 else (48 if sponsor.length() <= 8 else 36), ink, outline, 4 * thick)
		s.position = Vector2(0, 128)
		s.size = Vector2(256, 64)
	# Apellido abajo
	if surname != "":
		var t := _text(vp, surname.to_upper(), 40 if surname.length() <= 9 else 30, ink, outline, 4 * thick)
		t.position = Vector2(0, 192)
		t.size = Vector2(256, 64)


static func _text(vp: SubViewport, txt: String, size: int, ink: Color, outline: Color, ol: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = ink
	ls.outline_size = ol
	ls.outline_color = outline
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Black", "Impact", "sans-serif"])
	f.font_weight = 900
	ls.font = f
	l.label_settings = ls
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	vp.add_child(l)
	return l


## Escudo dibujado: dos mitades de color, borde blanco y siglas.
class Shield extends Control:
	var c1 := Color.RED
	var c2 := Color.WHITE
	var initials := ""

	func _ready() -> void:
		if size == Vector2.ZERO:
			size = Vector2(76, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var pts := PackedVector2Array([Vector2(0.08, 0.04), Vector2(0.92, 0.04), Vector2(0.92, 0.5),
				Vector2(0.5, 0.97), Vector2(0.08, 0.5)])
		for i in pts.size():
			pts[i] *= s
		draw_colored_polygon(pts, c1)
		draw_colored_polygon(PackedVector2Array([Vector2(0.5, 0.04) * s, pts[1], pts[2], pts[3]]), c2.lerp(c1, 0.15))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(1, 1, 1, 0.9), maxf(2.0, s.x * 0.04), true)
		var f := ThemeDB.fallback_font
		var fs := int(s.y * 0.34)
		var tw := f.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((s.x - tw) * 0.5, s.y * 0.56)
		draw_string_outline(f, at, initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, int(s.y * 0.08)), Color(0, 0, 0, 0.8))
		draw_string(f, at, initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
