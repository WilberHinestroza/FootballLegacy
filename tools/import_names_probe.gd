extends Node
## Prueba: el importador acepta letras como Â/Ã y avisa solo del texto roto real.
func _ready() -> void:
	var ok_names := ["MÂS Monumental", "Mohammed El Âdfaoui", "Ângelo", "João Ãlvaro", "São Paulo", "Müller", "Østergaard", "Łukasz", "Đorđević", "İstanbul"]
	var bad_names := ["JosÃ© PÃ©rez", "MartÃ­n", "Ã‘andÃº", "Estadio Â°1", "Pel�"]
	var fails := 0
	for n in ok_names:
		var f: String = WorldFactory.repair_imported_text(n)
		if WorldFactory.looks_corrupted(f):
			print("FALLA acepta: ", n); fails += 1
	for n in bad_names:
		var f: String = WorldFactory.repair_imported_text(n)
		if not WorldFactory.looks_corrupted(f) and f == n:
			print("FALLA detecta: ", n); fails += 1
	print("REPARA: ", WorldFactory.repair_imported_text("JosÃ© PÃ©rez"))
	var raw := {"clubs": [{"id": 1, "name": "Nacional", "leagueId": 1}, {"id": 2, "name": "Nacional", "leagueId": 2}]}
	print("SOSPECHOSOS en clubes iguales: ", WorldImporter.scan_suspicious_names(raw).size())
	print("RESULTADO fallas=", fails)
	get_tree().quit(fails)
