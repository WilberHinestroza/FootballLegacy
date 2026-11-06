extends RefCounted
class_name CompetitionNames

## Un solo lugar para el NOMBRE visible de cada competición que NO es una
## liga (copa doméstica y torneos continentales de club). Las ligas se
## nombran en WorldFactory.LEAGUE_BLUEPRINTS.
##
## Estilo: realista pero SIN marcas registradas — misma disciplina que
## con los nombres de futbolistas (decisión de Wilber, sept-2026:
## "realistas sin marca"). "Copa de España", no "Copa del Rey"; "Liga de
## Campeones de Europa", no "UEFA Champions League".

## Copa doméstica por país (tal como aparece en LeagueData.country). Si un
## país no está listado, se cae a la fórmula de `domestic_cup()`.
const DOMESTIC_CUP := {
	"España": "Copa de España",
	"Inglaterra": "Copa de Inglaterra",
	"Alemania": "Copa de Alemania",
	"Francia": "Copa de Francia",
	"Italia": "Copa de Italia",
	"Portugal": "Copa de Portugal",
	"Países Bajos": "Copa de los Países Bajos",
	"Bélgica": "Copa de Bélgica",
	"Turquía": "Copa de Turquía",
	"Escocia": "Copa de Escocia",
	"Austria": "Copa de Austria",
	"Azerbaiyán": "Copa de Azerbaiyán",
	"Croacia": "Copa de Croacia",
	"Chipre": "Copa de Chipre",
	"República Checa": "Copa de la República Checa",
	"Dinamarca": "Copa de Dinamarca",
	"Grecia": "Copa de Grecia",
	"Hungría": "Copa de Hungría",
	"Irlanda": "Copa de Irlanda",
	"Noruega": "Copa de Noruega",
	"Polonia": "Copa de Polonia",
	"Rumanía": "Copa de Rumanía",
	"Suecia": "Copa de Suecia",
	"Suiza": "Copa de Suiza",
	"Ucrania": "Copa de Ucrania",
	"Brasil": "Copa de Brasil",
	"Argentina": "Copa de Argentina",
	"Colombia": "Copa de Colombia",
	"Chile": "Copa de Chile",
	"Uruguay": "Copa de Uruguay",
	"Ecuador": "Copa de Ecuador",
	"Paraguay": "Copa de Paraguay",
	"México": "Copa de México",
	"Estados Unidos": "Copa de Estados Unidos",
	"Costa Rica": "Copa de Costa Rica",
	"Honduras": "Copa de Honduras",
	"Arabia Saudita": "Copa de Arabia Saudita",
	"Japón": "Copa de Japón",
	"Corea del Sur": "Copa de Corea del Sur",
	"China": "Copa de China",
	"India": "Copa de India",
	"Emiratos Árabes Unidos": "Copa de los Emiratos",
	"Australia": "Copa de Australia",
	"Marruecos": "Copa de Marruecos",
	"Egipto": "Copa de Egipto",
	"Nigeria": "Copa de Nigeria",
	"Ghana": "Copa de Ghana",
	"Senegal": "Copa de Senegal",
}

## Torneo continental de club por confederación (Confederations.UEFA, …) y
## nivel (1 = el más fuerte). Sustituye a la fórmula genérica que había en
## Confederations.tier_name().
const CONTINENTAL := {
	"UEFA": {
		1: "Liga de Campeones de Europa",
		2: "Liga Europa",
		3: "Liga Conferencia de Europa",
	},
	"CONMEBOL": {
		1: "Copa de Campeones de Sudamérica",
		2: "Copa Sudamericana",
	},
	"CONCACAF": {
		1: "Copa de Campeones de Centroamérica",
		2: "Copa Centroamericana",
		3: "Copa del Caribe",
	},
	"AFC": {
		1: "Liga de Campeones de Asia",
		2: "Copa de Asia",
		3: "Copa Challenge de Asia",
	},
	"CAF": {
		1: "Liga de Campeones de África",
		2: "Copa Confederación de África",
	},
}

## Copa continental de SELECCIONES por confederación (selecciones
## nacionales, Fase 4) — ver NationalCupEngine.gd. Mismo criterio "sin
## marca" que el resto: "Copa de Naciones de Europa" en vez de "Eurocopa",
## "...de Sudamérica" en vez de "Copa América", etc.
const NATIONAL_CONTINENTAL := {
	"UEFA": "Copa de Naciones de Europa",
	"CONMEBOL": "Copa de Naciones de Sudamérica",
	"CONCACAF": "Copa de Naciones de Centroamérica",
	"AFC": "Copa de Naciones de Asia",
	"CAF": "Copa de Naciones de África",
}

static func national_continental(confederation: String) -> String:
	if NATIONAL_CONTINENTAL.has(confederation):
		return NATIONAL_CONTINENTAL[confederation]
	var region: String = Confederations.REGION.get(confederation, confederation)
	return "Copa de Naciones de %s" % region

static func domestic_cup(country: String) -> String:
	if DOMESTIC_CUP.has(country):
		return DOMESTIC_CUP[country]
	return "Copa de %s" % country

static func continental(confederation: String, tier: int) -> String:
	var byconf: Dictionary = CONTINENTAL.get(confederation, {})
	if byconf.has(tier):
		return byconf[tier]
	# Fallback defensivo por si se agrega un nivel nuevo antes que su nombre.
	var region: String = Confederations.REGION.get(confederation, confederation)
	return "Copa de %s" % region
