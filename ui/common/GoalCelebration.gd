extends Node2D
class_name GoalCelebration

## Celebración de gol — la CARA del jugador (Avatar.build, la misma que ya
## se ve en su perfil, con la boca cambiada a una de festejo — ver
## Avatar.celebration_config_for_player) GRANDE, con una entrada vistosa +
## destello + confeti. Reemplaza a un emoji genérico (Parte 85), que a su
## vez había reemplazado a la figura articulada original (rig 2D de
## cápsulas sin IK, ~500 líneas, muchas rondas de ajuste documentadas en
## el historial de este archivo): pese a esos ajustes seguía viéndose
## rígida/antinatural — reporte directo de Wilber (13-sep). La cara del
## Avatar Mixer ya está PROBADA en el resto del juego (perfil, zona mixta,
## chat) — reusarla es más inmersiva que un ícono genérico ("sos VOS
## festejando") sin el riesgo de animar un cuerpo entero.
##
## Parte 91 (13-sep): se probó un cuerpo completo con el pack Kenney "Toon
## Characters" (piernas/torso/brazos reales + la cara acá arriba montada en
## el cuello) — Wilber lo vio en el celular y no convenció ("se ve
## terrible"), pidió volver a esta versión de solo la cara. Revertido tal
## cual estaba. El pack Kenney queda sin usar de nuevo en el repo (ver
## Parte 87) — no se borra por si se retoma más adelante con otro enfoque.
##
## La variedad entre las 24 celebraciones sigue viniendo del texto
## (Match._CELEBRATIONS) para elegir el ESTILO DE ENTRADA (rebote / giro /
## caída / deslizada / bamboleo, por hash) — la cara es siempre la misma
## (es SU cara), lo que cambia es cómo "entra" cada festejo.
##
## 9-oct: con las animaciones de PixelLab (Avatar.build_anim) el jugador
## ahora FESTEJA de cuerpo entero — una de 6 celebraciones (rodillas,
## salto con puño, avión, señalar al cielo, besar el escudo, mortal),
## elegida por el texto de la celebración y teñida con su piel/pelo/kit. Si
## falta el arte, cae al jugador quieto de antes (versión previa guardada
## en art_src/legacy_kenney/GoalCelebration.gd.txt). Con cuerpo animado,
## las entradas que GIRAN todo el cuerpo (spin/wobble) se ven raras — solo
## se usan pop/drop/slide.
##
## Uso:  var c := GoalCelebration.new(); add_child(c)
##       c.play(Avatar.celebration_config_for_player(player, world_seed),
##              "Se lo dedica a la grada", team_color, ball_idx)

## Y local (relativo a `position`, sin escala externa) donde debería
## arrancar el césped debajo de la cara.
const FEET_Y := 30.0
## Grande de verdad (pedido de Wilber) — sin fondo detrás (ni el propio
## del Avatar Mixer, sacado en Avatar.celebration_config_for_player, ni
## un glow nuestro: la cara sola, flotando, se lee mejor a este tamaño).
const AVATAR_PX := 168
## Animado: lienzo de 68 px de PixelLab ×3 (escala ENTERA = pixel art nítido).
const ANIM_AVATAR_PX := 204
const ANIM_ENTRIES := ["pop", "drop", "slide"]
var _animated: bool = false
var _px: int = AVATAR_PX
## 9-oct (Wilber: "el césped, el balón y el jugador celebrando se ven mal
## organizados"): el lienzo de la animación tiene aire debajo de los pies
## (pies en la fila 57 de 68) → se alineaba el BORDE del lienzo con el
## césped y el jugador flotaba ~30 px. Ahora se alinean los PIES. El balón
## era de 84 px (casi el torso) flotando al costado: ahora a escala y
## apoyado junto al pie, con sombras.
const FEET_RATIO := 57.0 / 68.0
const BALL_PX := 46

const ENTRIES := ["pop", "spin", "drop", "slide", "wobble"]

