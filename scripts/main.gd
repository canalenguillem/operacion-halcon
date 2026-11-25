class_name Main
extends Node3D
## Operación Halcón: steal a car, break into the air base, steal a jet and escape.
## The whole world is generated here from primitives. North is -Z.

const Car = preload("res://scripts/car.gd")
const Jet = preload("res://scripts/jet.gd")
const Soldier = preload("res://scripts/soldier.gd")
const Missile = preload("res://scripts/missile.gd")
const Hud = preload("res://scripts/hud.gd")

const BASE_MIN := Vector2(-350, -1300)  # x, z
const BASE_MAX := Vector2(350, -700)
const GATE := Vector3(0, 0, -700)
const DEST := Vector3(6000, 0, 5000)
const ROUTE_SAMS := [Vector3(2300, 0, 900), Vector3(3700, 0, 3100)]

enum { GET_CAR, GO_BASE, GET_JET, ESCAPE, WON }

var stage := GET_CAR
var wanted := 0
var kills := 0
var base_alert := false
var game_over := false
var elapsed := 0.0

var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.15
var cam_dir := Vector3.BACK
var mouse_idle := 9.0

var player: Player
var vehicle = null
var jets: Array = []
var cars: Array = []
var sams: Array = []
var missiles: Array = []
var hud
var marker: MeshInstance3D
var barrier: Node3D
var barrier_open := false
var rng := RandomNumberGenerator.new()

var _shot_path := ""
var _shot_frames := 0
var _debug := false


func _ready() -> void:
	process_physics_priority = 10  # run after the actors so the camera sees fresh positions
	rng.seed = 7
	_build_sky()
	_build_ground()
	_build_city()
	_build_base()
	_build_dest()
	_spawn_actors()

	cam = Camera3D.new()
	cam.near = 0.2
	cam.far = 20000.0
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()

	hud = Hud.new()
	hud.main = self
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_parse_args()


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var o: Vector2 = PlayerLogic.orbit(cam_yaw, cam_pitch, (e as InputEventMouseMotion).relative, player.data)
			cam_yaw = o.x
			cam_pitch = o.y
			mouse_idle = 0.0
	elif e is InputEventMouseButton:
		if e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif e.is_action_pressed("interact") and not game_over:
		_interact()


func nearby_vehicle():
	var best = null
	var bd := 1e9
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.dead:
			continue
		var d: float = v.global_position.distance_to(player.global_position)
		if d < v.enter_range and d < bd:
			best = v
			bd = d
	return best


func _interact() -> void:
	if vehicle:
		if vehicle.can_exit():
			_exit_vehicle()
		else:
			hud.flash("Detén el vehículo para bajar")
		return
	var v = nearby_vehicle()
	if v:
		_enter_vehicle(v)


func _enter_vehicle(v) -> void:
	vehicle = v
	v.driver = true
	player.active = false
	player.visible = false
	player.col.set_deferred("disabled", true)
	cam_yaw = v.rotation.y
	cam_dir = v.global_transform.basis.z


func _exit_vehicle() -> void:
	var v = vehicle
	var side := 4.5 if v.is_jet else 2.6
	player.global_position = v.global_position - v.global_transform.basis.x * side + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.active = true
	player.visible = true
	player.col.set_deferred("disabled", false)
	v.driver = false
	vehicle = null


func eject(dmg: float) -> void:
	if vehicle:
		_exit_vehicle()
	player.hurt(dmg)


# ---------------------------------------------------------------- queries

func target_node():
	return vehicle if vehicle else player


func target_pos() -> Vector3:
	return target_node().global_position


func heading() -> float:
	if vehicle:
		var f: Vector3 = -vehicle.global_transform.basis.z
		return atan2(-f.x, -f.z)
	return player.model.rotation.y


func _nearest(list: Array) -> Vector3:
	var best := Vector3.ZERO
	var bd := 1e9
	var found := false
	for v in list:
		if v.dead:
			continue
		var d: float = v.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = v.global_position
			found = true
	return best if found else GATE


func objective_pos() -> Vector3:
	match stage:
		GET_CAR:
			return _nearest(cars)
		GO_BASE:
			return GATE
		GET_JET:
			return _nearest(jets)
	return DEST


