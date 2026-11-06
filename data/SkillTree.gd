extends RefCounted
class_name SkillTree

## Árbol de HABILIDADES (schema v33, 9-oct — Wilber: "mejorar todo el
## sistema RPG"). Por posición amplia hay 3 ramas de 4 habilidades, más la
## rama común "Mentalidad". Se compran con puntos de habilidad (1 por nivel
## de ProgressionEngine) y en orden dentro de la rama.
##
## Cada habilidad suma a un EFECTO con nombre; quién lo usa:
##   w_finish / w_playmaking / w_dribble / w_defense / w_gk / w_aerial /
##   w_set_piece / w_penalty → ancho de la zona verde de la barra para esas
##       acciones (DecisionResolver.rpg_meter_mods)
##   bar_slow  → barra más lenta en TODAS las acciones (idem)
##   aim       → puntería del remate en la cancha 2D (pitch_shot_aim_score)
##   pass_aim  → puntería del pase en la cancha 2D (pitch_pass_aim_score)
##   fatigue   → menos desgaste físico por partido (PlayerDevelopment)
##   xp        → más XP de atributos (PlayerDevelopment.grant_attribute_xp)
## Los números de balance viven ACÁ (valores) y en DecisionResolver (cómo
## se aplican) — ninguna pantalla los recalcula.

const COST := [1, 2, 3, 4, 5, 6, 7]   # costo por escalón dentro de la rama

