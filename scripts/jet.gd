class_name Jet
extends Vehicle
## Caza arcade. El frente es -Z. Los ajustes están en `data/jet.tres`.

var data: JetData = preload("res://data/jet.tres")
## Potencia de 0 a 1.
var throttle: float = 0.0
var grounded: bool = true
var flares: int = 12
var flare_cd: float = 0.0
## Tras despegar con W pulsada, W no baja el morro hasta que se suelta.
var nose_lock: bool = false
var flame: Node3D
var gear: Node3D
var col: CollisionShape3D


func _ready() -> void:
	is_jet = true
	hp = data.max_hp
	enter_range = data.enter_range
	flares = data.flares
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.0, 2.4, 12.0)
	col = Build.collider(self, sh, Vector3(0, 1.2, 0))
	_build_model()


func _build_model() -> void:
	var grey := Color(0.42, 0.46, 0.52)
	var dark := Color(0.25, 0.28, 0.33)
	var light := Color(0.55, 0.59, 0.64)
	Build.box(self, Vector3(1.5, 1.2, 10.4), Vector3(0, 1.6, 0.3), grey)
	Build.box(self, Vector3(0.9, 0.35, 6.5), Vector3(0, 2.3, 1.6), dark)
	Build.cyl(self, 0.78, 3.4, Vector3(0, 1.6, -6.6), grey, Vector3(-PI / 2.0, 0, 0), 0.12)
	Build.cyl(self, 0.12, 1.4, Vector3(0, 1.6, -8.9), dark, Vector3(-PI / 2.0, 0, 0), 0.02)
	var canopy: MeshInstance3D = Build.sphere(self, 0.7, Vector3(0, 2.25, -2.8), Color(0.08, 0.18, 0.32))
	canopy.scale = Vector3(0.95, 0.9, 2.6)
	# alas, estabilizadores y derivas: polígonos (x, z) extruidos
	for s: float in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(s * 0.7, -1.6), Vector2(s * 5.4, 2.3), Vector2(s * 5.4, 3.5), Vector2(s * 0.7, 3.7)])
		Build.extrude(self, wing, 0.18, Vector3(0, 1.5, 0), grey)
		var strake := PackedVector2Array([Vector2(s * 0.7, -4.6), Vector2(s * 1.5, -1.6), Vector2(s * 0.7, -1.2)])
		Build.extrude(self, strake, 0.14, Vector3(0, 1.55, 0), light)
		var tail := PackedVector2Array([Vector2(s * 0.7, 4.1), Vector2(s * 3.1, 5.6), Vector2(s * 3.1, 6.3), Vector2(s * 0.7, 6.1)])
		Build.extrude(self, tail, 0.14, Vector3(0, 1.55, 0), dark)
		var fin := PackedVector2Array([Vector2(0, 3.2), Vector2(2.5, 5.1), Vector2(2.5, 5.9), Vector2(0, 6.0)])
		Build.extrude(self, fin, 0.14, Vector3(s * 0.75, 2.1, 0), dark, Vector3(0, 0, PI / 2.0 - s * 0.3))
		Build.box(self, Vector3(0.75, 0.85, 4.2), Vector3(s * 1.1, 1.4, -0.4), light)
		Build.box(self, Vector3(0.6, 0.7, 0.1), Vector3(s * 1.1, 1.4, -2.52), Color(0.04, 0.04, 0.05))
		Build.cyl(self, 0.55, 1.1, Vector3(s * 0.45, 1.5, 5.9), Color(0.1, 0.1, 0.1), Vector3(PI / 2.0, 0, 0), 0.42)
		Build.cyl(self, 0.1, 2.6, Vector3(s * 5.45, 1.5, 2.6), Color(0.9, 0.9, 0.9), Vector3(-PI / 2.0, 0, 0))
		Build.cyl(self, 0.1, 0.4, Vector3(s * 5.45, 1.5, 1.1), Color(0.8, 0.15, 0.1), Vector3(-PI / 2.0, 0, 0), 0.0)
	flame = Node3D.new()
	flame.position = Vector3(0, 1.5, 6.3)
	add_child(flame)
	for s: float in [-1.0, 1.0]:
		Build.cyl(flame, 0.42, 3.0, Vector3(s * 0.45, 0, 1.5), Color(1.0, 0.55, 0.15), Vector3(PI / 2.0, 0, 0), 0.0, 5.0)
	flame.visible = false
	gear = Node3D.new()
	add_child(gear)
	for p: Vector3 in [Vector3(0, 0.5, -3.5), Vector3(-1.2, 0.5, 1.5), Vector3(1.2, 0.5, 1.5)]:
		Build.box(gear, Vector3(0.18, 1.0, 0.18), p, Color(0.15, 0.15, 0.15))
		Build.cyl(gear, 0.28, 0.2, p + Vector3(0, -0.22, 0), Color(0.05, 0.05, 0.05), Vector3(0, 0, PI / 2.0))


