extends RefCounted
class_name ShopEngine

## Tienda de consumibles — pedido explícito (porte de Football Legacy):
## "cuida tu cuerpo entre partidos". Toda la matemática de precio/efecto
## vive acá, un solo lugar (mismo criterio que SponsorEngine/
## WageOfferEngine/ContractEngine). Se paga con PlayerData.balance, se
## guarda al momento (sin "carrito", igual que LifestyleEngine).
##
## Unidad: MILES DE EURO (igual que CurrencyFormat / ContractEngine).
##
## PRECIO DINÁMICO (12-sep, auditoría de economía a pedido de Wilber:
## "qué más hay que pulir, economía..."): antes eran precios FIJOS
## (8-350) — trivial frente al ingreso SEMANAL real de un jugador
## (ContractEngine.weekly_income, sueldo/52), que arranca en ~1,7 (rookie,
## MIN_WAGE=90/temporada) y sube con el nivel/reputación. Un titular
## decente (sueldo 2000-11000/temporada → 38-211/semana) pagaba MENOS DE
## UN DÍA de sueldo por CUALQUIER cosa de la tienda — comprar dejaba de
## ser una decisión económica. Ahora `price_for()` cobra una FRACCIÓN del
## ingreso semanal actual (con piso mínimo para que nunca sea gratis ni
## negativo para un rookie recién arrancado) — la tienda escala con vos
## en vez de quedarse fija.
## `kind`:
##   "instant" — "Usar" aplica el efecto ya y descuenta 1.
##   "arm"     — "Activar" arma un efecto de un solo uso en
##               PlayerData.active_effects; se consume cuando toca (partido
##               siguiente / próximo entrenamiento) y descuenta 1.
##   "halftime"— solo se usa desde la pantalla de entretiempo del partido
##               (ver MatchHalftime), no desde la Tienda.

const CATALOG := [
	{
		"id": "medkit", "name": "Botiquín de recuperación", "kind": "instant",
		"desc": "Si estás lesionado, recorta 3 días de recuperación al usarlo.",
		"tag": "-3 días", "icon": "res://assets/items/medkit.png", "color_key": "RED",
	},
	{
		"id": "energy_drink", "name": "Bebida energizante", "kind": "halftime",
		"desc": "Se usa en el entretiempo del partido: recuperás energía para la segunda mitad.",
		"tag": "-60% fatiga 2ª parte", "icon": "res://assets/items/energy_drink.png", "color_key": "GOLD",
	},
	{
		"id": "bandage", "name": "Vendaje preventivo", "kind": "arm",
		"desc": "Se activa para tu próximo partido: baja el riesgo de lesión ese partido.",
		"tag": "-60% riesgo, 1 partido", "icon": "res://assets/items/bandage.png", "color_key": "BLUE",
	},
	{
		"id": "training_camp", "name": "Campamento de alto rendimiento", "kind": "instant",
		"desc": "Una semana de entrenamiento de élite. Mejora de inmediato 3 atributos al azar.",
		"tag": "+1 en 3 atributos", "icon": "res://assets/items/training_camp.png", "color_key": "PURPLE",
	},
	{
		"id": "prematch_supp", "name": "Suplemento pre-partido", "kind": "arm",
		"desc": "Nutrición y enfoque de élite para tu próximo partido: te sentís más agudo.",
		"tag": "+5 a tus acciones, 1 partido", "icon": "res://assets/items/prematch_supp.png", "color_key": "GREEN",
	},
	{
		"id": "focus_supp", "name": "Suplemento de concentración", "kind": "arm",
		"desc": "Aprovechás muchísimo mejor tu próximo entrenamiento.",
		"tag": "progreso asegurado, 1 entreno", "icon": "res://assets/items/focus_supp.png", "color_key": "PURPLE",
	},
]

