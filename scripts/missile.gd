extends Node3D
## Surface-to-air missile: homes on the jet with a limited turn rate.

const TURN := 0.75
const TOP_SPEED := 185.0

var main
var target
var dir := Vector3.UP
var speed := 60.0
var life := 16.0
var decoyed := false
var dead := false


func _ready() -> void:
	Build.cyl(self, 0.25, 3.0, Vector3.ZERO, Color(0.9, 0.9, 0.9), Vector3(-PI / 2.0, 0, 0))
	Build.sphere(self, 0.6, Vector3(0, 0, 1.8), Color(1.0, 0.6, 0.1), 5.0)
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.2
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = Build.mat(Color(0.9, 0.9, 0.9, 0.5))
	p.mesh = sm
	p.position = Vector3(0, 0, 2.0)
	add_child(p)


func distance() -> float:
	if is_instance_valid(target):
		return global_position.distance_to(target.global_position)
	return 1e9


func _physics_process(dt: float) -> void:
	if dead:
		return
	life -= dt
	speed = minf(speed + 90.0 * dt, TOP_SPEED)
	var d := 1e9
	if is_instance_valid(target) and not target.dead:
		d = distance()
		if not decoyed:
			var tv: Vector3 = target.velocity
			var aim: Vector3 = target.global_position + tv * 0.4 * (d / speed)
			var want := (aim - global_position).normalized()
			var ang := dir.angle_to(want)
			var axis := dir.cross(want)
			if ang > 0.001 and axis.length() > 0.0001:
				dir = dir.rotated(axis.normalized(), minf(ang, TURN * dt)).normalized()
	global_position += dir * speed * dt
	look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)

	if d < 10.0:
		target.hurt(34.0)
		_boom()
	elif life <= 0.0 or global_position.y < 0.5:
		_boom()


func _boom() -> void:
	dead = true
	main.explosion(global_position, 9.0)
	queue_free()
