class_name Humanoid
extends Node3D
## Muñeco articulado de primitivas (jugador y soldados): piernas y brazos se balancean al andar.
## El frente es -Z. Los pies están en y = 0.

const STRIDE: float = 2.4  # radianes de fase por metro andado
const MAX_SWING: float = 0.75
const FULL_SWING_SPEED: float = 4.0

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var phase: float = 0.0


## Ángulo de la pierna izquierda (la derecha va al revés). Parado: 0.
static func swing(at_phase: float, speed: float) -> float:
	return sin(at_phase) * MAX_SWING * clampf(speed / FULL_SWING_SPEED, 0.0, 1.0)


## `headgear` con alfa 0: sin casco ni pelo. `gun_length` en metros (0: desarmado).
func build(shirt: Color, trousers: Color, skin: Color, headgear: Color, gun_length: float) -> void:
	var boots := Color(0.08, 0.07, 0.06)
	Build.box(self, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.16, 0), shirt)
	Build.box(self, Vector3(0.46, 0.14, 0.26), Vector3(0, 0.84, 0), trousers)
	Build.cyl(self, 0.07, 0.12, Vector3(0, 1.51, 0), skin)
	Build.sphere(self, 0.16, Vector3(0, 1.67, 0), skin)
	if headgear.a > 0.0:
		var cap: MeshInstance3D = Build.sphere(self, 0.185, Vector3(0, 1.72, 0.02), headgear)
		cap.scale = Vector3(1, 0.75, 1.05)
	leg_l = _limb(Vector3(-0.13, 0.82, 0))
	leg_r = _limb(Vector3(0.13, 0.82, 0))
	for leg: Node3D in [leg_l, leg_r]:
		Build.box(leg, Vector3(0.2, 0.72, 0.22), Vector3(0, -0.36, 0), trousers)
		Build.box(leg, Vector3(0.22, 0.12, 0.34), Vector3(0, -0.76, -0.05), boots)
	arm_l = _limb(Vector3(-0.33, 1.42, 0))
	arm_r = _limb(Vector3(0.33, 1.42, 0))
	for arm: Node3D in [arm_l, arm_r]:
		Build.box(arm, Vector3(0.14, 0.56, 0.14), Vector3(0, -0.26, 0), shirt)
		Build.sphere(arm, 0.075, Vector3(0, -0.58, 0), skin)
	if gun_length > 0.0:
		var dark := Color(0.06, 0.06, 0.07)
		Build.box(arm_r, Vector3(0.06, gun_length, 0.1), Vector3(0, -0.6 - gun_length / 2.0 + 0.12, -0.07), dark)
		Build.box(arm_r, Vector3(0.06, 0.1, 0.2), Vector3(0, -0.58, 0.05), dark)


func _limb(at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	return pivot


## Llamar cada fotograma con la velocidad horizontal. Con `aiming` el brazo derecho apunta al frente.
func animate(speed: float, dt: float, aiming: bool) -> void:
	phase = fmod(phase + speed * STRIDE * dt, TAU)
	var a: float = swing(phase, speed)
	leg_l.rotation.x = a
	leg_r.rotation.x = -a
	arm_l.rotation.x = -a
	arm_r.rotation.x = lerp_angle(arm_r.rotation.x, PI / 2.0 if aiming else a, minf(1.0, 18.0 * dt))
