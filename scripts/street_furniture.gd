class_name StreetFurniture
extends RefCounted
## Farolas y semáforos a partir de la red de calles de `CityMap`, todo con `MultiMesh`.
## (Solo visuales por ahora: más adelante se podrán derribar.)

## Distancia entre farolas a lo largo de una calle.
const LAMP_STEP: float = 32.0
## Barrios con semáforos (en el casco viejo, Los Bajos y la colina no hay).
const LIGHTS_IN: Array[String] = ["ensanche", "financiero", "milla", "puerto", "poligono"]

var map: CityMap
var terrain: Terrain
var parent: Node3D
var _parts: Dictionary = {}
## Posición de la cabeza de cada farola.
var lamp_heads: PackedVector3Array = PackedVector3Array()
## Calles que salen de cada cruce.
var _adj: Array[PackedInt32Array] = []


func _init(m: CityMap, t: Terrain, p: Node3D) -> void:
	map = m
	terrain = t
	parent = p


func build() -> void:
	var node_half: PackedFloat32Array = PackedFloat32Array()
	node_half.resize(map.nodes.size())
	var degree: PackedInt32Array = PackedInt32Array()
	degree.resize(map.nodes.size())
	var major: PackedByteArray = PackedByteArray()
	major.resize(map.nodes.size())
	_adj.resize(map.nodes.size())
	for i: int in map.road_count():
		for n: int in [map.road_a[i], map.road_b[i]]:
			_adj[n].append(i)
			node_half[n] = maxf(node_half[n], map.width(i) / 2.0)
			degree[n] += 1
			if map.road_type[i] in ["avenida", "calle"]:
				major[n] = 1
	for i: int in map.road_count():
		if map.road_type[i] in ["avenida", "calle", "autovia"] and not map.road_bridge[i]:
			_lamps(i, node_half)
	for n: int in map.nodes.size():
		if degree[n] >= 3 and major[n] == 1 and map.district_at(map.nodes[n]) in LIGHTS_IN:
			_traffic_lights(n, node_half[n])
	_flush()


func _lamps(i: int, node_half: PackedFloat32Array) -> void:
	var a: Vector2 = map.road_start(i)
	var b: Vector2 = map.road_end(i)
	var length: float = a.distance_to(b)
	var d: Vector2 = (b - a) / length
	var n: Vector2 = d.orthogonal()
	var half: float = map.width(i) / 2.0
	var start: float = node_half[map.road_a[i]] + 8.0
	var end: float = length - node_half[map.road_b[i]] - 8.0
	var both: bool = map.road_type[i] == "avenida"
	var t: float = start + fmod(float(i) * 7.0, LAMP_STEP * 0.5)
	var side: float = 1.0
	while t < end:
		for s: float in ([1.0, -1.0] if both else [side]):
			var p: Vector2 = a + d * t + n * s * (half + map.sidewalk - 0.6)
			_lamp(Vector3(p.x, terrain.surface(p), p.y), -n * s)
		side = -side
		t += LAMP_STEP


## Farola en `at` con el brazo hacia `toward` (hacia la calzada).
func _lamp(at: Vector3, toward: Vector2) -> void:
	var yaw: float = atan2(toward.x, toward.y)
	var basis := Basis(Vector3.UP, yaw)
	_add("pole", _cyl(), Transform3D(Basis.from_scale(Vector3(0.24, 7.5, 0.24)), at + Vector3(0, 3.75, 0)), Color(0.22, 0.23, 0.25))
	_add("arm", _box(), Transform3D(basis * Basis.from_scale(Vector3(0.12, 0.12, 2.4)), at + Vector3(toward.x, 0, toward.y) * 1.1 + Vector3(0, 7.4, 0)), Color(0.22, 0.23, 0.25))
	var head: Vector3 = at + Vector3(toward.x, 0, toward.y) * 2.2 + Vector3(0, 7.3, 0)
	_add("lamp", _box(), Transform3D(basis * Basis.from_scale(Vector3(0.4, 0.18, 0.9)), head), Color(1.0, 0.92, 0.7))
	lamp_heads.append(head)


func _traffic_lights(node: int, half: float) -> void:
	var c: Vector2 = map.nodes[node]
	for i: int in _adj[node]:
		var other: int = map.road_b[i] if map.road_a[i] == node else map.road_a[i]
		var d: Vector2 = (map.nodes[other] - c).normalized()
		var n: Vector2 = d.orthogonal()
		var p: Vector2 = c + d * (half + map.sidewalk + 1.5) - n * (map.width(i) / 2.0 + map.sidewalk - 0.8)
		var at := Vector3(p.x, terrain.surface(p), p.y)
		var yaw: float = atan2(-d.x, -d.y)  # el semáforo mira a los coches que llegan
		var basis := Basis(Vector3.UP, yaw)
		_add("pole", _cyl(), Transform3D(Basis.from_scale(Vector3(0.2, 4.2, 0.2)), at + Vector3(0, 2.1, 0)), Color(0.18, 0.19, 0.2))
		_add("housing", _box(), Transform3D(basis * Basis.from_scale(Vector3(0.45, 1.3, 0.4)), at + Vector3(0, 4.6, 0)), Color(0.12, 0.12, 0.13))
		var face: Vector3 = basis * Vector3(0, 0, -0.21)
		for k: int in 3:
			var colr: Color = [Color(0.9, 0.1, 0.08), Color(0.35, 0.25, 0.05), Color(0.15, 0.35, 0.15)][k]
			_add("light", _box(), Transform3D(basis * Basis.from_scale(Vector3(0.28, 0.28, 0.05)), at + face + Vector3(0, 5.0 - k * 0.38, 0)), colr)


func _add(part: String, mesh: Mesh, t: Transform3D, color: Color) -> void:
	if not _parts.has(part):
		_parts[part] = {"mesh": mesh, "t": [], "c": []}
	(_parts[part]["t"] as Array).append(t)
	(_parts[part]["c"] as Array).append(color)


func _flush() -> void:
	for part: String in _parts:
		var entry: Dictionary = _parts[part]
		var ts: Array = entry["t"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = entry["mesh"] as Mesh
		mm.instance_count = ts.size()
		for k: int in ts.size():
			mm.set_instance_transform(k, ts[k] as Transform3D)
			mm.set_instance_color(k, (entry["c"] as Array)[k] as Color)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Street_" + part
		mmi.multimesh = mm
		mmi.material_override = Build.glow_mat() if part in ["lamp", "light"] else Build.facade_mat("plain")
		mmi.visibility_range_end = 900.0  # de lejos no se ven y ahorran dibujo
		if part in ["lamp", "light"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


static var _box_mesh: BoxMesh
static var _cyl_mesh: CylinderMesh


static func _box() -> BoxMesh:
	if _box_mesh == null:
		_box_mesh = BoxMesh.new()
	return _box_mesh


static func _cyl() -> CylinderMesh:
	if _cyl_mesh == null:
		_cyl_mesh = CylinderMesh.new()
		_cyl_mesh.top_radius = 0.5
		_cyl_mesh.bottom_radius = 0.5
		_cyl_mesh.height = 1.0
		_cyl_mesh.radial_segments = 8
		_cyl_mesh.rings = 1
	return _cyl_mesh
