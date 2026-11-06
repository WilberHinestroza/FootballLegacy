extends RefCounted
class_name CountryFlags

## Banderas de país (Kenney flag-pack, assets/flags/Default/, 64×64 PNG por
## código ISO 3166-1 alfa-2). Mapea los nombres en español de
## Countries.ALL a su archivo. Un país sin bandera en el pack devuelve
## null / no dibuja nada (nunca rompe).

const _DIR := "res://assets/flags/Default/"

## nombre español (Countries.ALL) -> código de archivo (sin .png)
const CODE := {
	"Afganistán": "AF", "Albania": "AL", "Alemania": "DE", "Andorra": "AD", "Angola": "AO",
	"Antigua y Barbuda": "AG", "Arabia Saudita": "SA", "Argelia": "DZ", "Argentina": "AR",
	"Armenia": "AM", "Australia": "AU", "Austria": "AT", "Azerbaiyán": "AZ",
	"Bahamas": "BS", "Bangladés": "BD", "Barbados": "BB", "Baréin": "BH", "Bélgica": "BE",
	"Belice": "BZ", "Benín": "BJ", "Bielorrusia": "BY", "Birmania": "MM", "Bolivia": "BO",
	"Bosnia y Herzegovina": "BA", "Botsuana": "BW", "Brasil": "BR", "Brunéi": "BN",
	"Bulgaria": "BG", "Burkina Faso": "BF", "Burundi": "BI", "Bután": "BT",
	"Cabo Verde": "CV", "Camboya": "KH", "Camerún": "CM", "Canadá": "CA", "Catar": "QA",
	"Chad": "TD", "Chile": "CL", "China": "CN", "Chipre": "CY", "Ciudad del Vaticano": "VA",
	"Colombia": "CO", "Comoras": "KM", "Corea del Norte": "KP", "Corea del Sur": "KR",
	"Costa de Marfil": "CI", "Costa Rica": "CR", "Croacia": "HR", "Cuba": "CU",
	"Dinamarca": "DK", "Dominica": "DM",
	"Ecuador": "EC", "Egipto": "EG", "El Salvador": "SV", "Emiratos Árabes Unidos": "AE",
	"Eritrea": "ER", "Escocia": "GB_SCT", "Eslovaquia": "SK", "Eslovenia": "SI", "España": "ES",
	"Estados Unidos": "US", "Estonia": "EE", "Esuatini": "SZ", "Etiopía": "ET",
	"Filipinas": "PH", "Finlandia": "FI", "Fiyi": "FJ", "Francia": "FR",
	"Gabón": "GA", "Gales": "GB_WLS", "Gambia": "GM", "Georgia": "GE", "Ghana": "GH",
	"Granada": "GD", "Grecia": "GR", "Guatemala": "GT", "Guinea": "GN", "Guinea-Bisáu": "GW",
	"Guinea Ecuatorial": "GQ", "Guyana": "GY",
	"Haití": "HT", "Honduras": "HN", "Hungría": "HU",
	"India": "IN", "Indonesia": "ID", "Inglaterra": "GB_ENG", "Irak": "IQ", "Irán": "IR",
	"Irlanda": "IE", "Irlanda del Norte": "GB", "Islandia": "IS", "Islas Marshall": "MH",
	"Islas Salomón": "SB", "Israel": "IL", "Italia": "IT",
	"Jamaica": "JM", "Japón": "JP", "Jordania": "JO",
	"Kazajistán": "KZ", "Kenia": "KE", "Kirguistán": "KG", "Kiribati": "KI", "Kuwait": "KW",
	"Laos": "LA", "Lesoto": "LS", "Letonia": "LV", "Líbano": "LB", "Liberia": "LR", "Libia": "LY",
	"Liechtenstein": "LI", "Lituania": "LT", "Luxemburgo": "LU",
	"Macedonia del Norte": "MK", "Madagascar": "MG", "Malasia": "MY", "Malaui": "MW",
	"Maldivas": "MV", "Malí": "ML", "Malta": "MT", "Marruecos": "MA", "Mauricio": "MU",
	"Mauritania": "MR", "México": "MX", "Micronesia": "FM", "Moldavia": "MD", "Mónaco": "MC",
	"Mongolia": "MN", "Montenegro": "ME", "Mozambique": "MZ",
	"Namibia": "NA", "Nauru": "NR", "Nepal": "NP", "Nicaragua": "NI", "Níger": "NE",
	"Nigeria": "NG", "Noruega": "NO", "Nueva Zelanda": "NZ",
	"Omán": "OM",
	"Países Bajos": "NL", "Pakistán": "PK", "Palaos": "PW", "Palestina": "PS", "Panamá": "PA",
	"Papúa Nueva Guinea": "PG", "Paraguay": "PY", "Perú": "PE", "Polonia": "PL", "Portugal": "PT",
	"República Centroafricana": "CF", "República Checa": "CZ", "República del Congo": "CG",
	"República Democrática del Congo": "CD", "República Dominicana": "DO", "Ruanda": "RW",
	"Rumanía": "RO", "Rusia": "RU",
	"Samoa": "WS", "San Cristóbal y Nieves": "KN", "San Marino": "SM",
	"San Vicente y las Granadinas": "VC", "Santa Lucía": "LC", "Santo Tomé y Príncipe": "ST",
	"Senegal": "SN", "Serbia": "RS", "Seychelles": "SC", "Sierra Leona": "SL", "Singapur": "SG",
	"Siria": "SY", "Somalia": "SO", "Sri Lanka": "LK", "Sudáfrica": "ZA", "Sudán": "SD",
	"Sudán del Sur": "SS", "Suecia": "SE", "Suiza": "CH", "Surinam": "SR",
	"Tailandia": "TH", "Tanzania": "TZ", "Tayikistán": "TJ", "Timor Oriental": "TL", "Togo": "TG",
	"Tonga": "TO", "Trinidad y Tobago": "TT", "Túnez": "TN", "Turkmenistán": "TM", "Turquía": "TR",
	"Tuvalu": "TV",
	"Ucrania": "UA", "Uganda": "UG", "Uruguay": "UY", "Uzbekistán": "UZ",
	"Vanuatu": "VU", "Venezuela": "VE", "Vietnam": "VN",
	"Yemen": "YE", "Yibuti": "DJ",
	"Zambia": "ZM", "Zimbabue": "ZW",
}

