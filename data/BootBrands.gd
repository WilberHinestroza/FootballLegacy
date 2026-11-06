extends RefCounted
class_name BootBrands

## Marcas FICTICIAS de guayos (9-oct, pedido de Wilber: "4 marcas de guayos
## que puedan patrocinar al jugador en su carrera, con logos"). Logos de
## PixelLab (assets/brands/). Cada marca tiene sus modelos (los guayos de
## Avatar.ACCESSORIES). El contrato de patrocinio de guayos va aparte
## (schema v32, pendiente de confirmación de Wilber).
const BRANDS := [
	{"id": "voltix", "name": "Voltix", "logo": "bolt", "color": "#e3262f",
		"models": ["guayos_rojo", "guayos_negro"]},
	{"id": "aerion", "name": "Aerion", "logo": "wing", "color": "#2e7bff",
		"models": ["guayos_blanco", "guayos_azul"]},
	{"id": "vulpex", "name": "Vulpex", "logo": "fox", "color": "#ff7a1a",
		"models": ["guayos_rosa", "guayos_oro"]},
	{"id": "summit", "name": "Summit", "logo": "peak", "color": "#3ee03a",
		"models": ["guayos_verde", "guayos_morado", "guayos_arcoiris"]},
]

static func by_id(id: String) -> Dictionary:
	for b in BRANDS:
		if b["id"] == id:
			return b
	return {}

## Marca de un modelo de guayo ({} si no es de ninguna).
static func of_model(model_id: String) -> Dictionary:
	for b in BRANDS:
		if model_id in b["models"]:
			return b
	return {}

static func logo_rect(brand: Dictionary, px: int) -> TextureRect:
	var r := TextureRect.new()
	var p := "res://assets/brands/%s.png" % String(brand.get("logo", ""))
	if ResourceLoader.exists(p):
		r.texture = load(p)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
