class_name CityBuilder
extends RefCounted
## Construye en 3D la isla descrita por `CityMap`: relieve (`Terrain`), islotes, mar, calles con
## aceras, cruces, pasos de cebra y marcas, puentes, suelo de cada barrio y aeropuerto.
## Todo lo plano va en una malla con colores por vértice y se apoya en el relieve.

## Altura del agua y del fondo (el mar y el río).
const WATER_Y: float = -1.0
const FLOOR_Y: float = -2.2
## Alturas de cada capa plana (de abajo arriba) para que no se peleen en pantalla.
const Y_DISTRICT: float = 0.02
const Y_SIDEWALK: float = 0.05
const Y_ROAD: float = 0.08
const Y_MARK: float = 0.10
## Metros que el puente (tablero y barandillas) se alarga por cada orilla.
const BRIDGE_PAD: float = 6.0

const ASPHALT: Color = Color(0.11, 0.11, 0.12)
const SIDEWALK_COLOR: Color = Color(0.47, 0.46, 0.44)
const MARK: Color = Color(0.92, 0.92, 0.88)
const DISTRICT_GROUND: Dictionary = {
	"casco_antiguo": Color(0.6, 0.53, 0.45),
	"bloques": Color(0.52, 0.52, 0.5),
	"rascacielos": Color(0.5, 0.52, 0.56),
	"ocio": Color(0.56, 0.52, 0.53),
	"chabolas": Color(0.44, 0.39, 0.33),
	"naves": Color(0.45, 0.45, 0.43),
	"muelles": Color(0.42, 0.43, 0.45),
}
const ZONE_GROUND: Dictionary = {
	"parque": Color(0.26, 0.48, 0.2),
	"golf": Color(0.3, 0.56, 0.22),
	"estadio": Color(0.28, 0.5, 0.22),
	"cementerio": Color(0.36, 0.42, 0.3),
}

var map: CityMap
var parent: Node3D
var terrain: Terrain
var _flat: SurfaceTool
## Tramos sobre el agua del puente que se está dibujando: ahí las capas no siguen el relieve.
var _level_spans: Array[PackedVector2Array] = []
var _level: bool = false
var _river: PackedVector2Array


func _init(m: CityMap, t: Terrain, p: Node3D) -> void:
	map = m
	terrain = t
	parent = p


func build(ground_material: Material) -> void:
	_river = map.river_polygon()
	parent.add_child(terrain.make_node())
	_build_land(ground_material)
	_build_water()
	_flat = SurfaceTool.new()
	_flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_district_ground()
	_build_roads()
	_build_airport()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.12  # sin brillo: si no, el cielo se refleja y todo parece lavado
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "CityFlat"
	mi.mesh = _flat.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_build_bridges()


# ---------------------------------------------------------------- suelo y agua

## Trozos de tierra que no cubre `Terrain`: los islotes (llanos, con su borde y colisión).
func land_pieces() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: Dictionary in map.islets:
		out.append(circle(i["center"] as Vector2, float(i["radius"]), 40))
	return out