## ÁRBOL EXTENDIDO (10-oct, Wilber: "añade más, un árbol más extenso que se
## complemente con la evolución del personaje de un futbolista real").
## - Cada rama de posición suma 2 escalones (5.º y 6.º) → EXTRA.
## - Tres ramas comunes nuevas: Físico, Liderazgo y CARRERA. La de Carrera
##   no se compra solo con puntos: cada escalón pide un HITO real de tu
##   carrera ("req": [qué, cuánto, texto]) — debutar, afianzarte, llegar a
##   la selección, ganar un título, ser veterano — y cuesta 1 punto.
## Sin cambio de esquema: `player.skills` sigue siendo la lista de ids.
const EXTRA := {
	"st_def": [
		{"id": "st_def5", "name": "Definición de crack", "desc": "Apuntar el remate pide 8% menos", "fx": {"aim": 0.08}},
		{"id": "st_def6", "name": "Goleador histórico", "desc": "+6% remates y barras 2% más lentas", "fx": {"w_finish": 0.06, "bar_slow": 0.02}},
	],
	"st_reg": [
		{"id": "st_reg5", "name": "Enganche", "desc": "+5% gambeta y +4% pases", "fx": {"w_dribble": 0.05, "w_playmaking": 0.04}},
		{"id": "st_reg6", "name": "Imparable", "desc": "+6% gambeta y 4% menos desgaste", "fx": {"w_dribble": 0.06, "fatigue": 0.04}},
	],
	"st_piv": [
		{"id": "st_piv5", "name": "Aguantar la marca", "desc": "+5% juego aéreo y +4% al defender", "fx": {"w_aerial": 0.05, "w_defense": 0.04}},
		{"id": "st_piv6", "name": "Nueve total", "desc": "+5% remates y +5% juego aéreo", "fx": {"w_finish": 0.05, "w_aerial": 0.05}},
	],
	"mf_cre": [
		{"id": "mf_cre5", "name": "Último pase", "desc": "Apuntar el pase pide 8% menos", "fx": {"pass_aim": 0.08}},
		{"id": "mf_cre6", "name": "Maestro", "desc": "+6% pases y barras 2% más lentas", "fx": {"w_playmaking": 0.06, "bar_slow": 0.02}},
	],
	"mf_box": [
		{"id": "mf_box5", "name": "Ida y vuelta", "desc": "+5% al defender y +4% gambeta", "fx": {"w_defense": 0.05, "w_dribble": 0.04}},
		{"id": "mf_box6", "name": "Todocampista", "desc": "6% menos desgaste y +4% remates", "fx": {"fatigue": 0.06, "w_finish": 0.04}},
	],
	"mf_org": [
		{"id": "mf_org5", "name": "Pegada", "desc": "+8% tiros libres y apuntar pide 5% menos", "fx": {"w_set_piece": 0.08, "aim": 0.05}},
		{"id": "mf_org6", "name": "Cerebro", "desc": "Barras 4% más lentas y pase 5% más fácil de apuntar", "fx": {"bar_slow": 0.04, "pass_aim": 0.05}},
	],
	"df_muro": [
		{"id": "df_muro5", "name": "Lectura de juego", "desc": "+5% al defender y barras 2% más lentas", "fx": {"w_defense": 0.05, "bar_slow": 0.02}},
		{"id": "df_muro6", "name": "Mariscal", "desc": "+6% al defender y +5% juego aéreo", "fx": {"w_defense": 0.06, "w_aerial": 0.05}},
	],
	"df_lib": [
		{"id": "df_lib5", "name": "Conducción", "desc": "Zona verde +6% al gambetear", "fx": {"w_dribble": 0.06}},
		{"id": "df_lib6", "name": "Zaguero moderno", "desc": "+6% pases y apuntar el pase pide 6% menos", "fx": {"w_playmaking": 0.06, "pass_aim": 0.06}},
	],
	"df_inc": [
		{"id": "df_inc5", "name": "Recuperación", "desc": "6% menos desgaste por partido", "fx": {"fatigue": 0.06}},
		{"id": "df_inc6", "name": "Gladiador", "desc": "+5% al defender y 6% menos desgaste", "fx": {"w_defense": 0.05, "fatigue": 0.06}},
	],
	"gk_ref": [
		{"id": "gk_ref5", "name": "Mano cambiada", "desc": "Zona verde +6% en atajadas", "fx": {"w_gk": 0.06}},
		{"id": "gk_ref6", "name": "Muralla", "desc": "+6% atajadas y barras 2% más lentas", "fx": {"w_gk": 0.06, "bar_slow": 0.02}},
	],
	"gk_aer": [
		{"id": "gk_aer5", "name": "Puños", "desc": "Zona verde +6% en el juego aéreo", "fx": {"w_aerial": 0.06}},
		{"id": "gk_aer6", "name": "Mariscal del área", "desc": "+5% al defender y +4% atajadas", "fx": {"w_defense": 0.05, "w_gk": 0.04}},
	],
	"gk_dis": [
		{"id": "gk_dis5", "name": "Contraataque", "desc": "Apuntar el pase pide 6% menos", "fx": {"pass_aim": 0.06}},
		{"id": "gk_dis6", "name": "Primer atacante", "desc": "+6% pases y barras 2% más lentas", "fx": {"w_playmaking": 0.06, "bar_slow": 0.02}},
	],
}

