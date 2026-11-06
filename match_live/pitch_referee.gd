class_name PitchReferee
extends Node2D
## Árbitro y jueces de línea: usan las mismas animaciones de cancha que los
## jugadores (PlayerSprite), con uniforme de árbitro. No tocan la pelota ni
## chocan: solo acompañan la jugada para que la cancha se vea viva.
##  - "main": sigue la jugada en diagonal, a unos 10 m de la pelota.
##  - "line_top" / "line_bottom": corren por la banda (izquierda / derecha),
##    cada uno en su mitad de cancha, con el banderín.

var kind: String = "main"
var vel := Vector2.ZERO
var facing := Vector2.DOWN
var gfx: PlayerSprite
var flag_col := Color(1.0, 0.85, 0.1)
## Banderín levantado (fuera de juego), en segundos.
var flag_up_t: float = 0.0

func setup(p_kind: String, kit_col: String, seed_int: int) -> void:
	kind = p_kind
	var cfg: Dictionary = PitchAvatar.with_kit(PitchAvatar.random_config(seed_int),
		{"clothing": kit_col, "shorts": "#151515", "socks": kit_col, "boots": "#101010"})
	gfx = PlayerSprite.new()
	gfx.setup(cfg)
	gfx.scale = Vector2.ONE * Cfg.PLAYER_SCALE
	add_child(gfx)
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	match kind:
		"line_top":
			position = Vector2(-0.8 * Cfg.M, H * 0.25)
			flag_col = Color(1.0, 0.55, 0.1)
		"line_bottom":
			position = Vector2(W + 0.8 * Cfg.M, H * 0.75)
			flag_col = Color(1.0, 0.85, 0.1)
		_:
			position = Vector2(W * 0.5 - 8.0 * Cfg.M, H * 0.5 + 6.0 * Cfg.M)

## Avanza `dt` siguiendo la pelota.
func step(dt: float, ball_pos: Vector2, ball_vel: Vector2) -> void:
	var W: float = Cfg.FIELD_W
	var H: float = Cfg.FIELD_H
	var M: float = Cfg.M
	var target: Vector2 = position
	var top_speed: float = 6.6 * M
	match kind:
		"line_top":
			target = Vector2(-0.8 * M, clampf(ball_pos.y, 2.0 * M, H * 0.5))
		"line_bottom":
			target = Vector2(W + 0.8 * M, clampf(ball_pos.y, H * 0.5, H - 2.0 * M))
		_:
			# Diagonal: hacia el centro de la cancha y un poco detrás de la jugada.
			var side: float = -1.0 if ball_pos.x > W * 0.5 else 1.0
			var behind: float = 1.0 if ball_vel.y <= 0.0 else -1.0
			# Lejos de la jugada (antes se metía entre los jugadores).
			target = ball_pos + Vector2(side * 11.0 * M, behind * 12.0 * M)
			target.x = clampf(target.x, 5.0 * M, W - 5.0 * M)
			target.y = clampf(target.y, 8.0 * M, H - 8.0 * M)
			# Si la pelota viene hacia él, se corre.
			if position.distance_to(ball_pos) < 7.0 * M:
				target = position + (position - ball_pos).normalized() * 8.0 * M
			top_speed = 7.2 * M
	var to: Vector2 = target - position
	var want: Vector2 = Vector2.ZERO
	if to.length() > 1.2 * M:
		want = to.normalized() * minf(top_speed, to.length() * 1.6)
	if flag_up_t > 0.0:
		flag_up_t = maxf(flag_up_t - dt, 0.0)
		want = Vector2.ZERO
	vel = vel.move_toward(want, 18.0 * M * dt)
	position += vel * dt
	# Mira la pelota (los jueces de línea, siempre hacia la cancha).
	var look: Vector2 = ball_pos - position
	if kind != "main":
		look = Vector2(W * 0.5 - position.x, 0.0)
	if look.length() > 1.0:
		facing = look.normalized()
	_anim()
	queue_redraw()

func _anim() -> void:
	var spd: float = vel.length()
	if spd > 4.5 * Cfg.M:
		gfx.set_anim(PlayerSprite.resolve("run8", vel), true, 12.0)
		gfx.speed_scale = clampf(spd / (6.8 * Cfg.M), 0.7, 1.4)
	elif spd > 0.5 * Cfg.M:
		# Los jueces de línea trotan de costado mirando la cancha.
		gfx.set_anim(PlayerSprite.resolve("trote", vel if kind == "main" else facing), true, 10.0)
		gfx.speed_scale = clampf(spd / (3.0 * Cfg.M), 0.6, 1.4)
	else:
		gfx.set_anim(PlayerSprite.resolve("idle", facing), true, 1.0)
		gfx.speed_scale = 1.0

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 7.0 * Cfg.PLAYER_SCALE, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind != "main":
		# Banderín en la mano del lado de afuera.
		var sx: float = -7.0 if kind == "line_top" else 7.0
		var hand := Vector2(sx, -22.0) * Cfg.PLAYER_SCALE
		if flag_up_t > 0.0:
			# Brazo arriba con el banderín flameando.
			hand = Vector2(sx * 0.8, -40.0) * Cfg.PLAYER_SCALE
			var wav: float = sin(float(Time.get_ticks_msec()) / 70.0) * 1.5
			draw_line(Vector2(sx * 0.5, -26.0) * Cfg.PLAYER_SCALE, hand, Color(0.2, 0.2, 0.2), 1.5)
			draw_line(hand, hand + Vector2(0, -12), Color(0.15, 0.15, 0.15), 1.5)
			draw_rect(Rect2(hand + Vector2(0 if sx > 0.0 else -8, -12 + wav), Vector2(8, 6)), flag_col)
			return
		draw_line(hand, hand + Vector2(0, -10), Color(0.15, 0.15, 0.15), 1.5)
		draw_rect(Rect2(hand + Vector2(0 if sx > 0.0 else -7, -10), Vector2(7, 5)), flag_col)
