extends RefCounted
class_name CurrencyFormat

## Formatea montos monetarios del juego (fichajes, presupuestos, valores
## de mercado — todos en MILES DE EURO internamente, ver TransferMarketEngine)
## según la moneda que el usuario eligió en Ajustes (Preferences.currency)
## — pedido explícito: "en ajustes el jugador elije cual de los dos [EUR
## o USD]". Un solo lugar para esto: nunca formatear plata a mano en una
## pantalla suelta.

const EUR_TO_USD := 1.08 # tasa fija de trabajo — un juego no necesita una API de cambio real

## `amount_k`: monto en miles de EUR (la unidad interna). Se muestra con
## las abreviaturas estándar: **K = miles, M = millones** (pedido de
## Wilber). Ej.: "€4.7M" / "€267K" / "$5.1M". Según Preferences.currency.
static func format(amount_k: int) -> String:
	var symbol: String = "€"
	var amount: float = float(amount_k)
	if Preferences.currency == "USD":
		symbol = "$"
		amount *= EUR_TO_USD
	var neg: String = ""
	if amount < 0.0:
		neg = "-"
		amount = -amount
	if amount >= 1000.0:
		return "%s%s%.1fM" % [neg, symbol, amount / 1000.0]
	return "%s%s%dK" % [neg, symbol, int(round(amount))]