## Fracción del ingreso SEMANAL actual (ContractEngine.weekly_income) que
## cuesta cada item, y un piso absoluto (miles de EUR) para que nunca sea
## gratis ni negativo. `training_camp` bajó de precio (Parte 93, a pedido
## de Wilber): el motivo original de cobrarlo carísimo (8 semanas de
## sueldo) era que sumaba overall DIRECTO sin relación real con los
## atributos que se veían en pantalla — con el fix de "media = cálculo de
## los 6 atributos visibles" (PlayerDevelopment.compute_overall) eso ya no
## existe: el campamento sube 3 atributos como cualquier otro entreno, la
## media SIGUE esos mismos atributos, y el tope real de fondo (potential)
## no se puede cruzar. Ya no hace falta que el precio por sí solo frene el
## abuso — ahora es un gasto de rutina, no "la gran compra".
const PRICE_WEEKLY_FRACTION := {
	"energy_drink": 0.06, "medkit": 0.22, "bandage": 0.16,
	"prematch_supp": 0.20, "focus_supp": 0.28, "training_camp": 1.4,
}
const PRICE_FLOOR := {
	"energy_drink": 2, "medkit": 6, "bandage": 5,
	"prematch_supp": 6, "focus_supp": 8, "training_camp": 80,
}

## Precio de `id` PARA ESTE jugador ahora mismo — escala con su ingreso
## semanal actual, nunca un número fijo (ver cabecera del archivo).
static func price_for(player: PlayerData, id: String) -> int:
	var weekly: float = float(ContractEngine.weekly_income(player.wage if player != null else 0))
	var frac: float = float(PRICE_WEEKLY_FRACTION.get(id, 0.15))
	var floor_p: int = int(PRICE_FLOOR.get(id, 5))
	return maxi(floor_p, int(round(weekly * frac)))

const BANDAGE_RISK_FACTOR := 0.4        # multiplica la probabilidad de lesión del partido
const PREMATCH_ATTR_BONUS := 5          # bonus plano a los atributos del usuario EN SUS acciones, 1 partido
const CAMP_ATTRS := 3
const ENERGY_DRINK_RELIEF := 0.6        # fracción de la fatiga de 2ª parte que anula (ver MatchEngine.set_fatigue_relief)

## El campamento da +1 GARANTIZADO a 3 atributos, sin pasar por partidos ni
## entrenamiento (el overall solo sigue a esos atributos, igual que
## cualquier otro progreso — ver PlayerDevelopment.sync_overall). El tope
## bajo original (2/temporada) frenaba llegar al potencial "de una
## sentada" cuando el overall se acreditaba aparte del atributo real; ya
## no aplica ese riesgo, así que Wilber pidió subirlo a un uso mucho más
## regular (Parte 93: "ya no es necesario que sean tan caros"). `season`
## no se versiona, la clave nace en 0 con cada temporada nueva
## (SeasonCalendar.build_season arma el dict de cero).
const TRAINING_CAMP_SEASON_LIMIT := 12

static func item_by_id(id: String) -> Dictionary:
	for it in CATALOG:
		if it["id"] == id:
			return it
	return {}

static func training_camps_left(season: Dictionary) -> int:
	return maxi(TRAINING_CAMP_SEASON_LIMIT - int(season.get("training_camp_bought_season", 0)), 0)

## BUG real reportado por Wilber (Parte 88, "con 1 millón me compro 4
## campamentos y se rompería el juego"): el tope de 2/temporada de arriba
## solo frena la COMPRA — nunca el USO. `player.consumables` no se
## resetea entre temporadas, así que comprar 2 en la temporada A sin
## usarlos + 2 más en la B deja 4 en el inventario, y use() no tenía
## ningún tope propio — se podían activar los 4 de una sentada (8
## atributos +1 garantizados de golpe). El tope de verdad tiene que
## estar en el EFECTO (usarlo), no en la transacción de comprarlo.
static func training_camp_uses_left(season: Dictionary) -> int:
	return maxi(TRAINING_CAMP_SEASON_LIMIT - int(season.get("training_camp_used_season", 0)), 0)

## Compra: descuenta balance y suma 1 al inventario. false si no alcanza
## (o si es el campamento y ya se agotó el cupo de la temporada). Si
## `season` no es {}, quien llama debe guardarla después (SaveManager.
## save_season) — acá solo se mutan las claves relevantes.
static func buy(player: PlayerData, id: String, season: Dictionary = {}) -> bool:
	var it: Dictionary = item_by_id(id)
	if it.is_empty():
		return false
	var price: int = price_for(player, id)
	if player.balance < price:
		return false
	if id == "training_camp" and training_camps_left(season) <= 0:
		return false
	player.balance -= price
	player.consumables[id] = int(player.consumables.get(id, 0)) + 1
	if id == "training_camp":
		season["training_camp_bought_season"] = int(season.get("training_camp_bought_season", 0)) + 1
	return true

