extends CharacterBody3D
## Arcade fighter jet. Forward is -Z.

const MAX_SPEED := 150.0
const TAKEOFF := 55.0

var main
var is_jet := true
var enter_range := 9.0
var driver := false
var dead := false
var hp := 100.0
var speed := 0.0
var throttle := 0.0
var grounded := true
var flares := 12
var flare_cd := 0.0
var flame: Node3D
var gear: Node3D
var col: CollisionShape3D


func _ready() -> void:
	add_to_group("vehicles")
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.0, 2.4, 12.0)
	col = Build.collider(self, sh, Vector3(0, 1.2, 0))
	_build_model()


func _build_model() -> void:
	var grey := Color(0.42, 0.46, 0.52)
	var dark := Color(0.25, 0.28, 0.33)
	Build.box(self, Vector3(1.6, 1.3, 11.0), Vector3(0, 1.6, 0), grey)
	Build.cyl(self, 0.8, 3.2, Vector3(0, 1.6, -7.1), grey, Vector3(-PI / 2.0, 0, 0), 0.0)
	var canopy := Build.sphere(self, 0.7, Vector3(0, 2.3, -2.6), Color(0.1, 0.2, 0.35))
	canopy.scale = Vector3(1, 0.9, 2.4)
	for s in [-1.0, 1.0]:
		Build.box(self, Vector3(5.6, 0.18, 3.6), Vector3(s * 3.3, 1.5, 1.6), grey, false, Vector3(0, -s * 0.35, 0))
		Build.box(self, Vector3(2.6, 0.14, 1.7), Vector3(s * 1.9, 1.6, 5.0), dark, false, Vector3(0, -s * 0.3, 0))
		Build.box(self, Vector3(0.15, 2.4, 2.0), Vector3(s * 0.85, 2.9, 4.4), dark, false, Vector3(0.3, 0, -s * 0.3))
		Build.cyl(self, 0.5, 1.0, Vector3(s * 0.45, 1.5, 5.8), Color(0.1, 0.1, 0.1), Vector3(PI / 2.0, 0, 0))
	flame = Node3D.new()
	flame.position = Vector3(0, 1.5, 6.3)
	add_child(flame)
	for s in [-1.0, 1.0]:
		Build.cyl(flame, 0.42, 3.0, Vector3(s * 0.45, 0, 1.5), Color(1.0, 0.55, 0.15), Vector3(PI / 2.0, 0, 0), 0.0, 5.0)
	flame.visible = false
	gear = Node3D.new()
	add_child(gear)
	for p in [Vector3(0, 0.5, -3.5), Vector3(-1.2, 0.5, 1.5), Vector3(1.2, 0.5, 1.5)]:
		Build.box(gear, Vector3(0.18, 1.0, 0.18), p, Color(0.15, 0.15, 0.15))
		Build.cyl(gear, 0.28, 0.2, p + Vector3(0, -0.22, 0), Color(0.05, 0.05, 0.05), Vector3(0, 0, PI / 2.0))


func can_exit() -> bool:
	return grounded and speed < 3.0


func altitude() -> float:
	return global_position.y


func _physics_process(dt: float) -> void:
	if dead:
		return
	var ctl: bool = driver and not main.game_over
	flare_cd -= dt
	var pitch_in := 0.0
	var roll_in := 0.0
	if ctl:
		if Input.is_action_pressed("throttle_up"):
			throttle = minf(1.0, throttle + 0.7 * dt)
		if Input.is_action_pressed("throttle_down"):
			throttle = maxf(0.0, throttle - 0.9 * dt)
		pitch_in = Input.get_axis("forward", "back")
		roll_in = Input.get_axis("left", "right")
	elif not driver:
		throttle = 0.0
	flame.visible = throttle > 0.03
	flame.scale = Vector3(1, 1, 0.2 + throttle * 1.4)

	if grounded:
		_ground(dt, pitch_in, roll_in)
	else:
		_fly(dt, pitch_in, roll_in)
		if ctl and Input.is_action_just_pressed("flare") and flares > 0 and flare_cd <= 0.0:
			flares -= 1
			flare_cd = 1.0
			main.drop_flares(global_position, velocity)


func _ground(dt: float, pitch_in: float, roll_in: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	var target := throttle * MAX_SPEED
	speed = move_toward(speed, target, (24.0 if target > speed else 14.0) * dt)
	rotate_y(-roll_in * 0.9 * clampf(speed / 8.0, 0.0, 1.0) * dt)
	var fwd := -global_transform.basis.z
	velocity = fwd * speed + Vector3(0, -2, 0)
	move_and_slide()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.5:
			continue
		var other = c.get_collider()
		if other and other.is_in_group("soldiers"):
			other.hurt(999.0)
			continue
		var head_on := absf(n.dot(fwd))
		var impact := speed * head_on
		if impact > 8.0:
			hurt(impact * 0.8)
		speed *= 1.0 - head_on
	if dead:
		return
	if pitch_in > 0.2 and speed >= TAKEOFF:
		grounded = false
		gear.visible = false
		rotate_object_local(Vector3.RIGHT, 0.14)
		global_position.y += 0.6


func _fly(dt: float, pitch_in: float, roll_in: float) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	rotate_object_local(Vector3.RIGHT, pitch_in * 1.2 * dt)
	rotate_object_local(Vector3.FORWARD, roll_in * 2.4 * dt)
	var bank := global_transform.basis.x.y  # < 0 when the right wing is down
	if roll_in == 0.0:
		rotate_object_local(Vector3.FORWARD, bank * 1.2 * dt)
	global_rotate(Vector3.UP, bank * 1.1 * dt)
	orthonormalize()

	var fwd := -global_transform.basis.z
	speed = move_toward(speed, throttle * MAX_SPEED, 18.0 * dt)
	speed = maxf(0.0, speed - fwd.y * 20.0 * dt)
	velocity = fwd * speed
	if speed < TAKEOFF:  # stall: sink and drop the nose
		var k := (TAKEOFF - speed) / TAKEOFF
		velocity.y -= 40.0 * k
		rotate_object_local(Vector3.RIGHT, -0.6 * k * dt)
	move_and_slide()

	if get_slide_collision_count() > 0:
		var n := get_slide_collision(0).get_normal()
		if n.y > 0.8 and fwd.y > -0.3 and absf(bank) < 0.4:
			grounded = true
			gear.visible = true
			rotation = Vector3(0, atan2(-fwd.x, -fwd.z), 0)
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
		main.fail("EL CAZA HA SIDO DESTRUIDO")
