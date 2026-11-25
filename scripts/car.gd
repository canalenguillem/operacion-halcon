extends CharacterBody3D

const MAX_SPEED := 40.0

var main
var is_jet := false
var enter_range := 4.5
var driver := false
var dead := false
var hp := 100.0
var speed := 0.0
var color := Color(0.8, 0.1, 0.1)
var model: Node3D


func _ready() -> void:
	add_to_group("vehicles")
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 1.3, 4.4)
	Build.collider(self, sh, Vector3(0, 0.65, 0))
	model = Node3D.new()
	add_child(model)
	Build.box(model, Vector3(2.0, 0.6, 4.4), Vector3(0, 0.6, 0), color)
	Build.box(model, Vector3(1.8, 0.55, 2.2), Vector3(0, 1.15, 0.3), Color(0.1, 0.14, 0.2))
	for sx in [-1.0, 1.0]:
		for sz in [-1.4, 1.4]:
			Build.cyl(model, 0.38, 0.3, Vector3(sx, 0.38, sz), Color(0.06, 0.06, 0.06), Vector3(0, 0, PI / 2.0))
		Build.box(model, Vector3(0.4, 0.15, 0.1), Vector3(sx * 0.7, 0.7, -2.2), Color(1, 1, 0.8), false).material_override = Build.mat(Color(1, 1, 0.8), 2.0)
		Build.box(model, Vector3(0.4, 0.15, 0.1), Vector3(sx * 0.7, 0.7, 2.2), Color(0.9, 0.05, 0.05), false).material_override = Build.mat(Color(0.9, 0.05, 0.05), 1.5)


func can_exit() -> bool:
	return absf(speed) < 6.0


func _physics_process(dt: float) -> void:
	var thr := 0.0
	var steer := 0.0
	var brake := false
	if driver and not dead and not main.game_over:
		thr = Input.get_axis("back", "forward")
		steer = Input.get_axis("right", "left")
		brake = Input.is_action_pressed("jump")

	if thr > 0.0:
		speed = move_toward(speed, MAX_SPEED, (14.0 if speed >= 0.0 else 30.0) * dt)
	elif thr < 0.0:
		speed = move_toward(speed, -12.0, (30.0 if speed > 0.0 else 9.0) * dt)
	else:
		speed = move_toward(speed, 0.0, 6.0 * dt)
	if brake:
		speed = move_toward(speed, 0.0, 45.0 * dt)

	var grip := clampf(speed / 8.0, -1.0, 1.0) / (1.0 + absf(speed) / 45.0)
	rotate_y(steer * grip * 2.0 * dt)
	var fwd := -global_transform.basis.z
	velocity = fwd * speed + Vector3(0, -3, 0)
	move_and_slide()

	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.5:
			continue
		var other = c.get_collider()
		if other and other.is_in_group("soldiers"):
			if absf(speed) > 6.0:
				other.hurt(999.0)
			continue
		var head_on := absf(n.dot(fwd))
		var impact := absf(speed) * head_on
		if impact > 12.0:
			hurt(impact * 0.5)
		speed *= 1.0 - head_on


func hurt(d: float) -> void:
	if dead:
		return
	hp -= d
	if hp <= 0.0:
		hp = 0.0
		dead = true
		speed = 0.0
		for c in model.get_children():
			if c is MeshInstance3D:
				c.material_override = Build.mat(Color(0.08, 0.07, 0.06))
		main.explosion(global_position + Vector3.UP, 7.0)
		if driver:
			main.eject(40.0)
