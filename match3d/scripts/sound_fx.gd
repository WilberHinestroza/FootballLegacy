class_name SoundFx
extends Node
## Sonidos del partido generados por código (sin archivos de audio): golpes al balón, toques,
## silbato, poste, red, blocaje, ambiente del público y celebración.
## Lo crea el partido; cualquiera puede llamar a SoundFx.play("kick") (si no hay partido, no suena).

const RATE := 22050

static var instance: SoundFx
static var _cache := {}

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer
var _crowd_target := -14.0


func _ready() -> void:
	instance = self
	for k in ["kick", "touch", "catch", "post", "net", "whistle", "whistle_end", "cheer"]:
		_stream(k) # se generan al empezar, no a mitad de jugada
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd.stream = _stream("crowd")
	_crowd.volume_db = -14.0
	add_child(_crowd)
	_crowd.play()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	# El ambiente se ajusta despacio (más fuerte en los momentos clave)
	_crowd.volume_db = move_toward(_crowd.volume_db, _crowd_target, 12.0 * delta)


## Suena un efecto. volume_db: 0 = normal; pitch: 1 = normal.
static func play(sfx: String, volume_db := 0.0, pitch := 1.0) -> void:
	if instance == null:
		return
	var p := instance._pool[instance._next]
	instance._next = (instance._next + 1) % instance._pool.size()
	p.stream = _stream(sfx)
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()


## Volumen del murmullo del público (dB).
static func set_crowd(volume_db: float) -> void:
	if instance:
		instance._crowd_target = volume_db


static func _stream(sfx: String) -> AudioStreamWAV:
	if not _cache.has(sfx):
		_cache[sfx] = _make(sfx)
	return _cache[sfx]


# ---------- síntesis ----------

static func _make(sfx: String) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var loop := false
	match sfx:
		"kick":
			s = _render(0.16, func(t: float, n: float) -> float:
				return (sin(TAU * (70.0 + 120.0 * exp(-t * 40.0)) * t) * 0.9 + n * 0.5 * exp(-t * 90.0)) * exp(-t * 22.0))
		"touch":
			s = _render(0.08, func(t: float, n: float) -> float:
				return (sin(TAU * 110.0 * t) * 0.6 + n * 0.25 * exp(-t * 120.0)) * exp(-t * 45.0))
		"catch":
			s = _render(0.14, func(t: float, n: float) -> float:
				return (sin(TAU * 150.0 * t) * 0.6 + n * 0.7 * exp(-t * 60.0)) * exp(-t * 30.0))
		"post":
			s = _render(0.9, func(t: float, n: float) -> float:
				var ring := sin(TAU * 820.0 * t) + 0.7 * sin(TAU * 1310.0 * t) + 0.5 * sin(TAU * 2140.0 * t)
				return ring * 0.35 * exp(-t * 6.0) + n * 0.6 * exp(-t * 80.0))
		"net":
			s = _lowpass(_render(0.5, func(t: float, n: float) -> float:
				return n * sin(PI * minf(t / 0.5, 1.0)) * 0.8), 0.25)
		"whistle":
			s = _whistle([[0.0, 0.35]])
		"whistle_end":
			s = _whistle([[0.0, 0.3], [0.45, 0.3], [0.9, 0.9]])
		"cheer":
			s = _lowpass(_render(3.5, func(t: float, n: float) -> float:
				return n * minf(t * 4.0, 1.0) * exp(-maxf(t - 0.6, 0.0) * 0.9) * (0.8 + 0.2 * sin(t * 9.0))), 0.35)
		"crowd":
			loop = true
			s = _lowpass(_render(4.0, func(t: float, n: float) -> float:
				return n * (0.6 + 0.25 * sin(TAU * t / 4.0) + 0.1 * sin(TAU * t))), 0.08)
			# Unión suave del bucle
			var fade := int(RATE * 0.2)
			for i in fade:
				var k := float(i) / fade
				s[i] = s[i] * k + s[s.size() - fade + i] * (1.0 - k)
			s = s.slice(0, s.size() - fade)
	return _to_wav(s, loop)


static func _render(seconds: float, f: Callable) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	for i in out.size():
		out[i] = f.call(float(i) / RATE, randf() * 2.0 - 1.0)
	return out


## Filtro paso bajo simple (a = 0..1, más bajo = más grave), normalizado.
static func _lowpass(s: PackedFloat32Array, a: float) -> PackedFloat32Array:
	var y := 0.0
	var peak := 0.001
	for i in s.size():
		y += a * (s[i] - y)
		s[i] = y
		peak = maxf(peak, absf(y))
	for i in s.size():
		s[i] = s[i] / peak * 0.8
	return s


## Silbato de árbitro: tono agudo con el trino de la bolita. pulses = [[inicio, duración]].
static func _whistle(pulses: Array) -> PackedFloat32Array:
	var last: Array = pulses[pulses.size() - 1]
	return _render(float(last[0]) + float(last[1]) + 0.05, func(t: float, n: float) -> float:
		var v := 0.0
		for pu: Array in pulses:
			var lt := t - float(pu[0])
			if lt >= 0.0 and lt <= float(pu[1]):
				var env := minf(lt / 0.02, 1.0) * minf((float(pu[1]) - lt) / 0.04, 1.0)
				var trill := 0.65 + 0.35 * sin(TAU * 32.0 * lt)
				v += (sin(TAU * 2750.0 * lt) * 0.6 + sin(TAU * 2900.0 * lt) * 0.3 + n * 0.08) * env * trill
		return v * 0.6)


static func _to_wav(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	return w
