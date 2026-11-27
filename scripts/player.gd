class_name Player
extends CharacterBody3D
## Jugador a pie. Los ajustes están en `data/player.tres`.

var main: Main
var data: PlayerData = preload("res://data/player.tres")
var health: float = 100.0
var active: bool = true  # false dentro de un vehículo
var dead: bool = false
var shoot_cd: float = 0.0
var last_hurt: float = 99.0
var col: CollisionShape3D
var model: Humanoid
## Segundos que el brazo sigue apuntando tras disparar.
var aim_t: float = 0.0


func _init() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.ALL


func _ready() -> void:
	health = data.max_health
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col = Build.collider(self, cap, Vector3(0, 0.9, 0))
	model = Humanoid.new()
	add_child(model)
	model.build(Color(0.85, 0.3, 0.15), Color(0.15, 0.2, 0.4), Color(0.9, 0.72, 0.58), Color(0.2, 0.13, 0.08), 0.28)


func _physics_process(dt: float) -> void:
	if not active or main.game_over:
		return
	shoot_cd -= dt
	last_hurt += dt
	health = PlayerLogic.regen(health, last_hurt, dt, data)

	var yaw: float = main.camera.yaw
	var dir: Vector3 = PlayerLogic.move_dir(Input.get_vector("left", "right", "forward", "back"), yaw)
	var sp: float = PlayerLogic.target_speed(Input.is_action_pressed("sprint"), data)
	velocity.x = move_toward(velocity.x, dir.x * sp, data.acceleration * dt)
	velocity.z = move_toward(velocity.z, dir.z * sp, data.acceleration * dt)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = data.jump_speed
	else:
		velocity.y -= data.gravity * dt
	move_and_slide()
	aim_t -= dt
	model.animate(Vector2(velocity.x, velocity.z).length(), dt, aim_t > 0.0)

	var shooting: bool = Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if shooting:
		aim_t = 0.6
		model.rotation.y = lerp_angle(model.rotation.y, yaw, 20.0 * dt)
		if shoot_cd <= 0.0:
			shoot_cd = data.fire_interval
			main.combat.player_shoot()
	elif dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, PlayerLogic.facing_yaw(dir), data.turn_speed * dt)


func hurt(d: float) -> void:
	if not active or dead:
		return
	health -= d
	last_hurt = 0.0
	main.combat.on_player_hurt()
	if health <= 0.0:
		health = 0.0
		dead = true
		model.rotation.x = -PI / 2.0
		main.mission.fail("TE HAN ABATIDO")