func objective_text() -> String:
	match stage:
		GET_CAR:
			return "Consigue un coche"
		GO_BASE:
			return "Conduce hasta la base aérea"
		GET_JET:
			return "Entra en la base y roba un caza"
		ESCAPE:
			var d := Vector2(target_pos().x - DEST.x, target_pos().z - DEST.z).length()
			return "Despega y huye al aeródromo clandestino  ·  %.1f km" % (d / 1000.0)
	return ""


func nearest_missile() -> float:
	var best := 1e9
	for m in missiles:
		if is_instance_valid(m) and not m.dead and not m.decoyed:
			best = minf(best, m.distance())
	return best


# ---------------------------------------------------------------- game flow

func raise_alert() -> void:
	if base_alert:
		return
	base_alert = true
	wanted = maxi(wanted, 4)
	hud.flash("¡Zona restringida! Te han detectado")


func fail(msg: String) -> void:
	if game_over:
		return
	game_over = true
	hud.big(msg, "Pulsa R para reintentar", Color(1, 0.25, 0.2))


func _win() -> void:
	game_over = true
	stage = WON
	wanted = 0
	var t := int(elapsed)
	hud.big("MISIÓN CUMPLIDA", "Tiempo %d:%02d  ·  Bajas %d  ·  R para volver a jugar" % [t / 60, t % 60, kills], Color(0.4, 1.0, 0.5))


func _physics_process(dt: float) -> void:
	elapsed += dt
	if vehicle:
		player.global_position = vehicle.global_position
	if not game_over:
		_update_stage()
		_update_sams(dt)
	_update_marker()
	_update_camera(dt)
	if _debug and Engine.get_physics_frames() % 60 == 0:
		var v = target_node()
		print("t=%.0f pos=%s speed=%.0f grounded=%s hp=%.0f stage=%d over=%s" % [elapsed, v.global_position.round(), v.speed, v.grounded, v.hp, stage, game_over])
	if _shot_path != "":
		_shot_frames += 1
		if _shot_frames == 150:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _update_stage() -> void:
	var tp := target_pos()
	var in_base := tp.x > BASE_MIN.x and tp.x < BASE_MAX.x and tp.z > BASE_MIN.y and tp.z < BASE_MAX.y
	if in_base and stage < ESCAPE:
		raise_alert()
	if not barrier_open and tp.distance_to(GATE) < 14.0:
		barrier_open = true
		create_tween().tween_property(barrier, "rotation:z", 1.4, 0.35)

	var in_jet: bool = vehicle != null and vehicle.is_jet
	if in_jet and stage < ESCAPE:
		stage = ESCAPE
		wanted = 5
		raise_alert()
		hud.flash("¡Caza robado! Despega antes de que te acribillen")
	match stage:
		GET_CAR:
			if vehicle:
				stage = GO_BASE
				wanted = maxi(wanted, 1)
			elif in_base:
				stage = GET_JET
		GO_BASE:
			if in_base:
				stage = GET_JET
		GET_JET:
			var any := false
			for j in jets:
				any = any or not j.dead
			if not any:
				fail("NO QUEDAN CAZAS")
		ESCAPE:
			if not in_jet:
				stage = GET_JET
			elif Vector2(tp.x - DEST.x, tp.z - DEST.z).length() < 220.0:
				_win()


func _update_sams(dt: float) -> void:
	missiles = missiles.filter(func(m): return is_instance_valid(m) and not m.dead)
	if vehicle == null or not vehicle.is_jet or vehicle.dead or vehicle.global_position.y < 25.0:
		return
	var jp: Vector3 = vehicle.global_position
	for s in sams:
		s.cd -= dt
		var d: float = s.pos.distance_to(jp)
		if s.cd <= 0.0 and d < 2600.0 and d > 250.0 and missiles.size() < 2:
			s.cd = rng.randf_range(8.0, 12.0)
			var m = Missile.new()
			m.main = self
			m.target = vehicle
			m.position = s.pos + Vector3(0, 5, 0)
			add_child(m)
			missiles.append(m)
			explosion(s.pos + Vector3(0, 4, 0), 3.0)


