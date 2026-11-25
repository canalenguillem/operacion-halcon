class_name MissileLogic
extends RefCounted
## Lógica pura de misiles y baterías, con tests en `tests/test_missile_logic.gd`.


## Punto al que apunta el misil: por delante del blanco según el tiempo que tardará en llegar.
static func aim_point(pos: Vector3, speed: float, target_pos: Vector3, target_vel: Vector3, d: MissileData) -> Vector3:
	var eta: float = pos.distance_to(target_pos) / maxf(speed, 1.0)
	return target_pos + target_vel * d.lead * eta


## Nueva dirección (unitaria) del misil tras `dt`, girando como mucho `turn_rate` hacia `aim`.
static func steer(dir: Vector3, pos: Vector3, aim: Vector3, dt: float, d: MissileData) -> Vector3:
	var to: Vector3 = aim - pos
	if to.length() < 0.001:
		return dir
	var want: Vector3 = to.normalized()
	var angle: float = dir.angle_to(want)
	var axis: Vector3 = dir.cross(want)
	if angle < 0.001 or axis.length() < 0.0001:
		return dir
	return dir.rotated(axis.normalized(), minf(angle, d.turn_rate * dt)).normalized()


## Velocidad del misil tras `dt`.
static func next_speed(speed: float, dt: float, d: MissileData) -> float:
	return minf(speed + d.acceleration * dt, d.top_speed)


## ¿Puede disparar una batería a un caza a esa distancia y altura, con `airborne` misiles ya en el aire?
static func can_fire(dist: float, altitude: float, airborne: int, d: MissileData) -> bool:
	return altitude >= d.min_altitude and dist > d.min_range and dist < d.max_range and airborne < d.max_airborne