static func circle(c: Vector2, r: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in segments:
		var a: float = TAU * i / segments
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


func _build_land(ground_material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece: PackedVector2Array in land_pieces():
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
		for idx: int in tris:
			var p: Vector2 = piece[idx]
			var v := Vector3(p.x, 0.0, p.y)
			st.set_normal(Vector3.UP)
			st.set_uv(p / 200.0)
			st.add_vertex(v)
			faces.append(v)
		# borde: acantilado bajo hasta el fondo
		for i: int in piece.size():
			var a: Vector2 = piece[i]
			var b: Vector2 = piece[(i + 1) % piece.size()]
			var quad: Array[Vector3] = [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, FLOOR_Y, b.y), Vector3(a.x, FLOOR_Y, a.y)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				cliff.set_color(Color(0.55, 0.5, 0.4))
				cliff.add_vertex(quad[k])
				faces.append(quad[k])
	cliff.generate_normals()
	var top := MeshInstance3D.new()
	top.name = "Land"
	top.mesh = st.commit()
	top.material_override = ground_material
	parent.add_child(top)
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.vertex_color_is_srgb = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sides := MeshInstance3D.new()
	sides.name = "Shore"
	sides.mesh = cliff.commit()
	sides.material_override = cm
	parent.add_child(sides)
	var body := StaticBody3D.new()
	body.name = "LandBody"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	Build.collider(body, shape)
	parent.add_child(body)
	# fondo del mar (también bajo el relieve)
	var floor_body := StaticBody3D.new()
	floor_body.position.y = FLOOR_Y
	Build.collider(floor_body, WorldBoundaryShape3D.new())
	parent.add_child(floor_body)


func _build_water() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.33, 0.45)
	m.roughness = 0.08
	m.metallic = 0.25
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = pm
	mi.material_override = m
	mi.position.y = WATER_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ---------------------------------------------------------------- capas planas

func _poly(poly: PackedVector2Array, y: float, color: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for idx: int in tris:
		var p: Vector2 = poly[idx]
		_flat.set_color(color)
		_flat.set_normal(Vector3.UP)
		_flat.add_vertex(Vector3(p.x, _y(p, y), p.y))


## Rellena el polígono solo donde hay tierra de la isla (fuera del río y del mar).
func _poly_on_land(poly: PackedVector2Array, y: float, color: Color) -> void:
	for a: PackedVector2Array in Geometry2D.intersect_polygons(poly, map.island):
		for b: PackedVector2Array in Geometry2D.clip_polygons(a, _river):
			_poly(b, y, color)


## Altura de una capa plana en `p`: el relieve más su desplazamiento (salvo en los puentes).
func _y(p: Vector2, offset: float) -> float:
	if _level:
		for span: PackedVector2Array in _level_spans:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, span[0], span[1])) < 16.0:
				return offset
	return terrain.surface(p) + offset


## Banda de `a` a `b` de media anchura `half`; en la colina se trocea para seguir el relieve.
func _quad(a: Vector2, b: Vector2, half: float, y: float, color: Color) -> void:
	var n: Vector2 = (b - a).normalized().orthogonal() * half
	var pieces: int = 1
	if _level or terrain.on_hill(a) or terrain.on_hill(b):
		pieces = maxi(1, ceili(a.distance_to(b) / 6.0))
	for s: int in pieces:
		var p0: Vector2 = a.lerp(b, float(s) / pieces)
		var p1: Vector2 = a.lerp(b, float(s + 1) / pieces)
		var pts: Array[Vector2] = [p0 + n, p1 + n, p1 - n, p0 - n]
		for k: int in [0, 1, 2, 0, 2, 3]:
			_flat.set_color(color)
			_flat.set_normal(Vector3.UP)
			_flat.add_vertex(Vector3(pts[k].x, _y(pts[k], y), pts[k].y))


func _disc(c: Vector2, r: float, y: float, color: Color) -> void:
	_poly(circle(c, r, 14), y, color)


func _build_district_ground() -> void:
	var y: float = Y_DISTRICT
	for d: Dictionary in map.districts:
		var style: String = str(d["style"])
		if DISTRICT_GROUND.has(style):
			_poly_on_land(d["poly"] as PackedVector2Array, y, DISTRICT_GROUND[style] as Color)
			y += 0.002
	for id: String in map.zones:
		if ZONE_GROUND.has(id) and id != "golf":  # el golf y la playa los pinta el relieve
			_poly_on_land(map.zones[id] as PackedVector2Array, y, ZONE_GROUND[id] as Color)


