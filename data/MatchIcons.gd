extends RefCounted
class_name MatchIcons

## Sprites chicos de partido (tarjeta, balón, clima) — PNGs blancos 32×32
## en assets/matchicons/, teñidos con `modulate`. Mismo criterio que
## Icons.make_rect: el `px` manda, nada se sale de su recuadro.

const _DIR := "res://assets/matchicons/"

static func rect(name: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	var p := _DIR + name + ".png"
	if ResourceLoader.exists(p):
		r.texture = load(p)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	return r

static func card(is_red: bool, px: int) -> TextureRect:
	return rect("card", px, Color("#d33a3a") if is_red else Color("#e8c02a"))

static func ball(px: int, tint: Color = Color.WHITE) -> TextureRect:
	return rect("ball", px, tint)

## kind: "sun" | "cloud" | "rain" | "snow"
static func weather(kind: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	return rect("wx_" + kind, px, tint)

const _WX := ["sun", "sun", "cloud", "cloud", "cloud", "rain", "rain", "snow"]
const _WX_LABEL := {
	"sun": "Despejado", "cloud": "Nublado", "rain": "Lluvia", "snow": "Nieve",
}

## Clima DETERMINISTA de un partido (no se persiste — se deriva del
## fixture + world_seed, igual criterio que el "mundo vivo").
static func weather_for(fixture: Dictionary, world_seed: int) -> String:
	var key := "%s|%s|%d" % [
		String(fixture.get("home_club_id", "")),
		String(fixture.get("competition", "")),
		int(fixture.get("epoch_day", fixture.get("matchday", 0))),
	]
	return _WX[absi(hash("wx:" + key) ^ world_seed) % _WX.size()]

static func weather_label(kind: String) -> String:
	return _WX_LABEL.get(kind, "Despejado")