static var _cache: Dictionary = {}
static var _proc_cache: Dictionary = {}
static var _norm_index: Dictionary = {}

## Nombres alternativos que llegan del mundo importado (FL26-27_data) y que
## no coinciden con Countries.ALL — se mapean a la clave canónica de CODE.
const ALIAS := {
	"RP China": "China", "R.P. China": "China", "China PR": "China",
	"República de Corea": "Corea del Sur", "Corea": "Corea del Sur",
	"Rumania": "Rumanía",
	"República de Irlanda": "Irlanda", "Rep. de Irlanda": "Irlanda", "Eire": "Irlanda",
	"R.D. del Congo": "República Democrática del Congo", "RD Congo": "República Democrática del Congo",
	"Congo": "República del Congo",
	"Guinea-Bissau": "Guinea-Bisáu", "Guinea Bissau": "Guinea-Bisáu",
	"R. Dominicana": "República Dominicana", "Rep. Dominicana": "República Dominicana",
	"Rep. Centroafric.": "República Centroafricana", "Rep. Centroafricana": "República Centroafricana",
	"San Vicente G.": "San Vicente y las Granadinas",
	"Arabia Saudí": "Arabia Saudita", "Arabia Saudi": "Arabia Saudita",
	"Bosnia-Herzegovina": "Bosnia y Herzegovina",
	"Países Bajos ": "Países Bajos", "Holanda": "Países Bajos",
	"Chequia": "República Checa",
	"Bielorrusia ": "Bielorrusia",
	"Cabo Verde ": "Cabo Verde",
	"Costa de Marfil ": "Costa de Marfil",
	"Trinidad y Tobago ": "Trinidad y Tobago",
}

