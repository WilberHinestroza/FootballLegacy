extends Node

## Vibración / feedback háptico. En Android (y iOS) usa
## Input.vibrate_handheld(ms); en cualquier otra plataforma es un no-op
## silencioso. Se enciende/apaga en Ajustes (igual que los canales de
## sonido). Patrón = [ms_pulso, ms_pausa, ms_pulso, ...] (índices pares =
## pulsos, impares = pausas).
##
## Uso:  Haptics.hit("goal")   Haptics.hit("tap")

const PATTERNS := {
	"tap": [9],            # toque de botón — muy corto
	"select": [16],        # cambiar de pestaña / elegir opción
	"success": [38],       # acertaste un momento clave
	"fail": [28, 55, 70],  # fallaste
	"goal": [90, 70, 230], # ¡GOL tuyo! doble golpe
	"goal_against": [50, 40, 110],
	"card_yellow": [34],
	"card_red": [60, 55, 130],
	"injury": [70],
	"whistle": [48],       # inicio / entretiempo / final
	"sub": [20],
	"popup": [22],         # cualquier popup central de evento
	"big": [150],          # momentos grandes (trofeo, firma)
}

var enabled: bool = true

const _PREF_PATH := "user://haptics.json"

func _ready() -> void:
	_load_pref()

## Dispara el patrón `key` (o uno corto por defecto si no existe).
func hit(key: String) -> void:
	if not enabled or not _has_vibrator():
		return
	_play((PATTERNS.get(key, [18]) as Array).duplicate())

func _play(seq: Array) -> void:
	if seq.is_empty():
		return
	var ms: int = int(seq.pop_front())
	if ms > 0:
		Input.vibrate_handheld(ms)
	if seq.is_empty():
		return
	var gap: int = int(seq.pop_front())
	await get_tree().create_timer(float(ms + gap) / 1000.0).timeout
	_play(seq)

func _has_vibrator() -> bool:
	return OS.get_name() in ["Android", "iOS"]

func set_enabled(v: bool) -> void:
	enabled = v
	_save_pref()
	if v:
		hit("select")   # confirmación inmediata al activarla

func _save_pref() -> void:
	var f := FileAccess.open(_PREF_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"enabled": enabled}))

func _load_pref() -> void:
	if not FileAccess.file_exists(_PREF_PATH):
		return
	var f := FileAccess.open(_PREF_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		enabled = bool((d as Dictionary).get("enabled", true))
