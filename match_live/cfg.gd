class_name Cfg
extends RefCounted
## Todas las medidas y "perillas" del juego en un solo lugar.
## 1 metro = M píxeles. La cancha va de (0,0) a (FIELD_W, FIELD_H).
## El equipo local (azul, humano) ataca hacia ARRIBA (y = 0).

const M := 12.0

# Cancha (medidas reales FIFA, en metros * M).
const FIELD_W := 68.0 * M
const FIELD_H := 105.0 * M
const MARGIN := 4.0 * M
## Cámara y tamaños en pantalla (solo visual: la física usa metros).
const CAM_ZOOM := 1.35
## Medido en WSC (24-oct): jugador = 0,11 del alto de pantalla en una
## jugada; con 1,15 los nuestros ocupaban 0,175 y la cancha se veía chica.
const PLAYER_SCALE := 0.78
const PLAYER_RADIUS := 0.5 * M   # cuerpo para los choques entre jugadores
## Los arcos van más grandes que los reales (estilo arcade, como en Mini
## Soccer Star): con jugadores de ~40 px un arco real de 7,32 m se veía chico.
const GOAL_SCALE := 1.85
const GOAL_W := 7.32 * M * GOAL_SCALE
## Altura en pantalla: px por unidad de z. Igual a la de los sprites (un
## jugador de ~1,8 m mide ~35 px): con 0,8 una pelota a la altura de la cabeza
## se dibujaba en la cintura y los centros "atravesaban" a los jugadores.
const Z_PROJ := 1.6
## Travesaño casi real (2,5 m): dibujado mide 1,35 veces un jugador, como en
## WSC. El ancho sí queda agrandado (arcade).
const GOAL_H_Z := 2.5 * M
const GOAL_DEPTH := 2.2 * M * GOAL_SCALE
const BOX_W := 40.3 * M
const BOX_H := 16.5 * M
const SMALL_W := 18.3 * M
const SMALL_H := 5.5 * M
const CENTER_R := 9.15 * M
const PENALTY_SPOT := 11.0 * M

# Partido.
const PLAYERS_PER_TEAM := 11
const MATCH_SECONDS := 240.0         # duración real; el reloj muestra 0'..90'
const RESTART_DELAY := 0.9

# Jugadores.
const RUN_SPEED := 6.8 * M
const SPRINT_MULT := 1.25
const DRIBBLE_MULT := 0.9
const ACCEL := 32.0 * M
const CONTROL_RADIUS := 1.0 * M      # distancia para dominar un balón suelto
const TACKLE_RADIUS := 1.4 * M
const SLIDE_SPEED := 11.0 * M
const SLIDE_TIME := 0.38
const STUN_TIME := 0.6

# Balón.
const GRAVITY := 22.0 * M
const ROLL_DECEL := 5.5 * M
const AIR_DRAG := 0.35
const BOUNCE := 0.52
const AIR_DRAG_QUAD := 0.006   # roce del aire que crece con la velocidad
const GRASS_DRAG := 0.05       # el pasto frena más cuanto más rápido rueda
const POST_R := 0.38 * M       # radio palo + balón para los choques
const SPIN_DECAY := 2.2
const PASS_MIN := 9.0 * M
const PASS_MAX := 26.0 * M
const SHOT_MIN := 18.0 * M
const SHOT_MAX := 34.0 * M

# Arquero.
const GK_REACH := 2.1 * M
const GK_DIVE_SPEED := 11.5 * M
const GK_DIVE_REACH := 4.3 * M

## Centro de la portería que defiende un lado (0 = abajo, 1 = arriba).
static func own_goal(side: int) -> Vector2:
	return Vector2(FIELD_W * 0.5, FIELD_H if side == 0 else 0.0)

static func target_goal(side: int) -> Vector2:
	return own_goal(1 - side)

## Hacia dónde ataca un lado (vector unitario en y).
static func attack_dir(side: int) -> Vector2:
	return Vector2.UP if side == 0 else Vector2.DOWN

## Convierte coordenadas de formación (x 0..1 de izquierda a derecha según
## quien ataca, d 0..1 desde la propia portería) a píxeles de cancha.
static func form_to_world(side: int, x: float, d: float) -> Vector2:
	if side == 0:
		return Vector2(FIELD_W * x, FIELD_H * (1.0 - d))
	return Vector2(FIELD_W * (1.0 - x), FIELD_H * d)

## Progreso (0..1) de un punto hacia la portería rival para un lado.
static func depth_of(side: int, p: Vector2) -> float:
	return 1.0 - p.y / FIELD_H if side == 0 else p.y / FIELD_H
