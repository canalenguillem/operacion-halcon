class_name Main
extends Node3D
## Operación Halcón: une el mundo, los actores, la misión, la cámara y los efectos.

var mission: MissionState = MissionState.new()
var world: World
var kills: int = 0
## Segundos que queda visible la marca de impacto.
var hit_t: float = 0.0
var hit_kill: bool = false
var elapsed: float = 0.0

var cam: Camera3D
var cam_yaw: float = 0.0
var cam_pitch: float = -0.15
var cam_dir: Vector3 = Vector3.BACK
var mouse_idle: float = 9.0

var player: Player
## Vehículo que conduce el jugador, o null si va a pie.
var vehicle: Vehicle = null
var cars: Array[Car] = []
var jets: Array[Jet] = []
var soldiers: Array[Soldier] = []
var missiles: Array[Missile] = []
var missile_data: MissileData = preload("res://data/missile.tres")
## Segundos hasta el próximo disparo de cada batería (mismo orden que `world.sam_positions`).
var sam_cooldowns: Array[float] = []
var hud: Hud
var menu: Menu
## Ponlo a false antes de añadir la escena para arrancar sin menú (tests).
var show_menu: bool = true
## Al reiniciar la misión no se vuelve a pasar por el menú principal.
static var skip_menu: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var game_over: bool:
	get:
		return mission.over

var _debug: bool = false


func _ready() -> void:
	process_physics_priority = 10  # después de los actores, para que la cámara vea posiciones ya actualizadas
	rng.seed = 7
	world = World.new()
	add_child(world)
	world.build()
	for i: int in world.sam_positions.size():
		sam_cooldowns.append(rng.randf_range(missile_data.first_shot_min, missile_data.first_shot_max))
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

	mission.alert_raised.connect(_on_alert_raised)
	mission.jet_stolen.connect(_on_jet_stolen)
	mission.failed.connect(_on_failed)
	mission.completed.connect(_on_completed)

	Settings.load_file()
	menu = Menu.new()
	menu.play_pressed.connect(_on_play_pressed)
	menu.restart_pressed.connect(restart)
	menu.main_menu_pressed.connect(_on_main_menu_pressed)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu_layer.add_child(menu)

	var dev: bool = _parse_args()
	_update_camera(0.0)
	if show_menu and not skip_menu and not dev:
		hud.visible = false
		menu.open(Menu.Screen.MAIN)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	skip_menu = false


func _spawn_actors() -> void:
	player = Player.new()
	player.main = self
	player.position = World.PLAYER_START
	add_child(player)
	for i: int in World.CAR_SPOTS.size():
		var c := Car.new()
		c.main = self
		c.color = World.CAR_COLORS[i]
		c.position = World.CAR_SPOTS[i]
		add_child(c)
		cars.append(c)
	for p: Vector3 in World.JET_SPOTS:
		var j := Jet.new()
		j.main = self
		j.position = p
		add_child(j)
		jets.append(j)
	for p: Vector2 in World.SOLDIER_POSTS:
		var s := Soldier.new()
		s.main = self
		s.position = Vector3(p.x, 0.1, p.y)
		add_child(s)
		soldiers.append(s)


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var o: Vector2 = PlayerLogic.orbit(cam_yaw, cam_pitch, (e as InputEventMouseMotion).relative * Settings.mouse_scale, player.data)
			cam_yaw = o.x
			cam_pitch = o.y
			mouse_idle = 0.0
	elif e is InputEventMouseButton:
		if e.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu.open(Menu.Screen.PAUSE)
	elif e.is_action_pressed("restart"):
		restart()
	elif e.is_action_pressed("interact") and not game_over:
		_interact()


## Vuelve a empezar la misión sin pasar por el menú principal.
func restart() -> void:
	skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_play_pressed() -> void:
	hud.visible = true


func _on_main_menu_pressed() -> void:
	skip_menu = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func vehicles() -> Array[Vehicle]:
	var out: Array[Vehicle] = []
	out.append_array(cars)
	out.append_array(jets)
	return out


## El vehículo más cercano al que el jugador puede subir, o null.
func nearby_vehicle() -> Vehicle:
	var best: Vehicle = null
	var best_dist: float = 1e9
	for v: Vehicle in vehicles():
		if v.dead:
			continue
		var d: float = v.global_position.distance_to(player.global_position)
		if d < v.enter_range and d < best_dist:
			best = v
			best_dist = d
	return best


func _interact() -> void:
	if vehicle != null:
		if vehicle.can_exit():
			_exit_vehicle()
		else:
			hud.flash("Detén el vehículo para bajar")
		return
	var v: Vehicle = nearby_vehicle()
	if v != null:
		_enter_vehicle(v)


