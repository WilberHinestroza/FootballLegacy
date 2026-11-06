extends RefCounted
class_name Avatar3D

## Retratos y cuerpos 3D (el MISMO modelo del partido 3D, match3d/) a partir de la
## config de Avatar (piel, pelo, kit, ropa de calle, accesorios de la tienda).
## Avatar.build / build_full / build_feet / build_anim lo usan primero cuando
## Preferences.match_3d está activo; si devuelve null, sigue el pixel art de siempre.
## Las listas largas no se resienten: cada retrato se dibuja una vez, se guarda como
## imagen (PlayerPortrait.snapshot_key) y se suelta el 3D.

## Plantillas de Wilber (Kit.w_mask, índice w) -> diseño 3D. Copia de
## Match3DBridge.W_PATTERN_3D (no se referencia para no arrastrar el motor del partido
## a los autoloads que usan Avatar).
const W_PATTERN := [4, 14, 3, 1, 1, 2, 0, 11, 7, 0, 12, 6, 13, 6, 10, 0,
		1, 2, 4, 14, 3, 6, 10, 0, 0, 14, 7, 4, 0, 13, 0, 0]

## Ropa de calle -> colores del 3D: [camisa, pantalón, manga larga, diseño, color 2]
## (diseño 9 = traje con camisa y corbata del color 2; 13 = chándal con franjas).
const STREET := {
	"hoodie": ["#8a8d93", "#6b6e74", true, 0, ""],
	"hoodie_negro": ["#2a2a2e", "#2a2a2e", true, 0, ""],
	"jeans": ["#1e1e22", "#3b5a86", false, 0, ""],
	"polo": ["#c0392b", "#d8c7a0", false, 23, "#f2f2f2"],
	"chandal": ["#2e5fb0", "#2e5fb0", true, 13, "#f2f2f2"],
	"hawaiana": ["#2bb3a6", "#d8c7a0", false, 18, "#f6e27a"],
	"lino": ["#efe9dc", "#efe9dc", true, 0, ""],
	"bomber": ["#3e5a36", "#222226", true, 0, ""],
	"vaquera": ["#4a6fa5", "#222226", true, 0, ""],
	"universitaria": ["#7a1f2b", "#222226", true, 7, "#f0f0f0"],
	"camisa_vestir": ["#9cc3e6", "#233552", true, 0, ""],
	"cuello_alto": ["#2b2b2b", "#6e6e6e", true, 0, ""],
	"plumifero": ["#151517", "#222226", true, 2, "#2a2a30"],
	"cuero": ["#1c1c1c", "#2f4466", true, 0, ""],
	"abrigo": ["#b48a5a", "#233552", true, 0, ""],
	"traje_azul": ["#1f3566", "#1f3566", true, 9, "#8a1c2b"],
	"traje_negro": ["#15151a", "#15151a", true, 9, "#1a1a1a"],
	"smoking_blanco": ["#f2f2f2", "#141414", true, 9, "#141414"],
	"franela": ["#b5322f", "#3b5a86", true, 10, "#2b2b2b"],
	"chaleco": ["#2d4a7a", "#3b3b40", true, 0, ""],
	"oversize": ["#e8e8e8", "#8b7d5a", false, 0, ""],
	"traje_gris": ["#6d7078", "#6d7078", true, 9, "#2e5fb0"],
	"retro": ["#c0392b", "#c0392b", true, 13, "#f2f2f2"],
	"seda": ["#2a1f3d", "#141414", true, 18, "#c9a227"],
	"camisa_chinos": ["#f4f4f4", "#d8c7a0", true, 0, ""],
	"gabardina": ["#c8b48a", "#6e6e6e", true, 0, ""],
	"parka_roja": ["#c0392b", "#3e4a33", true, 0, ""],
	"blazer_terciopelo": ["#5a1f3a", "#141414", true, 9, "#141414"],
	"cortavientos": ["#2e7bd6", "#a0a0a6", true, 19, "#f0f0f0"],
	"traje_oro": ["#d4af37", "#d4af37", true, 9, "#141414"],
	"chandal_oro": ["#d4af37", "#d4af37", true, 13, "#141414"],
	"bomber_oro": ["#d4af37", "#141414", true, 0, ""],
	"polo_oro": ["#d4af37", "#141414", false, 23, "#141414"],
	"cuero_oro": ["#c9a227", "#141414", true, 0, ""],
}

