class_name Stadium
extends Node2D
## El estadio alrededor de la cancha (arte de PixelLab en assets/stadium2/,
## misma vista cenital alta que los jugadores):
##  - Césped hasta los carteles, carteles de publicidad en los 4 lados.
##  - Pista de cemento y tribunas llenas: la de ARRIBA la vemos de frente
##    (stand_front.png), las demás desde arriba (crowd_top.png).
##  - Bancos de suplentes y cámara de TV en la banda izquierda, fotógrafos
##    detrás de los arcos, alcanzapelotas en las esquinas, banderines.
## Todo va derecho (como los jugadores, que nunca rotan).

const BOARD_GAP := 5.0      # metros de la línea a los carteles
const BOARD_H := 0.9        # alto de los carteles (m)
const TRACK := 1.6          # pista de cemento detrás de los carteles (m)
const STAND_DEPTH := 26.0
const SPONSORS := ["vortex_sport", "andico_cafe", "prisma_telecom", "aurea_bebidas",
	"ferro_nutrition", "nimbus_gear", "rocamar_auto", "solmar_energia"]
const SPONSOR_COLORS := ["#1d2a44", "#3b2414", "#14143a", "#3a2a06", "#122c1a", "#1a2e3a", "#2e1414", "#3a1e06"]
const DIR := "res://assets/stadium2/"
const BENCH_ZONE := 18.0    # medio largo (m) de la zona de bancos + túnel (sin carteles)

var _crowd_top: Texture2D
var _stand_front: Texture2D
var _logos: Array = []
var _t := 0.0
var _redraw := 0.0
var _crowd_layer: Node2D

func _ready() -> void:
	z_index = -9
	_crowd_top = _tex(DIR + "crowd_top.png")
	_stand_front = _tex(DIR + "stand_front.png")
	if _crowd_top == null:
		_crowd_top = _tex("res://assets/stadium/crowd_tile.png")
	for s in SPONSORS:
		_logos.append(_tex("res://assets/sponsors/%s.png" % s))
	# Público en su propia capa (debajo de carteles y props).
	_crowd_layer = Node2D.new()
	_crowd_layer.z_index = -1
	_crowd_layer.z_as_relative = true
	_crowd_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crowd_layer.draw.connect(_draw_crowd)
	add_child(_crowd_layer)
	_add_props()

