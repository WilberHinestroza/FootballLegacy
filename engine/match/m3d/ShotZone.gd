extends RefCounted
## Zona de tiro visible (P1-03).
##
## Funciones puras: reciben la distancia a la portería, la stamina (0..1) y la
## distancia al rival más cercano (metros) y devuelven el radio, en metros, del
## área de portería que el jugador puede cubrir con seguridad. El aro que se
## dibuja en el arco se achica con la distancia, la fatiga y la presión: cuanto
## más pequeño, más precisa tiene que ser la definición.
##
## No toca nodos ni UI, así que se prueba en headless y se reutiliza desde el
## partido 3D.

## Radio máximo: a quemarropa, fresco y sin presión.
const MAX_RADIUS := 1.25
## Radio mínimo: lejos, agotado y con un rival encima.
const MIN_RADIUS := 0.22
## Distancia (m) a la que la zona llega a su mínimo por lejanía.
const MAX_DISTANCE := 40.0
## Hasta esta distancia (m) la zona conserva su radio máximo.
const NEAR_DISTANCE := 10.0
## A partir de esta distancia (m) un rival ya no presiona.
const PRESSURE_RADIUS := 6.0

## Radio del aro en metros. `nearest_rival` puede ser grande (sin rival cerca).
static func radius(dist: float, stamina: float, nearest_rival: float) -> float:
	var far := clampf((dist - NEAR_DISTANCE) / (MAX_DISTANCE - NEAR_DISTANCE), 0.0, 1.0)
	var fit := clampf(stamina, 0.0, 1.0)
	var pressure := clampf(1.0 - nearest_rival / PRESSURE_RADIUS, 0.0, 1.0)
	var r := lerpf(MAX_RADIUS, MIN_RADIUS, far)
	r *= lerpf(0.6, 1.0, fit)
	r *= lerpf(0.5, 1.0, 1.0 - pressure)
	return clampf(r, MIN_RADIUS, MAX_RADIUS)


## 0 = zona mínima (difícil), 1 = zona máxima (cómoda). Sirve para el color.
static func comfort(r: float) -> float:
	return clampf((r - MIN_RADIUS) / (MAX_RADIUS - MIN_RADIUS), 0.0, 1.0)


## Color del aro: verde cuando hay margen, ámbar al complicarse, rojo al límite.
static func color_for(r: float) -> Color:
	return Color(1.0, 0.32, 0.22).lerp(Color(0.25, 1.0, 0.42), comfort(r))


## Asistencia de puntería configurable (P1-04): cuánto se acerca el gesto a la
## portería. "alta" perdona un deslizamiento torcido; "manual" respeta el gesto.
const AIM_ASSIST_BLEND := {"alta": 0.55, "media": 0.28, "manual": 0.0}

static func assist_blend(level: String) -> float:
	return float(AIM_ASSIST_BLEND.get(level, 0.0))


## Mezcla la dirección del gesto con la dirección a la portería. Con "manual"
## devuelve el gesto intacto; con "alta" lo endereza bastante.
static func assist_dir(dir: Vector3, to_goal: Vector3, level: String) -> Vector3:
	var k := assist_blend(level)
	if k <= 0.0:
		return dir
	return dir.lerp(to_goal, k).normalized()