## Ramas comunes nuevas.
const COMMON := [
	{"id": "fis", "name": "Físico", "color": "#30a46c", "nodes": [
		{"id": "fis1", "name": "Pretemporada", "desc": "5% menos desgaste por partido", "fx": {"fatigue": 0.05}},
		{"id": "fis2", "name": "Explosión", "desc": "Zona verde +4% al gambetear", "fx": {"w_dribble": 0.04}},
		{"id": "fis3", "name": "Potencia", "desc": "+4% juego aéreo y +4% al defender", "fx": {"w_aerial": 0.04, "w_defense": 0.04}},
		{"id": "fis4", "name": "Blindado", "desc": "8% menos desgaste por partido", "fx": {"fatigue": 0.08}},
		{"id": "fis5", "name": "Atleta total", "desc": "8% menos desgaste y barras 2% más lentas", "fx": {"fatigue": 0.08, "bar_slow": 0.02}},
	]},
	{"id": "lid", "name": "Liderazgo", "color": "#0090ff", "nodes": [
		{"id": "lid1", "name": "Voz en el vestuario", "desc": "+4% XP de atributos", "fx": {"xp": 0.04}},
		{"id": "lid2", "name": "Ejemplo", "desc": "Todas las barras 3% más lentas", "fx": {"bar_slow": 0.03}},
		{"id": "lid3", "name": "Capitán", "desc": "+5% pases y +5% al defender", "fx": {"w_playmaking": 0.05, "w_defense": 0.05}},
		{"id": "lid4", "name": "Partidos grandes", "desc": "+6% penales y tiros libres", "fx": {"w_penalty": 0.06, "w_set_piece": 0.06}},
		{"id": "lid5", "name": "Ídolo", "desc": "+8% XP de atributos", "fx": {"xp": 0.08}},
	]},
	{"id": "car", "name": "Carrera", "color": "#e5c07b", "nodes": [
		{"id": "car1", "name": "Debut profesional", "desc": "+3% XP de atributos", "cost": 1, "req": ["matches", 1, "Jugá tu primer partido"], "fx": {"xp": 0.03}},
		{"id": "car2", "name": "Titular", "desc": "Todas las barras 2% más lentas", "cost": 1, "req": ["matches", 30, "Jugá 30 partidos"], "fx": {"bar_slow": 0.02}},
		{"id": "car3", "name": "Referente", "desc": "5% menos desgaste por partido", "cost": 1, "req": ["matches", 100, "Jugá 100 partidos"], "fx": {"fatigue": 0.05}},
		{"id": "car4", "name": "Internacional", "desc": "+5% XP y barras 2% más lentas", "cost": 1, "req": ["caps", 1, "Debutá en la selección"], "fx": {"xp": 0.05, "bar_slow": 0.02}},
		{"id": "car5", "name": "Campeón", "desc": "+8% penales y +6% tiros libres", "cost": 1, "req": ["trophies", 1, "Ganá un título"], "fx": {"w_penalty": 0.08, "w_set_piece": 0.06}},
		{"id": "car6", "name": "Veterano", "desc": "+6% XP y 6% menos desgaste (la experiencia)", "cost": 1, "req": ["age", 30, "Llegá a los 30 años"], "fx": {"xp": 0.06, "fatigue": 0.06}},
		{"id": "car7", "name": "Leyenda", "desc": "Todas las barras 4% más lentas", "cost": 1, "req": ["matches", 400, "Jugá 400 partidos"], "fx": {"bar_slow": 0.04}},
	]},
]

