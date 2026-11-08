extends RefCounted
class_name PrizeMoneyEngine

## Primas por título al cierre de temporada. Unidad: miles de EUR (igual
## que ContractEngine / CurrencyFormat). Se paga al `balance` del jugador
## — su parte de la prima colectiva del plantel campeón.
##
## Escala pensada contra el sueldo nuevo (un titular ~2000-11000/temporada):
## ganar la liga vale como medio año de sueldo de un buen jugador; una
## continental, bastante más; el Mundial de Clubes, lo máximo.

## `honors`: Array de {id, name, kind, ...} (HonorsEngine.collect_season).
## `league_rep`: reputación de la liga del jugador (0..100).
## Devuelve {"total": int, "lines": Array de {name, amount}}.
static func for_honors(honors: Array, league_rep: int, rng: RandomNumberGenerator) -> Dictionary:
	var lines: Array = []
	var total: int = 0
	for h in honors:
		var kind: String = String(h.get("kind", ""))
		var id: String = String(h.get("id", ""))
		var amount: int = 0
		match kind:
			"world":
				amount = 22000 + rng.randi_range(-2000, 4000)
			"continental":
				amount = 9000 + league_rep * 70 + rng.randi_range(-1000, 2000)
			"team":
				if id.begins_with("league_"):
					amount = 2400 + league_rep * 52 + rng.randi_range(-400, 900)
				elif id.begins_with("dcup_"):
					amount = 1500 + league_rep * 22 + rng.randi_range(-300, 600)
				else:
					amount = 1200 + rng.randi_range(-200, 500)
			_:
				# individual (Balón de Oro, Bota de Oro…): imagen/derechos.
				if id == "ballon_dor":
					amount = 1500
				elif id == "bota_oro_mundial" or id == "guante_oro" or id == "once_mundial":
					amount = 900
				elif id.begins_with("botaoro_") or id.begins_with("mvp_") or id.begins_with("goleador_liga_") \
						or id.begins_with("asist") or id == "guante_oro_podio":
					amount = 500
				elif id == "golden_boy":
					amount = 600
				elif id.begins_with("potm_"):
					amount = 250
		if amount > 0:
			amount = maxi(amount, 200)
			lines.append({"name": String(h.get("name", "Título")), "amount": amount})
			total += amount
	return {"total": total, "lines": lines}

## Prima de ascenso / penalizacion de descenso (Ascensos y Descensos, ver
## PromotionRelegationEngine) -- a diferencia de for_honors() no depende de
## titulos, es automatico para el club en el que se jugo la temporada que
## termina si ese club cambio de categoria. La prima de ascenso escala con
## la reputacion de la liga a la que SE ENTRA (subir a una liga grande paga
## mas); la penalizacion de descenso escala con la reputacion de la liga
## que SE DEJA (perder una liga grande duele mas que perder una chica) --
## mismo espiritu que for_honors con los titulos. Pedido explicito de
## Wilber ("repercute en el dinero por ascender o lo que recibes que es
## menos al descender").
## Bug real de la auditoría de balance (ronda 6, confirmado por Wilber: "así
## no debería ser, debería ser más baja"): con la fórmula vieja, ascender
## pagaba prácticamente lo mismo (a veces más) que salir campeón de tu
## propia liga (for_honors, "league_"), pese a ser un logro menor — quedar
## 1º en la categoría de ABAJO. Reescalado para rondar la mitad de lo que
## paga el título de liga en todo el rango de reputación.
## Prima por GANAR EL CLÁSICO (P5, 9-oct): ~una semana y media de sueldo
## (wage = sueldo de temporada, en miles), mínimo 5K.
static func derby_win_bonus(wage: int) -> int:
	return maxi(5, int(round(float(wage) / 34.0)))

static func for_promotion(new_league_rep: int, rng: RandomNumberGenerator) -> int:
	return maxi(900 + new_league_rep * 30 + rng.randi_range(-150, 350), 300)

static func for_relegation(old_league_rep: int, rng: RandomNumberGenerator) -> int:
	return -maxi(600 + old_league_rep * 20 + rng.randi_range(-100, 250), 150)
