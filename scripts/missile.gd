class_name Missile
extends Node3D
## Misil tierra-aire: persigue al caza con giro limitado. Los ajustes están en `data/missile.tres`.

var main: Main
var data: MissileData
var target: Jet
var dir: Vector3 = Vector3.UP
var speed: float = 60.0
var life: float = 16.0
## Una bengala lo ha despistado: sigue recto.
var decoyed: bool = false
var dead: bool = false


func _ready() -> void:
	speed = data.launch_speed
	life = data.lifetime
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
	speed = MissileLogic.next_speed(speed, dt, data)
	var chasing: bool = is_instance_valid(target) and not target.dead
	if chasing and not decoyed:
		var aim: Vector3 = MissileLogic.aim_point(global_position, speed, target.global_position, target.velocity, data)
		dir = MissileLogic.steer(dir, global_position, aim, dt, data)
	global_position += dir * speed * dt
	look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)

	if chasing and distance() < data.hit_radius:
		target.hurt(data.damage)
		_boom()
	elif life <= 0.0 or global_position.y < 0.5:
		_boom()


func _boom() -> void:
	dead = true
	main.explosion(global_position, 9.0)
	queue_free()
