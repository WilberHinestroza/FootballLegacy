extends Control

## Última pantalla de la cadena de fin de temporada (pedido de Wilber:
## "resumen → premios individuales → carga de la nueva temporada").
## El trabajo real (calendario, mercado, objetivos, copas) ya lo armó
## WorldTickEngine._finish_season_rollover() antes de llegar acá — esto
## es una pausa DELIBERADA (barra de progreso + club/temporada nueva)
## para que el salto de temporada se sienta como un paso, no un corte
## seco al Hub. Apaga post_season_flow al terminar.

const _STEPS := [
	"Cerrando el libro de la temporada…",
	"Actualizando el mercado de fichajes…",
	"Armando el calendario nuevo…",
	"Sorteando las copas…",
]
const _STEP_SECONDS := 0.45

@onready var _crest_slot: Control = $Root/VBox/CrestSlot
@onready var _title_label: Label = $Root/VBox/TitleLabel
@onready var _step_label: Label = $Root/VBox/StepLabel
@onready var _bar: ProgressBar = $Root/VBox/Bar

func _ready() -> void:
	WorldTickEngine.load_runtime()
	var player: PlayerData = SaveManager.load_player()
	var club: ClubData = null
	if player != null and player.club_id != "":
		club = WorldFactory.find_club(WorldTickEngine.world, player.club_id)
	if club != null:
		var crest := Styles.club_crest(club.club_id, 72)
		crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_crest_slot.add_child(crest)

	var start_year: int = int(WorldTickEngine.season.get("start_year", CalendarUtils.season_start_year(WorldTickEngine.current_epoch_day)))
	_title_label.text = "Preparando la temporada %d/%d" % [start_year, start_year + 1]
	_title_label.add_theme_font_override("font", Styles.font_black())
	_step_label.add_theme_color_override("font_color", Styles.GRAY_TEXT)
	_step_label.add_theme_font_size_override("font_size", 13)
	_bar.min_value = 0.0
	_bar.max_value = float(_STEPS.size())
	_bar.value = 0.0
	_bar.show_percentage = false

	_run_steps()

func _run_steps() -> void:
	for i in range(_STEPS.size()):
		_step_label.text = _STEPS[i]
		var tw := create_tween()
		tw.tween_property(_bar, "value", float(i + 1), _STEP_SECONDS).set_trans(Tween.TRANS_SINE)
		await tw.finished
	WorldTickEngine.post_season_flow = false
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
