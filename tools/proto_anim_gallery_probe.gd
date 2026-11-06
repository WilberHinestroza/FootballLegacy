extends Node2D
## Galería (render real) de las animaciones de cancha del prototipo match_v2,
## teñidas como en el partido. Captura: _pixellab_preview/proto_v2_anims.png
##   godot --path . --resolution 576x1024 res://tools/ProtoAnimGalleryProbe.tscn
const ANIMS := ["pitch_remate", "pitch_remate_s", "pitch_pase", "pitch_regate_e", "pitch_regate_w", "pitch_cabezazo_s",
	"pitch_entrada", "pitch_entrada_s", "gk_lanzar", "gk_lanzar_n", "gk_punos", "gk_punos_n", "gk_achique", "gk_achique_n",
	"gk_saque_largo", "gk_saque_largo_n", "gk_atajada", "gk_estirada_der", "gk_volada", "gk_hold"]
var tex: Array = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(ANIMS.size()):
		var gk: bool = String(ANIMS[i]).begins_with("gk_")
		var cfg := {"tint_clothing": "#e8c341" if gk else ("#2b6be0" if i % 2 == 0 else "#d8443a"), "tint_shorts": "#1f2026", "tint_base": "#d9a577", "tint_hair": "#2b2320"}
		var fr: Array = Avatar.anim_frames(cfg, ANIMS[i])
		tex.append(fr)
	queue_redraw()
	for k in range(10):
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_pixellab_preview/proto_v2_anims.png"))
	print("CAPTURA OK")
	get_tree().quit(0)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 576, 1024), Color(0.18, 0.43, 0.22))
	var font := ThemeDB.fallback_font
	for i in range(tex.size()):
		var fr: Array = tex[i]
		var x: float = 6.0 + float(i % 4) * 142.0
		var y: float = 6.0 + float(i / 4) * 200.0
		draw_string(font, Vector2(x, y + 12), ANIMS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if fr.is_empty():
			draw_string(font, Vector2(x, y + 40), "FALTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.RED)
			continue
		for j in range(mini(fr.size(), 4)):
			var t: Texture2D = fr[mini(j * maxi(1, fr.size() / 4), fr.size() - 1)]
			draw_texture_rect(t, Rect2(x + float(j % 2) * 68.0, y + 16.0 + float(j / 2) * 90.0, 68, 68), false)
