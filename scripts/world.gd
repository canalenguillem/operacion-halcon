class_name World
extends Node3D
## El escenario: la isla y su ciudad (datos de `CityMap`, construidas por `CityBuilder`),
## árboles, nubes, base aérea, baterías y el islote del aeródromo clandestino.
## El norte es -Z. Medidas en metros.

const BASE_MIN: Vector2 = Vector2(-350, -1300)  # x, z
const BASE_MAX: Vector2 = Vector2(350, -700)
const BASE_CENTER: Vector3 = Vector3(0, 0, -1000)
const GATE: Vector3 = Vector3(0, 0, -700)
const DEST: Vector3 = Vector3(6000, 0, 5000)
const BASE_SAMS: Array[Vector3] = [Vector3(-300, 0, -760), Vector3(300, 0, -1270), Vector3(-300, 0, -1270)]
const ROUTE_SAMS: Array[Vector3] = [Vector3(2300, 0, 900), Vector3(3700, 0, 3100)]

## El jugador empieza en el aeropuerto civil (ver `player_start` en data/map/city.json).
const PLAYER_START: Vector3 = Vector3(2100, 0.2, 470)
## Coches aparcados en el aparcamiento del aeropuerto.
const CAR_SPOTS: Array[Vector3] = [
	Vector3(1950, 0.1, 540), Vector3(2010, 0.1, 540), Vector3(2130, 0.1, 540),
	Vector3(2190, 0.1, 540), Vector3(2250, 0.1, 540),
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

var map: CityMap = CityMap.get_default()
## Relieve de la isla (alturas del suelo); se calcula en `build()`.
var terrain: Terrain
var sam_positions: Array[Vector3] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var marker: MeshInstance3D
var barrier: Node3D
var barrier_open: bool = false
var sun: DirectionalLight3D


## ¿Está el punto dentro del recinto de la base?
static func in_base(p: Vector3) -> bool:
	return p.x > BASE_MIN.x and p.x < BASE_MAX.x and p.z > BASE_MIN.y and p.z < BASE_MAX.y


## Distancia en horizontal al aeródromo de destino.
static func dest_distance(p: Vector3) -> float:
	return Vector2(p.x - DEST.x, p.z - DEST.z).length()


## ¿Se puede plantar un árbol aquí? (en tierra, en el campo o en zonas verdes, lejos de calles y recintos)
static func clear_spot(x: float, z: float) -> bool:
	var m: CityMap = CityMap.get_default()
	var p := Vector2(x, z)
	if not m.on_land(p) or in_base(Vector3(x, 0, z)):
		return false
	var dist_id: String = m.district_at(p)
	if dist_id != "" and dist_id != "colinas":
		return false
	for id: String in ["parque", "cementerio", "golf"]:
		if Geometry2D.is_point_in_polygon(p, m.zones[id] as PackedVector2Array):
			return id != "golf" or fmod(absf(x * 0.13 + z * 0.07), 1.0) < 0.15  # en el golf, pocos
	if m.in_zone(p):
		return false
	# en la colina, lejos de las calles para no plantar árboles dentro de las mansiones
	return m.road_clearance(p) > (34.0 if dist_id == "colinas" else 7.0) and dest_distance(Vector3(x, 0, z)) >= 320


func build() -> void:
	rng.seed = 7
	_build_sky()
	_build_ground()
	_build_base()
	_build_dest()


## Aplica la calidad de sombras de las opciones.
func apply_graphics() -> void:
	sun.shadow_enabled = Settings.shadows > 0
	sun.directional_shadow_max_distance = Settings.SHADOW_DISTANCE[Settings.shadows]


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
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	apply_graphics()


func _build_ground() -> void:
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
	gm.roughness = 1.0
	terrain = Terrain.new(map)
	terrain.build()
	CityBuilder.new(map, terrain, self).build(gm)
	BuildingsBuilder.new(map, terrain, self).build()
	StreetFurniture.new(map, terrain, self).build()

	# árboles (solo visuales)
	var spots: Array[Transform3D] = []
	var tries: int = 0
	while spots.size() < 4000 and tries < 60000:
		tries += 1
		var x: float = rng.randf_range(-2300, 3500)
		var z: float = rng.randf_range(-1800, 1300)
		if clear_spot(x, z):
			var s: float = rng.randf_range(0.8, 1.8)
			spots.append(Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, terrain.surface(Vector2(x, z)) - 0.3, z)))
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
	var round_crown := SphereMesh.new()
	round_crown.radius = 2.4
	round_crown.height = 4.2
	round_crown.radial_segments = 8
	round_crown.rings = 4
	round_crown.material = Build.mat(Color(0.24, 0.42, 0.14))
	var half: int = spots.size() / 2
	_scatter(trunk, 1.5, spots)
	_scatter(crown, 5.5, spots.slice(0, half))
	_scatter(round_crown, 4.6, spots.slice(half))
	_build_clouds()


