class_name CarLogic
extends RefCounted
## Lógica pura del coche, con tests en `tests/test_car_logic.gd`.


## Velocidad tras `dt` segundos. `throttle` va de -1 (marcha atrás) a 1.
static func next_speed(speed: float, throttle: float, handbrake: bool, dt: float, d: CarData) -> float:
	var out: float = speed
	if throttle > 0.0:
		out = move_toward(out, d.max_speed, (d.acceleration if out >= 0.0 else d.brake) * dt)
	elif throttle < 0.0:
		out = move_toward(out, -d.reverse_speed, (d.brake if out > 0.0 else d.reverse_acceleration) * dt)
	else:
		out = move_toward(out, 0.0, d.coast * dt)
	if handbrake:
		out = move_toward(out, 0.0, d.handbrake * dt)
	return out


## Giro en rad/s. `steer` va de -1 (derecha) a 1 (izquierda). Marcha atrás invierte el giro.
static func turn_rate(speed: float, steer: float, d: CarData) -> float:
	var grip: float = clampf(speed / d.grip_speed, -1.0, 1.0) / (1.0 + absf(speed) / d.understeer_speed)
	return steer * grip * d.steer
