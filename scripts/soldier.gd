class_name Soldier
extends CharacterBody3D
## Soldado de la base. Los ajustes están en `data/soldier.tres`.

var main: Main
var data: SoldierData = preload("res://data/soldier.tres")
var hp: float = 40.0
var alert: bool = false
var dead: bool = false
var cd: float = 1.0
var home: Vector3 = Vector3.ZERO
var col: CollisionShape3D


func _init() -> void:
	collision_layer = Layers.SOLDIERS
	collision_mask = Layers.ALL


func _ready() -> void:
	hp = data.max_hp
	home = global_position
	cd = randf_range(0.5, data.fire_interval_max)
	rotation.y = randf() * TAU
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col = Build.collider(self, cap, Vector3(0, 0.9, 0))
	var green := Color(0.28, 0.36, 0.2)
	Build.box(self, Vector3(0.5, 0.8, 0.28), Vector3(0, 0.4, 0), Color(0.2, 0.26, 0.15))
	Build.box(self, Vector3(0.58, 0.7, 0.32), Vector3(0, 1.15, 0), green)
	Build.sphere(self, 0.17, Vector3(0, 1.66, 0), Color(0.85, 0.68, 0.55))
	Build.sphere(self, 0.2, Vector3(0, 1.74, 0), Color(0.2, 0.26, 0.15))
	Build.box(self, Vector3(0.08, 0.1, 0.9), Vector3(0.25, 1.25, -0.45), Color(0.05, 0.05, 0.05))


func _physics_process(dt: float) -> void:
	if dead or main.game_over:
		return
	var target: Node3D = main.target_node()
	var tp: Vector3 = target.global_position
	var to: Vector3 = tp - global_position
	var dist: float = to.length()

	if not alert:
		if SoldierLogic.should_alert(dist, main.mission.base_alert, data):
			alert = true
			main.mission.raise_alert()
		return

	to.y = 0.0
	rotation.y = lerp_angle(rotation.y, PlayerLogic.facing_yaw(to), data.turn_speed * dt)
	var v: Vector3 = Vector3.ZERO
	if SoldierLogic.should_chase(dist, global_position.distance_to(home), data):
		v = to.normalized() * data.chase_speed
	velocity = Vector3(v.x, -1.0 if is_on_floor() else velocity.y - 25.0 * dt, v.z)
	move_and_slide()

	cd -= dt
	if cd <= 0.0 and SoldierLogic.can_fire(dist, tp.y, data):
		cd = randf_range(data.fire_interval_min, data.fire_interval_max)
		_fire(target, tp, dist)


func _fire(target: Node3D, tp: Vector3, dist: float) -> void:
	var from: Vector3 = global_position + Vector3(0, 1.4, 0)
	var aim: Vector3 = tp + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, aim)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider != target and not hit.collider is Soldier:
		return  # sin línea de visión
	if randf() < SoldierLogic.hit_chance(dist, data):
		main.hurt_target(data)
	else:
		aim += Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2))
	main.tracer(from, aim, Color(1, 0.4, 0.3))
	main.sfx.play_at("rifle", from, -2.0, 18.0)


func hurt(d: float) -> void:
	if dead:
		return
	hp -= d
	if not alert:
		alert = true
		main.mission.raise_alert()
	if hp <= 0.0:
		dead = true
		col.set_deferred("disabled", true)
		main.kills += 1
		create_tween().tween_property(self, "rotation:x", -PI / 2.0, 0.3)