## Zapatos de calle -> [color, suela]. "" = los de siempre con ropa de calle.
const SHOES := {
	"": ["#2a2a2e", "#151517"],
	"zapatillas_blancas": ["#f2f2f4", "#c9ccd2"],
	"mocasines": ["#6b3f22", "#24160d"],
	"botas_chelsea": ["#2b211b", "#0e0c0b"],
}
## Pantalones cortos de calle (bermudas): no llegan al tobillo.
const SHORT_BOTTOMS := ["hawaiana"]

## Festejos pixel art -> animación del modelo 3D.
const ANIM_3D := {
	"celeb_rodillas": "kneel", "celeb_salto": "fist_pump_2", "celeb_avion": "victory_idle",
	"celeb_cielo": "victory", "celeb_escudo": "fist_pump", "celeb_mortal": "dance_5",
	"celeb_baile": "dance_1", "celeb_corazon": "clap", "celeb_silencio": "point", "celeb_bebe": "dance_4",
	"celeb_pistolas": "point", "celeb_saludo": "clap", "celeb_aplauso": "clap", "celeb_grito": "yell",
	"celeb_brazos_cruzados": "idle", "celeb_dedos_cielo": "victory", "celeb_salto_giro": "dance_7",
	"celeb_surfero": "dance_2", "celeb_meditacion": "kneel", "celeb_brazos_abiertos": "victory_idle",
	"celeb_robot": "dance_3", "trofeo_oro": "victory_idle", "balon_oro": "victory_idle",
	"lamento": "sit_react", "himno": "idle", "arenga": "yell", "firma": "idle",
}


static func enabled() -> bool:
	return Preferences.match_3d and PlayerAvatar.available() and DisplayServer.get_name() != "headless"


## Busto (con fondo redondeado), cuerpo entero (cfg.full) o pies (cfg.region).
static func build(cfg: Dictionary, px: int) -> Control:
	if not enabled():
		return null
	var full: bool = bool(cfg.get("full", false))
	var feet: bool = cfg.has("region")
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not full:
		var bg := Panel.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(String(cfg.get("tint_background", "#7fb0d8"))).darkened(0.25)
		sb.set_corner_radius_all(maxi(4, int(px * 0.18)))
		bg.add_theme_stylebox_override("panel", sb)
		root.add_child(bg)
	var mode := "feet" if feet else ("full" if full else "bust")
	var key := "%s|%d|%s" % [mode, px, JSON.stringify(cfg, "", true)]
	var cached: Texture2D = PlayerPortrait.cached(key)
	if cached != null:
		root.add_child(_image(cached))
		return root
	var p := PlayerPortrait.new(px, Color(0, 0, 0, 0), false, mode)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if feet:
		# Recorte apaisado (como Avatar.build_feet): antes el retrato era cuadrado y la
		# tarjeta solo enseñaba su mitad de arriba (el pantalón), sin los pies.
		root.custom_minimum_size = Vector2(px, px * 0.5)
		p.custom_minimum_size = Vector2(px, px * 0.5)
	apply(p.avatar, cfg)
	p.snapshot_key = key
	_kit_decals(p, cfg)
	root.add_child(p)
	return root


