extends RefCounted
class_name Confederations

## Agrupa los países de WorldFactory.LEAGUE_BLUEPRINTS por confederación,
## para las competiciones continentales de clubes (Fase 10+ dejó afuera
## selecciones/Mundial a propósito, pero clubes cruzando ligas es del
## mismo alcance que copas domésticas — mundo vivo, nada pre-simulado).
##
## Cada confederación tiene VARIOS torneos por nivel (investigado: así
## funcionan de verdad — Europa reparte en 3 competiciones según la
## fuerza de cada liga, el resto del mundo en 2). Nombres genéricos, sin
## marca (misma disciplina que las ligas: "Primera División (España)" en
## vez de "La Liga" — aquí "Copa Europa" en vez del nombre real).

const UEFA := "UEFA"
const CONMEBOL := "CONMEBOL"
const CONCACAF := "CONCACAF"
const AFC := "AFC"
const CAF := "CAF"

const ALL := [UEFA, CONMEBOL, CONCACAF, AFC, CAF]

## Nombre de región para armar el nombre de cada torneo.
const REGION := {
	UEFA: "Europa", CONMEBOL: "Sudamérica", CONCACAF: "Centroamérica",
	AFC: "Asia", CAF: "África",
}

## Cuántos torneos por nivel tiene cada confederación — real: Europa 3
## (Campeones / Europa / Conferencia), CONCACAF 3 (Copa de Campeones /
## Centroamericana / Caribe, aunque acá se reparten por RANKING en vez de
## por sub-región real) y AFC 3 (Elite / Two / Challenge) — las tres
## usando reparto por RANKING, ver nota de
## ContinentalEngine._SHARED_TIER_CONFEDERATIONS. CONMEBOL/CAF se quedan
## en 2 (Campeones / Copa), que es lo real para esas dos.
const TIER_COUNT := {
	UEFA: 3, CONMEBOL: 2, CONCACAF: 3, AFC: 3, CAF: 2,
}