func _scatter(m: Mesh, height: float, spots: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = spots.size()
	for i: int in spots.size():
		var t: Transform3D = spots[i]
		t.origin.y += height * t.basis.get_scale().y
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


## Nubes: grupos de esferas aplastadas entre 900 y 1700 m (solo visuales).
func _build_clouds() -> void:
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 10
	puff.rings = 5
	puff.material = Build.mat(Color(1, 1, 1), 0.35)
	var spots: Array[Transform3D] = []
	for i: int in 70:
		var c := Vector3(rng.randf_range(-6000, 10000), rng.randf_range(900, 1700), rng.randf_range(-5000, 8500))
		for j: int in rng.randi_range(3, 6):
			var r: float = rng.randf_range(120, 280)
			var off := Vector3(rng.randf_range(-260, 260), rng.randf_range(-30, 30), rng.randf_range(-160, 160))
			spots.append(Transform3D(Basis().scaled(Vector3(r, r * 0.3, r * 0.8)), c + off))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = puff
	mm.instance_count = spots.size()
	for i: int in spots.size():
		mm.set_instance_transform(i, spots[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_sam(pos: Vector3) -> void:
	var olive := Color(0.25, 0.3, 0.2)
	Build.box(self, Vector3(5, 1.6, 5), pos + Vector3(0, 0.8, 0), olive, true)
	Build.cyl(self, 1.6, 0.8, pos + Vector3(0, 2.0, 0), olive.darkened(0.2))
	Build.box(self, Vector3(3.6, 0.5, 1.2), pos + Vector3(0, 2.6, 0.3), olive.darkened(0.2))
	for sx: float in [-1.35, -0.45, 0.45, 1.35]:
		Build.cyl(self, 0.36, 5.0, pos + Vector3(sx, 3.6, 0), Color(0.8, 0.8, 0.75), Vector3(0.5, 0, 0))
	Build.cyl(self, 0.1, 3.0, pos + Vector3(2.0, 3.1, 2.0), Color(0.2, 0.2, 0.2))
	Build.box(self, Vector3(1.8, 1.0, 0.15), pos + Vector3(2.0, 4.8, 2.0), Color(0.6, 0.62, 0.6), false, Vector3(0.3, 0.6, 0))
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
	var post := Color(0.2, 0.22, 0.2)
	for i: int in 29:
		var px: float = BASE_MIN.x + i * 25.0
		for pz: float in [BASE_MIN.y, BASE_MAX.y]:
			if absf(px) > 12.0 or pz == BASE_MIN.y:
				Build.box(self, Vector3(1.5, 5.0, 1.5), Vector3(px, 2.5, pz), post)
	for i: int in 25:
		for px: float in [BASE_MIN.x, BASE_MAX.x]:
			Build.box(self, Vector3(1.5, 5.0, 1.5), Vector3(px, 2.5, BASE_MIN.y + i * 25.0), post)
	for s: float in [-1.0, 1.0]:
		Build.box(self, Vector3(6.4, 0.4, 6.4), Vector3(s * 14.0, 3.7, BASE_MAX.y + 6.0), Color(0.3, 0.32, 0.3))
		Build.box(self, Vector3(5.1, 1.1, 5.1), Vector3(s * 14.0, 2.4, BASE_MAX.y + 6.0), Color(0.12, 0.2, 0.28))
	barrier = Node3D.new()
	barrier.position = Vector3(-8, 1.1, BASE_MAX.y)
	add_child(barrier)
	Build.box(barrier, Vector3(16, 0.25, 0.25), Vector3(8, 0, 0), Color(0.9, 0.15, 0.1))
	for i: int in 4:
		Build.box(barrier, Vector3(1.6, 0.27, 0.27), Vector3(2.5 + i * 4.0, 0, 0), Color(0.95, 0.95, 0.95))

	# pista (este-oeste) y plataforma
	Build.box(self, Vector3(660, 0.1, 40), Vector3(0, 0.08, -1200), Color(0.13, 0.13, 0.15))
	for i: int in 16:
		Build.box(self, Vector3(18, 0.1, 0.8), Vector3(-300 + i * 40, 0.1, -1200), Color(0.95, 0.95, 0.95))
	var lamp: StandardMaterial3D = Build.mat(Color(1.0, 0.85, 0.4), 2.5)
	for i: int in 23:
		for sz: float in [-21.0, 21.0]:
			Build.box(self, Vector3(0.6, 0.4, 0.6), Vector3(-330 + i * 30.0, 0.2, -1200 + sz), Color.WHITE).material_override = lamp
	for sx: float in [-1.0, 1.0]:
		for i: int in 8:
			Build.box(self, Vector3(14, 0.1, 2.2), Vector3(sx * 315.0, 0.1, -1216.5 + i * 4.7), Color(0.95, 0.95, 0.95))
	Build.box(self, Vector3(240, 0.1, 110), Vector3(205, 0.06, -1125), Color(0.38, 0.38, 0.38))
	for x: float in [160.0, 250.0]:
		Build.box(self, Vector3(0.5, 0.1, 110), Vector3(x, 0.09, -1125), Color(0.9, 0.75, 0.1))
	# hangares
	for x: float in [160.0, 250.0]:
		Build.box(self, Vector3(70, 16, 36), Vector3(x, 8, -1050), Color(0.55, 0.58, 0.55), true)
		Build.box(self, Vector3(50, 12, 0.5), Vector3(x, 6, -1068.2), Color(0.12, 0.13, 0.15))
		var vault: MeshInstance3D = Build.cyl(self, 35.0, 36.4, Vector3(x, 15.5, -1050), Color(0.42, 0.45, 0.43), Vector3(PI / 2.0, 0, 0))
		vault.scale = Vector3(1, 1, 0.22)
		for i: int in 5:
			Build.box(self, Vector3(0.4, 12, 0.6), Vector3(x - 20.0 + i * 10.0, 6, -1068.3), Color(0.3, 0.32, 0.34))
	# torre de control
	Build.box(self, Vector3(10, 30, 10), Vector3(-60, 15, -1060), Color(0.7, 0.7, 0.68), true)
	Build.box(self, Vector3(15, 5, 15), Vector3(-60, 32.5, -1060), Color(0.15, 0.3, 0.4))
	Build.box(self, Vector3(17, 0.8, 17), Vector3(-60, 35.4, -1060), Color(0.7, 0.7, 0.68))
	Build.box(self, Vector3(16.5, 0.8, 16.5), Vector3(-60, 29.8, -1060), Color(0.7, 0.7, 0.68))
	Build.cyl(self, 0.3, 10, Vector3(-60, 40.5, -1060), Color(0.9, 0.2, 0.2))
	Build.sphere(self, 0.7, Vector3(-60, 45.8, -1060), Color(1.0, 0.15, 0.1), 3.0)
	var dish: MeshInstance3D = Build.sphere(self, 2.2, Vector3(-55, 37.6, -1055), Color(0.85, 0.85, 0.85))
	dish.scale = Vector3(1, 0.35, 1)
	# barracones
	for p: Vector2 in [Vector2(-270, -800), Vector2(-200, -800), Vector2(-270, -860), Vector2(-200, -860), Vector2(-130, -830)]:
		Build.box(self, Vector3(44, 6, 16), Vector3(p.x, 3, p.y), Color(0.4, 0.44, 0.3), true)
		var gable := PackedVector2Array([Vector2(0, -9), Vector2(3.2, 0), Vector2(0, 9)])
		Build.extrude(self, gable, 45.0, Vector3(p.x, 6, p.y), Color(0.28, 0.3, 0.22), Vector3(0, 0, PI / 2.0))
		Build.box(self, Vector3(2.4, 3.4, 0.3), Vector3(p.x, 1.7, p.y + 8.0), Color(0.2, 0.22, 0.16))
		for i: int in 4:
			Build.box(self, Vector3(3.0, 1.6, 0.3), Vector3(p.x - 16.5 + i * 11.0, 3.6, p.y + 8.0), Color(0.12, 0.2, 0.28))
	# depósitos de combustible
	for i: int in 3:
		var tp := Vector3(40.0 + i * 14.0, 4, -820)
		Build.cyl(self, 5.5, 8, tp, Color(0.85, 0.85, 0.82))
		Build.cyl(self, 5.5, 1.6, tp + Vector3(0, 4.8, 0), Color(0.78, 0.78, 0.75), Vector3.ZERO, 1.5)
		Build.cyl(self, 5.56, 1.0, tp + Vector3(0, 1.5, 0), Color(0.8, 0.25, 0.15))
		Build.box(self, Vector3(9, 8, 9), tp, Color(0.85, 0.85, 0.82), true).visible = false

	for s: Vector3 in BASE_SAMS:
		_build_sam(s)
	for s: Vector3 in ROUTE_SAMS:
		_build_sam(s)


func _build_dest() -> void:
	Build.box(self, Vector3(30, 0.1, 500), DEST + Vector3(0, 0.05, 0), Color(0.45, 0.36, 0.25))
	Build.box(self, Vector3(18, 6, 14), DEST + Vector3(40, 3, 60), Color(0.5, 0.3, 0.2), true)
	Build.box(self, Vector3(12, 5, 20), DEST + Vector3(45, 2.5, 20), Color(0.35, 0.38, 0.3), true)
	Build.box(self, Vector3(19, 0.5, 15), DEST + Vector3(40, 6.2, 60), Color(0.4, 0.2, 0.14))
	Build.box(self, Vector3(13, 0.5, 21), DEST + Vector3(45, 5.2, 20), Color(0.25, 0.27, 0.22))
	var lamp: StandardMaterial3D = Build.mat(Color(1.0, 0.85, 0.4), 2.5)
	for i: int in 17:
		for sx: float in [-16.0, 16.0]:
			Build.box(self, Vector3(0.6, 0.4, 0.6), DEST + Vector3(sx, 0.2, -240 + i * 30.0), Color.WHITE).material_override = lamp
	# manga de viento y bidones
	Build.cyl(self, 0.1, 7.0, DEST + Vector3(24, 3.5, -20), Color(0.8, 0.8, 0.8))
	Build.cyl(self, 0.5, 3.0, DEST + Vector3(25.5, 6.8, -20), Color(0.95, 0.4, 0.1), Vector3(0, 0, PI / 2.0), 0.2)
	for i: int in 6:
		Build.cyl(self, 0.45, 1.2, DEST + Vector3(30.0 + (i % 3) * 1.1, 0.6, 40.0 + (i / 3) * 1.1), Color(0.15, 0.3, 0.45))
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