var _avatar: Control
var _ball: Control
var _kit := Color(0.95, 0.82, 0.25)
## Compañeros que se suman al festejo (configs de Avatar.teammate_config).
## Vacío = festejo solo (como antes). Los arma Match.
var mates: Array = []
## Festejo de firma del jugador (CareerRpgEngine.signature_celebration); "" = sin.
var signature: String = ""
const MATE_ANIMS := ["celeb_salto", "celeb_aplauso", "celeb_grito", "celeb_baile"]

## Césped del festejo (lo usa Match y el probe de captura): franjas, una
## línea de cal y un degradado que oscurece hacia abajo. `feet_y` = Y (en
## coordenadas de `parent`) donde apoyan los pies: el césped empieza más
## arriba para que el jugador quede PARADO sobre él, no en el borde.
static func build_grass(parent: Control, area: Vector2, feet_y: float) -> Control:
	var pitch := Control.new()
	pitch.name = "CelebPitch"
	pitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	var top: float = feet_y - 70.0
	var base := ColorRect.new()
	base.color = Color(0.15, 0.36, 0.18)
	base.position = Vector2(0, top)
	base.size = Vector2(area.x, area.y - top)
	pitch.add_child(base)
	var band: float = 46.0
	for i in range(0, int(area.x / band) + 1):
		if i % 2 == 0:
			var stripe := ColorRect.new()
			stripe.color = Color(0.18, 0.42, 0.21)
			stripe.position = Vector2(i * band, top)
			stripe.size = Vector2(band, area.y - top)
			pitch.add_child(stripe)
	# Línea de cal (borde del área) cruzando detrás del jugador.
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.55)
	line.position = Vector2(0, top + 26.0)
	line.size = Vector2(area.x, 3)
	pitch.add_child(line)
	var horizon := ColorRect.new()
	horizon.color = Color(0.5, 0.75, 0.45, 0.6)
	horizon.position = Vector2(0, top)
	horizon.size = Vector2(area.x, 3)
	pitch.add_child(horizon)
	# Oscurece hacia abajo (profundidad).
	var fade := TextureRect.new()
	fade.texture = Styles.gradient_texture(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55))
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.position = Vector2(0, top)
	fade.size = Vector2(area.x, area.y - top)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pitch.add_child(fade)
	parent.add_child(pitch)
	return pitch

func play(avatar_config: Dictionary, variant_seed: String, team_color: Color = Color.WHITE, ball_idx: int = -1) -> void:
	if team_color != Color.WHITE:
		_kit = team_color
	_build(avatar_config, variant_seed, ball_idx)
	var entries: Array = ANIM_ENTRIES if _animated else ENTRIES
	var entry: String = entries[absi(hash(variant_seed)) % entries.size()]
	match entry:
		"pop": _anim_pop()
		"spin": _anim_spin()
		"drop": _anim_drop()
		"slide": _anim_slide()
		_: _anim_wobble()
	if _animated and not mates.is_empty():
		var mt := create_tween()
		mt.tween_interval(0.35)
		mt.tween_callback(_spawn_mates.bind(variant_seed))

