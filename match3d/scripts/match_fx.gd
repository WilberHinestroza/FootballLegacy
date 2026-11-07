extends Node3D
## Efectos del partido 3D sin reglas de juego (separado de match.gd, 7-nov):
## polvo de césped/agua en golpes y barridas, y la lluvia que sigue a la cámara.
## Lo crea SoccerMatch como hijo "Fx"; no sabe nada del estado del partido.
const Weather = preload("res://engine/match/m3d/Weather.gd")


## Golpe fuerte o barrida: salta un poco de césped (o agua, si llueve). Dos
## emisores que se turnan, de un solo disparo: barato también en el móvil.
var _puffs: Array[CPUParticles3D] = []
var _puff_i := 0


func turf_puff(pos: Vector3, strength: float) -> void:
	if _puffs.is_empty():
		var wet := FieldBuilder.weather == Weather.RAIN
		for k in 2:
			var e := CPUParticles3D.new()
			e.one_shot = true
			e.emitting = false
			e.amount = 14
			e.lifetime = 0.55
			e.explosiveness = 0.95
			e.local_coords = false
			e.direction = Vector3.UP
			e.spread = 50.0
			e.initial_velocity_min = 1.8
			e.initial_velocity_max = 3.6
			e.gravity = Vector3(0.0, -9.0, 0.0)
			e.scale_amount_min = 0.5
			e.scale_amount_max = 1.0
			var q := QuadMesh.new()
			q.size = Vector2(0.05, 0.05)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.85, 0.9, 1.0, 0.55) if wet else Color(0.27, 0.5, 0.2, 0.95)
			q.material = mat
			e.mesh = q
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(e)
			_puffs.append(e)
	var e := _puffs[_puff_i]
	_puff_i = (_puff_i + 1) % _puffs.size()
	e.global_position = Vector3(pos.x, 0.05, pos.z)
	e.initial_velocity_max = lerpf(2.4, 4.2, clampf(strength, 0.0, 1.0))
	e.restart()


## Lluvia: gotas alrededor de la cámara (en el mundo, no pegadas a ella, para que
## caigan rectas al girar) y su sonido de fondo.
var _rain: CPUParticles3D


func start_rain() -> void:
	_rain = CPUParticles3D.new()
	_rain.amount = 360 if OS.has_feature("mobile") else 700
	_rain.lifetime = 0.9
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(15.0, 1.0, 15.0)
	_rain.direction = Vector3(0.08, -1.0, 0.04)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 16.0
	_rain.initial_velocity_max = 20.0
	_rain.gravity = Vector3(0.0, -6.0, 0.0)
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_color = Color(0.8, 0.85, 0.93, 0.22)
	q.material = mat
	_rain.mesh = q
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)
	SoundFx.start_loop("rain", -13.0)


func follow_rain(cam: Camera3D, indoors: bool) -> void:
	if _rain == null or cam == null:
		return
	var cp := cam.global_position
	# Bajo techo (vestuario, túnel) no llueve
	_rain.visible = not indoors and absf(cp.x) < 64.0 and absf(cp.z) < 50.0
	var fwd := Vector3(-cam.global_transform.basis.z.x, 0.0, -cam.global_transform.basis.z.z).normalized()
	_rain.global_position = cp + fwd * 9.0 + Vector3.UP * 9.0