## País (tal como aparece en LeagueData.country, y en Countries.ALL para la
## nacionalidad de un jugador) -> confederación. Cubre los 199 de
## Countries.ALL (necesario desde que existen selecciones nacionales,
## Mundial/eliminatorias/copas — no solo los ~40 con liga de club modelada).
## Oceanía NO tiene confederación propia en este juego (no hay OFC): se
## pliega a AFC para selecciones, mismo precedente real de Australia
## (se mudó de OFC a AFC en 2006).
const COUNTRY_TO_CONFEDERATION := {
	# --- UEFA (Europa) ---
	"Albania": UEFA, "Alemania": UEFA, "Andorra": UEFA, "Armenia": UEFA,
	"Austria": UEFA, "Azerbaiyán": UEFA, "Bélgica": UEFA, "Bielorrusia": UEFA,
	"Bosnia y Herzegovina": UEFA, "Bulgaria": UEFA, "Chipre": UEFA,
	"Ciudad del Vaticano": UEFA, "Croacia": UEFA, "Dinamarca": UEFA,
	"Escocia": UEFA, "Eslovaquia": UEFA, "Eslovenia": UEFA, "España": UEFA,
	"Estonia": UEFA, "Finlandia": UEFA, "Francia": UEFA, "Gales": UEFA,
	"Georgia": UEFA, "Grecia": UEFA, "Hungría": UEFA, "Inglaterra": UEFA,
	"Irlanda": UEFA, "Irlanda del Norte": UEFA, "Islandia": UEFA,
	"Israel": UEFA, "Italia": UEFA, "Kazajistán": UEFA, "Kosovo": UEFA,
	"Letonia": UEFA, "Liechtenstein": UEFA, "Lituania": UEFA,
	"Luxemburgo": UEFA, "Macedonia del Norte": UEFA, "Malta": UEFA,
	"Moldavia": UEFA, "Mónaco": UEFA, "Montenegro": UEFA, "Noruega": UEFA,
	"Países Bajos": UEFA, "Polonia": UEFA, "Portugal": UEFA,
	"República Checa": UEFA, "Rumanía": UEFA, "Rusia": UEFA,
	"San Marino": UEFA, "Serbia": UEFA, "Suecia": UEFA, "Suiza": UEFA,
	"Turquía": UEFA, "Ucrania": UEFA,

	# --- CONMEBOL (Sudamérica) ---
	"Argentina": CONMEBOL, "Bolivia": CONMEBOL, "Brasil": CONMEBOL,
	"Chile": CONMEBOL, "Colombia": CONMEBOL, "Ecuador": CONMEBOL,
	"Paraguay": CONMEBOL, "Perú": CONMEBOL, "Uruguay": CONMEBOL,
	"Venezuela": CONMEBOL,

	# --- CONCACAF (Norte/Centroamérica y Caribe — incluye Guyana/Surinam,
	# como en la vida real, aunque geográficamente son Sudamérica) ---
	"Antigua y Barbuda": CONCACAF, "Bahamas": CONCACAF, "Barbados": CONCACAF,
	"Belice": CONCACAF, "Canadá": CONCACAF, "Costa Rica": CONCACAF,
	"Cuba": CONCACAF, "Curazao": CONCACAF, "Dominica": CONCACAF, "El Salvador": CONCACAF,
	"Estados Unidos": CONCACAF, "Granada": CONCACAF, "Guatemala": CONCACAF,
	"Guyana": CONCACAF, "Haití": CONCACAF, "Honduras": CONCACAF,
	"Jamaica": CONCACAF, "México": CONCACAF, "Nicaragua": CONCACAF,
	"Panamá": CONCACAF, "República Dominicana": CONCACAF,
	"San Cristóbal y Nieves": CONCACAF, "San Vicente y las Granadinas": CONCACAF,
	"Santa Lucía": CONCACAF, "Surinam": CONCACAF, "Trinidad y Tobago": CONCACAF,

	# --- AFC (Asia + Oceanía plegada) ---
	"Afganistán": AFC, "Arabia Saudita": AFC, "Australia": AFC,
	"Bangladés": AFC, "Baréin": AFC, "Birmania": AFC, "Brunéi": AFC,
	"Bután": AFC, "Camboya": AFC, "Catar": AFC, "China": AFC,
	"Corea del Norte": AFC, "Corea del Sur": AFC,
	"Emiratos Árabes Unidos": AFC, "Filipinas": AFC, "Fiyi": AFC,
	"India": AFC, "Indonesia": AFC, "Irak": AFC, "Irán": AFC,
	"Islas Marshall": AFC, "Islas Salomón": AFC, "Japón": AFC,
	"Jordania": AFC, "Kirguistán": AFC, "Kiribati": AFC, "Kuwait": AFC,
	"Laos": AFC, "Líbano": AFC, "Malasia": AFC, "Maldivas": AFC,
	"Micronesia": AFC, "Mongolia": AFC, "Nauru": AFC, "Nepal": AFC,
	"Nueva Zelanda": AFC, "Omán": AFC, "Pakistán": AFC, "Palaos": AFC,
	"Palestina": AFC, "Papúa Nueva Guinea": AFC, "Samoa": AFC,
	"Singapur": AFC, "Siria": AFC, "Sri Lanka": AFC, "Tailandia": AFC,
	"Tayikistán": AFC, "Timor Oriental": AFC, "Tonga": AFC,
	"Turkmenistán": AFC, "Tuvalu": AFC, "Uzbekistán": AFC, "Vanuatu": AFC,
	"Vietnam": AFC, "Yemen": AFC,

	# --- CAF (África) ---
	"Angola": CAF, "Argelia": CAF, "Benín": CAF, "Botsuana": CAF,
	"Burkina Faso": CAF, "Burundi": CAF, "Cabo Verde": CAF, "Camerún": CAF,
	"Chad": CAF, "Comoras": CAF, "Costa de Marfil": CAF, "Egipto": CAF,
	"Eritrea": CAF, "Esuatini": CAF, "Etiopía": CAF, "Gabón": CAF,
	"Gambia": CAF, "Ghana": CAF, "Guinea": CAF, "Guinea-Bisáu": CAF,
	"Guinea Ecuatorial": CAF, "Kenia": CAF, "Lesoto": CAF, "Liberia": CAF,
	"Libia": CAF, "Madagascar": CAF, "Malaui": CAF, "Malí": CAF,
	"Marruecos": CAF, "Mauricio": CAF, "Mauritania": CAF, "Mozambique": CAF,
	"Namibia": CAF, "Níger": CAF, "Nigeria": CAF,
	"República Centroafricana": CAF, "República del Congo": CAF,
	"República Democrática del Congo": CAF, "Ruanda": CAF,
	"Santo Tomé y Príncipe": CAF, "Senegal": CAF, "Seychelles": CAF,
	"Sierra Leona": CAF, "Somalia": CAF, "Sudáfrica": CAF, "Sudán": CAF,
	"Sudán del Sur": CAF, "Tanzania": CAF, "Togo": CAF, "Túnez": CAF,
	"Uganda": CAF, "Yibuti": CAF, "Zambia": CAF, "Zimbabue": CAF,
}

static func confederation_of(country: String) -> String:
	return COUNTRY_TO_CONFEDERATION.get(country, "")

static func tier_count(confederation: String) -> int:
	return TIER_COUNT.get(confederation, 2)

## Nombre visible del torneo continental — realista y sin marca. La tabla
## real vive en CompetitionNames.CONTINENTAL (un solo lugar para todos los
## nombres de competición que no son liga).
static func tier_name(confederation: String, tier: int) -> String:
	return CompetitionNames.continental(confederation, tier)