## Cuerpo entero haciendo una animación (festejos, firma, trofeo...). null = sin
## equivalente en 3D (las de cancha del partido 2D siguen en pixel art).
static func build_anim(cfg: Dictionary, anim: String, px: int, loop: bool) -> Control:
	if not enabled() or anim.begins_with("pitch_") or anim.begins_with("gk_") or anim.begins_with("coach_"):
		return null
	var name3d := String(ANIM_3D.get(anim, "idle"))
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PlayerPortrait.new(px, Color(0, 0, 0, 0), true)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply(p.avatar, cfg)
	_kit_decals(p, cfg)
	p.play(name3d, loop or name3d in PlayerAvatar.LOOP_ANIMS)
	root.add_child(p)
	return root


## Pasa la config de Avatar al modelo 3D.
static func apply(av: PlayerAvatar, cfg: Dictionary) -> void:
	var c := {}
	if String(cfg.get("tint_base", "")) != "":
		c["skin_color"] = Color(String(cfg["tint_base"]))
	if String(cfg.get("tint_hair", "")) != "":
		c["hair_color"] = Color(String(cfg["tint_hair"]))
	var hat: bool = String(cfg.get("acc_head", "")) in ["gorra", "gorro_lana", "boina"]
	var hair := String(cfg.get("hair", "rapado"))
	if hat or not ItemCatalog.hair_available(hair):
		hair = "rapado"
	c["show_hair"] = hair != "calvo"
	c["hair_style"] = ItemCatalog.shader_hair_index(hair)
	c["beard_style"] = ItemCatalog.face_index(String(cfg.get("face", "")))
	# Kit del club
	var shirt := Color(String(cfg.get("tint_clothing", "#c0392b")))
	c["shirt_color"] = shirt
	c["shorts_color"] = Color(String(cfg.get("tint_shorts", "#f0f0f0")))
	c["socks_color"] = Color(String(cfg.get("tint_socks", cfg.get("tint_clothing", "#c0392b"))))
	var pattern := 0
	var w := int(cfg.get("kit_w", -1))
	if w >= 0 and String(cfg.get("tint_kit2", "")) != "":
		pattern = int(W_PATTERN[w % W_PATTERN.size()])
		c["shirt_color2"] = Color(String(cfg["tint_kit2"]))
	c["shirt_pattern"] = pattern
	c["long_sleeves"] = false
	c["long_pants"] = false
	# Ropa de calle: conjunto entero o prendas sueltas (la mitad que falta es el kit)
	var outfit := String(cfg.get("outfit", ""))
	var top := String(cfg.get("top", ""))
	var bottom := String(cfg.get("bottom", ""))
	if top == "" and bottom == "" and STREET.has(outfit):
		top = outfit
		bottom = outfit
	var street := false
	if STREET.has(top):
		var s: Array = STREET[top]
		c["shirt_color"] = Color(String(s[0]))
		c["long_sleeves"] = bool(s[2])
		c["shirt_pattern"] = int(s[3])
		if String(s[4]) != "":
			c["shirt_color2"] = Color(String(s[4]))
		street = true
	if STREET.has(bottom):
		var b: Array = STREET[bottom]
		c["shorts_color"] = Color(String(b[1]))
		c["long_pants"] = not SHORT_BOTTOMS.has(bottom)
		street = true
	# Calzado: guayos de la tienda con el kit; zapatos de calle con ropa de calle
	if street:
		var shoes: Array = SHOES.get(String(cfg.get("acc_shoes", "")), SHOES[""])
		c["boots_color"] = Color(String(shoes[0]))
		c["sole_color"] = Color(String(shoes[1]))
		c["use_sole"] = true
		if bool(c["long_pants"]):
			c["socks_color"] = c["shorts_color"]
	else:
		c["use_sole"] = false
		var g := String(cfg.get("acc_feet", ""))
		if Avatar.GUAYOS_TINT.has(g):
			c["boots_color"] = Color(String(Avatar.GUAYOS_TINT[g]))
	av.set_colors(c)
	av.set_hair_style(hair)
	var acc := {}
	for slot: String in ["acc_head", "acc_eyes", "acc_neck", "acc_ears", "acc_wrist"]:
		var id := String(cfg.get(slot, ""))
		if id != "":
			acc[slot] = id
	av.set_accessories(acc)