## branch: {id, name, color, nodes: [{id, name, desc, fx: {efecto: valor}}]}
const BRANCHES := {
	"ST": [
		{"id": "st_def", "name": "Definidor", "color": "#e5484d", "nodes": [
			{"id": "st_def1", "name": "Sangre fría", "desc": "Zona verde +6% al rematar", "fx": {"w_finish": 0.06}},
			{"id": "st_def2", "name": "Ojo de halcón", "desc": "Apuntar el remate pide 12% menos", "fx": {"aim": 0.12}},
			{"id": "st_def3", "name": "Killer del área", "desc": "Zona verde +8% al rematar", "fx": {"w_finish": 0.08}},
			{"id": "st_def4", "name": "Leyenda del gol", "desc": "+10% remates y penales", "fx": {"w_finish": 0.10, "w_penalty": 0.10}},
		]},
		{"id": "st_reg", "name": "Regateador", "color": "#f5a524", "nodes": [
			{"id": "st_reg1", "name": "Pies rápidos", "desc": "Zona verde +6% al gambetear", "fx": {"w_dribble": 0.06}},
			{"id": "st_reg2", "name": "Cintura", "desc": "Zona verde +8% al gambetear", "fx": {"w_dribble": 0.08}},
			{"id": "st_reg3", "name": "Tiempo de sobra", "desc": "Todas las barras 4% más lentas", "fx": {"bar_slow": 0.04}},
			{"id": "st_reg4", "name": "Crack", "desc": "Zona verde +10% al gambetear", "fx": {"w_dribble": 0.10}},
		]},
		{"id": "st_piv", "name": "Pivote", "color": "#46a758", "nodes": [
			{"id": "st_piv1", "name": "Cabezazo", "desc": "Zona verde +8% en el juego aéreo", "fx": {"w_aerial": 0.08}},
			{"id": "st_piv2", "name": "Tanque", "desc": "8% menos desgaste por partido", "fx": {"fatigue": 0.08}},
			{"id": "st_piv3", "name": "Torre", "desc": "Zona verde +10% en el juego aéreo", "fx": {"w_aerial": 0.10}},
			{"id": "st_piv4", "name": "Descarga", "desc": "Zona verde +8% en pases", "fx": {"w_playmaking": 0.08}},
		]},
	],
	"MF": [
		{"id": "mf_cre", "name": "Creador", "color": "#3e63dd", "nodes": [
			{"id": "mf_cre1", "name": "Visión", "desc": "Zona verde +6% en pases", "fx": {"w_playmaking": 0.06}},
			{"id": "mf_cre2", "name": "Pase al hueco", "desc": "Apuntar el pase pide 12% menos", "fx": {"pass_aim": 0.12}},
			{"id": "mf_cre3", "name": "Batuta", "desc": "Zona verde +8% en pases", "fx": {"w_playmaking": 0.08}},
			{"id": "mf_cre4", "name": "Genio", "desc": "Zona verde +10% en pases", "fx": {"w_playmaking": 0.10}},
		]},
		{"id": "mf_box", "name": "Box to box", "color": "#46a758", "nodes": [
			{"id": "mf_box1", "name": "Pulmón", "desc": "10% menos desgaste por partido", "fx": {"fatigue": 0.10}},
			{"id": "mf_box2", "name": "Recuperador", "desc": "Zona verde +6% al defender", "fx": {"w_defense": 0.06}},
			{"id": "mf_box3", "name": "Llegada", "desc": "Zona verde +6% al rematar", "fx": {"w_finish": 0.06}},
			{"id": "mf_box4", "name": "Motor", "desc": "12% menos desgaste por partido", "fx": {"fatigue": 0.12}},
		]},
		{"id": "mf_org", "name": "Organizador", "color": "#8e4ec6", "nodes": [
			{"id": "mf_org1", "name": "Pausa", "desc": "Todas las barras 4% más lentas", "fx": {"bar_slow": 0.04}},
			{"id": "mf_org2", "name": "Cambio de frente", "desc": "Zona verde +6% en pases", "fx": {"w_playmaking": 0.06}},
			{"id": "mf_org3", "name": "Pelota parada", "desc": "Zona verde +10% en tiros libres", "fx": {"w_set_piece": 0.10}},
			{"id": "mf_org4", "name": "Director", "desc": "Todas las barras 6% más lentas", "fx": {"bar_slow": 0.06}},
		]},
	],
	"DF": [
		{"id": "df_muro", "name": "Muro", "color": "#3e63dd", "nodes": [
			{"id": "df_muro1", "name": "Anticipo", "desc": "Zona verde +6% al defender", "fx": {"w_defense": 0.06}},
			{"id": "df_muro2", "name": "Barrida limpia", "desc": "Zona verde +8% al defender", "fx": {"w_defense": 0.08}},
			{"id": "df_muro3", "name": "Juego aéreo", "desc": "Zona verde +8% en el juego aéreo", "fx": {"w_aerial": 0.08}},
			{"id": "df_muro4", "name": "Infranqueable", "desc": "Zona verde +10% al defender", "fx": {"w_defense": 0.10}},
		]},
		{"id": "df_lib", "name": "Líbero", "color": "#f5a524", "nodes": [
			{"id": "df_lib1", "name": "Salida limpia", "desc": "Zona verde +6% en pases", "fx": {"w_playmaking": 0.06}},
			{"id": "df_lib2", "name": "Pase largo", "desc": "Apuntar el pase pide 12% menos", "fx": {"pass_aim": 0.12}},
			{"id": "df_lib3", "name": "Calma", "desc": "Todas las barras 4% más lentas", "fx": {"bar_slow": 0.04}},
			{"id": "df_lib4", "name": "Comandante", "desc": "Zona verde +8% en pases", "fx": {"w_playmaking": 0.08}},
		]},
		{"id": "df_inc", "name": "Incansable", "color": "#46a758", "nodes": [
			{"id": "df_inc1", "name": "Resistencia", "desc": "10% menos desgaste por partido", "fx": {"fatigue": 0.10}},
			{"id": "df_inc2", "name": "Marca pegajosa", "desc": "Zona verde +6% al defender", "fx": {"w_defense": 0.06}},
			{"id": "df_inc3", "name": "Último hombre", "desc": "Zona verde +8% al defender", "fx": {"w_defense": 0.08}},
			{"id": "df_inc4", "name": "De hierro", "desc": "12% menos desgaste por partido", "fx": {"fatigue": 0.12}},
		]},
	],
	"GK": [
		{"id": "gk_ref", "name": "Reflejos", "color": "#f5a524", "nodes": [
			{"id": "gk_ref1", "name": "Manos rápidas", "desc": "Zona verde +8% en atajadas", "fx": {"w_gk": 0.08}},
			{"id": "gk_ref2", "name": "Felino", "desc": "Zona verde +10% en atajadas", "fx": {"w_gk": 0.10}},
			{"id": "gk_ref3", "name": "Lectura", "desc": "Todas las barras 5% más lentas", "fx": {"bar_slow": 0.05}},
			{"id": "gk_ref4", "name": "San Arquero", "desc": "+12% atajadas y penales", "fx": {"w_gk": 0.12, "w_penalty": 0.12}},
		]},
		{"id": "gk_aer", "name": "Dominio del área", "color": "#3e63dd", "nodes": [
			{"id": "gk_aer1", "name": "Salida por arriba", "desc": "Zona verde +8% en el juego aéreo", "fx": {"w_aerial": 0.08}},
			{"id": "gk_aer2", "name": "Achique", "desc": "Zona verde +8% al defender", "fx": {"w_defense": 0.08}},
			{"id": "gk_aer3", "name": "Voz de mando", "desc": "Zona verde +6% en atajadas", "fx": {"w_gk": 0.06}},
			{"id": "gk_aer4", "name": "Dueño del área", "desc": "Zona verde +10% al defender", "fx": {"w_defense": 0.10}},
		]},
		{"id": "gk_dis", "name": "Distribuidor", "color": "#46a758", "nodes": [
			{"id": "gk_dis1", "name": "Saque largo", "desc": "Zona verde +8% en pases", "fx": {"w_playmaking": 0.08}},
			{"id": "gk_dis2", "name": "Pies de jugador", "desc": "Apuntar el pase pide 12% menos", "fx": {"pass_aim": 0.12}},
			{"id": "gk_dis3", "name": "Paciencia", "desc": "Todas las barras 4% más lentas", "fx": {"bar_slow": 0.04}},
			{"id": "gk_dis4", "name": "Arquero-líbero", "desc": "Zona verde +10% en pases", "fx": {"w_playmaking": 0.10}},
		]},
	],
}

