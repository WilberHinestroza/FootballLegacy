extends "res://scenes/Match3D/Match3D.gd"
## Sesión de PRÁCTICA en el partido 3D (8-nov): el mismo partido que Match3D, pero
## con la configuración de Match3DBridge.practice_config (estadio de tu club vacío,
## titulares contra suplentes con peto, o solo las jugadas de una faceta). Al final
## no hay resumen ni ceremonia: se miran los retos (PracticeEngine) y vuelve a la
## pantalla Práctica. No avanza el día ni toca tus estadísticas.

const PRACTICE_SCENE := "res://scenes/Practice/Practice.tscn"

var _player: PlayerData
var _mode := "free"
var _facet := ""


func _ready() -> void:
	Audio.music_stop()
	Audio.crowd_stop()
	_mode = String(MatchState.practice.get("mode", "free"))
	_facet = String(MatchState.practice.get("facet", ""))
	_player = SaveManager.load_player()
	_cfg = Match3DBridge.practice_config(_mode, _facet, _on_finished)
	if _cfg.is_empty() or _player == null:
		get_tree().change_scene_to_file.call_deferred(PRACTICE_SCENE)
		return
	_go_landscape()
	SoccerMatch.config = _cfg
	_match = (load(MATCH_SCENE) as PackedScene).instantiate()
	add_child(_match)
	_match.moment_started.connect(_on_moment_started)
	_match.moment_ended.connect(_on_moment_ended)
	_match.outro_finished.connect(_on_outro_finished)
	_build_card()


func _card_player() -> PlayerData:
	return _player


## Sin MVP ni resumen: directo a mirar los retos.
func _on_outro_finished() -> void:
	_hide_card()
	_match.finish_and_exit()


func _on_finished(res: Dictionary) -> void:
	if _done:
		return
	_done = true
	var summary: Dictionary = PracticeEngine.session_summary(res, _mode, _facet)
	var player := SaveManager.load_player()
	var rewards := {}
	if player != null:
		rewards = PracticeEngine.apply_session(WorldTickEngine.season, player, WorldTickEngine.current_epoch_day,
				SaveManager.load_world_seed(), summary)
		SaveManager.save_season(WorldTickEngine.season)
		if int(rewards.get("xp", 0)) > 0:
			SaveManager.save_player(player)
	MatchState.practice_result = {"summary": summary, "rewards": rewards}
	_go_portrait()
	get_tree().change_scene_to_file(PRACTICE_SCENE)