func _build_roads() -> void:
	var degree: PackedInt32Array = PackedInt32Array()
	degree.resize(map.nodes.size())
	var node_half: PackedFloat32Array = PackedFloat32Array()
	node_half.resize(map.nodes.size())
	for i: int in map.road_count():
		for n: int in [map.road_a[i], map.road_b[i]]:
			degree[n] += 1
			node_half[n] = maxf(node_half[n], map.width(i) / 2.0)
	for i: int in map.road_count():
		var a: Vector2 = map.road_start(i)
		var b: Vector2 = map.road_end(i)
		var half: float = map.width(i) / 2.0
		_level = map.road_bridge[i]
		_level_spans.clear()
		if _level:
			_level_spans = bridge_spans(a, b, _river, BRIDGE_PAD)
		_quad(a, b, half + map.sidewalk, Y_SIDEWALK, SIDEWALK_COLOR)
		_quad(a, b, half, Y_ROAD, ASPHALT)
		_markings(i, a, b, half, node_half[map.road_a[i]], node_half[map.road_b[i]], degree[map.road_a[i]], degree[map.road_b[i]])
		_level = false
	for n: int in map.nodes.size():
		if degree[n] > 0:
			_disc(map.nodes[n], node_half[n] + map.sidewalk, Y_SIDEWALK, SIDEWALK_COLOR)
			_disc(map.nodes[n], node_half[n] + 0.4, Y_ROAD + 0.001, ASPHALT)


## Barrios con pasos de cebra.
const CROSSWALK_DISTRICTS: Array[String] = ["casco", "ensanche", "financiero", "milla", "puerto", "poligono", "bajos", "bajos_este"]


## Línea central discontinua y pasos de cebra a la salida de los cruces. Todo empieza donde la
## calzada deja de pisar las otras calles del cruce (`CityMap.junction_setback`).
func _markings(i: int, a: Vector2, b: Vector2, half: float, _ra: float, _rb: float, da: int, db: int) -> void:
	var kind: String = map.road_type[i]
	var length: float = a.distance_to(b)
	var d: Vector2 = (b - a) / length
	var sa: float = map.junction_setback(map.road_a[i], i)
	var sb: float = map.junction_setback(map.road_b[i], i)
	var start: float = sa + 2.0
	var end: float = length - sb - 2.0
	if kind == "callejon" or end - start < 6.0:
		return
	var dash: float = 3.0 if kind == "calle" else 4.5
	var t: float = start
	while t + dash < end:
		_quad(a + d * t, a + d * (t + dash), 0.12, Y_MARK, MARK)
		t += dash * 2.5
	if kind == "autovia":
		for s: float in [-1.0, 1.0]:
			var off: Vector2 = d.orthogonal() * s * (half - 0.6)
			_quad(a + d * start + off, a + d * end + off, 0.1, Y_MARK, MARK)
		return
	# pasos de cebra a la salida de los cruces de más de dos calles, en calles de ciudad con sitio
	if kind == "muelle" or end - start < 14.0:
		return
	for side: int in [0, 1]:
		var node: int = map.road_a[i] if side == 0 else map.road_b[i]
		if (da if side == 0 else db) < 3 or not map.district_at(map.nodes[node]) in CROSSWALK_DISTRICTS:
			continue
		var base: float = (sa + 1.0) if side == 0 else (length - sb - 4.0)
		var nrm: Vector2 = d.orthogonal()
		var stripe: float = -half + 0.8
		while stripe < half - 0.8:
			var c: Vector2 = a + d * base + nrm * stripe
			_quad(c, c + d * 3.0, 0.3, Y_MARK, MARK)
			stripe += 1.4


# ---------------------------------------------------------------- puentes

## Tablero y barandillas solo sobre el agua (más `BRIDGE_PAD` por cada orilla): si cubrieran
## el tramo entero, las barandillas cortarían las calles que llegan al puente.
func _build_bridges() -> void:
	for i: int in map.road_count():
		if not map.road_bridge[i]:
			continue
		var a: Vector2 = map.road_start(i)
		var b: Vector2 = map.road_end(i)
		var w: float = map.width(i) + map.sidewalk * 2.0
		for span: PackedVector2Array in bridge_spans(a, b, _river, BRIDGE_PAD):
			_deck(span[0], span[1], w)
		for span: PackedVector2Array in bridge_spans(a, b, _river, 0.0):
			_railings(span[0], span[1], w)


## Tramos de la recta a-b que van sobre el agua, alargados `pad` metros por cada lado.
static func bridge_spans(a: Vector2, b: Vector2, river: PackedVector2Array, pad: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var dir: Vector2 = (b - a).normalized()
	for part: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), river):
		var p: Vector2 = part[0]
		var q: Vector2 = part[part.size() - 1]
		if (q - p).dot(dir) < 0.0:
			var t: Vector2 = p
			p = q
			q = t
		p = p - dir * minf(pad, p.distance_to(a))
		q = q + dir * minf(pad, q.distance_to(b))
		out.append(PackedVector2Array([p, q]))
	return out


