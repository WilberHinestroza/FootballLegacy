class_name PlayGenerator
extends RefCounted
## Jugadas procedurales. Según tu puesto elige la fase (ataque, creación, defensa o
## arquero), dentro de ella una familia de jugada, y la arma con parámetros al azar:
## banda, altura en el campo, cuántos compañeros y rivales hay y cuánta presión.
## SoccerMatch._setup_play coloca a todos a partir de lo que devuelve generate().

## Reparto de fases por puesto (antes de ajustarlo al dominio real del partido).
const PHASES := {
	"ST": {"ataque": 0.62, "creacion": 0.1, "defensa": 0.28},
	"MF": {"ataque": 0.42, "creacion": 0.33, "defensa": 0.25},
	"DF": {"ataque": 0.18, "creacion": 0.3, "defensa": 0.52},
	"GK": {"arquero": 0.8, "creacion": 0.2},
}

## Familias: fase, mecánica base (SoccerMatch.Moment), peso por puesto, título y ayuda
## ("" = la de la mecánica base).
const FAMILIES := {
	# ---------- ataque ----------
	"elaborado": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 1.5, "MF": 1.6, "DF": 1.0},
		"title": "¡OCASIÓN DE GOL!", "hint": ""},
	"mano_a_mano": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 2.2, "MF": 0.8, "DF": 0.2},
		"title": "¡MANO A MANO!", "hint": "Solo ante el portero: desliza hacia la portería para definir\nDesliza hacia un lado para regatearlo"},
	"superioridad": {"phase": "ataque", "base": "COUNTER", "w": {"ST": 1.6, "MF": 1.6, "DF": 0.8},
		"title": "¡%d CONTRA %d!", "hint": "Sois más: toca a un compañero para soltarla en el momento justo\no desliza a la portería si te dejan pasillo"},
	"frontal": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 1.2, "MF": 1.8, "DF": 0.9},
		"title": "¡BALÓN EN LA FRONTAL!", "hint": "Te cierran rápido: chuta de lejos (desliza fuerte y curvo)\no toca a un compañero que entre al área"},
	"desborde": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 1.3, "MF": 1.3, "DF": 0.7},
		"title": "¡ENCARA AL LATERAL!", "hint": "Uno contra uno por la banda: desliza hacia un lado para irte\ny luego toca a un compañero del área o chuta"},
	"diagonal": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 0.8, "MF": 0.9, "DF": 0.2},
		"title": "¡RECORTA HACIA DENTRO!", "hint": "Pierna cambiada: el lateral te cierra la línea, no el centro\nDesliza en diagonal hacia el área y chuta al palo largo"},
	"balon_largo": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 1.0, "MF": 0.3, "DF": 0.1},
		"title": "¡BALÓN LARGO!", "hint": "El central te la manda en largo: ve a por ella (toca el césped)\ncontrolas de pecho y encaras o defines"},
	"pared": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 1.0, "MF": 1.7, "DF": 0.5},
		"title": "¡TIRA LA PARED!", "hint": "Toca al compañero de al lado y sigue corriendo:\ntócate a ti para pedirla de vuelta y define"},
	"rechace": {"phase": "ataque", "base": "ATTACK", "w": {"ST": 1.6, "MF": 0.7, "DF": 0.6},
		"title": "¡BALÓN SUELTO EN EL ÁREA!", "hint": "Toca el balón para ir a por él antes que el defensa\ny desliza hacia la portería para rematar"},
	"centro": {"phase": "ataque", "base": "CROSS", "w": {"ST": 1.6, "MF": 0.9, "DF": 0.5}, "title": "", "hint": ""},
	"corner": {"phase": "ataque", "base": "CORNER", "w": {"ST": 0.9, "MF": 0.8, "DF": 1.1}, "title": "", "hint": ""},
	"tiro_libre": {"phase": "ataque", "base": "FREE_KICK", "w": {"ST": 0.8, "MF": 1.0, "DF": 0.5}, "title": "", "hint": ""},
	"penalti": {"phase": "ataque", "base": "PENALTY", "w": {"ST": 0.35, "MF": 0.25, "DF": 0.15}, "title": "", "hint": "", "max": 1},
	# ---------- creación ----------
	"salida_presion": {"phase": "creacion", "base": "BUILDUP", "w": {"DF": 2.0, "MF": 1.2, "ST": 0.3},
		"title": "SAL DE LA PRESIÓN", "hint": ""},
	"entre_lineas": {"phase": "creacion", "base": "BUILDUP", "w": {"MF": 2.2, "ST": 1.4, "DF": 0.4},
		"title": "¡RECIBES ENTRE LÍNEAS!", "hint": "Estás de cara: busca al delantero que pica al espacio\n(desliza = pase al hueco · toca = pase al pie)"},
	"cambio_orientacion": {"phase": "creacion", "base": "BUILDUP", "w": {"MF": 1.8, "DF": 1.5, "ST": 0.3},
		"title": "CAMBIA DE ORIENTACIÓN", "hint": "Te cargan una banda: el compañero de la otra está solo\nDesliza largo hacia él o tócalo para el pase"},
	"contra_rapida": {"phase": "creacion", "base": "BUILDUP", "w": {"MF": 1.5, "DF": 1.3, "ST": 1.0},
		"title": "¡ROBO! LANZA LA CONTRA", "hint": "El rival está descolocado: pase al hueco al más adelantado\nantes de que vuelvan (desliza hacia delante)"},
	"saque_arquero": {"phase": "creacion", "base": "BUILDUP", "w": {"GK": 1.0}, "title": "SACA JUGANDO", "hint": ""},
	# ---------- defensa ----------
	"duelo": {"phase": "defensa", "base": "DEFENSE", "w": {"DF": 2.0, "MF": 1.4, "ST": 0.8}, "title": "¡DEFIENDE!", "hint": ""},
	"dos_contra_uno": {"phase": "defensa", "base": "DEFENSE", "w": {"DF": 1.6, "MF": 0.8, "ST": 0.2},
		"title": "¡DOS CONTRA UNO!", "hint": "Estás solo ante dos: no te tires, toca el césped para tapar el pase\ny entra (toca al rival) cuando se acerque"},
	"repliegue": {"phase": "defensa", "base": "DEFENSE", "w": {"MF": 1.8, "ST": 1.4, "DF": 0.9},
		"title": "¡VUELVE! CONTRA DEL RIVAL", "hint": "Te pillaron arriba: toca el césped delante del rival para cortarle\ny barre (desliza hacia él) cuando le alcances"},
	"presion_alta": {"phase": "defensa", "base": "DEFENSE", "w": {"ST": 2.0, "MF": 1.3, "DF": 0.2},
		"title": "¡PRESIÓN ALTA!", "hint": "El rival saca desde atrás: toca al que tiene el balón para encimarle\nRobarla aquí es media ocasión"},
	"centro_rival": {"phase": "defensa", "base": "DEFENSE", "w": {"DF": 1.7, "MF": 0.6, "ST": 0.3},
		"title": "¡CENTRO RIVAL!", "hint": "Va a centrar: toca el césped para ponerte delante de tu marca\nsi el balón te llega alto, lo despejas de cabeza"},
	"corner_contra": {"phase": "defensa", "base": "DEFENSE", "w": {"DF": 1.4, "MF": 0.6, "ST": 0.7},
		"title": "CÓRNER EN CONTRA", "hint": "Defiende el área: toca el césped para ir al primer palo o a tu marca\nsi te llega alto, despeje de cabeza"},
	# ---------- arquero ----------
	"remate_area": {"phase": "arquero", "base": "KEEPER", "w": {"GK": 1.4}, "title": "¡ATAJA!", "hint": ""},
	"mano_a_mano_gk": {"phase": "arquero", "base": "KEEPER", "w": {"GK": 1.3}, "title": "¡MANO A MANO!",
		"hint": "Se te planta solo: toca al rival para salir y achicar\no espera y desliza hacia donde dispare (hacia arriba = alto)"},
	"disparo_lejano": {"phase": "arquero", "base": "KEEPER", "w": {"GK": 1.2}, "title": "¡DISPARO DE LEJOS!",
		"hint": "Va a chutar desde fuera: colócate (toca el césped)\ny desliza hacia el lado del balón cuando salga el tiro"},
	"penalti_contra": {"phase": "arquero", "base": "KEEPER", "w": {"GK": 0.45}, "title": "¡PENALTI EN CONTRA!",
		"hint": "Adivina el lado: cuando chute, desliza hacia donde va\nhacia arriba = estirada alta", "max": 1},
	"tiro_libre_contra": {"phase": "arquero", "base": "KEEPER", "w": {"GK": 0.8}, "title": "TIRO LIBRE EN CONTRA",
		"hint": "Tu barrera tapa un palo: vigila el otro\ndesliza hacia el lado del balón cuando pase la barrera"},
	"centro_gk": {"phase": "arquero", "base": "KEEPER", "w": {"GK": 1.0}, "title": "¡CENTRO AL ÁREA!",
		"hint": "Si el centro cae cerca, toca el balón para salir a por él\nsi rematan, desliza hacia el lado del balón"},
	"corner_gk": {"phase": "arquero", "base": "KEEPER", "w": {"GK": 0.6}, "title": "CÓRNER EN CONTRA",
		"hint": "Mucha gente en tu área: sal si cae cerca (toca el balón)\nsi alguien cabecea, desliza hacia el lado del balón"},
}