func _tex(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null

func _process(dt: float) -> void:
	_t += dt
	_redraw -= dt
	if _redraw <= 0.0:
		_redraw = 0.08          # banderines y carteles LED a ~12 fps
		queue_redraw()

# ---------------------------------------------------------------- geometría

func _sg() -> float:
	return (BOARD_GAP + TRACK) * Cfg.M

func _stand_rects() -> Dictionary:
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	var sg: float = _sg()
	var sd: float = STAND_DEPTH * Cfg.M
	return {
		"top": Rect2(-sg - sd, -sg - sd, W + (sg + sd) * 2.0, sd),
		"bottom": Rect2(-sg - sd, H + sg, W + (sg + sd) * 2.0, sd),
		"left": Rect2(-sg - sd, -sg, sd, H + sg * 2.0),
		"right": Rect2(W + sg, -sg, sd, H + sg * 2.0),
	}

# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	var M: float = Cfg.M
	var bg: float = BOARD_GAP * M
	var sg: float = _sg()
	# Pista de cemento entre los carteles y la tribuna.
	var track := Color(0.36, 0.37, 0.40)
	draw_rect(Rect2(-sg, -sg, W + sg * 2.0, sg - bg), track)
	draw_rect(Rect2(-sg, H + bg, W + sg * 2.0, sg - bg), track)
	draw_rect(Rect2(-sg, -bg, sg - bg, H + bg * 2.0), track)
	draw_rect(Rect2(W + bg, -bg, sg - bg, H + bg * 2.0), track)
	# Borde de la tribuna (muro bajo).
	var wall := Color(0.2, 0.21, 0.25)
	draw_rect(Rect2(-sg, -sg - 0.6 * M, W + sg * 2.0, 0.6 * M), wall)
	draw_rect(Rect2(-sg, H + sg, W + sg * 2.0, 0.5 * M), wall)
	draw_rect(Rect2(-sg - 0.5 * M, -sg, 0.5 * M, H + sg * 2.0), wall)
	draw_rect(Rect2(W + sg, -sg, 0.5 * M, H + sg * 2.0), wall)
	_draw_boards(W, H, M)
	_draw_flags(W, H, M)

## Carteles LED: los de arriba de frente (logos), los de abajo de espaldas
## (estructura), los laterales vistos desde arriba (tira con logos chicos).
func _draw_boards(W: float, H: float, M: float) -> void:
	var by: float = -BOARD_GAP * M
	var bh: float = BOARD_H * M * 1.4
	var panel: float = 10.0 * M
	var shift: int = int(_t / 6.0)          # rotación de anuncios cada 6 s
	var x: float = -BOARD_GAP * M
	var i: int = 0
	while x < W + BOARD_GAP * M:
		var k: int = i + shift
		var r := Rect2(x, by - bh, minf(panel, W + BOARD_GAP * M - x), bh)
		var col := Color(String(SPONSOR_COLORS[k % SPONSOR_COLORS.size()]))
		draw_rect(r, col)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), col.lightened(0.35))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), col.darkened(0.5))
		var logo: Texture2D = _logos[k % _logos.size()]
		if logo != null:
			var ls: float = bh - 5.0
			var n: int = maxi(1, int(r.size.x / (ls * 2.4)))
			for j in n:
				draw_texture_rect(logo, Rect2(r.position + Vector2(r.size.x * (j + 0.5) / n - ls * 0.5, 3), Vector2(ls, ls)), false)
		draw_line(Vector2(x, by - bh), Vector2(x, by), Color(0, 0, 0, 0.5), 1.0)
		x += panel
		i += 1
	# Abajo: de espaldas (estructura gris con patas).
	var ry: float = H + BOARD_GAP * M
	draw_rect(Rect2(-BOARD_GAP * M, ry, W + BOARD_GAP * 2.0 * M, bh * 0.6), Color(0.22, 0.23, 0.27))
	draw_rect(Rect2(-BOARD_GAP * M, ry, W + BOARD_GAP * 2.0 * M, 2), Color(0.42, 0.43, 0.48))
	var px: float = -BOARD_GAP * M
	while px < W + BOARD_GAP * M:
		draw_rect(Rect2(px, ry + bh * 0.6, 2, 3), Color(0.15, 0.15, 0.18))
		px += 2.5 * M
	# Laterales: desde arriba se ve el borde superior del cartel (tira) con
	# la cara apenas inclinada hacia la cancha.
	var seg: float = 10.0 * M
	var y: float = -BOARD_GAP * M
	i = 0
	while y < H + BOARD_GAP * M:
		var k2: int = i + shift
		var col2 := Color(String(SPONSOR_COLORS[k2 % SPONSOR_COLORS.size()]))
		var h2: float = minf(seg, H + BOARD_GAP * M - y)
		for side in [-1.0, 1.0]:
			if side < 0.0 and absf(y + h2 * 0.5 - H * 0.5) < BENCH_ZONE * M:
				continue
			var bx: float = -BOARD_GAP * M - 0.6 * M if side < 0.0 else W + BOARD_GAP * M
			draw_rect(Rect2(bx, y, 0.6 * M, h2), col2)
			draw_rect(Rect2(bx + (0.6 * M - 2.0 if side < 0.0 else 0.0), y, 2, h2), col2.lightened(0.4))
			var logo2: Texture2D = _logos[k2 % _logos.size()]
			if logo2 != null:
				var ls2: float = 0.6 * M - 2.0
				var yy: float = y + 4.0
				while yy < y + h2 - ls2:
					draw_texture_rect(logo2, Rect2(bx + 1.0, yy, ls2, ls2), false)
					yy += ls2 * 3.0
		draw_line(Vector2(-BOARD_GAP * M - 0.6 * M, y), Vector2(-BOARD_GAP * M, y), Color(0, 0, 0, 0.5), 1.0)
		draw_line(Vector2(W + BOARD_GAP * M, y), Vector2(W + BOARD_GAP * M + 0.6 * M, y), Color(0, 0, 0, 0.5), 1.0)
		y += seg
		i += 1

func _draw_flags(W: float, H: float, M: float) -> void:
	for c in [Vector2(0, 0), Vector2(W, 0), Vector2(0, H), Vector2(W, H)]:
		var top: Vector2 = c + Vector2(0, -1.6 * M * 0.8 * 1.6)
		draw_line(c, top, Color(0.95, 0.95, 0.95), 1.5)
		var wave: float = sin(_t * 6.0 + c.x * 0.01) * 2.0
		var dir: float = 1.0 if c.x < W * 0.5 else -1.0
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(dir * 9, 2 + wave), top + Vector2(0, 6)]), Color(1.0, 0.85, 0.1))
		draw_circle(c, 1.5, Color(0.9, 0.9, 0.9))