## Rama común a todas las posiciones.
const MENTAL := {"id": "men", "name": "Mentalidad", "color": "#d6409f", "nodes": [
	{"id": "men1", "name": "Profesional", "desc": "+5% XP de atributos", "fx": {"xp": 0.05}},
	{"id": "men2", "name": "Concentración", "desc": "Todas las barras 3% más lentas", "fx": {"bar_slow": 0.03}},
	{"id": "men3", "name": "Hambre", "desc": "+8% XP de atributos", "fx": {"xp": 0.08}},
	{"id": "men4", "name": "Mentalidad ganadora", "desc": "+10% XP y 5% menos desgaste", "fx": {"xp": 0.10, "fatigue": 0.05}},
]}

## Ramas visibles para esta posición amplia (las 3 propias + Mentalidad).
static func branches_for(position: String) -> Array:
	var out: Array = []
	for b in (BRANCHES.get(position, BRANCHES["ST"]) as Array):
		out.append(_full(b))
	out.append(MENTAL)
	for c in COMMON:
		out.append(c)
	return out

## La rama con sus escalones extra (5.º y 6.º).
static func _full(b: Dictionary) -> Dictionary:
	if not EXTRA.has(String(b["id"])):
		return b
	var d: Dictionary = b.duplicate()
	d["nodes"] = (b["nodes"] as Array) + (EXTRA[String(b["id"])] as Array)
	return d