## Cómo juega cada puesto fino (Positions.gd): "lane" = su carril (+1 banda derecha,
## -1 izquierda, ±0.5 carril interior, 0 centro; derecha = +Z con el equipo atacando
## a +X) y "w" = cuánto pesa cada familia para ese puesto respecto al de su línea.
## Así un extremo vive de desbordes por SU banda y un central de duelos y centros.
const POSITION_STYLE := {
	"DFC": {"lane": 0.0, "w": {"duelo": 1.4, "centro_rival": 1.5, "corner_contra": 1.4, "salida_presion": 1.3,
		"desborde": 0.2, "frontal": 0.6, "repliegue": 0.6, "diagonal": 0.0}},
	"LD": {"lane": 1.0, "w": {"desborde": 1.8, "cambio_orientacion": 1.4, "centro_rival": 1.3, "dos_contra_uno": 1.3,
		"corner_contra": 0.6, "frontal": 0.5, "diagonal": 0.3}},
	"LI": {"lane": -1.0, "w": {"desborde": 1.8, "cambio_orientacion": 1.4, "centro_rival": 1.3, "dos_contra_uno": 1.3,
		"corner_contra": 0.6, "frontal": 0.5, "diagonal": 0.3}},
	"CAD": {"lane": 1.0, "w": {"desborde": 2.2, "centro": 1.3, "repliegue": 1.4, "contra_rapida": 1.3, "diagonal": 0.5}},
	"CAI": {"lane": -1.0, "w": {"desborde": 2.2, "centro": 1.3, "repliegue": 1.4, "contra_rapida": 1.3, "diagonal": 0.5}},
	"MCD": {"lane": 0.0, "w": {"salida_presion": 1.6, "cambio_orientacion": 1.5, "duelo": 1.4, "repliegue": 1.3,
		"mano_a_mano": 0.3, "desborde": 0.3, "rechace": 0.5, "diagonal": 0.0}},
	"MC": {"lane": 0.0, "w": {"pared": 1.3, "entre_lineas": 1.2, "frontal": 1.2, "diagonal": 0.2}},
	"MD": {"lane": 0.5, "w": {"desborde": 1.2, "cambio_orientacion": 1.3, "pared": 1.2, "diagonal": 0.8}},
	"MI": {"lane": -0.5, "w": {"desborde": 1.2, "cambio_orientacion": 1.3, "pared": 1.2, "diagonal": 0.8}},
	"MCO": {"lane": 0.0, "w": {"entre_lineas": 1.9, "frontal": 1.7, "pared": 1.5, "mano_a_mano": 1.2,
		"duelo": 0.6, "desborde": 0.5, "diagonal": 0.3}},
	"MP": {"lane": 0.0, "w": {"entre_lineas": 1.8, "frontal": 1.6, "pared": 1.6, "mano_a_mano": 1.4,
		"duelo": 0.5, "desborde": 0.4, "diagonal": 0.3}},
	"ED": {"lane": 1.0, "w": {"desborde": 2.4, "contra_rapida": 1.3, "superioridad": 1.2, "frontal": 0.5,
		"entre_lineas": 0.6, "rechace": 0.5, "duelo": 0.6, "diagonal": 1.0}},
	"EI": {"lane": -1.0, "w": {"desborde": 2.4, "contra_rapida": 1.3, "superioridad": 1.2, "frontal": 0.5,
		"entre_lineas": 0.6, "rechace": 0.5, "duelo": 0.6, "diagonal": 1.0}},
	"SD": {"lane": 0.0, "w": {"pared": 1.7, "frontal": 1.4, "entre_lineas": 1.4, "centro": 0.7, "diagonal": 0.6, "balon_largo": 0.9}},
	"DC": {"lane": 0.0, "w": {"rechace": 1.5, "centro": 1.5, "mano_a_mano": 1.3, "pared": 0.8, "desborde": 0.5,
		"diagonal": 0.2, "balon_largo": 1.6}},
}

