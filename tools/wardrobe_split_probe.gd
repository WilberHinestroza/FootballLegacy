extends Node
## Tienda por prendas (10-oct): lógica de compra/propiedad de prendas
## sueltas y compatibilidad con conjuntos enteros de guardados anteriores.
##   godot --headless --path . res://tools/WardrobeSplitProbe.tscn
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _ready() -> void:
	var p := PlayerData.new()
	p.player_name = "Prueba"
	p.balance = 100000
	p.wage = 10
	# Guardado viejo: conjunto entero comprado y puesto + zapatos en acc_feet.
	p.cosmetics_owned = ["hoodie", "abrigo", "mocasines"]
	p.cosmetics_equipped = {"outfit": "hoodie", "acc_feet": "mocasines"}
	var cfg := Avatar.config_for_player(p, 1)
	_check(String(cfg.get("outfit", "")) == "hoodie", "conjunto entero viejo se sigue viendo")
	_check(String(cfg.get("acc_shoes", "")) == "mocasines" and not cfg.has("acc_feet"), "zapatos de calle guardados en acc_feet caen en acc_shoes")
	_check(Avatar.owns(p, "top_hoodie") and Avatar.owns(p, "bot_hoodie"), "tener el conjunto = tener sus dos prendas")
	_check(Avatar.owns(p, "bot_camisa_vestir") and not Avatar.owns(p, "bot_jeans"), "abrigo largo presta su pantalón alias; lo demás no")
	_check(ShopEngine.is_equipped(p, "top_hoodie") and ShopEngine.is_equipped(p, "bot_hoodie"), "las mitades del conjunto puesto figuran puestas")
	# Comprar un pantalón suelto: el conjunto se desarma, no se pierde el hoodie.
	var price: int = ShopEngine.cosmetic_price(p, "bot_jeans")
	_check(price > 0 and price < ShopEngine.cosmetic_price(p, "jeans"), "el pantalón suelto cuesta menos que el conjunto (%d)" % price)
	_check(ShopEngine.buy_cosmetic(p, "bot_jeans"), "comprar pantalón suelto")
	_check(not p.cosmetics_equipped.has("outfit") and String(p.cosmetics_equipped.get("top", "")) == "top_hoodie" and String(p.cosmetics_equipped.get("bottom", "")) == "bot_jeans", "queda hoodie arriba + jeans abajo")
	cfg = Avatar.config_for_player(p, 1)
	_check(String(cfg.get("top", "")) == "hoodie" and String(cfg.get("bottom", "")) == "jeans" and not cfg.has("outfit"), "config con prendas sueltas")
	var layers: Array = Avatar._layers(cfg)
	_check(layers[0] == ["bottom", "jeans"] and layers[1] == ["top", "hoodie"], "capas: pantalón y encima la parte de arriba")
	_check(layers.has(["acc", "mocasines"]), "con ropa de calle se ven los zapatos de calle")
	# Sacarse la parte de arriba: jersey del club + jeans.
	ShopEngine.unequip_cosmetic(p, "top_hoodie")
	cfg = Avatar.config_for_player(p, 1)
	_check(Avatar._layers(cfg)[1] == ["top", "kit"], "sin parte de arriba → camiseta del club")
	# En la cancha: nada de calle, guayos sí.
	p.cosmetics_owned.append("guayos_oro")
	p.cosmetics_equipped["acc_feet"] = "guayos_oro"
	var cel := Avatar.celebration_config_for_player(p, 1)
	_check(not Avatar.wears_street(cel) and Avatar._layers(cel).has(["acc", "guayos_oro"]) and not Avatar._layers(cel).has(["acc", "mocasines"]), "festejo: kit + guayos, sin zapatos de calle")
	_check(not ShopEngine.buy_cosmetic(p, "top_traje_oro"), "las prendas doradas no se compran")
	for t in Avatar.TOPS:
		if not ResourceLoader.exists("res://assets/pixelplayer/top/%s.png" % String(t["src"])):
			_check(false, "falta arte top/" + String(t["src"]))
	for b in Avatar.BOTTOMS:
		if not ResourceLoader.exists("res://assets/pixelplayer/bottom/%s.png" % String(b["src"])):
			_check(false, "falta arte bottom/" + String(b["src"]))
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
