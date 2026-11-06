extends CPUParticles2D
class_name Confetti

## Confeti reutilizable (Kenney Particle Pack, star_04). Cae desde arriba
## de la pantalla con giro y colores variados. Se usa en la ceremonia de
## fin de temporada; pensado para reusar en celebraciones de gol/título.
## CPUParticles2D a propósito (no GPU): más seguro en GPUs Android viejas
## y el conteo es bajo.

const _TEX := "res://assets/particles/PNG (Transparent)/star_04.png"

func _ready() -> void:
	if ResourceLoader.exists(_TEX):
		texture = load(_TEX)
	amount = 70
	lifetime = 3.8
	preprocess = 1.2
	explosiveness = 0.0
	randomness = 0.6
	local_coords = false

	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(320, 8)
	direction = Vector2(0, 1)
	spread = 30.0
	gravity = Vector2(0, 120)
	initial_velocity_min = 30.0
	initial_velocity_max = 110.0
	angular_velocity_min = -220.0
	angular_velocity_max = 220.0
	scale_amount_min = 0.045
	scale_amount_max = 0.085

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.25))
	ramp.add_point(0.33, Color(0.35, 0.7, 1.0))
	ramp.add_point(0.66, Color(0.95, 0.35, 0.55))
	ramp.set_color(1, Color(0.4, 0.85, 0.45))
	color_ramp = ramp

## Enciende el confeti por `seconds` y después lo apaga (queda listo para
## volver a dispararse).
func burst(seconds: float = 3.0) -> void:
	# Ajustes → "Menos animaciones": el confeti no se emite.
	if Preferences.reduce_motion:
		return
	emitting = true
	await get_tree().create_timer(seconds).timeout
	emitting = false
