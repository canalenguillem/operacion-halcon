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


## Dirección de avance sobre una pendiente de normal `floor_normal` (unitaria).
static func along_slope(forward: Vector3, floor_normal: Vector3) -> Vector3:
	var d: Vector3 = forward - floor_normal * forward.dot(floor_normal)
	return d.normalized() if d.length() > 0.001 else forward


## Giro en rad/s. `steer` va de -1 (derecha) a 1 (izquierda). Marcha atrás invierte el giro.
static func turn_rate(speed: float, steer: float, d: CarData) -> float:
	var grip: float = clampf(speed / d.grip_speed, -1.0, 1.0) / (1.0 + absf(speed) / d.understeer_speed)
	return steer * grip * d.steer