func _enter_vehicle(v: Vehicle) -> void:
	vehicle = v
	v.driver = true
	player.active = false
	player.visible = false
	player.col.set_deferred("disabled", true)
	cam_yaw = v.rotation.y
	cam_dir = v.global_transform.basis.z


func _exit_vehicle() -> void:
	var v: Vehicle = vehicle
	var side: float = 4.5 if v.is_jet else 2.6
	player.global_position = v.global_position - v.global_transform.basis.x * side + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.active = true
	player.visible = true
	player.col.set_deferred("disabled", false)
	v.driver = false
	vehicle = null


## Saca al jugador del vehículo (porque ha explotado) y le hace daño.
func eject(dmg: float) -> void:
	if vehicle != null:
		_exit_vehicle()
	player.hurt(dmg)


# ---------------------------------------------------------------- consultas

## Lo que los enemigos persiguen: el vehículo que conduces o, a pie, el jugador.
func target_node() -> Node3D:
	return vehicle if vehicle != null else player


func target_pos() -> Vector3:
	return target_node().global_position


func heading() -> float:
	if vehicle != null:
		return PlayerLogic.facing_yaw(-vehicle.global_transform.basis.z)
	return player.model.rotation.y


func _nearest_alive(list: Array[Vehicle]) -> Vector3:
	var best: Vector3 = World.GATE
	var best_dist: float = 1e9
	for v: Vehicle in list:
		if v.dead:
			continue
		var d: float = v.global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best = v.global_position
	return best


func objective_pos() -> Vector3:
	match mission.stage:
		MissionState.Stage.GET_CAR:
			var list: Array[Vehicle] = []
			list.append_array(cars)
			return _nearest_alive(list)
		MissionState.Stage.GO_BASE:
			return World.GATE
		MissionState.Stage.GET_JET:
			var list: Array[Vehicle] = []
			list.append_array(jets)
			return _nearest_alive(list)
	return World.DEST


func objective_text() -> String:
	var text: String = mission.objective_text()
	if mission.stage == MissionState.Stage.ESCAPE:
		text += "  ·  %.1f km" % (World.dest_distance(target_pos()) / 1000.0)
	return text


## Distancia del misil más cercano que aún persigue al caza (1e9 si no hay).
func nearest_missile() -> float:
	var best: float = 1e9
	for m: Missile in missiles:
		if is_instance_valid(m) and not m.dead and not m.decoyed:
			best = minf(best, m.distance())
	return best


# ---------------------------------------------------------------- misión

func _on_alert_raised() -> void:
	hud.flash("¡Zona restringida! Te han detectado")


func _on_jet_stolen() -> void:
	hud.flash("¡Caza robado! Despega antes de que te acribillen")


func _on_failed(reason: String) -> void:
	hud.big(reason, "Pulsa R para reintentar", Color(1, 0.25, 0.2))


func _on_completed() -> void:
	var record: String = "  ·  ¡NUEVO RÉCORD!" if Settings.submit_time(elapsed) else ""
	hud.big("MISIÓN CUMPLIDA", "Tiempo %s%s  ·  Bajas %d  ·  R para volver a jugar" % [Settings.format_time(elapsed), record, kills], Color(0.4, 1.0, 0.5))


func _physics_process(dt: float) -> void:
	elapsed += dt
	hit_t -= dt
	if vehicle != null:
		player.global_position = vehicle.global_position
	if not game_over:
		_update_mission()
		_update_sams(dt)
	world.set_marker(objective_pos(), mission.stage == MissionState.Stage.ESCAPE, mission.stage != MissionState.Stage.WON)
	_update_camera(dt)
	_dev_tick()


func _update_mission() -> void:
	var tp: Vector3 = target_pos()
	if tp.distance_to(World.GATE) < 14.0:
		world.open_barrier()
	var jets_alive: int = 0
	for j: Jet in jets:
		if not j.dead:
			jets_alive += 1
	var in_jet: bool = vehicle != null and vehicle.is_jet
	mission.step(vehicle != null, in_jet, World.in_base(tp), jets_alive, World.dest_distance(tp))


