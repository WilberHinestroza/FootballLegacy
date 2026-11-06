extends Node
## Compila TODOS los .gd del proyecto CON los autoloads cargados y reporta
## los que fallan. El scan `--editor --quit-after` no detecta errores de
## parseo en scripts que no se cargan solos (así se coló SeasonCeremony.gd
## :160). Este hace load() de cada .gd con el proyecto entero levantado.
##   godot --headless res://tools/CompileCheck.tscn

func _ready() -> void:
	var files: Array = []
	_walk("res://", files)
	files.sort()
	var bad: Array = []
	for f in files:
		if String(f).begins_with("res://tools/") or String(f).begins_with("res://android/"):
			continue
		var res = load(f)
		if res == null:
			bad.append(f)
	print("=== COMPILE CHECK ===")
	for f in bad:
		print("FAIL  ", f)
	print("revisados=", files.size(), "  con_error=", bad.size())
	get_tree().quit(1 if bad.size() > 0 else 0)

func _walk(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n == "." or n == "..":
			n = d.get_next()
			continue
		var full: String = dir_path.path_join(n)
		if d.current_is_dir():
			if n != ".godot" and n != "addons" and n != "android":
				_walk(full, out)
		elif n.ends_with(".gd"):
			out.append(full)
		n = d.get_next()
	d.list_dir_end()