static func _all_nodes() -> Array:
	var out: Array = []
	for pos in BRANCHES:
		for b0 in BRANCHES[pos]:
			var b: Dictionary = _full(b0)
			for i in range((b["nodes"] as Array).size()):
				out.append([b, i])
	for i in range((MENTAL["nodes"] as Array).size()):
		out.append([MENTAL, i])
	for c in COMMON:
		for i in range((c["nodes"] as Array).size()):
			out.append([c, i])
	return out

## Hito de carrera que pide un escalón: [] si no pide nada, o
## [cumplido, valor actual, valor pedido, texto].
static func requirement(player: PlayerData, skill_id: String) -> Array:
	var f: Array = find(skill_id)
	if f.is_empty():
		return []
	var req: Array = (f[0]["nodes"][f[1]] as Dictionary).get("req", [])
	if req.is_empty():
		return []
	var have: int = CareerRpgEngine.value_of(player, String(req[0]))
	return [have >= int(req[1]), have, int(req[1]), String(req[2])]

## [rama, índice] de un id de habilidad ([] si no existe).
static func find(skill_id: String) -> Array:
	for pair in _all_nodes():
		if String(pair[0]["nodes"][pair[1]]["id"]) == skill_id:
			return pair
	return []

static func cost_of(skill_id: String) -> int:
	var f: Array = find(skill_id)
	if f.is_empty():
		return 99
	return int((f[0]["nodes"][f[1]] as Dictionary).get("cost", COST[mini(int(f[1]), COST.size() - 1)]))

## Se puede comprar si: existe, es de tu posición (o Mentalidad), no la
## tenés, la anterior de la rama sí, y te alcanzan los puntos.
static func can_unlock(player: PlayerData, skill_id: String) -> bool:
	var f: Array = find(skill_id)
	if f.is_empty() or player.skills.has(skill_id):
		return false
	var branch: Dictionary = f[0]
	var visible: bool = false
	for b in branches_for(player.position):
		if String(b["id"]) == String(branch["id"]):
			visible = true
	if not visible:
		return false
	var idx: int = int(f[1])
	if idx > 0 and not player.skills.has(String(branch["nodes"][idx - 1]["id"])):
		return false
	var rq: Array = requirement(player, skill_id)
	if not rq.is_empty() and not bool(rq[0]):
		return false
	return player.skill_points >= cost_of(skill_id)

static func unlock(player: PlayerData, skill_id: String) -> bool:
	if not can_unlock(player, skill_id):
		return false
	player.skill_points -= cost_of(skill_id)
	player.skills.append(skill_id)
	return true

## Suma de un efecto entre las habilidades desbloqueadas. Las habilidades
## de OTRA posición (si cambiaste de puesto) no cuentan.
static func total(player: PlayerData, effect: String) -> float:
	if player == null or player.skills.is_empty():
		return 0.0
	var allowed: Dictionary = {}
	for b in branches_for(player.position):
		allowed[String(b["id"])] = true
	var v: float = 0.0
	for sid in player.skills:
		var f: Array = find(String(sid))
		if f.is_empty() or not allowed.has(String(f[0]["id"])):
			continue
		v += float((f[0]["nodes"][f[1]]["fx"] as Dictionary).get(effect, 0.0))
	return v