func _update_sams(dt: float) -> void:
	missiles = missiles.filter(func(m: Missile) -> bool: return is_instance_valid(m) and not m.dead)
	var jet: Jet = vehicle as Jet
	if jet == null or jet.dead:
		return
	var jp: Vector3 = jet.global_position
	for i: int in world.sam_positions.size():
		var pos: Vector3 = world.sam_positions[i]
		sam_cooldowns[i] -= dt
		if sam_cooldowns[i] <= 0.0 and MissileLogic.can_fire(pos.distance_to(jp), jp.y, missiles.size(), missile_data):
			sam_cooldowns[i] = rng.randf_range(missile_data.reload_min, missile_data.reload_max) * Settings.sam_reload_scale()
			var m := Missile.new()
			m.main = self
			m.data = missile_data
			m.target = jet
			m.position = pos + Vector3(0, 5, 0)
			add_child(m)
			missiles.append(m)
			explosion(pos + Vector3(0, 4, 0), 3.0)


func _update_camera(dt: float) -> void:
	mouse_idle += dt
	var jet: Jet = vehicle as Jet
	if jet != null:
		var b: Basis = jet.global_transform.basis
		cam_dir = cam_dir.lerp(b.z, clampf(jet.data.cam_follow * dt, 0.0, 1.0)).normalized()
		var pos: Vector3 = jet.global_position + cam_dir * jet.data.cam_distance + Vector3.UP * jet.data.cam_height
		pos.y = maxf(pos.y, 1.0)
		cam.global_position = pos
		var look: Vector3 = jet.global_position - b.z * 40.0 + Vector3.UP * 2.0
		if absf((look - pos).normalized().y) < 0.97:
			cam.look_at(look, Vector3.UP)
		return

	var car: Car = vehicle as Car
	var pivot_height: float = player.data.cam_pivot_height
	var offset: Vector3 = player.data.cam_offset
	if car != null:
		pivot_height = car.data.cam_pivot_height
		offset = car.data.cam_offset
		if mouse_idle > car.data.cam_idle and absf(car.speed) > 3.0:
			cam_yaw = lerp_angle(cam_yaw, car.rotation.y, car.data.cam_follow * dt)
			cam_pitch = lerpf(cam_pitch, car.data.cam_pitch, car.data.cam_follow * dt)
	var pivot: Vector3 = target_pos() + Vector3(0, pivot_height, 0)
	var cb: Basis = Basis.from_euler(Vector3(cam_pitch, cam_yaw, 0))
	var want: Vector3 = pivot + cb * offset
	var q := PhysicsRayQueryParameters3D.create(pivot, want)
	var ex: Array[RID] = [player.get_rid()]
	if vehicle != null:
		ex.append(vehicle.get_rid())
	q.exclude = ex
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = pivot.lerp(hit.position as Vector3, 0.9)
	want.y = maxf(want.y, 0.3)
	cam.global_transform = Transform3D(cb, want)


# ---------------------------------------------------------------- combate y efectos

## Un soldado ha acertado a lo que conduces (o a ti).
func hurt_target(d: SoldierData) -> void:
	var k: float = Settings.soldier_damage_scale()
	if vehicle == null:
		player.hurt(d.damage_player * k)
	elif vehicle.is_jet:
		vehicle.hurt(d.damage_jet * k)
	else:
		vehicle.hurt(d.damage_car * k)


func player_shoot() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var fwd: Vector3 = -cam.global_transform.basis.z
	var reach: float = player.data.cam_offset.z + 0.3  # el rayo sale por delante del jugador
	var from: Vector3 = cam.global_position + fwd * reach
	var to: Vector3 = from + fwd * player.data.fire_range
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)

	# Ayuda de puntería: si no has dado a un soldado pero hay uno casi en la mira y a la vista, le das.
	if hit.is_empty() or not hit.collider is Soldier:
		var alive: Array[Soldier] = []
		var chests: Array[Vector3] = []
		for s: Soldier in soldiers:
			if not s.dead:
				alive.append(s)
				chests.append(s.global_position + Vector3(0, 1.1, 0))
		var i: int = PlayerLogic.aim_assist(cam.global_position, fwd, chests, player.data.aim_assist_degrees, reach, player.data.fire_range)
		if i >= 0:
			var q2 := PhysicsRayQueryParameters3D.create(from, chests[i])
			q2.exclude = [player.get_rid()]
			var hit2: Dictionary = space.intersect_ray(q2)
			if not hit2.is_empty() and hit2.collider == alive[i]:
				hit = hit2

	var end: Vector3 = to
	if not hit.is_empty():
		end = hit.position
		var soldier: Soldier = hit.collider as Soldier
		var veh: Vehicle = hit.collider as Vehicle
		if soldier != null:
			soldier.hurt(player.data.damage)
			hit_t = 0.18
			hit_kill = soldier.dead
			explosion(end, 0.35)
		elif veh != null:
			veh.hurt(player.data.damage)
	tracer(player.global_position + Vector3(0, 1.35, 0), end, Color(1, 0.9, 0.4))
	for s: Soldier in soldiers:
		if not s.dead and not s.alert and s.global_position.distance_to(player.global_position) < player.data.noise_radius:
			s.alert = true
			mission.raise_alert()