## Usa/activa un consumible del inventario. `season`: hace falta para el
## tope de USO del campamento de alto rendimiento (ver
## training_camp_uses_left) — quien llama debe guardarla después
## (SaveManager.save_season) si el uso fue "training_camp" y salió ok.
## Devuelve {"ok": bool, "message": String} para feedback en la UI.
static func use(player: PlayerData, id: String, rng: RandomNumberGenerator, season: Dictionary = {}) -> Dictionary:
	if int(player.consumables.get(id, 0)) <= 0:
		return {"ok": false, "message": "No tenés ese consumible."}
	var it: Dictionary = item_by_id(id)
	if it.is_empty():
		return {"ok": false, "message": "Consumible desconocido."}

	match id:
		"medkit":
			if player.injury_days_remaining <= 0:
				return {"ok": false, "message": "No estás lesionado ahora mismo."}
			player.injury_days_remaining = maxi(player.injury_days_remaining - 3, 0)
			_consume(player, id)
			return {"ok": true, "message": "Recuperación acelerada: -3 días."}
		"training_camp":
			if training_camp_uses_left(season) <= 0:
				return {"ok": false, "message": "Ya usaste tu cupo de campamentos esta temporada (aunque tengas más comprados, quedan para la próxima)."}
			var picks: Array = _pick_attrs(CAMP_ATTRS, rng)
			for attr_name in picks:
				player.set(attr_name, clampi(int(player.get(attr_name)) + 1, 20, 99))
			PlayerDevelopment.bank_overall_progress(player, picks.size())
			_consume(player, id)
			season["training_camp_used_season"] = int(season.get("training_camp_used_season", 0)) + 1
			return {"ok": true, "message": "Mejora inmediata: %s +1." % ", ".join(picks)}
		"bandage":
			player.active_effects["injury_shield_matches"] = 1
			_consume(player, id)
			return {"ok": true, "message": "Vendaje listo para tu próximo partido."}
		"prematch_supp":
			player.active_effects["match_boost_matches"] = 1
			_consume(player, id)
			return {"ok": true, "message": "Suplemento activo para tu próximo partido."}
		"focus_supp":
			player.active_effects["training_boost"] = true
			_consume(player, id)
			return {"ok": true, "message": "Concentración lista para tu próximo entrenamiento."}
		"energy_drink":
			return {"ok": false, "message": "La bebida energizante se usa en el entretiempo del partido, no acá."}
		_:
			return {"ok": false, "message": "Ese consumible no se puede usar así."}

## Uso de la "Bebida energizante" (kind "halftime") DESDE la pantalla de
## entretiempo — el único consumible que no se usa ni desde la Tienda ni se
## arma en active_effects. Consume 1 y devuelve el alivio de fatiga que la
## escena pasa a MatchEngine.set_fatigue_relief(). La persistencia la guarda
## la escena en el acto (uso inmediato, mismo criterio que LifestyleEngine).
static func use_halftime(player: PlayerData) -> Dictionary:
	if int(player.consumables.get("energy_drink", 0)) <= 0:
		return {"ok": false, "message": "No tenés bebida energizante.", "relief": 0.0}
	_consume(player, "energy_drink")
	return {"ok": true, "message": "Energía recuperada para la segunda mitad.", "relief": ENERGY_DRINK_RELIEF}

static func _consume(player: PlayerData, id: String) -> void:
	var left: int = int(player.consumables.get(id, 0)) - 1
	if left <= 0:
		player.consumables.erase(id)
	else:
		player.consumables[id] = left

