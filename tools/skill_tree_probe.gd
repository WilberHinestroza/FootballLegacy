extends "res://tools/ui_gallery_probe.gd"
## Árbol de habilidades extendido (10-oct). Carrera desechable en slot_3.
##   godot --path . --resolution 432x936 res://tools/SkillTreeProbe.tscn
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var p: PlayerData = SaveManager.load_player()
	var br: Array = SkillTree.branches_for(p.position)
	_check(br.size() == 7, "7 ramas: 3 del puesto + Mentalidad + Físico + Liderazgo + Carrera (%d)" % br.size())
	_check((br[0]["nodes"] as Array).size() == 6, "las ramas del puesto tienen 6 escalones")
	var ids := {}
	var dup: bool = false
	for pair in SkillTree._all_nodes():
		var id: String = String(pair[0]["nodes"][pair[1]]["id"])
		dup = dup or ids.has(id)
		ids[id] = true
	_check(not dup, "sin ids repetidos (%d habilidades)" % ids.size())
	# Carrera: pide el hito además del punto.
	p.skills = []
	p.skill_points = 20
	p.career_matches = 0
	p.season_matches_played = 0
	_check(not SkillTree.can_unlock(p, "car1") and not bool(SkillTree.requirement(p, "car1")[0]), "sin partidos no se abre 'Debut profesional'")
	p.career_matches = 40
	_check(SkillTree.can_unlock(p, "car1") and SkillTree.cost_of("car1") == 1, "con partidos sí, y cuesta 1 punto")
	_check(SkillTree.unlock(p, "car1") and SkillTree.unlock(p, "car2") and not SkillTree.can_unlock(p, "car3"), "Titular (30) sí, Referente (100) todavía no")
	_check(is_equal_approx(SkillTree.total(p, "xp"), 0.03) and is_equal_approx(SkillTree.total(p, "bar_slow"), 0.02), "los efectos de Carrera cuentan")
	# Escalones 5 y 6 de la rama del puesto: en orden y con su costo.
	var first: Dictionary = br[0]
	_check(SkillTree.cost_of(String(first["nodes"][4]["id"])) == 5 and SkillTree.cost_of(String(first["nodes"][5]["id"])) == 6, "5.º y 6.º escalón cuestan 5 y 6")
	_check(not SkillTree.can_unlock(p, String(first["nodes"][4]["id"])), "el 5.º pide tener el 4.º")
	p.skills.append(String(first["nodes"][0]["id"]))
	p.skills.append("fis1")
	p.skill_points = 3
	SaveManager.save_player(p)
	var panel := SkillsPanel.open(self)
	for i in range(40):
		await get_tree().process_frame
	panel._selected = "car3"
	panel._render()
	for i in range(20):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/skill_tree.png"))
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