## Estampados de la camiseta del club (los mismos del partido 3D, KitDecals):
## escudo real del club y patrocinio delante, apellido y dorsal detrás. Solo con
## el kit puesto (cfg.kit_club, que pone Avatar._apply_kit_tint); con ropa de
## calle arriba, nada. Se hornean una vez por club+dorsal+nombre y se reutilizan;
## la foto del retrato (snapshot) espera a que lleguen.
static var _decal_cache := {}

static func _kit_decals(p: PlayerPortrait, cfg: Dictionary) -> void:
	var club := String(cfg.get("kit_club", ""))
	if club == "":
		return
	var top := String(cfg.get("top", ""))
	if STREET.has(top) or (top == "" and STREET.has(String(cfg.get("outfit", "")))):
		return
	stamp_kit(p, club, int(cfg.get("kit_num", 0)), String(cfg.get("kit_name", "")),
		Color(String(cfg.get("tint_clothing", "#c0392b"))),
		Color(String(cfg.get("tint_kit2", cfg.get("tint_shorts", "#f0f0f0")))))


## Estampa en el retrato `p` el escudo real de `club`, su patrocinio, el dorsal y el
## apellido (también lo usa Match3DBridge.portrait para la carta Ultimate).
static func stamp_kit(p: PlayerPortrait, club: String, num: int, surname: String, shirt: Color, c2: Color) -> void:
	if club == "" or DisplayServer.get_name() == "headless":
		return
	p.avatar.set_colors({"crest_center": Kit.crest_centered(club, WorldTickEngine.get_season_start_year())})
	var key := "%s|%d|%s|%s" % [club, num, surname, shirt.to_html(false)]
	var tex: Texture2D = _decal_cache.get(key)
	if tex != null:
		p.avatar.set_decals(tex)
		return
	var ink := c2 if absf(shirt.get_luminance() - c2.get_luminance()) > 0.45 		else (Color(0.08, 0.08, 0.1) if shirt.get_luminance() > 0.55 else Color(0.97, 0.97, 0.97))
	var cname := club
	var w: Dictionary = WorldTickEngine.world
	var cd: ClubData = WorldFactory.find_club(w, club) if not w.is_empty() else null
	if cd != null:
		cname = cd.club_name
	p.hold_frames = 40
	var wr: WeakRef = weakref(p)
	var job := {
		"target": func(t: Texture2D) -> void:
			if _decal_cache.size() > 40:
				_decal_cache.clear()
			_decal_cache[key] = t
			var pp: PlayerPortrait = wr.get_ref()
			if pp != null:
				pp.avatar.set_decals(t)
				pp.hold_frames = 2,
		"crest": func() -> Control: return Styles.club_crest(club, 112),
		"crest_key": club, "sponsor": KitDecals.sponsor_for(cname),
		"number": num, "name": surname, "ink": ink}
	_bake_when_ready(wr, job, 0)


## Hornea cuando el retrato ya está en pantalla (reintenta unos cuadros).
static func _bake_when_ready(wr: WeakRef, job: Dictionary, tries: int) -> void:
	var p: PlayerPortrait = wr.get_ref()
	if p == null:
		return
	if not p.is_inside_tree():
		var tree := Engine.get_main_loop() as SceneTree
		if tries < 30 and tree != null:
			tree.process_frame.connect(func() -> void: _bake_when_ready(wr, job, tries + 1), CONNECT_ONE_SHOT)
		return
	KitDecals.bake_all(p.get_tree().root, [job])


## Cuerpo entero 3D dentro de un TextureRect que antes llevaba el sprite de cancha
## (plantilla, previa). false = 3D apagado: el llamador pone el pixel art.
static func fill(rect: TextureRect, cfg: Dictionary, px: int) -> bool:
	var c2 := cfg.duplicate()
	c2["full"] = true
	var c := build(c2, px)
	if c == null:
		return false
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.add_child(c)
	return true


static func _image(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
