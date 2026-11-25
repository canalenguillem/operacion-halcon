class_name World
extends Node3D
## El escenario, generado con primitivas: suelo, árboles, colinas, ciudad, base aérea y aeródromo.
## El norte es -Z. Medidas en metros.

const BASE_MIN: Vector2 = Vector2(-350, -1300)  # x, z
const BASE_MAX: Vector2 = Vector2(350, -700)
const BASE_CENTER: Vector3 = Vector3(0, 0, -1000)
const GATE: Vector3 = Vector3(0, 0, -700)
const DEST: Vector3 = Vector3(6000, 0, 5000)
const BASE_SAMS: Array[Vector3] = [Vector3(-300, 0, -760), Vector3(300, 0, -1270), Vector3(-300, 0, -1270)]
const ROUTE_SAMS: Array[Vector3] = [Vector3(2300, 0, 900), Vector3(3700, 0, 3100)]

const PLAYER_START: Vector3 = Vector3(0, 0.2, 262)
const CAR_SPOTS: Array[Vector3] = [
	Vector3(4.5, 0.1, 245), Vector3(-4.5, 0.1, 200), Vector3(4.5, 0.1, 130),
	Vector3(-4.5, 0.1, 30), Vector3(4.5, 0.1, -400),
]
const CAR_COLORS: Array[Color] = [
	Color(0.8, 0.12, 0.1), Color(0.1, 0.35, 0.8), Color(0.9, 0.75, 0.1),
	Color(0.85, 0.85, 0.85), Color(0.15, 0.5, 0.25),
]
const JET_SPOTS: Array[Vector3] = [Vector3(160, 0.1, -1130), Vector3(250, 0.1, -1130)]
const SOLDIER_POSTS: Array[Vector2] = [
	Vector2(-10, -712), Vector2(10, -712), Vector2(-18, -735), Vector2(18, -735),
	Vector2(140, -1100), Vector2(205, -1105), Vector2(285, -1100), Vector2(205, -1160),
	Vector2(120, -1150), Vector2(300, -1150),
	Vector2(-235, -830), Vector2(-165, -830), Vector2(-235, -890), Vector2(-130, -810),
	Vector2(-50, -1040), Vector2(-72, -1085), Vector2(0, -1170), Vector2(-150, -1170),
]

var sam_positions: Array[Vector3] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var marker: MeshInstance3D
var barrier: Node3D
var barrier_open: bool = false


## ¿Está el punto dentro del recinto de la base?
static func in_base(p: Vector3) -> bool:
	return p.x > BASE_MIN.x and p.x < BASE_MAX.x and p.z > BASE_MIN.y and p.z < BASE_MAX.y


## Distancia en horizontal al aeródromo de destino.
static func dest_distance(p: Vector3) -> float:
	return Vector2(p.x - DEST.x, p.z - DEST.z).length()


## ¿Se puede plantar un árbol aquí? (fuera de la base, la ciudad, la carretera y el aeródromo)
static func clear_spot(x: float, z: float) -> bool:
	if x > BASE_MIN.x - 60 and x < BASE_MAX.x + 60 and z > BASE_MIN.y - 60 and z < BASE_MAX.y + 60:
		return false
	if absf(x) < 220 and z > -240 and z < 340:
		return false
	if absf(x) < 22 and z > -720 and z < 360:
		return false
	return dest_distance(Vector3(x, 0, z)) >= 320


func build() -> void:
	rng.seed = 7
	_build_sky()
	_build_ground()
	_build_city()
	_build_base()
	_build_dest()


func open_barrier() -> void:
	if barrier_open:
		return
	barrier_open = true
	create_tween().tween_property(barrier, "rotation:z", 1.4, 0.35)


## Coloca el haz de luz del objetivo. `big` es el del aeródromo, visible desde lejos.
func set_marker(pos: Vector3, big: bool, shown: bool) -> void:
	marker.visible = shown
	var r: float = 150.0 if big else 1.5
	var h: float = 5000.0 if big else 150.0
	marker.scale = Vector3(r, h, r)
	marker.position = Vector3(pos.x, h / 2.0, pos.z)


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

	# árboles (solo visuales)
	var spots: Array[Transform3D] = []
	while spots.size() < 3500:
		var x: float = rng.randf_range(-4500, 7500)
		var z: float = rng.randf_range(-3000, 6500)
		if clear_spot(x, z):
			var s: float = rng.randf_range(0.8, 1.8)
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
	_scatter(trunk, 1.5, spots)
	_scatter(crown, 5.5, spots)

	# colinas (sólidas: no vueles contra ellas)
	var made: int = 0
	while made < 16:
		var x: float = rng.randf_range(-5000, 8000)
		var z: float = rng.randf_range(-4000, 7000)
		var r: float = rng.randf_range(300, 700)
		var p := Vector2(x, z)
		var ok: bool = p.distance_to(Vector2(0, -1000)) > 1300 + r and p.distance_to(Vector2(0, 50)) > 600 + r
		ok = ok and p.distance_to(Vector2(DEST.x, DEST.z)) > 900 + r and absf(x) > r + 40
		for s: Vector3 in ROUTE_SAMS:
			ok = ok and p.distance_to(Vector2(s.x, s.z)) > r + 150
		if not ok:
			continue
		made += 1
		var h: float = rng.randf_range(150, 450)
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.12
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 10
		cm.rings = 1
		var hill: MeshInstance3D = Build.mesh(self, cm, Vector3(x, h / 2.0 - 4.0, z), Color(0.36, 0.4, 0.26))
		var sb := StaticBody3D.new()
		Build.collider(sb, cm.create_convex_shape())
		hill.add_child(sb)


