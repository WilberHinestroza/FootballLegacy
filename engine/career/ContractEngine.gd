extends RefCounted
class_name ContractEngine

## Centraliza salario, ingresos y renovación de contrato — mismo principio
## que CoachRelations / PlayerDevelopment: una sola fórmula, nunca
## dispersa por pantallas.
##
## Unidad monetaria del juego: MILES DE EURO (igual que CurrencyFormat y
## TransferMarketEngine). Un `wage` de 640 = 640 000 €/temporada; de 18000
## = 18 M€/temporada. La curva abajo apunta a rangos reales:
##   fuerza ~45 (2ª división)      → ~0,3-0,5 M€
##   fuerza ~60 (1ª división media)→ ~2-3 M€
##   fuerza ~78 (equipo grande)    → ~8-11 M€
##   fuerza ~92 (élite mundial)    → ~17-22 M€

const STARTING_CONTRACT_YEARS := 2
const RENEWAL_YEARS := 2
const MIN_WAGE := 90   # 90 000 €/temporada, contrato de promesa

## Sueldo de temporada al fichar por un club (Offers / mercado futuro).
## Curva potencia sobre la fuerza del club, modulada por la reputación de
## la liga (una liga fuerte paga más por el mismo nivel de club).
static func starting_wage(club_strength: int, league_reputation: int) -> int:
	var t: float = clampf(float(club_strength - 30) / 70.0, 0.0, 1.0)
	var base: float = pow(t, 2.6) * 26000.0
	var league_factor: float = 0.72 + float(league_reputation) / 100.0 * 0.58
	return maxi(int(round(base * league_factor)), MIN_WAGE)

## Ingreso semanal, repartiendo el sueldo de temporada en 52 semanas.
static func weekly_income(wage: int) -> int:
	return maxi(int(round(float(wage) / 52.0)), 1)

## Techo de sueldo realista para un jugador de nivel `overall` — mismo
## criterio que starting_wage() pero con la liga/club más generosos
## posibles (reputación ~92) más un margen, así rara vez cobrás más que
## una élite mundial por jugar de comparsa en algún lado. Sin esto,
## renewal_wage() de abajo (puramente RELATIVO a tu sueldo actual, sin
## ningún techo) podía dispararse sin límite con rachas largas de
## confianza/tabla altas, sin relación con tu nivel real — bug real
## reportado por Wilber (Parte 93c: "revisa también los sueldos", mismo
## espíritu que el fix de market_value cacheado).
static func wage_ceiling(overall: int) -> int:
	return int(round(starting_wage(overall, 92) * 1.2))

## Nuevo sueldo al renovar (fin de temporada, ver WorldTickEngine._rollover_season).
## league_position_ratio: 0.0 = campeón de tu liga, 1.0 = último clasificado.
## Es una aproximación (no hay histórico propio de ratings todavía): buena
## confianza del entrenador + buena clasificación del equipo = subida;
## lo contrario = recorte, con un piso para no desplomarse a la nada — y
## un TECHO (wage_ceiling) para que la subida relativa nunca se despegue
## de lo que tu nivel actual puede sostener.
static func renewal_wage(current_wage: int, coach_trust: int, league_position_ratio: float, overall: int) -> int:
	var trust_factor: float = clampf(float(coach_trust - 50) / 50.0, -1.0, 1.0)
	var table_factor: float = clampf(1.0 - league_position_ratio * 2.0, -1.0, 1.0)
	var change_pct: float = 0.05 + (trust_factor + table_factor) * 0.10 # aprox -0.15..+0.25
	var raw: int = int(round(float(current_wage) * (1.0 + change_pct)))
	return clampi(raw, MIN_WAGE, wage_ceiling(overall))
