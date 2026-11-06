class_name Sfx
extends Node
## Sonido y vibración del partido. Los audios de público, silbato y gol son
## los de FootballCareer (assets/audio/match y assets/sound); las patadas,
## el quite y el palo se generaron sintetizados.
## Al integrar en FootballCareer conviene llamar a su autoload Audio /
## Haptics en lugar de esto (mismos nombres de evento).

const FILES := {
	"kick_soft": ["kick_soft.wav", -10.0], "kick_hard": ["kick_hard.wav", -4.0],
	"tackle": ["tackle.wav", -6.0], "post": ["post.wav", -5.0],
	"whistle": ["whistle_short.wav", -9.0], "whistle_long": ["whistle_long.wav", -8.0],
	"roar": ["crowd_roar.wav", -4.0], "ohh": ["crowd_ohh.wav", -6.0],
	"goal": ["goal.mp3", -6.0], "goal_rival": ["goal_rival.mp3", -6.0],
	"good": ["chime_good.wav", -12.0],
}
## Patrones de vibración (ms pulso, ms pausa, ...), como Haptics.gd.
const BUZZ := {
	"goal": [90, 70, 230], "goal_against": [50, 40, 110], "tackle": [30],
	"post": [40], "kick": [10], "won": [25],
}

var enabled := true
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer

func _ready() -> void:
	for k in FILES:
		var path: String = "res://assets/sfx/" + String(FILES[k][0])
		if ResourceLoader.exists(path):
			_streams[k] = load(path)
	for _i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_crowd = AudioStreamPlayer.new()
	add_child(_crowd)
	var cl: String = "res://assets/sfx/crowd_loop.wav"
	if ResourceLoader.exists(cl):
		var st: AudioStream = load(cl)
		if st is AudioStreamWAV:
			var w := st as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * float(w.mix_rate))
		_crowd.stream = st
		_crowd.volume_db = -16.0
		_crowd.play()

func play(key: String, extra_db: float = 0.0) -> void:
	if not enabled or not _streams.has(key):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[key]
	p.volume_db = float(FILES[key][1]) + extra_db
	p.pitch_scale = randf_range(0.94, 1.06) if key.begins_with("kick") else 1.0
	p.play()

## Público: sube con el gol y vuelve solo.
func crowd_swell(db: float, secs: float) -> void:
	if _crowd == null:
		return
	var tw := create_tween()
	tw.tween_property(_crowd, "volume_db", -16.0 + db, 0.2)
	tw.tween_property(_crowd, "volume_db", -16.0, secs)

func buzz(key: String) -> void:
	if not enabled or not BUZZ.has(key):
		return
	_buzz_seq(BUZZ[key])

func _buzz_seq(seq: Array) -> void:
	for i in seq.size():
		if i % 2 == 0:
			Input.vibrate_handheld(int(seq[i]))
		else:
			await get_tree().create_timer(float(seq[i]) / 1000.0).timeout
