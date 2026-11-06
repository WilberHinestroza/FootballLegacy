extends RefCounted
class_name CalendarUtils

## Aprendizaje de FL: una temporada ago-may NO debe identificarse por
## el año calendario crudo, o se parte en dos buckets el 1 de enero.
## Siempre usar el año de INICIO de la temporada como identificador.

const EPOCH_START_DATE := {"year": 2026, "month": 7, "day": 1} # 2026-07-01, como en FL V11
const SEASON_START_MONTH := 7 # julio: si el mes actual es < julio, la temporada empezó el año anterior

static func epoch_day_to_date(epoch_day: int) -> Dictionary:
	var base_unix := Time.get_unix_time_from_datetime_dict(EPOCH_START_DATE)
	var target_unix := base_unix + epoch_day * 86400
	return Time.get_datetime_dict_from_unix_time(target_unix)

static func season_start_year(epoch_day: int) -> int:
	var date := epoch_day_to_date(epoch_day)
	var year: int = date["year"]
	var month: int = date["month"]
	if month < SEASON_START_MONTH:
		return year - 1
	return year

## Inverso de epoch_day_to_date — para armar una cuadrícula de calendario
## por mes (día del mes -> epoch_day, para consultar si ese día tiene
## partido). `day` puede ser 1..31, `month` 1..12, siempre que la fecha
## exista de verdad (no se valida acá).
static func date_to_epoch_day(year: int, month: int, day: int) -> int:
	var base_unix := Time.get_unix_time_from_datetime_dict(EPOCH_START_DATE)
	var target_unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day})
	return int(round(float(target_unix - base_unix) / 86400.0))

## Cuántos días tiene `month`/`year` — la resta entre el 1° de ESE mes y
## el 1° del siguiente evita tener que hardcodear 28/29/30/31 a mano.
static func days_in_month(year: int, month: int) -> int:
	var next_month: int = month + 1
	var next_year: int = year
	if next_month > 12:
		next_month = 1
		next_year += 1
	var this_start := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": 1})
	var next_start := Time.get_unix_time_from_datetime_dict({"year": next_year, "month": next_month, "day": 1})
	return int(round(float(next_start - this_start) / 86400.0))

## Día de la semana de year/month/day, 0=Lunes .. 6=Domingo (para alinear
## la cuadrícula Lun-Dom) — Time.get_datetime_dict_from_unix_time() de
## Godot devuelve 0=Domingo..6=Sábado, se rota acá una sola vez.
static func weekday_of(year: int, month: int, day: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day})
	var d := Time.get_datetime_dict_from_unix_time(unix)
	var sunday_first: int = int(d.get("weekday", 0))
	return (sunday_first + 6) % 7

## Día de la semana de un epoch_day directo, 0=Lunes .. 6=Domingo — para
## fijar los partidos de liga en (Sáb/Dom) y las copas en (Mar/Mié/Jue)
## sin tener que convertir a año/mes/día primero (ver SeasonCalendar).
static func weekday_of_epoch_day(epoch_day: int) -> int:
	var d := epoch_day_to_date(epoch_day)
	var sunday_first: int = int(d.get("weekday", 0))
	return (sunday_first + 6) % 7
