extends RefCounted
class_name PersonalityQuiz

## Test de personalidad de la creación de personaje.
## Aprendizaje directo de Football Legacy: 20 preguntas fijas, se muestran
## 5 al azar, y cada respuesta ajusta uno o varios rasgos sobre una base
## de 50. Los rasgos que ninguna de las 5 preguntas toca se quedan en 50
## ("personalidad por definir") — eso es deliberado, no un bug.
##
## El resultado (Dictionary rasgo -> 0..100) se guarda tal cual en
## PlayerData.personality_traits.

const BASELINE := 50
const QUESTIONS_SHOWN := 5

## Orden canónico de rasgos. Cualquier UI que los liste debe respetarlo.
const TRAITS := [
	"ambition",       # ambición: quiere llegar a lo más alto, clubes grandes
	"loyalty",        # lealtad: apego al club y a la gente
	"professionalism",# profesionalidad: descanso, dieta, entrenamiento extra
	"determination",  # determinación: aguante ante la adversidad
	"sportsmanship",  # deportividad: juego limpio frente a picardía
	"sociability",    # sociabilidad: vestuario, medios, actos del club
]

const QUESTIONS: Array = [
	{
		"text": "Un club más grande te ofrece mejor sueldo pero menos minutos. ¿Qué haces?",
		"options": [
			{"text": "Firmo sin dudarlo, quiero jugar en la élite", "effects": {"ambition": 12, "loyalty": -6}},
			{"text": "Me quedo donde soy importante", "effects": {"ambition": -8, "loyalty": 10}},
			{"text": "Lo consulto con mi agente y mi familia", "effects": {"sociability": 6, "professionalism": 3}},
		],
	},
	{
		"text": "El entrenador te critica en público tras un mal partido.",
		"options": [
			{"text": "Le respondo en la rueda de prensa", "effects": {"sportsmanship": -10, "determination": 4}},
			{"text": "Lo hablo con él en privado", "effects": {"professionalism": 8, "sociability": 4}},
			{"text": "Entreno el doble para callar bocas", "effects": {"determination": 12, "professionalism": 6}},
		],
	},
	{
		"text": "Es tu día libre después de tres partidos en una semana.",
		"options": [
			{"text": "Gimnasio y fisio, el descanso también es trabajo", "effects": {"professionalism": 12}},
			{"text": "Salgo con mis compañeros a desconectar", "effects": {"sociability": 10, "professionalism": -4}},
			{"text": "Me quedo en casa con la familia", "effects": {"loyalty": 6, "sociability": -2}},
		],
	},
	{
		"text": "Vas ganando 3-0 y puedes hacer un caño humillante al rival.",
		"options": [
			{"text": "Lo hago, el espectáculo es parte del juego", "effects": {"sportsmanship": -8, "ambition": 3}},
			{"text": "Mantengo la posesión con respeto", "effects": {"sportsmanship": 10}},
			{"text": "Cedo el balón para que marque un compañero", "effects": {"sociability": 8, "sportsmanship": 5}},
		],
	},
	{
		"text": "Un periodista publica un rumor falso sobre ti.",
		"options": [
			{"text": "Comunicado oficial y sigo a lo mío", "effects": {"professionalism": 6, "determination": 5}},
			{"text": "Respondo con ironía en redes", "effects": {"sportsmanship": -6, "sociability": 2}},
			{"text": "No le doy ninguna importancia", "effects": {"determination": 8}},
		],
	},
	{
		"text": "Tu mejor amigo del equipo es traspasado.",
		"options": [
			{"text": "Le deseo suerte, así es el fútbol", "effects": {"determination": 6}},
			{"text": "Me cuesta, éramos clave dentro y fuera del campo", "effects": {"loyalty": 8, "sociability": 6}},
			{"text": "Aprovecho para ganarme su sitio", "effects": {"ambition": 10, "loyalty": -4}},
		],
	},
	{
		"text": "Te ofrecen renovar con cláusula de fidelidad y sueldo algo menor.",
		"options": [
			{"text": "Firmo, este club me formó", "effects": {"loyalty": 14, "ambition": -4}},
			{"text": "Negocio una subida o me planteo salir", "effects": {"ambition": 10, "loyalty": -6}},
			{"text": "Firmo solo un año y reevalúo", "effects": {"ambition": 4, "professionalism": 2}},
		],
	},
	{
		"text": "Llegas a la pretemporada con tres kilos de más.",
		"options": [
			{"text": "Nunca me pasaría, cuido cada comida", "effects": {"professionalism": 12}},
			{"text": "Me pongo a punto en dos semanas", "effects": {"determination": 8, "professionalism": -2}},
			{"text": "El físico ya llega con los partidos", "effects": {"professionalism": -10}},
		],
	},
	{
		"text": "El míster te pide cambiar de posición por el bien del equipo.",
		"options": [
			{"text": "Lo que haga falta por el grupo", "effects": {"sociability": 8, "loyalty": 5}},
			{"text": "Acepto si me lo explican bien", "effects": {"professionalism": 5}},
			{"text": "Me incomoda, es mi carrera la que está en juego", "effects": {"ambition": 8, "sociability": -5}},
		],
	},
	{
		"text": "Un rival te provoca durante todo el partido.",
		"options": [
			{"text": "Le contesto con un gol y me voy", "effects": {"determination": 10, "sportsmanship": 4}},
			{"text": "Entro fuerte a la próxima", "effects": {"sportsmanship": -12, "determination": 3}},
			{"text": "Se lo hago saber al árbitro", "effects": {"sportsmanship": 2}},
		],
	},
	{
		"text": "Te dejan fuera de la convocatoria sin explicación.",
		"options": [
			{"text": "Hablo con el entrenador de forma directa", "effects": {"professionalism": 6, "determination": 5}},
			{"text": "Redoblo el esfuerzo en los entrenamientos", "effects": {"determination": 12, "professionalism": 5}},
			{"text": "Filtro mi malestar a un periodista", "effects": {"sportsmanship": -10, "loyalty": -5}},
		],
	},
	{
		"text": "Una marca te ofrece un patrocinio que te quitaría horas de descanso.",
		"options": [
			{"text": "Lo rechazo, primero el rendimiento", "effects": {"professionalism": 10, "ambition": -2}},
			{"text": "Acepto, hay que construir una marca", "effects": {"ambition": 8, "professionalism": -5}},
			{"text": "Acepto con límites claros de agenda", "effects": {"ambition": 4, "professionalism": 3}},
		],
	},
	{
		"text": "Un compañero joven está hundido tras un error grave.",
		"options": [
			{"text": "Le hablo y le subo el ánimo", "effects": {"sociability": 12, "loyalty": 4}},
			{"text": "Le doy espacio, ya se recuperará", "effects": {"determination": 3}},
			{"text": "Le digo que espabile, esto es de mayores", "effects": {"sociability": -8, "determination": 5}},
		],
	},
	{
		"text": "Tu equipo desciende y llegan ofertas de Primera.",
		"options": [
			{"text": "Me voy, mi sitio es la élite", "effects": {"ambition": 12, "loyalty": -8}},
			{"text": "Me quedo para devolverlos a Primera", "effects": {"loyalty": 14, "determination": 8}},
			{"text": "Escucho ofertas pero sin prisa", "effects": {"ambition": 5}},
		],
	},
	{
		"text": "El preparador físico te manda un plan extra para las vacaciones.",
		"options": [
			{"text": "Lo sigo día por día", "effects": {"professionalism": 14}},
			{"text": "Hago la mitad, también hay que vivir", "effects": {"professionalism": -4, "sociability": 4}},
			{"text": "Improviso según cómo me sienta", "effects": {"professionalism": -8}},
		],
	},
	{
		"text": "Ganas el premio al mejor jugador del mes.",
		"options": [
			{"text": "Se lo dedico a mis compañeros y al staff", "effects": {"sociability": 8, "sportsmanship": 4}},
			{"text": "Es fruto de mi trabajo, me lo he ganado", "effects": {"ambition": 8}},
			{"text": "Digo que lo importante es el equipo y paso página", "effects": {"professionalism": 5, "loyalty": 3}},
		],
	},
	{
		"text": "Ves a un compañero saltarse la dieta y el descanso.",
		"options": [
			{"text": "Se lo comento, nos afecta a todos", "effects": {"professionalism": 8, "sociability": 3}},
			{"text": "Cada uno es responsable de lo suyo", "effects": {"sociability": -4}},
			{"text": "Lo hablo con el capitán o el staff", "effects": {"professionalism": 5, "sportsmanship": 3}},
		],
	},
	{
		"text": "Te llega una oferta del extranjero: idioma y cultura nuevos.",
		"options": [
			{"text": "Acepto, quiero crecer como sea", "effects": {"ambition": 12, "determination": 6}},
			{"text": "Me lo pienso, salir de casa es duro", "effects": {"loyalty": 8, "ambition": -3}},
			{"text": "Solo si el proyecto deportivo es serio", "effects": {"ambition": 5, "professionalism": 4}},
		],
	},
	{
		"text": "Hay que lanzar un penalti decisivo en el minuto 90.",
		"options": [
			{"text": "Lo pido yo, quiero esa responsabilidad", "effects": {"determination": 12, "ambition": 5}},
			{"text": "Que lo tire el especialista del equipo", "effects": {"sociability": 4, "determination": -4}},
			{"text": "Lo tiro si el capitán me lo pide", "effects": {"loyalty": 4, "sociability": 3}},
		],
	},
	{
		"text": "El club organiza una cena benéfica en tu día libre.",
		"options": [
			{"text": "Voy encantado, representar al club es parte del trabajo", "effects": {"sociability": 10, "loyalty": 6}},
			{"text": "Voy un rato por compromiso", "effects": {"sociability": 2}},
			{"text": "Prefiero descansar, lo entenderán", "effects": {"professionalism": 5, "sociability": -6}},
		],
	},
]

## Devuelve QUESTIONS_SHOWN preguntas distintas al azar (o menos si el
## banco fuese más pequeño). Cada elemento es el mismo dict de QUESTIONS.
static func pick_random(count: int = QUESTIONS_SHOWN) -> Array:
	var pool: Array = QUESTIONS.duplicate()
	pool.shuffle()
	var take: int = mini(count, pool.size())
	return pool.slice(0, take)

## answered: Array con la OPCIÓN elegida de cada pregunta
## (el dict {"text":..., "effects":{...}}). Devuelve todos los rasgos de
## TRAITS con valor 0..100, partiendo de BASELINE.
static func score(answered: Array) -> Dictionary:
	var traits: Dictionary = {}
	for trait_key in TRAITS:
		traits[trait_key] = BASELINE
	for option in answered:
		var effects: Dictionary = option.get("effects", {})
		for trait_key in effects:
			var current: int = traits.get(trait_key, BASELINE)
			traits[trait_key] = clampi(current + int(effects[trait_key]), 0, 100)
	return traits
