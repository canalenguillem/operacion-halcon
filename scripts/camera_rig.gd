class_name CameraRig
extends Camera3D
## Cámara de la partida: orbital a pie y en coche (con colisión), de persecución en el caza,
## y sacudida (la lógica de la sacudida está en `CameraLogic`).

var main: Main
var yaw: float = 0.0
var pitch: float = -0.15
## Dirección suavizada desde la que se persigue al caza.
var chase_dir: Vector3 = Vector3.BACK
## Segundos desde que se movió el ratón (en coche, la cámara se recoloca sola al rato).
var mouse_idle: float = 9.0
## Sacudida actual (ver `CameraLogic`).
var shake: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	near = 0.2
	far = 20000.0
	fov = 70.0


## Gira la cámara con el movimiento del ratón.
func orbit(relative: Vector2) -> void:
	var o: Vector2 = PlayerLogic.orbit(yaw, pitch, relative * Settings.mouse_scale, main.player.data)
	yaw = o.x
	pitch = o.y
	mouse_idle = 0.0


## Coloca la cámara detrás del vehículo al subir.
func snap_behind(v: Vehicle) -> void:
	yaw = v.rotation.y
	chase_dir = v.global_transform.basis.z


func add_shake(amount: float) -> void:
	shake = CameraLogic.add(shake, amount)


func tick(dt: float) -> void:
	_follow(dt)
	shake = CameraLogic.decay(shake, dt)
	h_offset = rng.randf_range(-1.0, 1.0) * shake * 0.6
	v_offset = rng.randf_range(-1.0, 1.0) * shake * 0.6


func _follow(dt: float) -> void:
	mouse_idle += dt
	var vehicle: Vehicle = main.vehicle
	var jet: Jet = vehicle as Jet
	if jet != null:
		var b: Basis = jet.global_transform.basis
		chase_dir = chase_dir.lerp(b.z, clampf(jet.data.cam_follow * dt, 0.0, 1.0)).normalized()
		var pos: Vector3 = jet.global_position + chase_dir * jet.data.cam_distance + Vector3.UP * jet.data.cam_height
		pos.y = maxf(pos.y, 1.0)
		global_position = pos
		var look: Vector3 = jet.global_position - b.z * 40.0 + Vector3.UP * 2.0
		if absf((look - pos).normalized().y) < 0.97:
			look_at(look, Vector3.UP)
		return

	var car: Car = vehicle as Car
	var pivot_height: float = main.player.data.cam_pivot_height
	var offset: Vector3 = main.player.data.cam_offset
	if car != null:
		pivot_height = car.data.cam_pivot_height
		offset = car.data.cam_offset
		if mouse_idle > car.data.cam_idle and absf(car.speed) > 3.0:
			yaw = lerp_angle(yaw, car.rotation.y, car.data.cam_follow * dt)
			pitch = lerpf(pitch, car.data.cam_pitch, car.data.cam_follow * dt)
	var pivot: Vector3 = main.target_pos() + Vector3(0, pivot_height, 0)
	var cb: Basis = Basis.from_euler(Vector3(pitch, yaw, 0))
	var want: Vector3 = pivot + cb * offset
	var q := PhysicsRayQueryParameters3D.create(pivot, want)
	var ex: Array[RID] = [main.player.get_rid()]
	if vehicle != null:
		ex.append(vehicle.get_rid())
	q.exclude = ex
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = pivot.lerp(hit.position as Vector3, 0.9)
	want.y = maxf(want.y, 0.3)
	global_transform = Transform3D(cb, want)