static func _pick_attrs(count: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = PlayerDevelopment.ALL_TRAINABLE.duplicate()
	var picks: Array = []
	for i in range(mini(count, pool.size())):
		var idx: int = rng.randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks

# --- Guardarropa: ropa y accesorios en pixel art (schema v31) -----------
## Pedido de Wilber (9-oct): "ropa de muchos estilos para vender en la
## tienda, cadenas y cosas así". Las piezas (qué son, en qué slot van) viven
## en Avatar.OUTFITS / Avatar.ACCESSORIES; acá solo el PRECIO y la
## transacción, mismo criterio que los consumibles. Son permanentes: se
## compran una vez y se ponen/sacan gratis.
##
## Precio = [fracción del ingreso SEMANAL, piso en miles de EUR] — escala
## con el jugador igual que price_for(): un rookie paga el piso, una
## estrella paga semanas de sueldo por el smoking o el reloj.
const COSMETIC_PRICE := {
	# Ropa de calle
	"hoodie": [0.6, 15], "jeans": [0.6, 15], "polo": [0.6, 15],
	"chandal": [0.7, 18], "hawaiana": [0.7, 18], "lino": [0.8, 20],
	"bomber": [1.2, 30], "vaquera": [1.2, 30], "universitaria": [1.3, 32],
	"camisa_vestir": [1.2, 30], "cuello_alto": [1.4, 35], "plumifero": [1.6, 40],
	"cuero": [2.0, 50],
	# Formal / lujo
	"abrigo": [2.5, 60], "traje_azul": [3.0, 70], "traje_negro": [3.0, 70],
	"smoking_blanco": [4.0, 100],
	# Accesorios
	"cinta": [0.15, 4], "gorra": [0.3, 8], "gorro_lana": [0.3, 8],
	"lentes_sol": [0.5, 12], "aviador": [0.9, 22], "auriculares": [0.6, 15],
	"pendientes": [1.0, 25], "cadena_fina": [1.5, 35], "cadena_gruesa": [3.0, 80],
	"reloj": [4.0, 100],
	# Guayos (9-oct)
	"guayos_verde": [0.8, 20], "guayos_rosa": [0.8, 20], "guayos_blanco": [0.8, 20],
	"guayos_negro": [1.0, 25], "guayos_oro": [2.5, 65],
	"guayos_azul": [0.9, 22], "guayos_rojo": [0.9, 22], "guayos_morado": [1.2, 30],
	"guayos_arcoiris": [1.8, 45],
	# Ropa nueva (9-oct)
	"franela": [0.7, 18], "hoodie_negro": [0.7, 18], "oversize": [1.0, 25],
	"chaleco": [1.4, 35], "retro": [1.2, 30], "seda": [2.2, 55],
	"traje_gris": [3.2, 75],
	# 10-oct: conjuntos, zapatos de salir, guayos y accesorios nuevos.
	"camisa_chinos": [1.0, 25], "cortavientos": [0.9, 22], "parka_roja": [1.6, 40],
	"gabardina": [2.4, 60], "blazer_terciopelo": [2.8, 70],
	"zapatillas_blancas": [0.6, 15], "mocasines": [1.4, 35], "botas_chelsea": [1.6, 40],
	"guayos_plata": [1.6, 40], "guayos_lava": [1.4, 35],
	# 7-nov: más camisas, chaquetas y pantalones
	"marinera": [0.8, 20],
	"tiedye": [0.9, 22],
	"camisa_denim": [1.2, 30],
	"escocesa": [1.0, 25],
	"militar": [1.4, 35],
	"noventas": [1.3, 32],
	"tecnica": [1.6, 40],
	"sobrecamisa": [1.5, 38],
	"diplomatico": [3.2, 75],
	# 7-nov: guayos con diseños locos
	"guayos_tormenta": [2.2, 55], "guayos_galaxia": [2.8, 70], "guayos_tigre": [2.0, 50],
	"guayos_camo": [1.8, 45], "guayos_fuego": [2.2, 55], "guayos_hielo": [1.8, 45],
	"guayos_neon": [2.4, 60], "guayos_dos_caras": [2.0, 50],
	"guayos_voltaje": [2.0, 50],
	"guayos_dragon": [2.6, 65],
	"guayos_grafiti": [1.8, 45],
	"guayos_marmol": [2.4, 60],
	"guayos_oceano": [2.2, 55],
	"guayos_aurora": [2.6, 65],
	"guayos_ajedrez": [2.0, 50],
	"guayos_cobra": [2.4, 60],
	"guayos_pantera": [2.2, 55],
	"guayos_atardecer": [1.6, 40],
	"guayos_glaciar": [2.2, 55],
	"guayos_bosque": [1.8, 45],
	"guayos_confeti": [2.0, 50],
	"bufanda": [0.4, 10], "boina": [0.5, 12], "lentes_redondos": [0.7, 18],
}

## Una prenda suelta cuesta una parte del conjunto del que sale: 60% la de
## arriba, 45% el pantalón (comprar las dos por separado sale apenas más
## caro que el conjunto de antes).
const PIECE_SHARE := {"top": 0.60, "bottom": 0.45}

static func cosmetic_price(player: PlayerData, id: String) -> int:
	var weekly: float = float(ContractEngine.weekly_income(player.wage if player != null else 0))
	var src: String = Avatar.piece_src(id)
	var share: float = float(PIECE_SHARE.get(Avatar.slot_of(id), 1.0)) if src != "" else 1.0
	var p: Array = COSMETIC_PRICE.get(src if src != "" else id, [1.0, 25])
	return maxi(int(ceil(float(p[1]) * share)), int(round(weekly * float(p[0]) * share)))

static func owns_cosmetic(player: PlayerData, id: String) -> bool:
	return Avatar.owns(player, id)

## Las prendas de un conjunto DORADO tampoco se compran.
static func is_gold_cosmetic(id: String) -> bool:
	var src: String = Avatar.piece_src(id)
	return GoldEditions.is_gold(src if src != "" else id)

## Al ponerse una prenda suelta con un conjunto ENTERO puesto (guardado de
## antes de separar la tienda): el conjunto se desarma en sus dos mitades
## para no perder la otra.
static func _unpack_outfit(player: PlayerData) -> void:
	var whole: String = String(player.cosmetics_equipped.get("outfit", ""))
	if whole == "":
		return
	player.cosmetics_equipped.erase("outfit")
	if Avatar.outfit_by_id(whole).is_empty():
		return
	player.cosmetics_equipped["top"] = "top_" + whole
	player.cosmetics_equipped["bottom"] = "bot_" + Avatar.bottom_src_for(whole)

static func is_equipped(player: PlayerData, id: String) -> bool:
	var slot: String = Avatar.slot_of(id)
	if slot == "":
		return false
	if String(player.cosmetics_equipped.get(slot, "")) == id:
		return true
	# Media prenda de un conjunto entero que sigue puesto como conjunto.
	var whole: String = String(player.cosmetics_equipped.get("outfit", ""))
	if whole != "" and (slot == "top" or slot == "bottom") and String(player.cosmetics_equipped.get(slot, "")) == "":
		return id == ("top_" + whole if slot == "top" else "bot_" + Avatar.bottom_src_for(whole))
	return false

## Compra: descuenta balance, lo agrega al guardarropa y se lo PONE (lo
## natural después de comprar algo). false si no alcanza, ya lo tiene o el
## id no existe.
static func buy_cosmetic(player: PlayerData, id: String) -> bool:
	var slot: String = Avatar.slot_of(id)
	if slot == "" or owns_cosmetic(player, id) or is_gold_cosmetic(id):
		return false   # las doradas se GANAN (GoldEditions), no se compran
	var price: int = cosmetic_price(player, id)
	if player.balance < price:
		return false
	player.balance -= price
	player.cosmetics_owned.append(id)
	if slot == "top" or slot == "bottom":
		_unpack_outfit(player)
	player.cosmetics_equipped[slot] = id
	return true

## Ponerse algo ya comprado (reemplaza lo que haya en ese slot).
static func equip_cosmetic(player: PlayerData, id: String) -> bool:
	var slot: String = Avatar.slot_of(id)
	if slot == "" or not owns_cosmetic(player, id):
		return false
	if slot == "top" or slot == "bottom":
		_unpack_outfit(player)
	elif slot == "outfit":
		player.cosmetics_equipped.erase("top")
		player.cosmetics_equipped.erase("bottom")
	player.cosmetics_equipped[slot] = id
	return true

## Sacarse lo que haya en el slot de `id` (ropa → vuelve el kit del club).
static func unequip_cosmetic(player: PlayerData, id: String) -> void:
	var slot: String = Avatar.slot_of(id)
	if slot == "top" or slot == "bottom":
		_unpack_outfit(player)   # sacarse media prenda de un conjunto entero
	if slot != "" and String(player.cosmetics_equipped.get(slot, "")) == id:
		player.cosmetics_equipped.erase(slot)