func _update_marker() -> void:
	marker.visible = stage != WON
	var o := objective_pos()
	var r := 150.0 if stage == ESCAPE else 1.5
	var h := 5000.0 if stage == ESCAPE else 150.0
	marker.scale = Vector3(r, h, r)
	marker.position = Vector3(o.x, h / 2.0, o.z)


func _update_camera(dt: float) -> void:
	mouse_idle += dt
	if vehicle and vehicle.is_jet:
		var b: Basis = vehicle.global_transform.basis
		cam_dir = cam_dir.lerp(b.z, clampf(5.0 * dt, 0.0, 1.0)).normalized()
		var pos: Vector3 = vehicle.global_position + cam_dir * 26.0 + Vector3.UP * 7.0
		pos.y = maxf(pos.y, 1.0)
		cam.global_position = pos
		var look: Vector3 = vehicle.global_position - b.z * 40.0 + Vector3.UP * 2.0
		if absf((look - pos).normalized().y) < 0.97:
			cam.look_at(look, Vector3.UP)
		return

	var t = target_node()
	var is_car: bool = vehicle != null
	if is_car and mouse_idle > 1.0 and absf(vehicle.speed) > 3.0:
		cam_yaw = lerp_angle(cam_yaw, vehicle.rotation.y, 3.0 * dt)
		cam_pitch = lerpf(cam_pitch, -0.22, 3.0 * dt)
	var pivot: Vector3 = t.global_position + Vector3(0, 1.9 if is_car else player.data.cam_pivot_height, 0)
	var cb := Basis.from_euler(Vector3(cam_pitch, cam_yaw, 0))
	var off: Vector3 = Vector3(0, 0.4, 9.5) if is_car else player.data.cam_offset
	var want := pivot + cb * off
	var q := PhysicsRayQueryParameters3D.create(pivot, want)
	var ex: Array[RID] = [player.get_rid()]
	if vehicle:
		ex.append(vehicle.get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = pivot.lerp(hit.position, 0.9)
	want.y = maxf(want.y, 0.3)
	cam.global_transform = Transform3D(cb, want)


# ---------------------------------------------------------------- combat / effects

func player_shoot() -> void:
	var fwd := -cam.global_transform.basis.z
	var from := cam.global_position + fwd * (player.data.cam_offset.z + 0.3)
	var to := from + fwd * player.data.fire_range
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit.position
		if hit.collider.has_method("hurt"):
			hit.collider.hurt(player.data.damage)
	tracer(player.global_position + Vector3(0, 1.35, 0), end, Color(1, 0.9, 0.4))
	for s in get_tree().get_nodes_in_group("soldiers"):
		if not s.dead and not s.alert and s.global_position.distance_to(player.global_position) < player.data.noise_radius:
			s.alert = true
			raise_alert()


func tracer(a: Vector3, b: Vector3, color: Color) -> void:
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, len)
	var mi := Build.mesh(self, bm, (a + b) / 2.0, color, Vector3.ZERO, 4.0)
	var d := (b - a) / len
	mi.look_at(b, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.07).timeout.connect(mi.queue_free)


func explosion(pos: Vector3, radius: float) -> void:
	var s := Build.sphere(self, 1.0, pos, Color(1.0, 0.55, 0.1), 5.0)
	s.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * radius, 0.3)
	tw.tween_property(s, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(s.queue_free)
	var smoke := Build.sphere(self, 1.0, pos, Color(0.15, 0.15, 0.15, 0.6))
	smoke.scale = Vector3.ONE * 0.2
	var tw2 := create_tween()
	tw2.tween_property(smoke, "scale", Vector3.ONE * radius * 1.3, 0.9)
	tw2.parallel().tween_property(smoke, "position", pos + Vector3(0, radius, 0), 1.6)
	tw2.tween_property(smoke, "scale", Vector3.ONE * 0.01, 0.7)
	tw2.tween_callback(smoke.queue_free)


func drop_flares(pos: Vector3, vel: Vector3) -> void:
	for i in 3:
		var f := Build.sphere(self, 0.9, pos, Color(1.0, 0.95, 0.6), 6.0)
		var end := pos + vel * 0.6 + Vector3(rng.randf_range(-30, 30), -70, rng.randf_range(-30, 30))
		var tw := create_tween()
		tw.tween_property(f, "position", end, 2.5)
		tw.tween_callback(f.queue_free)
	for m in missiles:
		if is_instance_valid(m) and m.global_position.distance_to(pos) < 1200.0 and rng.randf() < 0.75:
			m.decoyed = true


# ---------------------------------------------------------------- world

func _build_sky() -> void:
	var haze := Color(0.75, 0.82, 0.9)
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.2, 0.45, 0.85)
	sm.sky_horizon_color = haze
	sm.ground_horizon_color = haze
	sm.ground_bottom_color = Color(0.35, 0.4, 0.35)
	var sky := Sky.new()
	sky.sky_material = sm
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = haze
	env.fog_density = 0.00013
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	sun.light_energy = 1.2
	add_child(sun)