func tracer(a: Vector3, b: Vector3, color: Color) -> void:
	var length: float = a.distance_to(b)
	if length < 0.5:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, length)
	var mi: MeshInstance3D = Build.mesh(self, bm, (a + b) / 2.0, color, Vector3.ZERO, 4.0)
	var d: Vector3 = (b - a) / length
	mi.look_at(b, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.07).timeout.connect(mi.queue_free)


func explosion(pos: Vector3, radius: float) -> void:
	var s: MeshInstance3D = Build.sphere(self, 1.0, pos, Color(1.0, 0.55, 0.1), 5.0)
	s.scale = Vector3.ONE * 0.2
	var tw: Tween = create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * radius, 0.3)
	tw.tween_property(s, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(s.queue_free)
	var smoke: MeshInstance3D = Build.sphere(self, 1.0, pos, Color(0.15, 0.15, 0.15, 0.6))
	smoke.scale = Vector3.ONE * 0.2
	var tw2: Tween = create_tween()
	tw2.tween_property(smoke, "scale", Vector3.ONE * radius * 1.3, 0.9)
	tw2.parallel().tween_property(smoke, "position", pos + Vector3(0, radius, 0), 1.6)
	tw2.tween_property(smoke, "scale", Vector3.ONE * 0.01, 0.7)
	tw2.tween_callback(smoke.queue_free)


func drop_flares(pos: Vector3, vel: Vector3) -> void:
	for i: int in 3:
		var f: MeshInstance3D = Build.sphere(self, 0.9, pos, Color(1.0, 0.95, 0.6), 6.0)
		var end: Vector3 = pos + vel * 0.6 + Vector3(rng.randf_range(-30, 30), -70, rng.randf_range(-30, 30))
		var tw: Tween = create_tween()
		tw.tween_property(f, "position", end, 2.5)
		tw.tween_callback(f.queue_free)
	for m: Missile in missiles:
		if is_instance_valid(m) and m.global_position.distance_to(pos) < missile_data.flare_radius and rng.randf() < missile_data.flare_chance:
			m.decoyed = true


# ---------------------------------------------------------------- ayudas de desarrollo
# godot --path . -- [--play] [--at=x,y,z] [--test-jet] [--test-takeoff] [--menu] [--pause] [--controls] [--options] [--shot=/ruta/captura.png]

## Lee los argumentos de desarrollo. Devuelve true si hay que saltarse el menú principal.
func _parse_args() -> bool:
	var dev: bool = false
	var force_menu: bool = false
	for a: String in OS.get_cmdline_user_args():
		dev = true
		if a.begins_with("--shot="):
			# captura a los 2,5 s (también con el juego en pausa) y sale
			get_tree().create_timer(2.5).timeout.connect(_take_shot.bind(a.trim_prefix("--shot=")))
		elif a.begins_with("--at="):
			var p: PackedFloat64Array = a.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(p[0], p[1], p[2])
		elif a == "--menu":
			force_menu = true
		elif a == "--pause":
			menu.open.call_deferred(Menu.Screen.PAUSE)
		elif a == "--controls" or a == "--options":
			menu.open.call_deferred(Menu.Screen.PAUSE)
			menu.show_screen.call_deferred(Menu.Screen.CONTROLS if a == "--controls" else Menu.Screen.OPTIONS)
		elif a == "--test-takeoff":
			_enter_vehicle(jets[1])
			Input.action_press("forward")  # lo que hace un jugador nuevo: solo W, sin soltarla
			_debug = true
		elif a == "--test-jet":
			var j: Jet = jets[0]
			_enter_vehicle(j)
			j.position = Vector3(250, 220, -1200)
			j.rotation.y = PI / 2.0
			j.grounded = false
			j.gear.visible = false
			j.throttle = 1.0
			j.speed = 120.0
	return dev and not force_menu


func _take_shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _dev_tick() -> void:
	var jet: Jet = vehicle as Jet
	if _debug and jet != null and Engine.get_physics_frames() % 60 == 0:
		print("t=%.0f pos=%s speed=%.0f grounded=%s hp=%.0f stage=%d over=%s" % [elapsed, jet.global_position.round(), jet.speed, jet.grounded, jet.hp, mission.stage, game_over])
