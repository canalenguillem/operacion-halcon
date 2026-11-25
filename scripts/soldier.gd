extends CharacterBody3D

const Build = preload("res://scripts/build.gd")

var main
var hp := 40.0
var alert := false
var dead := false
var cd := 1.0
var home := Vector3.ZERO
var col: CollisionShape3D


func _ready() -> void:
	add_to_group("soldiers")
	home = global_position
	cd = randf_range(0.5, 1.8)
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
	var t = main.target_node()
	var tp: Vector3 = t.global_position
	var to := tp - global_position
	var d := to.length()

	if not alert:
		if d < 45.0 or (main.base_alert and d < 500.0):
			alert = true
			main.raise_alert()
		return

	to.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 8.0 * dt)
	var chase := d > 25.0 and d < 300.0 and global_position.distance_to(home) < 350.0
	var v := to.normalized() * 4.5 if chase else Vector3.ZERO
	velocity = Vector3(v.x, velocity.y - 25.0 * dt if not is_on_floor() else -1.0, v.z)
	move_and_slide()

	cd -= dt
	if cd <= 0.0 and d < 95.0 and tp.y < 25.0:
		cd = randf_range(1.0, 1.8)
		_fire(t, tp, d)


func _fire(t, tp: Vector3, d: float) -> void:
	var from := global_position + Vector3(0, 1.4, 0)
	var aim := tp + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, aim)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider != t and not hit.collider.is_in_group("soldiers"):
		return  # no line of sight
	var chance := clampf(0.75 - d / 130.0, 0.1, 0.7)
	if randf() < chance:
		var dmg := 5.0
		if t != main.player:
			dmg = 1.2 if t.is_jet else 2.0
		t.hurt(dmg)
		main.tracer(from, aim, Color(1, 0.4, 0.3))
	else:
		var miss := Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2))
		main.tracer(from, aim + miss, Color(1, 0.4, 0.3))


func hurt(d: float) -> void:
	if dead:
		return
	hp -= d
	if not alert:
		alert = true
		main.raise_alert()
	if hp <= 0.0:
		dead = true
		col.set_deferred("disabled", true)
		main.kills += 1
		var tw := create_tween()
		tw.tween_property(self, "rotation:x", -PI / 2.0, 0.3)
		tw.tween_interval(8.0)
		tw.tween_callback(queue_free)
