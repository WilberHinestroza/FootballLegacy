extends "res://tools/ui_gallery_probe.gd"
## LESION DENTRO DE UN PARTIDO REAL (11-oct): camilla -> aviso -> cambio
## obligado, sin que una cosa corte a la otra. slot_3.
##   godot --path . --resolution 432x936 res://tools/InjuryMatchProbe.tscn
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var pl := SaveManager.load_player()
	var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
	MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
	var m: Node = (load("res://scenes/Match/Match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(m)
	await _wait(200)
	MatchState.engine.hold = true
	await _wait(160)
	var t0: int = Time.get_ticks_msec()
	while (bool(m.get("_replaying")) or (m.get("decision_panel") as Control).visible) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	var pv: PitchView = m.get("_pitch")
	var mate: PlayerData = null
	for p in MatchState.engine.home_team.starting_xi + MatchState.engine.away_team.starting_xi:
		if p != MatchState.user_player and p.position != "GK":
			mate = p
			break
	var is_home: bool = mate in MatchState.engine.home_team.starting_xi
	m.call("_on_event_emitted", MatchEvent.new(MatchEvent.Type.INJURY, 30, {"player": mate, "is_user": false, "home": is_home}))
	await _wait(3)
	_check(bool(m.get("_replaying")) and pv.visible, "la lesion abre su repeticion en la cancha")
	var saw_stretcher: bool = false
	var shot: bool = false
	t0 = Time.get_ticks_msec()
	while bool(m.get("_replaying")) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
		saw_stretcher = saw_stretcher or pv._str_on
		if pv._str_on and not shot and Time.get_ticks_msec() - t0 > 2600:
			shot = true
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/injury_match.png"))
	var took: float = (Time.get_ticks_msec() - t0) / 1000.0
	_check(saw_stretcher, "entran los camilleros")
	_check(took > 3.5 and took < 9.0, "la escena dura lo suyo y termina (%.1f s)" % took)
	await _wait(10)
	_check((m.get("event_log") as RichTextLabel).get_parsed_text().contains("Lesi"), "despues sale el aviso de lesion")
	# El cambio obligado que viene atras no se pisa con nada.
	var sub_in: PlayerData = MatchState.engine.home_team.bench[0] if is_home else MatchState.engine.away_team.bench[0]
	m.call("_on_event_emitted", MatchEvent.new(MatchEvent.Type.SUBSTITUTION, 30, {"player_out": mate, "player_in": sub_in, "home": is_home, "is_user": false}))
	t0 = Time.get_ticks_msec()
	await _wait(3)
	while bool(m.get("_replaying")) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	_check(not bool(m.get("_replaying")), "el cambio se ve y termina (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# Entre jugadas NO hay cancha: solo el relato.
	await _wait(30)
	_check(not pv.visible and (m.get("event_log") as Control).visible, "entre jugadas se ve el relato, sin cancha")
	# Ocasion clara: se ve en la cancha (grande) y despues se narra.
	m.call("_on_event_emitted", MatchEvent.new(MatchEvent.Type.AMBIENT, 33, {"kind": "clear_chance", "home": not is_home}))
	await _wait(8)
	_check(bool(m.get("_replaying")) and pv.visible and not (m.get("event_log") as Control).visible, "la ocasion clara abre la cancha y guarda el relato")
	print("alto de la cancha en la jugada: ", pv.size.y, " de ", get_viewport().get_visible_rect().size.y)
	_check(pv.size.y > 480.0, "la cancha ocupa la pantalla (alto %.0f)" % pv.size.y)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/chance_match.png"))
	t0 = Time.get_ticks_msec()
	while bool(m.get("_replaying")) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	await _wait(10)
	_check((m.get("event_log") as RichTextLabel).get_parsed_text().contains("Ocasi"), "despues sale narrada")
	_check(not pv.visible, "y la cancha se va")
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
