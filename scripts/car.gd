class_name Car
extends Vehicle
## Coche arcade. Los ajustes están en `data/car.tres`.

var data: CarData = preload("res://data/car.tres")
var color: Color = Color(0.8, 0.1, 0.1)
var model: Node3D


func _ready() -> void:
	hp = data.max_hp
	enter_range = data.enter_range
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 1.3, 4.4)
	Build.collider(self, sh, Vector3(0, 0.65, 0))
	model = Node3D.new()
	add_child(model)
	Build.box(model, Vector3(2.0, 0.6, 4.4), Vector3(0, 0.6, 0), color)
	Build.box(model, Vector3(1.8, 0.55, 2.2), Vector3(0, 1.15, 0.3), Color(0.1, 0.14, 0.2))
	var head := BoxMesh.new()
	head.size = Vector3(0.4, 0.15, 0.1)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.4, 1.4]:
			Build.cyl(model, 0.38, 0.3, Vector3(sx, 0.38, sz), Color(0.06, 0.06, 0.06), Vector3(0, 0, PI / 2.0))
		Build.mesh(model, head, Vector3(sx * 0.7, 0.7, -2.2), Color(1, 1, 0.8), Vector3.ZERO, 2.0)
		Build.mesh(model, head, Vector3(sx * 0.7, 0.7, 2.2), Color(0.9, 0.05, 0.05), Vector3.ZERO, 1.5)


func can_exit() -> bool:
	return absf(speed) < data.exit_speed


func _physics_process(dt: float) -> void:
	var throttle: float = 0.0
	var steer: float = 0.0
	var handbrake: bool = false
	if controlled():
		throttle = Input.get_axis("back", "forward")
		steer = Input.get_axis("right", "left")
		handbrake = Input.is_action_pressed("jump")

	speed = CarLogic.next_speed(speed, throttle, handbrake, dt, data)
	rotate_y(CarLogic.turn_rate(speed, steer, data) * dt)
	var forward: Vector3 = -global_transform.basis.z
	velocity = forward * speed + Vector3(0, -3, 0)
	move_and_slide()
	resolve_bumps(forward, data.min_impact, data.impact_damage, data.run_over_speed)
	update_smoke(data.max_hp, Vector3(0, 1.0, -1.6))


func hurt(d: float) -> void:
	if dead:
		return
	hp -= d
	if hp <= 0.0:
		hp = 0.0
		dead = true
		speed = 0.0
		for c: Node in model.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = Build.mat(Color(0.08, 0.07, 0.06))
		main.explosion(global_position + Vector3.UP, 7.0)
		if driver:
			main.eject(data.eject_damage)