## Códigos ISO para países/territorios que no están en Countries.ALL pero
## sí aparecen entre los jugadores importados (y en la Kenney flag-pack).
const EXTRA_CODE := {
	"Curazao": "CW", "Curaçao": "CW",
	"Hong Kong": "HK", "Hongkong": "HK",
	"Puerto Rico": "PR",
	"I. Feroe": "FO", "Islas Feroe": "FO",
	"Nueva Caledonia": "NC",
	"China Taipéi": "TW", "Taiwán": "TW", "Taipéi Chino": "TW",
	"Gibraltar": "GI",
	"Nueva Zelanda ": "NZ",
}

static func _norm(s: String) -> String:
	var t := s.to_lower().strip_edges()
	var out := ""
	for i in range(t.length()):
		var ch := t[i]
		if ch >= "a" and ch <= "z" or ch >= "0" and ch <= "9":
			out += ch
		elif ch in ["á", "à", "ä", "â"]:
			out += "a"
		elif ch in ["é", "è", "ë", "ê"]:
			out += "e"
		elif ch in ["í", "ì", "ï", "î"]:
			out += "i"
		elif ch in ["ó", "ò", "ö", "ô"]:
			out += "o"
		elif ch in ["ú", "ù", "ü", "û"]:
			out += "u"
		elif ch == "ñ":
			out += "n"
	return out

static func _build_norm_index() -> void:
	for k in CODE:
		_norm_index[_norm(k)] = CODE[k]
	for k in EXTRA_CODE:
		_norm_index[_norm(k)] = EXTRA_CODE[k]
	for k in ALIAS:
		if CODE.has(ALIAS[k]):
			_norm_index[_norm(k)] = CODE[ALIAS[k]]

## Devuelve el código de archivo ISO para un nombre de país (con alias,
## códigos extra y comparación sin acentos/mayúsculas). "" si no hay.
static func code_for(country_name: String) -> String:
	if CODE.has(country_name):
		return CODE[country_name]
	if ALIAS.has(country_name) and CODE.has(ALIAS[country_name]):
		return CODE[ALIAS[country_name]]
	if EXTRA_CODE.has(country_name):
		return EXTRA_CODE[country_name]
	if _norm_index.is_empty():
		_build_norm_index()
	return String(_norm_index.get(_norm(country_name), ""))

## Texture2D de la bandera del pack Kenney, o null si ese país no tiene
## archivo (usar `flag_or_proc` para SIEMPRE tener algo).
static func flag(country_name: String) -> Texture2D:
	var code: String = code_for(country_name)
	if code == "":
		return null
	if _cache.has(code):
		return _cache[code]
	var path: String = _DIR + code + ".png"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[code] = tex
	return tex

## ¿Tiene bandera REAL del pack (no la procedural)?
static func has_real_flag(country_name: String) -> bool:
	return flag(country_name) != null

## Bandera del pack si existe; si no, una bandera PROCEDURAL al estilo
## plano de Kenney (colores + diseño deterministas por país). Nunca null
## — pedido de Wilber: ningún país sin bandera, para la sección de
## selecciones.
static func flag_or_proc(country_name: String) -> Texture2D:
	var real := flag(country_name)
	if real != null:
		return real
	return _proc_flag(country_name)

## Paleta tipo bandera (vexilología real: rojos, azules, verdes, blanco,
## negro, amarillo, celeste...).
const _FLAG_PAL := [
	"#c62828", "#b71c1c", "#1565c0", "#0d47a1", "#2e7d32", "#1b5e20",
	"#f9f9f9", "#111418", "#f9c22e", "#f4a300", "#00897b", "#3aa0d8",
	"#7b1fa2", "#e65100", "#5d4037",
]