const PHASE_BY_POSITION := {
	"ED": {"ataque": 1.5, "creacion": 0.7, "defensa": 0.7},
	"EI": {"ataque": 1.5, "creacion": 0.7, "defensa": 0.7},
	"MCO": {"ataque": 1.3, "defensa": 0.7},
	"MP": {"ataque": 1.35, "defensa": 0.65},
	"MCD": {"ataque": 0.55, "creacion": 1.3, "defensa": 1.3},
	"CAD": {"ataque": 1.4, "defensa": 0.85},
	"CAI": {"ataque": 1.4, "defensa": 0.85},
	"SD": {"ataque": 0.9, "creacion": 1.6},
}

## Familias en las que el balón te puede LLEGAR (pase de un compañero al arrancar)
## en vez de empezar ya con él en los pies: así no todas arrancan igual.
const ARRIVE_FAMILIES := {"frontal": 0.4, "desborde": 0.45, "diagonal": 0.5, "pared": 0.3, "mano_a_mano": 0.45}


## ¿Pierna cambiada? Extremo/interior de un lado que le pega con la pierna del otro:
## su jugada natural es recortar hacia dentro, no ir a línea de fondo.
static func inverted(detailed: String, foot: int) -> bool:
	var lane := float((POSITION_STYLE.get(detailed, {}) as Dictionary).get("lane", 0.0))
	if absf(lane) < 0.4:
		return false
	if foot == 2:
		return true # ambidiestro: puede hacer las dos
	# foot: 0 diestro, 1 zurdo. Banda derecha + zurdo o izquierda + diestro.
	return (lane > 0.0 and foot == 1) or (lane < 0.0 and foot == 0)


