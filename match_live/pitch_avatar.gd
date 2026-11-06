class_name PitchAvatar
extends RefCounted
## Versión de CANCHA del sistema de avatares de FootballCareer (data/Avatar.gd):
## mismas imágenes y máscaras (assets/pixelplayer/), mismo config v2
## ({"hair", "face", "nose", "ears", "rasgo", "acc_head", "tint_*"}), pero el
## teñido lo hace un SHADER en la GPU en vez de componer imágenes en CPU,
## así 22 jugadores con todas sus animaciones no traban el celular.
##
## Al integrar en FootballCareer: el config del jugador creado
## (Avatar.config_for_player) sirve tal cual acá.

const DIR := "res://assets/pixelplayer/"
const ANIM_PX := 68

const MASK_SKIN := 1
const MASK_HAIR := 2
const MASK_SHIRT := 3
const MASK_SHORTS := 4
const MASK_SOCKS := 5
const MASK_BOOTS := 7

# Mismas paletas y sorteos que Avatar.gd.
const SKIN := ["#f4d6c0", "#eec1a3", "#d9a577", "#b57e56", "#8a5a3b", "#5f3a26"]
const HAIR_COL := ["#2b2320", "#5a3b26", "#8a5a3b", "#c98f4b", "#d8c07a", "#9a9a9a", "#e8e8e8"]
const RANDOM_HAIR := ["rapado", "rapado", "tupe", "rulos", "melena", "cresta", "rastas", "trenzas",
	"afro", "flequillo", "puntas", "degradado", "raya", "calvo", "coleta"]
const RANDOM_FACES := ["barba", "barba3", "candado", "bigote", "barba_larga"]
const NOSES := ["grande", "aguilena", "chata"]
const RASGOS := ["mandibula", "redonda", "pecas", "cejas", "cicatriz"]
const HEAD_ACC := ["cinta", "gorra", "gorro_lana", "lentes_sol", "aviador", "pendientes", "boina", "lentes_redondos"]

const SHADER_CODE := """
shader_type canvas_item;
// Teñido por clase de máscara (R = clase, G = luminancia), igual que
// Avatar._tinted() de FootballCareer.
uniform sampler2D mask_tex : filter_nearest;
uniform vec4 c_skin = vec4(-1.0);
uniform vec4 c_hair = vec4(-1.0);
uniform vec4 c_shirt = vec4(-1.0);
uniform vec4 c_shorts = vec4(-1.0);
uniform vec4 c_socks = vec4(-1.0);
uniform vec4 c_boots = vec4(-1.0);
uniform vec4 flash = vec4(0.0);

vec3 tinted(vec3 t, float k) {
	float hi = max(0.0, k - 0.9) * 2.0;
	return min(vec3(1.0), t * k + (vec3(1.0) - t) * hi);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 m = texture(mask_tex, UV);
	int cls = int(round(m.r * 255.0));
	vec4 t = vec4(-1.0);
	if (cls == 1) t = c_skin;
	else if (cls == 2) t = c_hair;
	else if (cls == 3) t = c_shirt;
	else if (cls == 4) t = c_shorts;
	else if (cls == 5) t = c_socks;
	else if (cls == 7) t = c_boots;
	vec3 rgb = c.rgb;
	if (t.r >= 0.0) rgb = tinted(t.rgb, m.g);
	rgb = mix(rgb, flash.rgb, flash.a);
	COLOR = vec4(rgb, c.a);
}
"""

static var _shader: Shader
static var _tex: Dictionary = {}

static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader

static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[path] = t
	return t

## Config determinista para un NPC (misma idea que Avatar.random_config).
static func random_config(seed_int: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_int) + 1
	var cfg: Dictionary = {"v": 2}
	cfg["hair"] = RANDOM_HAIR[rng.randi() % RANDOM_HAIR.size()]
	cfg["face"] = String(RANDOM_FACES[rng.randi() % RANDOM_FACES.size()]) if rng.randf() < 0.35 else ""
	cfg["tint_base"] = SKIN[rng.randi() % SKIN.size()]
	cfg["tint_hair"] = HAIR_COL[rng.randi() % HAIR_COL.size()]
	if rng.randf() < 0.3:
		cfg["nose"] = NOSES[rng.randi() % NOSES.size()]
	if rng.randf() < 0.25:
		cfg["rasgo"] = RASGOS[rng.randi() % RASGOS.size()]
	if rng.randf() < 0.12:
		cfg["ears"] = "grandes"
	return cfg

## Le pone el kit de un equipo (camiseta, short, medias, botines).
static func with_kit(cfg: Dictionary, kit: Dictionary) -> Dictionary:
	var c: Dictionary = cfg.duplicate()
	for k in ["clothing", "shorts", "socks", "boots"]:
		if kit.has(k):
			c["tint_" + k] = kit[k]
	return c

## Capas de la CABEZA que van encima de cada cuadro (vista de frente):
## [grupo, id]. El peinado de espaldas/costado se resuelve aparte.
static func head_layers(cfg: Dictionary) -> Array:
	var out: Array = []
	for grp in ["rasgo", "nose", "ears"]:
		var rid: String = String(cfg.get(grp, ""))
		if rid != "":
			out.append([grp, rid])
	var face: String = String(cfg.get("face", ""))
	if face != "":
		out.append(["face", face])
	var hair: String = String(cfg.get("hair", "rapado"))
	var acc: String = String(cfg.get("acc_head", ""))
	var hat: bool = acc in ["gorra", "gorro_lana", "boina"]
	if hair != "rapado" and hair != "" and not hat:
		out.append(["hair", hair])
	if acc != "" and HEAD_ACC.has(acc):
		out.append(["acc", acc])
	return out

static func color_of(cfg: Dictionary, key: String) -> Color:
	var h: String = String(cfg.get("tint_" + key, ""))
	return Color(h) if h != "" else Color(-1, -1, -1, -1)

## Material nuevo con los colores del config.
static func make_material(cfg: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	apply_colors(m, cfg)
	return m

static func apply_colors(m: ShaderMaterial, cfg: Dictionary) -> void:
	m.set_shader_parameter("c_skin", color_of(cfg, "base"))
	m.set_shader_parameter("c_hair", color_of(cfg, "hair"))
	m.set_shader_parameter("c_shirt", color_of(cfg, "clothing"))
	m.set_shader_parameter("c_shorts", color_of(cfg, "shorts"))
	var socks: Color = color_of(cfg, "socks") if cfg.has("tint_socks") else color_of(cfg, "clothing")
	m.set_shader_parameter("c_socks", socks)
	m.set_shader_parameter("c_boots", color_of(cfg, "boots"))

## Cantidad de cuadros de una animación (cacheado).
static var _counts: Dictionary = {}
static func frame_count(anim: String) -> int:
	if _counts.has(anim):
		return _counts[anim]
	var n: int = 0
	while ResourceLoader.exists("%sanim/%s/%d.png" % [DIR, anim, n]):
		n += 1
	_counts[anim] = n
	return n

static func has_anim(anim: String) -> bool:
	return frame_count(anim) > 0
