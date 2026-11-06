extends Node

## Prueba del avatar en pixel art (Avatar.gd, 9-oct) + guardarropa de la
## Tienda (ShopEngine.*_cosmetic, schema v31):
##  1. Avatar.from_legacy convierte un config Kenney viejo sin perder tintes.
##  2. La migración v30→v31 agrega los campos y convierte el avatar.
##  3. Comprar / poner / quitar ropa y accesorios.
##  4. Avatar.compose en Godot == el mockup de Python (tools/pixel_layers.py
##     + compose de referencia en _pixellab_preview/probe_ref/), píxel a
##     píxel (±2 por canal de redondeo) — la parte visual SÍ se puede
##     verificar acá porque es determinista.
##  5. Tienda y editor de jugador se instancian sin errores (slot_3).
##   godot --headless res://tools/PixelAvatarProbe.tscn

var _fails: Array = []

func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)

func _ready() -> void:
	# --- 1. Conversión Kenney -> pixel ---
	var legacy := {"base": 3, "hair": 5, "facial": 2, "glasses": 3, "tint_base": "#b57e56", "tint_hair": "#2b2320", "tint_clothing": "#c0392b", "clothing_locked": true}
	var conv: Dictionary = Avatar.from_legacy(legacy)
	_check(int(conv.get("v", 0)) == 2 and String(conv.get("hair")) == String(Avatar.RANDOM_HAIR[5 % Avatar.RANDOM_HAIR.size()]), "from_legacy: v2 + peinado mapeado (%s)" % conv.get("hair"))
	_check(conv.get("face") == "barba" and conv.get("tint_base") == "#b57e56" and conv.get("tint_hair") == "#2b2320" and bool(conv.get("clothing_locked", false)), "from_legacy: barba + tintes + clothing_locked conservados")
	_check(not conv.has("glasses") and not conv.has("acc_eyes"), "from_legacy: los lentes Kenney NO se regalan como accesorio de la tienda")

	# --- 2. Migración v30 -> v31 ---
	var migrated: Dictionary = SaveManager._migrate_if_needed({"schema_version": 30, "player": {"player_name": "Viejo", "avatar": legacy.duplicate(true)}})
	var mp: Dictionary = migrated.get("player", {})
	_check(int(migrated.get("schema_version", 0)) == 31, "migración: schema_version = 31")
	_check(mp.get("cosmetics_owned") is Array and mp.get("cosmetics_equipped") is Dictionary, "migración: cosmetics_owned/equipped creados")
	_check(int((mp.get("avatar", {}) as Dictionary).get("v", 0)) == 2, "migración: avatar convertido a v2")
	var skin_only: Dictionary = SaveManager._migrate_if_needed({"schema_version": 30, "player": {"avatar": {"skin": 2}}})
	_check((skin_only["player"]["avatar"] as Dictionary) == {"skin": 2}, "migración: avatar {skin} del import queda igual")

	# --- 3. Guardarropa ---
	var p := PlayerData.new()
	p.player_name = "Probe Pixel"
	p.country = "Argentina"
	p.wage = 0
	p.balance = 1000
	var price: int = ShopEngine.cosmetic_price(p, "traje_negro")
	_check(price == 70, "precio de piso del traje negro para un rookie = 70 (fue %d)" % price)
	_check(ShopEngine.buy_cosmetic(p, "traje_negro") and p.balance == 930, "comprar traje: descuenta saldo")
	_check(ShopEngine.is_equipped(p, "traje_negro"), "comprar = ponérselo")
	_check(not ShopEngine.buy_cosmetic(p, "traje_negro"), "no se puede comprar dos veces")
	_check(ShopEngine.buy_cosmetic(p, "hoodie") and String(p.cosmetics_equipped.get("outfit")) == "hoodie", "otra ropa reemplaza el slot outfit")
	_check(ShopEngine.equip_cosmetic(p, "traje_negro") and ShopEngine.is_equipped(p, "traje_negro"), "volver a ponerse algo comprado")
	_check(not ShopEngine.equip_cosmetic(p, "smoking_blanco"), "no se puede poner algo no comprado")
	ShopEngine.buy_cosmetic(p, "cadena_fina")
	ShopEngine.unequip_cosmetic(p, "traje_negro")
	_check(not p.cosmetics_equipped.has("outfit") and String(p.cosmetics_equipped.get("acc_neck")) == "cadena_fina", "quitar ropa = vuelve el kit, la cadena sigue")
	var poor := PlayerData.new()
	poor.balance = 5
	_check(not ShopEngine.buy_cosmetic(poor, "reloj") and poor.cosmetics_owned.is_empty(), "sin saldo no compra")
	var rt: PlayerData = PlayerData.from_save_dict(p.to_save_dict())
	_check(rt.cosmetics_owned == p.cosmetics_owned and rt.cosmetics_equipped == p.cosmetics_equipped, "guardar/cargar conserva el guardarropa")
	var cfg_p: Dictionary = Avatar.config_for_player(p, 1)
	_check(String(cfg_p.get("acc_neck", "")) == "cadena_fina" and not cfg_p.has("outfit"), "config_for_player aplica lo puesto")

	# --- 4. Render Godot vs referencia Python ---
	var ref_dir: String = ProjectSettings.globalize_path("res://_pixellab_preview/probe_ref/")
	var f := FileAccess.open(ref_dir + "cfgs.json", FileAccess.READ)
	var cfgs: Array = JSON.parse_string(f.get_as_text()) if f != null else []
	_check(cfgs.size() > 0, "referencias de Python encontradas (%d)" % cfgs.size())
	for i in range(cfgs.size()):
		var got: Image = Avatar.compose(cfgs[i]).get_image()
		var want := Image.load_from_file(ref_dir + "%d.png" % i)
		want.convert(Image.FORMAT_RGBA8)
		var worst: int = 0
		var bad_px: int = 0
		for y in range(48):
			for x in range(48):
				var a: Color = got.get_pixel(x, y)
				var b: Color = want.get_pixel(x, y)
				var d: int = maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), maxi(absi(a.b8 - b.b8), absi(a.a8 - b.a8)))
				worst = maxi(worst, d)
				if d > 2:
					bad_px += 1
		_check(bad_px == 0, "render %d igual a Python (peor diferencia %d, píxeles fuera de ±2: %d)" % [i, worst, bad_px])
	# Animaciones del jugador (PixelLab, 9-oct): todas existen y el tinte
	# por cuadro coincide con el mockup de Python.
	for anim in Avatar.CELEBRATION_ANIMS + ["trofeo_oro", "balon_oro", "lesion", "cambio"]:
		_check(Avatar.anim_frames({}, anim).size() == 9, "animación %s: 9 cuadros" % anim)
	var af := FileAccess.open(ref_dir + "anim_refs.json", FileAccess.READ)
	var aref: Dictionary = JSON.parse_string(af.get_as_text()) if af != null else {}
	for r in aref.get("refs", []):
		var got_a: Image = (Avatar.anim_frames(aref["cfg"], String(r[0]))[int(r[1])] as ImageTexture).get_image()
		var want_a := Image.load_from_file(ref_dir + "anim_%s_%d.png" % [r[0], int(r[1])])
		want_a.convert(Image.FORMAT_RGBA8)
		var bad_a: int = 0
		for y in range(68):
			for x in range(68):
				var ga: Color = got_a.get_pixel(x, y)
				var wa: Color = want_a.get_pixel(x, y)
				if maxi(maxi(absi(ga.r8 - wa.r8), absi(ga.g8 - wa.g8)), maxi(absi(ga.b8 - wa.b8), absi(ga.a8 - wa.a8))) > 2:
					bad_a += 1
		_check(bad_a == 0, "animación %s cuadro %d teñida igual que Python (%d px distintos)" % [r[0], int(r[1]), bad_a])
	# NPCs: todos los roles arman algo con ropa coherente.
	for role in ["coach", "president", "agent", "journalist", "partner", "player"]:
		var c: Dictionary = Avatar.config_for_npc("Fulano " + role, role, 7)
		var tex: ImageTexture = Avatar.compose(c)
		_check(tex != null and tex.get_width() == 48, "NPC %s: %s / %s" % [role, c.get("outfit", "kit"), c.get("hair")])

	# --- 5. Escenas (slot_3 desechable) ---
	SaveManager.active_slot_id = "slot_3"
	SaveManager.save_world_seed(20260906)
	p.balance = 5000
	SaveManager.save_player(p)
	WorldTickEngine.load_runtime()
	var shop: Node = load("res://scenes/Shop/Shop.tscn").instantiate()
	add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	var style_box: VBoxContainer = shop.get("_style_box")
	_check(style_box != null and style_box.get_child_count() >= 5, "Tienda: sección ESTILO armada (%d hijos)" % (style_box.get_child_count() if style_box else -1))
	shop.call("_on_buy_cosmetic", "reloj")
	await get_tree().process_frame
	var after := SaveManager.load_player()
	_check(after.cosmetics_owned.has("reloj") and String(after.cosmetics_equipped.get("acc_wrist")) == "reloj", "Tienda: comprar desde la UI guarda en el slot")
	shop.queue_free()

	CharacterDraft.edit_mode = true
	var ed: Node = load("res://scenes/AvatarCreator/AvatarCreator.tscn").instantiate()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var body: VBoxContainer = ed.get("body")
	_check(body != null and body.get_child_count() >= 4, "Editor: categorías + colores + grilla (%d hijos)" % (body.get_child_count() if body else -1))
	CharacterDraft.edit_mode = false
	ed.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.get_slot_path("slot_3")))
	print("PROBE %s (%d fallos)" % ["OK" if _fails.is_empty() else "FAIL", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)