func _clear_spot(x: float, z: float) -> bool:
	if x > BASE_MIN.x - 60 and x < BASE_MAX.x + 60 and z > BASE_MIN.y - 60 and z < BASE_MAX.y + 60:
		return false
	if absf(x) < 220 and z > -240 and z < 340:
		return false
	if absf(x) < 22 and z > -720 and z < 360:
		return false
	if Vector2(x - DEST.x, z - DEST.z).length() < 320:
		return false
	return true


func _build_ground() -> void:
	var body := StaticBody3D.new()
	Build.collider(body, WorldBoundaryShape3D.new())
	add_child(body)

	var noise := FastNoiseLite.new()
	noise.frequency = 0.015
	var grad := Gradient.new()
	grad.set_color(0, Color(0.27, 0.4, 0.2))
	grad.set_color(1, Color(0.56, 0.56, 0.34))
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = tex
	gm.uv1_scale = Vector3(300, 300, 1)
	gm.roughness = 1.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = gm
	add_child(mi)

	# trees (visual only)
	var spots: Array[Transform3D] = []
	while spots.size() < 3500:
		var x := rng.randf_range(-4500, 7500)
		var z := rng.randf_range(-3000, 6500)
		if _clear_spot(x, z):
			var s := rng.randf_range(0.8, 1.8)
			spots.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, 0, z)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.35
	trunk.height = 3.0
	trunk.radial_segments = 6
	trunk.material = Build.mat(Color(0.35, 0.25, 0.15))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 2.2
	crown.height = 6.0
	crown.radial_segments = 7
	crown.material = Build.mat(Color(0.14, 0.33, 0.14))
	for part in [[trunk, 1.5], [crown, 5.5]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = spots.size()
		for i in spots.size():
			var t := spots[i]
			t.origin.y = part[1] * t.basis.get_scale().y
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)

	# hills (solid: don't fly into them)
	var made := 0
	while made < 16:
		var x := rng.randf_range(-5000, 8000)
		var z := rng.randf_range(-4000, 7000)
		var r := rng.randf_range(300, 700)
		var p := Vector2(x, z)
		var ok := p.distance_to(Vector2(0, -1000)) > 1300 + r and p.distance_to(Vector2(0, 50)) > 600 + r
		ok = ok and p.distance_to(Vector2(DEST.x, DEST.z)) > 900 + r and absf(x) > r + 40
		for s in ROUTE_SAMS:
			ok = ok and p.distance_to(Vector2(s.x, s.z)) > r + 150
		if not ok:
			continue
		made += 1
		var h := rng.randf_range(150, 450)
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.12
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 10
		cm.rings = 1
		var hill := Build.mesh(self, cm, Vector3(x, h / 2.0 - 4.0, z), Color(0.36, 0.4, 0.26))
		var sb := StaticBody3D.new()
		Build.collider(sb, cm.create_convex_shape())
		hill.add_child(sb)