## Los compañeros llegan corriendo desde los costados y festejan DETRÁS
## tuyo (un poco más chicos y oscuros = profundidad), cada uno con su
## animación.
func _spawn_mates(variant_seed: String) -> void:
	var mpx: int = int(_px * 0.82)
	for i in range(mini(mates.size(), 2)):
		var side: float = -1.0 if i == 0 else 1.0
		var anim: String = String(MATE_ANIMS[absi(hash("%s|mate%d" % [variant_seed, i])) % MATE_ANIMS.size()])
		if not Avatar.has_anim(anim):
			anim = "celeb_salto"
		var m: Control = Avatar.build_anim(mates[i], anim, mpx)
		m.size = Vector2(mpx, mpx)
		m.modulate = Color(0.86, 0.86, 0.9, 0.0)
		var rest := Vector2(side * _px * 0.42 - mpx * 0.5, FEET_Y - 10.0 - mpx * FEET_RATIO)
		m.position = rest + Vector2(side * 160.0, 0)
		add_child(m)
		move_child(m, 0)   # detrás del jugador
		var t := create_tween()
		t.tween_property(m, "modulate:a", 1.0, 0.12)
		t.parallel().tween_property(m, "position", rest, 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _build(avatar_config: Dictionary, variant_seed: String, ball_idx: int = -1) -> void:
	var anim: String = Avatar.celebration_anim_for(variant_seed)
	# FESTEJO DE FIRMA (10-oct): si elegiste uno en Mi Perfil, sale 2 de cada 3
	# goles; el resto sigue variando.
	if signature != "" and absi(hash("sig:" + variant_seed)) % 3 != 0:
		anim = signature
	_animated = Avatar.has_anim(anim)
	_px = ANIM_AVATAR_PX if _animated else AVATAR_PX
	_avatar = Avatar.build_anim(avatar_config, anim, _px) if _animated else Avatar.build(avatar_config, AVATAR_PX)
	# Avatar.build() deja custom_minimum_size puesto (pensado para vivir
	# dentro de un Container que lo respete) — acá cuelga directo de un
	# Node2D, así que hay que fijar `size` a mano o los TextureRect
	# internos (anclados PRESET_FULL_RECT) quedan en área cero.
	_avatar.size = Vector2(_px, _px)
	var feet: float = FEET_RATIO if _animated else 1.0
	_avatar.position = Vector2(-_px * 0.5, FEET_Y - _px * feet)
	# Sombras en el piso (jugador y pelota).
	for sh in [[Vector2(-58, FEET_Y - 9), Vector2(116, 18)], [Vector2(_px * 0.24 - 4, FEET_Y - 7), Vector2(BALL_PX + 8, 12)]]:
		var shadow := Panel.new()
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(0, 0, 0, 0.32)
		ss.set_corner_radius_all(60)
		shadow.add_theme_stylebox_override("panel", ss)
		shadow.position = sh[0]
		shadow.size = sh[1]
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shadow)
	_avatar.pivot_offset = Vector2(_px * 0.5, _px * 0.5)
	add_child(_avatar)

	# El balón al lado (pedido de Wilber) — el MISMO balón del partido
	# (Match._match_ball_idx(), fijo/aleatorio según Preferences.ball_mode
	# — ver PreMatch.gd), no uno propio: antes la celebración sorteaba su
	# balón por su cuenta, sin mirar el elegido/sorteado para el partido —
	# inconsistencia real encontrada al cablear la opción de balón
	# aleatorio (Parte 88). -1 = sin pasar (compatibilidad) → cae al
	# mismo determinista de siempre por texto de la celebración.
	var idx: int = ball_idx if ball_idx >= 0 else BallDesign.default_for(variant_seed)
	_ball = BallDesign.build(idx, BALL_PX)
	_ball.size = Vector2(BALL_PX, BALL_PX)
	_ball.position = Vector2(_px * 0.24, FEET_Y - BALL_PX + 4.0)
	_ball.pivot_offset = Vector2(BALL_PX * 0.5, BALL_PX * 0.5)
	add_child(_ball)

	# Entrada del balón: siempre la misma (pop + balanceo suave), sea cual
	# sea el estilo de entrada de la cara — no hacía falta una por estilo.
	_ball.scale = Vector2(0.1, 0.1)
	_ball.modulate.a = 0.0
	var bt := create_tween()
	bt.tween_interval(0.12)
	bt.tween_property(_ball, "modulate:a", 1.0, 0.1)
	bt.parallel().tween_property(_ball, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_property(_ball, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
	var spin := create_tween().set_loops()
	spin.tween_interval(0.4)
	spin.tween_property(_ball, "rotation", deg_to_rad(16), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	spin.tween_property(_ball, "rotation", deg_to_rad(-16), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _flash() -> void:
	for i in range(6):
		var f := Polygon2D.new()
		var pp := PackedVector2Array()
		for j in range(12):
			pp.append(Vector2(cos(TAU * j / 12.0), sin(TAU * j / 12.0)) * 3.4)
		f.polygon = pp
		f.color = Color(1, 1, 1, 0.0)
		var ang := randf() * TAU
		f.position = Vector2(cos(ang) * randf_range(56, 88), (FEET_Y - AVATAR_PX * 0.55) + sin(ang) * randf_range(26, 46))
		add_child(f)
		var ft := create_tween()
		ft.tween_interval(0.09 * i)
		ft.tween_property(f, "color:a", 0.98, 0.035).set_trans(Tween.TRANS_QUAD)
		ft.parallel().tween_property(f, "scale", Vector2(4.2, 4.2), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ft.parallel().tween_property(f, "color:a", 0.0, 0.22)
		ft.tween_callback(f.queue_free)

func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.amount = 46
	p.lifetime = 1.7
	p.one_shot = true
	p.explosiveness = 0.75
	p.position = Vector2(0, FEET_Y - AVATAR_PX * 0.75)
	p.direction = Vector2(0, -1)
	p.spread = 62.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 95)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.8
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.color = _kit.lightened(0.25)
	add_child(p)
	p.emitting = true
	var dt := create_tween()
	dt.tween_interval(2.0)
	dt.tween_callback(p.queue_free)

func _squash_avatar(sx: float, sy: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(_avatar, "scale", Vector2(sx, sy), dur * 0.35).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_avatar, "scale", Vector2(1.0, 1.0), dur * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _finish(delay: float) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)

# --------------------------------------------------------------------------
# Estilos de entrada
# --------------------------------------------------------------------------

func _anim_pop() -> void:
	_avatar.scale = Vector2(0.1, 0.1)
	_avatar.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_avatar, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(_avatar, "scale", Vector2(1.2, 1.2), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_avatar, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_flash)
	t.tween_callback(_confetti)
	var bob := create_tween().set_loops(3)
	bob.tween_interval(0.5)
	bob.tween_property(_avatar, "rotation", deg_to_rad(-7), 0.18).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_avatar, "rotation", deg_to_rad(7), 0.18).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_avatar, "rotation", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	_finish(1.8)

func _anim_spin() -> void:
	_avatar.scale = Vector2(0.1, 0.1)
	_avatar.modulate.a = 0.0
	_avatar.rotation = deg_to_rad(-540)
	var t := create_tween()
	t.tween_property(_avatar, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(_avatar, "scale", Vector2(1.12, 1.12), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_avatar, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(_avatar, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_flash)
	t.tween_callback(_confetti)
	_finish(1.8)

func _anim_drop() -> void:
	_avatar.modulate.a = 0.0
	var rest_y: float = _avatar.position.y
	_avatar.position.y = rest_y - 110.0
	var t := create_tween()
	t.tween_property(_avatar, "modulate:a", 1.0, 0.08)
	t.tween_property(_avatar, "position:y", rest_y, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_squash_avatar(1.26, 0.76, 0.26)
		_flash()
		_confetti())
	_finish(1.8)

func _anim_slide() -> void:
	_avatar.modulate.a = 0.0
	var rest_x: float = _avatar.position.x
	_avatar.position.x = rest_x - 110.0
	var t := create_tween()
	t.tween_property(_avatar, "modulate:a", 1.0, 0.08)
	t.tween_property(_avatar, "position:x", rest_x, 0.36).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_squash_avatar(1.18, 0.86, 0.22)
		_flash()
		_confetti())
	_finish(1.8)

func _anim_wobble() -> void:
	_avatar.scale = Vector2(0.1, 0.1)
	_avatar.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_avatar, "modulate:a", 1.0, 0.1)
	t.tween_property(_avatar, "scale", Vector2(1.12, 1.12), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_avatar, "scale", Vector2(1.0, 1.0), 0.14)
	t.tween_callback(_flash)
	t.tween_callback(_confetti)
	var w := create_tween().set_loops(4)
	w.tween_property(_avatar, "rotation", deg_to_rad(-12), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	w.tween_property(_avatar, "rotation", deg_to_rad(12), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	w.tween_property(_avatar, "rotation", 0.0, 0.12)
	_finish(1.8)
