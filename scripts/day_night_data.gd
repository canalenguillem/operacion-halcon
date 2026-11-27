class_name DayNightData
extends Resource
## Ajustes del ciclo de día y noche. Se editan en `data/day_night.tres`.

## Hora a la que empieza la partida (0-24).
@export_range(0.0, 24.0, 0.25) var start_hour: float = 10.0
## Minutos reales que dura un día entero del juego.
@export var day_minutes: float = 24.0
## Farolas cercanas que dan luz de verdad por la noche (el resto solo brillan).
@export var lamp_lights: int = 14
@export var lamp_range: float = 22.0
@export var lamp_energy: float = 3.0
