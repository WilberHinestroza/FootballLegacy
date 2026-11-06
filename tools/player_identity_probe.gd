extends Node

## Prueba dirigida del bug real reportado por Wilber ("no me está contando
## las titularidades"). Causa raíz: MatchSummary._apply_match_consequences()
## comparaba `_player` (SaveManager.load_player(), una instancia RECIÉN
## releída de disco) contra `starting_xi.has(_player)` — Array.has() en
## Godot compara OBJETOS por IDENTIDAD (misma referencia en memoria), no
## por contenido, así que dos PlayerData con los mismos datos pero
## instancias distintas dan `has() == false` SIEMPRE. El fix usa
## `MatchState.user_player` (la MISMA referencia que MatchLauncher.prepare()
## puso en starting_xi) en vez de `_player`.
##
## Esta prueba no necesita mundo/temporada: solo confirma el mecanismo de
## Array.has() con PlayerData, que es la base lógica del fix real en
## MatchSummary.gd.
##   godot --headless res://tools/PlayerIdentityProbe.tscn

func _ready() -> void:
	var a := PlayerData.new()
	a.player_name = "Jugador"
	a.club_id = "club_x"
	a.season_appearances = 3

	# Misma info, instancia DISTINTA — exactamente lo que hace
	# SaveManager.load_player() al volver a leer el mismo save.
	var b: PlayerData = PlayerData.from_save_dict(a.to_save_dict())

	var starting_xi: Array[PlayerData] = [a]

	var same_ref_found: bool = starting_xi.has(a)
	var reloaded_found: bool = starting_xi.has(b)

	print("misma referencia (a) encontrada en starting_xi: %s (esperado true)" % same_ref_found)
	print("instancia releída (b, mismos datos) encontrada: %s (esperado false — este era el bug)" % reloaded_found)

	var ok: bool = same_ref_found and not reloaded_found
	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