## Elige la fase: el reparto del puesto, ajustado al dominio del partido (attack_share).
static func pick_phase(role: String, attack_share: float, detailed := "") -> String:
	var w: Dictionary = (PHASES.get(role, PHASES["MF"]) as Dictionary).duplicate()
	# El puesto fino corrige el reparto: el extremo vive arriba, el pivote en la salida
	var pm: Dictionary = PHASE_BY_POSITION.get(detailed, {})
	for ph: String in pm:
		if w.has(ph):
			w[ph] = float(w[ph]) * float(pm[ph])
	if w.has("ataque"):
		w["ataque"] = float(w["ataque"]) * attack_share / 0.55
		w["defensa"] = float(w["defensa"]) * (1.0 - attack_share) / 0.45
	return _weighted(w)


## Una jugada nueva para `role` en `phase`. `counts` = cuántas veces salió cada familia
## (para variar y para los topes, como un penalti por partido); `last` = la anterior.
static func generate(role: String, phase: String, counts: Dictionary, last := "",
		detailed := "", foot := 0) -> Dictionary:
	var style: Dictionary = POSITION_STYLE.get(detailed, {})
	var mults: Dictionary = style.get("w", {})
	var inv := inverted(detailed, foot)
	var options := {}
	for id: String in FAMILIES:
		var f: Dictionary = FAMILIES[id]
		if f.phase != phase or not (f.w as Dictionary).has(role):
			continue
		if f.has("max") and int(counts.get(id, 0)) >= int(f.max):
			continue
		# Lo que ya salió pesa menos: más variedad a lo largo del partido
		var wt: float = float(f.w[role]) / (1.0 + int(counts.get(id, 0)) * 0.8)
		if id == last:
			wt *= 0.15
		wt *= float(mults.get(id, 1.0))
		if id == "diagonal":
			wt *= 2.8 if inv else 0.3 # el recorte es la jugada del de pierna cambiada
		elif id == "desborde" and absf(float(style.get("lane", 0.0))) > 0.4:
			wt *= 0.7 if inv else 1.3 # el de pierna natural, a línea de fondo
		if wt > 0.0:
			options[id] = wt
	if options.is_empty():
		options = {"remate_area": 1.0} if role == "GK" else {"elaborado": 1.0}
	var play := make(_weighted(options))
	_fit_to_position(play, style)
	return play