func _build_city() -> void:
	var road := Color(0.16, 0.16, 0.18)
	Build.box(self, Vector3(14, 0.1, 1040), Vector3(0, 0.04, -180), road)
	for i in 52:
		Build.box(self, Vector3(0.3, 0.1, 6), Vector3(0, 0.06, 330 - i * 20), Color(0.9, 0.85, 0.5))
	for z in range(-210, 300, 60):
		Build.box(self, Vector3(420, 0.1, 10), Vector3(0, 0.02, z), road)
	for x in [-160, -100, -40, 40, 100, 160]:
		for z in range(-180, 300, 60):
			if rng.randf() < 0.12:
				continue
			var w := rng.randf_range(22, 40)
			var d := rng.randf_range(22, 40)
			var h := rng.randf_range(8, 45)
			var c := Color.from_hsv(rng.randf_range(0.02, 0.14), rng.randf_range(0.1, 0.35), rng.randf_range(0.55, 0.9))
			Build.box(self, Vector3(w, h, d), Vector3(x, h / 2.0, z), c, true)
			Build.box(self, Vector3(w + 0.1, h * 0.12, d + 0.1), Vector3(x, h * 0.55, z), Color(0.15, 0.2, 0.28))


func _build_sam(pos: Vector3) -> void:
	Build.box(self, Vector3(5, 1.6, 5), pos + Vector3(0, 0.8, 0), Color(0.25, 0.3, 0.2), true)
	for sx in [-1.2, 1.2]:
		Build.cyl(self, 0.5, 5.0, pos + Vector3(sx, 3.2, 0), Color(0.8, 0.8, 0.75), Vector3(0.5, 0, 0))
	sams.append({"pos": pos, "cd": rng.randf_range(4.0, 9.0)})


func _build_base() -> void:
	var cx := (BASE_MIN.x + BASE_MAX.x) / 2.0
	var cz := (BASE_MIN.y + BASE_MAX.y) / 2.0
	var w := BASE_MAX.x - BASE_MIN.x
	var d := BASE_MAX.y - BASE_MIN.y
	var concrete := Color(0.33, 0.33, 0.32)
	var fence := Color(0.3, 0.33, 0.3)
	Build.box(self, Vector3(w, 0.1, d), Vector3(cx, 0.0, cz), concrete)
	# perimeter fence with a gate gap on the south side
	Build.box(self, Vector3(w, 4, 1), Vector3(cx, 2, BASE_MIN.y), fence, true)
	Build.box(self, Vector3(1, 4, d), Vector3(BASE_MIN.x, 2, cz), fence, true)
	Build.box(self, Vector3(1, 4, d), Vector3(BASE_MAX.x, 2, cz), fence, true)
	var seg := w / 2.0 - 9.0
	for s in [-1.0, 1.0]:
		Build.box(self, Vector3(seg, 4, 1), Vector3(s * (9.0 + seg / 2.0), 2, BASE_MAX.y), fence, true)
		Build.box(self, Vector3(5, 3.5, 5), Vector3(s * 14.0, 1.75, BASE_MAX.y + 6.0), Color(0.6, 0.6, 0.55), true)
	barrier = Node3D.new()
	barrier.position = Vector3(-8, 1.1, BASE_MAX.y)
	add_child(barrier)
	Build.box(barrier, Vector3(16, 0.25, 0.25), Vector3(8, 0, 0), Color(0.9, 0.15, 0.1))

	# runway (east-west) and apron
	Build.box(self, Vector3(660, 0.1, 40), Vector3(0, 0.08, -1200), Color(0.13, 0.13, 0.15))
	for i in 16:
		Build.box(self, Vector3(18, 0.1, 0.8), Vector3(-300 + i * 40, 0.1, -1200), Color(0.95, 0.95, 0.95))
	Build.box(self, Vector3(240, 0.1, 110), Vector3(205, 0.06, -1125), Color(0.38, 0.38, 0.38))
	# hangars
	for x in [160.0, 250.0]:
		Build.box(self, Vector3(70, 16, 36), Vector3(x, 8, -1050), Color(0.55, 0.58, 0.55), true)
		Build.box(self, Vector3(50, 12, 0.5), Vector3(x, 6, -1068.2), Color(0.12, 0.13, 0.15))
	# control tower
	Build.box(self, Vector3(10, 30, 10), Vector3(-60, 15, -1060), Color(0.7, 0.7, 0.68), true)
	Build.box(self, Vector3(15, 5, 15), Vector3(-60, 32.5, -1060), Color(0.15, 0.3, 0.4))
	Build.cyl(self, 0.3, 10, Vector3(-60, 40, -1060), Color(0.9, 0.2, 0.2))
	# barracks
	for p in [Vector2(-270, -800), Vector2(-200, -800), Vector2(-270, -860), Vector2(-200, -860), Vector2(-130, -830)]:
		Build.box(self, Vector3(44, 6, 16), Vector3(p.x, 3, p.y), Color(0.4, 0.44, 0.3), true)
	# fuel tanks
	for i in 3:
		var tp := Vector3(40.0 + i * 14.0, 4, -820)
		Build.cyl(self, 5.5, 8, tp, Color(0.85, 0.85, 0.82))
		Build.box(self, Vector3(9, 8, 9), tp, Color(0.85, 0.85, 0.82), true).visible = false

	_build_sam(Vector3(-300, 0, -760))
	_build_sam(Vector3(300, 0, -1270))
	_build_sam(Vector3(-300, 0, -1270))
	for s in ROUTE_SAMS:
		_build_sam(s)


