class_name PlayerLogic
extends RefCounted
## Lógica pura del jugador a pie (sin nodos), con tests en `tests/test_player_logic.gd`.
## El norte y el frente son -Z; un giro (yaw) positivo gira a la izquierda.


## Dirección de movimiento en el mundo a partir del input (x derecha, y atrás) y del giro de la cámara.
static func move_dir(input: Vector2, cam_yaw: float) -> Vector3:
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, cam_yaw)


## Giro (yaw) con el que un actor mira hacia `dir`.
static func facing_yaw(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Velocidad horizontal objetivo.
static func target_speed(sprinting: bool, data: PlayerData) -> float:
	return data.sprint_speed if sprinting else data.walk_speed


## Salud tras `dt` segundos, con `since_hurt` segundos desde el último daño.
static func regen(health: float, since_hurt: float, dt: float, data: PlayerData) -> float:
	if since_hurt < data.regen_delay or health >= data.max_health:
		return health
	return minf(data.max_health, health + data.regen_rate * dt)


## Nuevo giro y cabeceo de la cámara tras mover el ratón `relative` píxeles. Devuelve (yaw, pitch).
static func orbit(yaw: float, pitch: float, relative: Vector2, data: PlayerData) -> Vector2:
	var new_yaw: float = yaw - relative.x * data.mouse_sensitivity
	var new_pitch: float = clampf(pitch - relative.y * data.mouse_sensitivity, data.pitch_min, data.pitch_max)
	return Vector2(new_yaw, new_pitch)