## La banda y el carril salen de tu puesto (casi siempre la tuya; a veces, la otra
## como un cambio de banda puntual) y a veces el balón te llega de un pase.
static func _fit_to_position(play: Dictionary, style: Dictionary) -> void:
	if style.is_empty():
		return
	var lane := float(style.get("lane", 0.0))
	play.lane = lane
	if absf(lane) > 0.1 and randf() < 0.85:
		play.side = signf(lane)
	var fam := String(play.family)
	if ARRIVE_FAMILIES.has(fam) and randf() < float(ARRIVE_FAMILIES[fam]):
		play.arrive = true


## Arma la familia `id` con sus parámetros al azar.
static func make(id: String) -> Dictionary:
	if not FAMILIES.has(id):
		id = "elaborado"
	var f: Dictionary = FAMILIES[id]
	var play := {
		"family": id,
		"phase": f.phase,
		"base": SoccerMatch.Moment[f.base],
		"title": f.title,
		"hint": f.hint,
		"side": 1.0 if randf() < 0.5 else -1.0, # banda (signo de z)
		"depth": randf(),                        # 0 = más lejos de la portería, 1 = más cerca
		"pressure": randi_range(1, 3),           # rivales encima
		"rival_action": "",                      # qué hace el rival con balón: shoot / cross / free_kick
		"rival_delay": randf_range(0.8, 1.5),
	}
	match id:
		"superioridad":
			var att := randi_range(2, 3)
			play.attackers = att
			play.defenders = att - 1
			play.title = String(f.title) % [att, att - 1]
		"pared":
			play.pressure = randi_range(1, 2)
		"salida_presion":
			if play.pressure == 3:
				play.title = "¡PRESIÓN DE 3 RIVALES!"
		"disparo_lejano":
			play.rival_action = "shoot"
		"penalti_contra":
			play.rival_action = "shoot"
			play.rival_delay = 1.4
		"tiro_libre_contra":
			play.rival_action = "free_kick"
			play.rival_delay = 1.6
		"centro_rival", "centro_gk":
			play.rival_action = "cross"
			play.rival_delay = randf_range(0.9, 1.6)
		"corner_contra", "corner_gk":
			play.rival_action = "cross"
			play.rival_delay = 1.5
	return play


static func _weighted(w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return String(k)
	return String(w.keys()[0])