## Público: arriba de frente (gradas que suben), el resto desde arriba.
## Mosaico espejado (sin costuras visibles).
func _draw_crowd() -> void:
	var rects: Dictionary = _stand_rects()
	for key in rects:
		var r: Rect2 = rects[key]
		_crowd_layer.draw_rect(r, Color(0.17, 0.18, 0.22))
		if key == "top" and _stand_front != null:
			_tile(_stand_front, r, 1.5, true)
		elif _crowd_top != null:
			_tile(_crowd_top, r, 1.25, false)
	# Sombra de la tribuna sobre la pista (da profundidad).
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	var sg: float = _sg()
	_crowd_layer.draw_rect(Rect2(-sg, -sg, W + sg * 2.0, 0.8 * Cfg.M), Color(0, 0, 0, 0.18))
	_crowd_layer.draw_rect(Rect2(-sg, -sg, 0.8 * Cfg.M, H + sg * 2.0), Color(0, 0, 0, 0.14))

## Llena `r` con la textura a escala `k`, espejando en filas/columnas
## alternas. `from_bottom`: la grada de frente arranca abajo (pegada a la
## cancha) y sube; las filas superiores se oscurecen (más lejos).
func _tile(tex: Texture2D, r: Rect2, k: float, from_bottom: bool) -> void:
	var tw: float = tex.get_width() * k
	var th: float = tex.get_height() * k
	var nx: int = int(ceil(r.size.x / tw))
	var ny: int = int(ceil(r.size.y / th))
	for j in ny:
		for i in nx:
			var pos := Vector2(r.position.x + i * tw, (r.end.y - (j + 1) * th) if from_bottom else (r.position.y + j * th))
			var w: float = minf(tw, r.end.x - pos.x)
			var top_cut: float = maxf(r.position.y - pos.y, 0.0)
			var h: float = minf(th - top_cut, r.end.y - pos.y - top_cut)
			if w <= 0.0 or h <= 0.0:
				continue
			var src := Rect2(0, top_cut / k, w / k, h / k)
			var dst := Rect2(pos + Vector2(0, top_cut), Vector2(w, h))
			var shade: float = clampf(1.0 - float(j) * (0.12 if from_bottom else 0.0), 0.55, 1.0)
			if i % 2 == 1:
				# Espejo horizontal (un tamaño negativo NO espeja: corre el
				# dibujo). Se refleja con una transformación sobre la baldosa.
				src.position.x = tex.get_width() - src.size.x
				_crowd_layer.draw_set_transform(Vector2(dst.position.x * 2.0 + dst.size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
				_crowd_layer.draw_texture_rect_region(tex, dst, src, Color(shade, shade, shade * 1.03))
				_crowd_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				_crowd_layer.draw_texture_rect_region(tex, dst, src, Color(shade, shade, shade * 1.03))

# ---------------------------------------------------------------- personajes

func _add_props() -> void:
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	var M: float = Cfg.M
	# Bancos de suplentes (banda izquierda, a los lados de la mitad).
	# Bancos más grandes (antes 3,6 m de ancho: se veían de juguete) y el
	# túnel de los vestuarios entre los dos, saliendo de la tribuna.
	for dy in [-10.5, 10.5]:
		_prop("dugout_v.png", Vector2(-3.2 * M, H * 0.5 + dy * M + 7.0 * M), 1.6, false)
	_prop("tunnel.png", Vector2(-5.0 * M, H * 0.5 + 2.6 * M), 2.6, false)
	# Cámara de TV en la mitad, banda derecha (mira hacia la cancha).
	_prop("cameraman.png", Vector2(W + 2.6 * M, H * 0.5), 1.0, false)
	_prop("cameraman.png", Vector2(W + 2.6 * M, H * 0.5 - 30.0 * M), 1.0, false)
	_prop("cameraman.png", Vector2(W + 2.6 * M, H * 0.5 + 30.0 * M), 1.0, false)
	# Fotógrafos detrás de los arcos, a los costados del arco.
	for gy in [-2.4 * M, H + 3.6 * M]:
		for gx in [-14.0, -10.0, 10.5, 14.5]:
			_prop("photographer.png", Vector2(W * 0.5 + gx * M, gy), 0.9, gx > 0.0)
	# Alcanzapelotas cerca de los córners.
	for c in [Vector2(-2.8 * M, 14.0 * M), Vector2(W + 2.8 * M, 14.0 * M), Vector2(-2.8 * M, H - 14.0 * M), Vector2(W + 2.8 * M, H - 14.0 * M)]:
		_prop("ballboy.png", c, 0.85, c.x > W * 0.5)

## Un personaje/objeto del estadio parado en `feet` (sus pies en ese punto).
func _prop(file: String, feet: Vector2, k: float, flip: bool) -> void:
	var tex: Texture2D = _tex(DIR + file)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.flip_h = flip
	s.scale = Vector2(k, k)
	var r: Rect2i = Sprites.opaque_rect(tex)
	# El punto de apoyo es el borde inferior del dibujo.
	var bottom: float = (float(r.end.y) - tex.get_height() * 0.5) * k
	s.position = feet - Vector2(0, bottom)
	s.z_index = 1
	add_child(s)