func _build_dest() -> void:
	Build.box(self, Vector3(30, 0.1, 500), DEST + Vector3(0, 0.05, 0), Color(0.45, 0.36, 0.25))
	Build.box(self, Vector3(18, 6, 14), DEST + Vector3(40, 3, 60), Color(0.5, 0.3, 0.2), true)
	Build.box(self, Vector3(12, 5, 20), DEST + Vector3(45, 2.5, 20), Color(0.35, 0.38, 0.3), true)
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 24
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.2, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	marker = MeshInstance3D.new()
	marker.mesh = cm
	marker.material_override = m
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)


func _spawn_actors() -> void:
	player = Player.new()
	player.main = self
	player.position = Vector3(0, 0.2, 262)
	add_child(player)

	var car_spots := [
		[Vector3(4.5, 0.1, 245), Color(0.8, 0.12, 0.1)],
		[Vector3(-4.5, 0.1, 200), Color(0.1, 0.35, 0.8)],
		[Vector3(4.5, 0.1, 130), Color(0.9, 0.75, 0.1)],
		[Vector3(-4.5, 0.1, 30), Color(0.85, 0.85, 0.85)],
		[Vector3(4.5, 0.1, -400), Color(0.15, 0.5, 0.25)],
	]
	for cs in car_spots:
		var c = Car.new()
		c.main = self
		c.color = cs[1]
		c.position = cs[0]
		add_child(c)
		cars.append(c)

	for x in [160.0, 250.0]:
		var j = Jet.new()
		j.main = self
		j.position = Vector3(x, 0.1, -1130)
		add_child(j)
		jets.append(j)

	var posts := [
		Vector2(-10, -712), Vector2(10, -712), Vector2(-18, -735), Vector2(18, -735),
		Vector2(140, -1100), Vector2(205, -1105), Vector2(285, -1100), Vector2(205, -1160),
		Vector2(120, -1150), Vector2(300, -1150),
		Vector2(-235, -830), Vector2(-165, -830), Vector2(-235, -890), Vector2(-130, -810),
		Vector2(-50, -1040), Vector2(-72, -1085), Vector2(0, -1170), Vector2(-150, -1170),
	]
	for p in posts:
		var s = Soldier.new()
		s.main = self
		s.position = Vector3(p.x, 0.1, p.y)
		add_child(s)


# ---------------------------------------------------------------- dev helpers
# godot --path . -- --at=x,y,z --test-jet --shot=/path/out.png

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--at="):
			var p := a.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(p[0], p[1], p[2])
		elif a == "--test-takeoff":
			_enter_vehicle(jets[1])
			Input.action_press("forward")  # lo que hace un jugador nuevo: solo W, sin soltarla
			_debug = true
		elif a == "--test-jet":
			var j = jets[0]
			_enter_vehicle(j)
			j.position = Vector3(250, 220, -1200)
			j.rotation.y = PI / 2.0
			j.grounded = false
			j.gear.visible = false
			j.throttle = 1.0
			j.speed = 120.0
