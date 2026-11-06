class_name NationalKits
extends RefCounted
## Equipaciones de las selecciones para el partido 3D, al estilo de las actuales:
## camiseta, segundo color (ribetes/rayas), pantalón, medias, diseño del shader 3D
## (match3d/shaders/player_body.gdshaderinc: 1 rayas, 10 cuadros, 15 banda, 16 degradado,
## 17 diplomática, 22 ribetes, 23 polo retro…) y si el escudo va al centro del pecho.
## Lo usa Match3DBridge.build_config; los países que no están aquí salen de
## CountryFlags.team_color con ribetes (mismo país, misma camiseta, siempre).

# país: [local], [visitante] — cada una: [camiseta, color2, pantalón, medias, diseño, escudo_centro]
const KITS := {
	# CONMEBOL
	"Argentina": [["#f4f6fa", "#6cace4", "#14161c", "#f4f6fa", 1, false], ["#24224f", "#6cace4", "#24224f", "#24224f", 22, false]],
	"Brasil": [["#ffdc02", "#00923f", "#1d3f9a", "#f4f4f4", 22, false], ["#1d4fc4", "#ffdc02", "#1d4fc4", "#1d4fc4", 22, false]],
	"Uruguay": [["#5cbfeb", "#141414", "#141414", "#141414", 23, true], ["#f4f4f4", "#5cbfeb", "#141414", "#f4f4f4", 22, false]],
	"Colombia": [["#fcd116", "#0b2a6b", "#0b2a6b", "#f4f4f4", 22, false], ["#0b2a6b", "#fcd116", "#0b2a6b", "#0b2a6b", 25, false]],
	"Chile": [["#d52b1e", "#0039a6", "#0039a6", "#f4f4f4", 22, false], ["#f4f4f4", "#d52b1e", "#f4f4f4", "#f4f4f4", 22, false]],
	"Ecuador": [["#ffd100", "#034ea2", "#034ea2", "#e2001a", 22, false], ["#034ea2", "#ffd100", "#034ea2", "#034ea2", 13, false]],
	"Paraguay": [["#da020e", "#f4f4f4", "#0038a8", "#0038a8", 21, false], ["#0038a8", "#da020e", "#0038a8", "#0038a8", 22, false]],
	"Perú": [["#f4f4f4", "#d91023", "#f4f4f4", "#f4f4f4", 15, false], ["#d91023", "#f4f4f4", "#d91023", "#d91023", 15, false]],
	"Venezuela": [["#7a0f2b", "#e8b84a", "#7a0f2b", "#7a0f2b", 22, false], ["#f4f4f4", "#7a0f2b", "#f4f4f4", "#f4f4f4", 22, false]],
	"Bolivia": [["#007a33", "#f4f4f4", "#f4f4f4", "#007a33", 22, false], ["#f4f4f4", "#007a33", "#007a33", "#f4f4f4", 22, false]],
	# CONCACAF
	"México": [["#0b6b3a", "#c8102e", "#f4f4f4", "#c8102e", 14, true], ["#f4f1e8", "#7a1f2b", "#7a1f2b", "#f4f1e8", 22, false]],
	"Estados Unidos": [["#f4f4f4", "#1b2a5a", "#1b2a5a", "#f4f4f4", 22, true], ["#1b2a5a", "#c8102e", "#1b2a5a", "#1b2a5a", 17, true]],
	"Canadá": [["#d80621", "#f4f4f4", "#d80621", "#d80621", 22, false], ["#f4f4f4", "#d80621", "#f4f4f4", "#f4f4f4", 13, false]],
	"Costa Rica": [["#ce1126", "#002b7f", "#002b7f", "#f4f4f4", 22, false], ["#f4f4f4", "#ce1126", "#f4f4f4", "#f4f4f4", 22, false]],
	"Jamaica": [["#fed100", "#009b3a", "#141414", "#fed100", 28, false], ["#141414", "#fed100", "#141414", "#141414", 22, false]],
	"Panamá": [["#da121a", "#005293", "#da121a", "#da121a", 22, false], ["#f4f4f4", "#005293", "#f4f4f4", "#f4f4f4", 22, false]],
	"Honduras": [["#f4f4f4", "#0073cf", "#f4f4f4", "#f4f4f4", 22, false], ["#0073cf", "#f4f4f4", "#0073cf", "#0073cf", 22, false]],
	# UEFA
	"España": [["#c60b1e", "#ffc400", "#1b2a4a", "#1b2a4a", 22, false], ["#f2efe6", "#c60b1e", "#f2efe6", "#f2efe6", 22, false]],
	"Francia": [["#21304d", "#e1000f", "#f4f4f4", "#e1000f", 22, true], ["#f4f4f4", "#21304d", "#21304d", "#f4f4f4", 17, true]],
	"Alemania": [["#f4f4f4", "#141414", "#141414", "#f4f4f4", 22, false], ["#e0409a", "#5b2a86", "#5b2a86", "#e0409a", 16, false]],
	"Inglaterra": [["#f4f4f4", "#1b2a5a", "#1b2a5a", "#f4f4f4", 22, false], ["#4b2a7a", "#c8102e", "#4b2a7a", "#4b2a7a", 22, false]],
	"Italia": [["#1f5fc1", "#d4af37", "#f4f4f4", "#1f5fc1", 22, false], ["#f4f4f4", "#1f5fc1", "#1f5fc1", "#f4f4f4", 22, false]],
	"Portugal": [["#c8102e", "#046a38", "#046a38", "#c8102e", 22, false], ["#f4f4f4", "#0b5b9e", "#f4f4f4", "#f4f4f4", 10, false]],
	"Países Bajos": [["#f36c21", "#141414", "#141414", "#f36c21", 22, false], ["#1b2a5a", "#f36c21", "#1b2a5a", "#1b2a5a", 6, false]],
	"Bélgica": [["#c8102e", "#fdda24", "#c8102e", "#c8102e", 22, false], ["#9fd3ec", "#c8102e", "#9fd3ec", "#9fd3ec", 22, false]],
	"Croacia": [["#e2231a", "#f4f4f4", "#f4f4f4", "#171796", 10, true], ["#171796", "#24247a", "#171796", "#171796", 10, true]],
	"Suiza": [["#d52b1e", "#f4f4f4", "#f4f4f4", "#d52b1e", 22, false], ["#f4f4f4", "#d52b1e", "#d52b1e", "#f4f4f4", 22, false]],
	"Dinamarca": [["#c60c30", "#f4f4f4", "#f4f4f4", "#c60c30", 22, false], ["#f4f4f4", "#c60c30", "#f4f4f4", "#f4f4f4", 22, false]],
	"Suecia": [["#fecc02", "#006aa7", "#006aa7", "#fecc02", 22, false], ["#006aa7", "#fecc02", "#006aa7", "#006aa7", 22, false]],
	"Noruega": [["#d71e2b", "#00205b", "#f4f4f4", "#00205b", 27, false], ["#f4f4f4", "#00205b", "#00205b", "#f4f4f4", 22, false]],
	"Polonia": [["#f4f4f4", "#dc143c", "#dc143c", "#f4f4f4", 19, false], ["#dc143c", "#f4f4f4", "#dc143c", "#dc143c", 22, false]],
	"Turquía": [["#e30a17", "#f4f4f4", "#e30a17", "#e30a17", 22, true], ["#f4f4f4", "#e30a17", "#f4f4f4", "#f4f4f4", 22, true]],
	"Escocia": [["#0b2a5e", "#f4f4f4", "#f4f4f4", "#0b2a5e", 22, false], ["#f2efe6", "#6a2c70", "#6a2c70", "#f2efe6", 22, false]],
	"Gales": [["#d30731", "#00843d", "#d30731", "#d30731", 22, false], ["#f2c94c", "#00843d", "#00843d", "#f2c94c", 22, false]],
	"Irlanda": [["#169b62", "#f4f4f4", "#f4f4f4", "#169b62", 22, false], ["#f4f4f4", "#ff883e", "#169b62", "#f4f4f4", 22, false]],
	"Serbia": [["#c6363c", "#0c4076", "#0c4076", "#f4f4f4", 22, false], ["#f4f4f4", "#c6363c", "#f4f4f4", "#f4f4f4", 22, false]],
	"Grecia": [["#f4f4f4", "#0d5eaf", "#f4f4f4", "#f4f4f4", 13, true], ["#0d5eaf", "#f4f4f4", "#0d5eaf", "#0d5eaf", 13, true]],
	"Ucrania": [["#ffd500", "#0057b7", "#ffd500", "#ffd500", 22, false], ["#0057b7", "#ffd500", "#0057b7", "#0057b7", 22, false]],
	"Hungría": [["#ce2939", "#477050", "#f4f4f4", "#477050", 22, false], ["#f4f4f4", "#ce2939", "#f4f4f4", "#f4f4f4", 22, false]],
	"República Checa": [["#d7141a", "#11457e", "#f4f4f4", "#11457e", 22, false], ["#f4f4f4", "#11457e", "#f4f4f4", "#f4f4f4", 22, false]],
	"Austria": [["#ed2939", "#f4f4f4", "#f4f4f4", "#ed2939", 22, false], ["#f4f4f4", "#ed2939", "#141414", "#f4f4f4", 22, false]],
	# AFC / OFC
	"Japón": [["#1a2f7a", "#e60012", "#1a2f7a", "#1a2f7a", 26, false], ["#f4f4f4", "#1a2f7a", "#f4f4f4", "#f4f4f4", 22, false]],
	"Corea del Sur": [["#c60c30", "#141414", "#141414", "#c60c30", 22, false], ["#f4f4f4", "#141414", "#141414", "#f4f4f4", 22, false]],
	"Australia": [["#ffcd00", "#00843d", "#00843d", "#ffcd00", 22, false], ["#00843d", "#ffcd00", "#00843d", "#00843d", 22, false]],
	"Arabia Saudita": [["#f4f4f4", "#006c35", "#f4f4f4", "#f4f4f4", 22, false], ["#006c35", "#f4f4f4", "#006c35", "#006c35", 22, false]],
	"Catar": [["#8d1b3d", "#f4f4f4", "#8d1b3d", "#8d1b3d", 28, false], ["#f4f4f4", "#8d1b3d", "#f4f4f4", "#f4f4f4", 22, false]],
	"Irán": [["#f4f4f4", "#da0000", "#f4f4f4", "#f4f4f4", 22, false], ["#da0000", "#f4f4f4", "#da0000", "#da0000", 22, false]],
	"China": [["#de2910", "#ffde00", "#de2910", "#de2910", 22, false], ["#f4f4f4", "#de2910", "#f4f4f4", "#f4f4f4", 22, false]],
	# CAF
	"Marruecos": [["#c1272d", "#006233", "#006233", "#c1272d", 22, false], ["#f4f4f4", "#c1272d", "#f4f4f4", "#f4f4f4", 22, false]],
	"Senegal": [["#f4f4f4", "#00853f", "#f4f4f4", "#f4f4f4", 22, false], ["#00853f", "#fdef42", "#00853f", "#00853f", 22, false]],
	"Nigeria": [["#008751", "#c8f0c8", "#008751", "#008751", 28, false], ["#f4f4f4", "#008751", "#f4f4f4", "#f4f4f4", 22, false]],
	"Ghana": [["#f4f4f4", "#141414", "#f4f4f4", "#f4f4f4", 22, true], ["#ce1126", "#fcd116", "#ce1126", "#ce1126", 22, true]],
	"Egipto": [["#ce1126", "#141414", "#f4f4f4", "#141414", 22, false], ["#f4f4f4", "#ce1126", "#141414", "#f4f4f4", 22, false]],
	"Argelia": [["#f4f4f4", "#006233", "#f4f4f4", "#f4f4f4", 22, false], ["#006233", "#f4f4f4", "#006233", "#006233", 22, false]],
	"Túnez": [["#e70013", "#f4f4f4", "#f4f4f4", "#e70013", 22, false], ["#f4f4f4", "#e70013", "#f4f4f4", "#f4f4f4", 22, false]],
	"Costa de Marfil": [["#ff8200", "#009e60", "#f4f4f4", "#009e60", 22, false], ["#f4f4f4", "#ff8200", "#f4f4f4", "#f4f4f4", 22, false]],
	"Camerún": [["#007a5e", "#ce1126", "#ce1126", "#fcd116", 22, false], ["#fcd116", "#007a5e", "#007a5e", "#fcd116", 22, false]],
}

## La equipación de un país: {shirt, c2, shorts, socks (Color), pattern (int), center (bool)}.
static func kit(country: String, away: bool) -> Dictionary:
	var k: Array
	if KITS.has(country):
		k = KITS[country][1 if away else 0]
	else:
		var c: Color = CountryFlags.team_color(country)
		var dark := c.get_luminance() < 0.6
		var sec: String = "#f2f2f2" if dark else "#141414"
		var col: String = "#" + c.to_html(false)
		k = [col, sec, sec, col, 22, false] if not away else [sec, col, sec, sec, 22, false]
	return {"shirt": Color(String(k[0])), "c2": Color(String(k[1])), "shorts": Color(String(k[2])),
		"socks": Color(String(k[3])), "pattern": int(k[4]), "center": bool(k[5])}
