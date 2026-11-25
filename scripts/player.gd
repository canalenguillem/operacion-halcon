extends CharacterBody3D

const Build = preload("res://scripts/build.gd")

var main
var health := 100.0
var active := true  # false while inside a vehicle
var dead := false
var shoot_cd := 0.0
var last_hurt := 99.0
var col: CollisionShape3D
var model: Node3D


func _ready() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col = Build.collider(self, cap, Vector3(0, 0.9, 0))
	model = Node3D.new()
	add_child(model)
	Build.box(model, Vector3(0.5, 0.8, 0.28), Vector3(0, 0.4, 0), Color(0.15, 0.2, 0.4))
	Build.box(model, Vector3(0.55, 0.7, 0.3), Vector3(0, 1.15, 0), Color(0.85, 0.3, 0.15))
	Build.sphere(model, 0.17, Vector3(0, 1.68, 0), Color(0.9, 0.72, 0.58))
	Build.box(model, Vector3(0.12, 0.12, 0.55), Vector3(0.33, 1.25, -0.3), Color(0.85, 0.3, 0.15))
	Build.box(model, Vector3(0.07, 0.14, 0.3), Vector3(0.33, 1.3, -0.65), Color(0.08, 0.08, 0.08))


func _physics_process(dt: float) -> void:
	if not active or main.game_over:
		return
	shoot_cd -= dt
	last_hurt += dt
	if last_hurt > 6.0:
		health = minf(100.0, health + 4.0 * dt)

	var iv := Input.get_vector("left", "right", "forward", "back")
	var yaw: float = main.cam_yaw
	var dir := Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, yaw)
	var sp := 9.0 if Input.is_action_pressed("sprint") else 5.0
	velocity.x = move_toward(velocity.x, dir.x * sp, 50.0 * dt)
	velocity.z = move_toward(velocity.z, dir.z * sp, 50.0 * dt)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = 8.0
	else:
		velocity.y -= 25.0 * dt
	move_and_slide()

	var shooting := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if shooting:
		model.rotation.y = lerp_angle(model.rotation.y, yaw, 20.0 * dt)
		if shoot_cd <= 0.0:
			shoot_cd = 0.22
			main.player_shoot()
	elif dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 12.0 * dt)


func hurt(d: float) -> void:
	if not active or dead:
		return
	health -= d
	last_hurt = 0.0
	if health <= 0.0:
		health = 0.0
		dead = true
		model.rotation.x = -PI / 2.0
		main.fail("TE HAN ABATIDO")