static func _proc_flag(country_name: String) -> ImageTexture:
	# Kosovo: no está en el pack — azul con franja dorada y 6 estrellitas.
	if country_name == "Kosovo":
		return _kosovo()
	if _proc_cache.has(country_name):
		return _proc_cache[country_name]
	var h: int = absi(hash("flag:" + country_name))
	var w := 64
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Marco de bandera Kenney: ocupa casi todo, con 3px de aire arriba/abajo.
	var top := 8
	var bot := w - 8
	var a := Color(_FLAG_PAL[h % _FLAG_PAL.size()])
	var b := Color(_FLAG_PAL[(h / 7) % _FLAG_PAL.size()])
	var c := Color(_FLAG_PAL[(h / 53) % _FLAG_PAL.size()])
	# evitar dos colores casi iguales
	if b.is_equal_approx(a):
		b = Color(_FLAG_PAL[(h / 7 + 3) % _FLAG_PAL.size()])
	if c.is_equal_approx(a) or c.is_equal_approx(b):
		c = Color("#f9f9f9")
	var layout: int = (h / 211) % 6
	var fh := bot - top
	match layout:
		0: # 3 franjas horizontales
			for y in range(top, bot):
				var band := (y - top) * 3 / fh
				_fillrow(img, y, [a, b, c][band])
		1: # 2 franjas horizontales
			for y in range(top, bot):
				_fillrow(img, y, a if (y - top) < fh / 2 else b)
		2: # 3 franjas verticales
			for y in range(top, bot):
				for x in range(w):
					img.set_pixel(x, y, [a, b, c][clampi(x * 3 / w, 0, 2)])
		3: # 2 franjas verticales
			for y in range(top, bot):
				for x in range(w):
					img.set_pixel(x, y, a if x < w / 2 else b)
		4: # campo + canton (esquina)
			for y in range(top, bot):
				_fillrow(img, y, a)
			for y in range(top, top + fh / 2):
				for x in range(0, w / 2):
					img.set_pixel(x, y, b)
		5: # cruz nórdica
			for y in range(top, bot):
				_fillrow(img, y, a)
			for y in range(top, bot):
				for x in range(w):
					if x >= 20 and x <= 28:
						img.set_pixel(x, y, b)
				if y >= (top + fh / 2 - 4) and y <= (top + fh / 2 + 4):
					_fillrow(img, y, b)
	_border(img, top, bot)  # borde oscuro fino (look Kenney)
	var t := ImageTexture.create_from_image(img)
	_proc_cache[country_name] = t
	return t

static func _fillrow(img: Image, y: int, col: Color) -> void:
	for x in range(img.get_width()):
		img.set_pixel(x, y, col)

static func _border(img: Image, top: int, bot: int) -> void:
	var w := img.get_width()
	var d := Color(0.06, 0.07, 0.09, 0.85)
	for x in range(w):
		img.set_pixel(x, top, d)
		img.set_pixel(x, bot - 1, d)
	for y in range(top, bot):
		img.set_pixel(0, y, d)
		img.set_pixel(w - 1, y, d)

static func _kosovo() -> ImageTexture:
	if _proc_cache.has("Kosovo"):
		return _proc_cache["Kosovo"]
	var w := 64
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var top := 8
	var bot := w - 8
	var blue := Color("#244aa5")
	for y in range(top, bot):
		_fillrow(img, y, blue)
	# contorno dorado abstracto (banda inferior) + 6 estrellas blancas arriba
	var gold := Color("#d0a933")
	for y in range(bot - 12, bot - 6):
		_fillrow(img, y, gold)
	var white := Color("#f5f5f5")
	for i in range(6):
		var cx := 10 + i * 8
		var cy := top + 8 + (2 if i == 0 or i == 5 else (0 if i == 2 or i == 3 else 1))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if absi(dx) + absi(dy) <= 1:
					img.set_pixel(cx + dx, cy + dy, white)
	_border(img, top, bot)
	var t := ImageTexture.create_from_image(img)
	_proc_cache["Kosovo"] = t
	return t