func can_exit() -> bool:
	return grounded and speed < data.exit_speed


func altitude() -> float:
	return global_position.y


func _physics_process(dt: float) -> void:
	if dead:
		return
	var ctl: bool = controlled()
	flare_cd -= dt
	var pitch_in: float = 0.0
	var roll_in: float = 0.0
	if ctl:
		if Input.is_action_pressed("throttle_up"):
			throttle = minf(1.0, throttle + data.throttle_up * dt)
		if Input.is_action_pressed("throttle_down"):
			throttle = maxf(0.0, throttle - data.throttle_down * dt)
		pitch_in = Input.get_axis("forward", "back")
		roll_in = Input.get_axis("left", "right")
		if grounded:
			throttle = JetLogic.ground_throttle(throttle, pitch_in, speed, dt, data)
		elif nose_lock:
			if pitch_in >= 0.0:
				nose_lock = false
			else:
				pitch_in = 0.0
	elif not driver:
		throttle = 0.0
	update_smoke(data.max_hp, Vector3(0, 1.8, 5.0))
	flame.visible = throttle > 0.03
	flame.scale = Vector3(1, 1, 0.2 + throttle * 1.4)

	if grounded:
		_ground(dt, pitch_in, roll_in)
	else:
		_fly(dt, pitch_in, roll_in)
		if ctl and Input.is_action_just_pressed("flare") and flares > 0 and flare_cd <= 0.0:
			flares -= 1
			flare_cd = data.flare_cooldown
			main.drop_flares(global_position, velocity)


func _ground(dt: float, pitch_in: float, roll_in: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	var target: float = throttle * data.max_speed
	speed = move_toward(speed, target, (data.ground_acceleration if target > speed else data.ground_brake) * dt)
	rotate_y(-roll_in * data.ground_steer * clampf(speed / 8.0, 0.0, 1.0) * dt)
	var forward: Vector3 = -global_transform.basis.z
	velocity = forward * speed + Vector3(0, -2, 0)
	move_and_slide()
	resolve_bumps(forward, data.min_impact, data.impact_damage, 0.0)
	if dead:
		return
	if JetLogic.should_lift(pitch_in, speed, data):
		grounded = false
		nose_lock = pitch_in < 0.0
		gear.visible = false
		rotate_object_local(Vector3.RIGHT, data.liftoff_pitch)
		global_position.y += 0.6


func _fly(dt: float, pitch_in: float, roll_in: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	rotate_object_local(Vector3.RIGHT, pitch_in * data.pitch_rate * dt)
	rotate_object_local(Vector3.FORWARD, roll_in * data.roll_rate * dt)
	var bank: float = global_transform.basis.x.y  # < 0 con el ala derecha abajo
	if roll_in == 0.0:
		rotate_object_local(Vector3.FORWARD, bank * data.auto_level * dt)
	global_rotate(Vector3.UP, bank * data.bank_turn * dt)
	orthonormalize()

	var forward: Vector3 = -global_transform.basis.z
	speed = JetLogic.air_speed(speed, throttle, forward.y, dt, data)
	velocity = forward * speed
	var stall: float = JetLogic.stall(speed, data)
	if stall > 0.0:
		velocity.y -= data.stall_sink * stall
		rotate_object_local(Vector3.RIGHT, -data.stall_nose_drop * stall * dt)
	move_and_slide()

	if get_slide_collision_count() > 0:
		if JetLogic.can_land(get_slide_collision(0).get_normal(), forward, bank):
			grounded = true
			gear.visible = true
			rotation = Vector3(0, PlayerLogic.facing_yaw(forward), 0)
		else:
			die()


func hurt(d: float) -> void:
	if dead:
		return
	hp -= d
	if hp <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	visible = false
	col.set_deferred("disabled", true)
	main.explosion(global_position, 16.0)
	if driver:
		main.mission.fail("EL CAZA HA SIDO DESTRUIDO")
