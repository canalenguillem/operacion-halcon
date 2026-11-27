class_name DayNightLogic
extends RefCounted
## Lógica pura del ciclo de día y noche, con tests en `tests/test_day_night_logic.gd`.
## La hora va de 0 a 24; el sol sale a las 6 y se pone a las 18.

const NIGHT_TOP: Color = Color(0.02, 0.03, 0.08)
const NIGHT_HORIZON: Color = Color(0.07, 0.09, 0.16)
const DAY_TOP: Color = Color(0.2, 0.45, 0.85)
const DAY_HORIZON: Color = Color(0.75, 0.82, 0.9)
const DUSK_HORIZON: Color = Color(0.95, 0.55, 0.32)
const DUSK_TOP: Color = Color(0.3, 0.3, 0.55)


## Hora tras `dt` segundos reales, si un día dura `day_minutes` minutos.
static func advance(hour: float, dt: float, day_minutes: float) -> float:
	return fposmod(hour + dt * 24.0 / (day_minutes * 60.0), 24.0)


## Altura del sol sobre el horizonte en grados (negativa de noche; 70° a mediodía).
static func sun_elevation(hour: float) -> float:
	return 70.0 * sin((hour - 6.0) / 12.0 * PI)


## Rumbo del sol en grados: sale por el este y se pone por el oeste.
static func sun_azimuth(hour: float) -> float:
	return lerpf(-90.0, 90.0, clampf((hour - 6.0) / 12.0, 0.0, 1.0))


## Cuánta luz de día hay: 0 de noche, 1 con el sol alto.
static func daylight(hour: float) -> float:
	return smoothstep(-6.0, 14.0, sun_elevation(hour))


## Cuánto se nota el amanecer o el atardecer (sol cerca del horizonte).
static func dusk(hour: float) -> float:
	var e: float = sun_elevation(hour)
	return clampf(1.0 - absf(e - 2.0) / 14.0, 0.0, 1.0)


static func sky_top(hour: float) -> Color:
	return NIGHT_TOP.lerp(DAY_TOP, daylight(hour)).lerp(DUSK_TOP, dusk(hour) * 0.5)


static func sky_horizon(hour: float) -> Color:
	return NIGHT_HORIZON.lerp(DAY_HORIZON, daylight(hour)).lerp(DUSK_HORIZON, dusk(hour) * 0.75)


## Brillo de las ventanas y los neones (0 de día, 1 de noche).
static func lights_on(hour: float) -> float:
	return 1.0 - smoothstep(-2.0, 8.0, sun_elevation(hour))


## «hh:mm».
static func clock(hour: float) -> String:
	var minutes: int = int(hour * 60.0) % (24 * 60)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minutes / 60, minutes % 60]