## Color de camiseta REAL para las selecciones que un hincha reconoce de
## memoria — bug real reportado por Wilber ("revisa las camisetas de las
## selecciones y sus colores"): antes TODO país, sin excepción, sacaba un
## color inventado por hash del nombre — Argentina podía no salir celeste,
## Brasil no salir amarillo. Cubre las selecciones más reconocibles
## (los 48 del Mundial real 2026 -ver WorldCupEngine.REAL_WC_2026_FIELD-
## + las principales de cada confederación); el resto (selecciones sin un
## color "de memoria" claro para la mayoría) sigue con el hash de
## siempre, nunca al azar de verdad — mismo país, mismo color, siempre.
const REAL_KIT_COLOR := {
	# UEFA
	"Alemania": "#FFFFFF", "Francia": "#0055A4", "Inglaterra": "#FFFFFF",
	"España": "#C60B1E", "Italia": "#0038A8", "Portugal": "#C8102E",
	"Países Bajos": "#F36C21", "Bélgica": "#DA121A", "Croacia": "#FF0000",
	"Suiza": "#FF0000", "Escocia": "#0065BD", "Austria": "#ED2939",
	"Suecia": "#FECC02", "Turquía": "#E30A17", "República Checa": "#D7141A",
	"Noruega": "#EF2B2D", "Bosnia y Herzegovina": "#002395", "Polonia": "#DC143C",
	"Ucrania": "#FFD500", "Rusia": "#DA291C", "Dinamarca": "#C60C30",
	"Gales": "#D30731", "Irlanda": "#169B62", "Rumanía": "#FCD116",
	"Serbia": "#C6363C", "Grecia": "#0D5EAF", "Hungría": "#CE2939",
	"Eslovaquia": "#0B4EA2", "Eslovenia": "#00A651",
	# CONMEBOL
	"Argentina": "#75AADB", "Brasil": "#FFCC00", "Uruguay": "#4C9ED9",
	"Colombia": "#FCD116", "Ecuador": "#FFE000", "Chile": "#D52B1E",
	"Paraguay": "#DA020E", "Perú": "#FFFFFF", "Venezuela": "#820019",
	"Bolivia": "#007A33",
	# CONCACAF
	"México": "#006847", "Estados Unidos": "#002868", "Canadá": "#FF0000",
	"Costa Rica": "#CE1126", "Jamaica": "#FED100", "Panamá": "#DA121A",
	"Honduras": "#0073CF", "Curazao": "#002F6C", "Haití": "#00209F",
	# AFC (+ Nueva Zelanda, OFC plegada acá por diseño)
	"Japón": "#0033A0", "Corea del Sur": "#C60C30", "Irán": "#FFFFFF",
	"Arabia Saudita": "#006C35", "Catar": "#8D1B3D", "Australia": "#FFCD00",
	"Irak": "#FFFFFF", "Uzbekistán": "#0099CC", "Jordania": "#FFFFFF",
	"China": "#DE2910", "Nueva Zelanda": "#FFFFFF",
	# CAF
	"Marruecos": "#C1272D", "Senegal": "#00853F", "Nigeria": "#008751",
	"Ghana": "#FFFFFF", "Egipto": "#CE1126", "Argelia": "#006233",
	"Túnez": "#E70013", "Costa de Marfil": "#FF8200", "Camerún": "#007A5E",
	"Sudáfrica": "#FFB81C", "Cabo Verde": "#003893",
	"República Democrática del Congo": "#007FFF",
}

## Color "de camiseta" determinista de un país (Parte 91: partidos de
## selección en Match.gd/PreMatch.gd) — no hay un primary_color_hex de
## país como en ClubData. REAL_KIT_COLOR de arriba primero (las
## selecciones reconocibles); si no está ahí, se deriva del nombre
## (mismo criterio de "nunca al azar de verdad" que el resto del juego:
## mismo país, mismo color, siempre). Centralizado ACÁ (antes vivía
## duplicado en Match.gd._resolve_team_colors) para no repetir la fórmula.
static func team_color(country_name: String) -> Color:
	if REAL_KIT_COLOR.has(country_name):
		return Color(String(REAL_KIT_COLOR[country_name]))
	return Color.from_hsv(float(absi(hash(country_name)) % 360) / 360.0, 0.62, 0.82)

## TextureRect listo para meter en una fila. `h` = alto en px (la bandera
## mantiene su relación de aspecto). Devuelve null si no hay bandera.
static func flag_rect(country_name: String, h: int = 16) -> TextureRect:
	var tex := flag_or_proc(country_name)
	if tex == null:
		return null
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(h * 1.5, h)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