func _scatter(m: Mesh, height: float, spots: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = spots.size()
	for i: int in spots.size():
		var t: Transform3D = spots[i]
		t.origin.y = height * t.basis.get_scale().y
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _build_city() -> void:
	var road := Color(0.16, 0.16, 0.18)
	Build.box(self, Vector3(14, 0.1, 1040), Vector3(0, 0.04, -180), road)
	for i: int in 52:
		Build.box(self, Vector3(0.3, 0.1, 6), Vector3(0, 0.06, 330 - i * 20), Color(0.9, 0.85, 0.5))
	for z: int in range(-210, 300, 60):
		Build.box(self, Vector3(420, 0.1, 10), Vector3(0, 0.02, z), road)
	for x: int in [-160, -100, -40, 40, 100, 160]:
		for z: int in range(-180, 300, 60):
			if rng.randf() < 0.12:
				continue
			var w: float = rng.randf_range(22, 40)
			var d: float = rng.randf_range(22, 40)
			var h: float = rng.randf_range(8, 45)
			var c: Color = Color.from_hsv(rng.randf_range(0.02, 0.14), rng.randf_range(0.1, 0.35), rng.randf_range(0.55, 0.9))
			Build.box(self, Vector3(w, h, d), Vector3(x, h / 2.0, z), c, true)
			Build.box(self, Vector3(w + 0.1, h * 0.12, d + 0.1), Vector3(x, h * 0.55, z), Color(0.15, 0.2, 0.28))


func _build_sam(pos: Vector3) -> void:
	Build.box(self, Vector3(5, 1.6, 5), pos + Vector3(0, 0.8, 0), Color(0.25, 0.3, 0.2), true)
	for sx: float in [-1.2, 1.2]:
		Build.cyl(self, 0.5, 5.0, pos + Vector3(sx, 3.2, 0), Color(0.8, 0.8, 0.75), Vector3(0.5, 0, 0))
	sam_positions.append(pos)


func _build_base() -> void:
	var cx: float = (BASE_MIN.x + BASE_MAX.x) / 2.0
	var cz: float = (BASE_MIN.y + BASE_MAX.y) / 2.0
	var w: float = BASE_MAX.x - BASE_MIN.x
	var d: float = BASE_MAX.y - BASE_MIN.y
	var concrete := Color(0.33, 0.33, 0.32)
	var fence := Color(0.3, 0.33, 0.3)
	Build.box(self, Vector3(w, 0.1, d), Vector3(cx, 0.0, cz), concrete)
	# valla con hueco para la puerta en el lado sur
	Build.box(self, Vector3(w, 4, 1), Vector3(cx, 2, BASE_MIN.y), fence, true)
	Build.box(self, Vector3(1, 4, d), Vector3(BASE_MIN.x, 2, cz), fence, true)
	Build.box(self, Vector3(1, 4, d), Vector3(BASE_MAX.x, 2, cz), fence, true)
	var seg: float = w / 2.0 - 9.0
	for s: float in [-1.0, 1.0]:
		Build.box(self, Vector3(seg, 4, 1), Vector3(s * (9.0 + seg / 2.0), 2, BASE_MAX.y), fence, true)
		Build.box(self, Vector3(5, 3.5, 5), Vector3(s * 14.0, 1.75, BASE_MAX.y + 6.0), Color(0.6, 0.6, 0.55), true)
	barrier = Node3D.new()
	barrier.position = Vector3(-8, 1.1, BASE_MAX.y)
	add_child(barrier)
	Build.box(barrier, Vector3(16, 0.25, 0.25), Vector3(8, 0, 0), Color(0.9, 0.15, 0.1))

	# pista (este-oeste) y plataforma
	Build.box(self, Vector3(660, 0.1, 40), Vector3(0, 0.08, -1200), Color(0.13, 0.13, 0.15))
	for i: int in 16:
		Build.box(self, Vector3(18, 0.1, 0.8), Vector3(-300 + i * 40, 0.1, -1200), Color(0.95, 0.95, 0.95))
	Build.box(self, Vector3(240, 0.1, 110), Vector3(205, 0.06, -1125), Color(0.38, 0.38, 0.38))
	# hangares
	for x: float in [160.0, 250.0]:
		Build.box(self, Vector3(70, 16, 36), Vector3(x, 8, -1050), Color(0.55, 0.58, 0.55), true)
		Build.box(self, Vector3(50, 12, 0.5), Vector3(x, 6, -1068.2), Color(0.12, 0.13, 0.15))
	# torre de control
	Build.box(self, Vector3(10, 30, 10), Vector3(-60, 15, -1060), Color(0.7, 0.7, 0.68), true)
	Build.box(self, Vector3(15, 5, 15), Vector3(-60, 32.5, -1060), Color(0.15, 0.3, 0.4))
	Build.cyl(self, 0.3, 10, Vector3(-60, 40, -1060), Color(0.9, 0.2, 0.2))
	# barracones
	for p: Vector2 in [Vector2(-270, -800), Vector2(-200, -800), Vector2(-270, -860), Vector2(-200, -860), Vector2(-130, -830)]:
		Build.box(self, Vector3(44, 6, 16), Vector3(p.x, 3, p.y), Color(0.4, 0.44, 0.3), true)
	# depósitos de combustible
	for i: int in 3:
		var tp := Vector3(40.0 + i * 14.0, 4, -820)
		Build.cyl(self, 5.5, 8, tp, Color(0.85, 0.85, 0.82))
		Build.box(self, Vector3(9, 8, 9), tp, Color(0.85, 0.85, 0.82), true).visible = false

	for s: Vector3 in BASE_SAMS:
		_build_sam(s)
	for s: Vector3 in ROUTE_SAMS:
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
