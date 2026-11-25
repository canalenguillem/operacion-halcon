class_name JetLogic
extends RefCounted
## Lógica pura del caza, con tests en `tests/test_jet_logic.gd`.


## Potencia (0..1) en tierra: W (`pitch_in` < 0) acelera; S frena mientras no se pueda despegar.
static func ground_throttle(throttle: float, pitch_in: float, speed: float, dt: float, d: JetData) -> float:
	if pitch_in < 0.0:
		return minf(1.0, throttle + d.throttle_up * dt)
	if pitch_in > 0.0 and speed < d.takeoff_speed:
		return maxf(0.0, throttle - d.throttle_down * dt)
	return throttle


## ¿Despega? Tirando del morro a partir de `takeoff_speed`, o solo a partir de `auto_lift_speed`.
static func should_lift(pitch_in: float, speed: float, d: JetData) -> bool:
	return (pitch_in > 0.2 and speed >= d.takeoff_speed) or speed >= d.auto_lift_speed


## Grado de pérdida: 0 volando bien, 1 parado en el aire.
static func stall(speed: float, d: JetData) -> float:
	return clampf((d.takeoff_speed - speed) / d.takeoff_speed, 0.0, 1.0)


## Velocidad en vuelo tras `dt`. `climb` es la componente vertical del morro (-1 picado, 1 vertical).
static func air_speed(speed: float, throttle: float, climb: float, dt: float, d: JetData) -> float:
	var out: float = move_toward(speed, throttle * d.max_speed, d.air_acceleration * dt)
	return maxf(0.0, out - climb * d.climb_drag * dt)


## Tocar algo en vuelo es aterrizar solo si es suelo plano, con poco picado y las alas casi niveladas.
static func can_land(normal: Vector3, forward: Vector3, bank: float) -> bool:
	return normal.y > 0.8 and forward.y > -0.3 and absf(bank) < 0.4