## Tablero del puente (sobresale un poco por cada orilla para que no quede escalón).
func _deck(a: Vector2, b: Vector2, w: float) -> void:
	var d: Vector2 = b - a
	var mid: Vector2 = (a + b) / 2.0
	Build.box(parent, Vector3(w, 1.2, d.length()), Vector3(mid.x, -0.6 + Y_SIDEWALK - 0.01, mid.y), Color(0.6, 0.58, 0.54), true, Vector3(0, atan2(d.x, d.y), 0))


## Barandillas, solo sobre el agua: así no cortan las calles que llegan a la orilla.
func _railings(a: Vector2, b: Vector2, w: float) -> void:
	var d: Vector2 = b - a
	var length: float = d.length()
	var yaw: float = atan2(d.x, d.y)
	var mid: Vector2 = (a + b) / 2.0
	var side: Vector2 = (d / length).orthogonal() * (w / 2.0 - 0.2)
	for s: float in [-1.0, 1.0]:
		var p: Vector2 = mid + side * s
		Build.box(parent, Vector3(0.35, 1.0, length), Vector3(p.x, 0.55, p.y), Color(0.5, 0.48, 0.45), true, Vector3(0, yaw, 0))


# ---------------------------------------------------------------- aeropuerto

func _build_airport() -> void:
	var ap: Dictionary = map.airport
	_poly_on_land(ap["apron"] as PackedVector2Array, Y_SIDEWALK, Color(0.5, 0.5, 0.49))
	_poly_on_land(ap["parking"] as PackedVector2Array, Y_SIDEWALK, Color(0.3, 0.3, 0.32))
	_poly_on_land(ap["taxiway"] as PackedVector2Array, Y_ROAD, Color(0.24, 0.24, 0.26))
	var rw: PackedVector2Array = ap["runway"] as PackedVector2Array
	_poly_on_land(rw, Y_ROAD, Color(0.2, 0.2, 0.22))
	var z: float = (rw[0].y + rw[2].y) / 2.0
	var x: float = rw[0].x + 40.0
	while x < rw[1].x - 60.0:
		_quad(Vector2(x, z), Vector2(x + 30.0, z), 0.5, Y_MARK, MARK)
		x += 60.0
	for s: float in [-1.0, 1.0]:
		_quad(Vector2(rw[0].x + 10.0, z + s * 22.0), Vector2(rw[1].x - 10.0, z + s * 22.0), 0.4, Y_MARK, MARK)
	# terminal: edificio bajo y acristalado con torre de control
	var t: PackedVector2Array = ap["terminal"] as PackedVector2Array
	var size := Vector2(t[1].x - t[0].x, t[2].y - t[1].y)
	var c := Vector2(t[0].x + size.x / 2.0, t[0].y + size.y / 2.0)
	Build.box(parent, Vector3(size.x, 12.0, size.y), Vector3(c.x, 6.0, c.y), Color(0.75, 0.77, 0.8), true)
	Build.box(parent, Vector3(size.x + 0.2, 5.0, size.y + 0.2), Vector3(c.x, 7.0, c.y), Color(0.2, 0.32, 0.42))
	Build.box(parent, Vector3(size.x + 6.0, 0.8, size.y + 6.0), Vector3(c.x, 12.4, c.y), Color(0.85, 0.85, 0.85))
	var tower := Vector2(t[1].x + 40.0, t[1].y + 10.0)
	Build.cyl(parent, 3.0, 34.0, Vector3(tower.x, 17.0, tower.y), Color(0.8, 0.8, 0.78))
	Build.box(parent, Vector3(10, 5, 10), Vector3(tower.x, 36.5, tower.y), Color(0.2, 0.32, 0.42))
	Build.box(parent, Vector3(11, 0.6, 11), Vector3(tower.x, 39.3, tower.y), Color(0.85, 0.85, 0.85))
