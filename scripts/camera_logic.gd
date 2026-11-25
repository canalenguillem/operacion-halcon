class_name CameraLogic
extends RefCounted
## Lógica pura de la sacudida de cámara, con tests en `tests/test_effects.gd`.

const MAX_SHAKE: float = 0.8
## Sacudida que se pierde por segundo.
const DECAY: float = 1.6


## Sacudida que provoca una explosión de ese radio a esa distancia de la cámara.
static func shake_amount(radius: float, dist: float) -> float:
	return clampf(radius * 2.0 / maxf(dist, 1.0), 0.0, 1.0) * MAX_SHAKE


## Suma una sacudida a la que ya había, sin pasar del máximo.
static func add(shake: float, amount: float) -> float:
	return minf(MAX_SHAKE, shake + amount)


static func decay(shake: float, dt: float) -> float:
	return move_toward(shake, 0.0, DECAY * dt)
