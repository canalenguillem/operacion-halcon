class_name Terrain
extends RefCounted
## Relieve de la isla en una rejilla de `CELL` metros: colinas (con las carreteras allanadas),
## orillas en pendiente hacia el mar y el río, malla con colores por vértice y colisión
## `HeightMapShape3D`. Los islotes no van aquí (ver `CityBuilder`).

const CELL: float = 10.0
## Esquina noroeste de la rejilla y su tamaño en vértices.
const ORIGIN: Vector2 = Vector2(-2400, -1800)
const COLS: int = 601
const ROWS: int = 311
## Cuánto se ensancha la tierra hacia el agua (para que la pendiente de la orilla caiga fuera
## de las calles y los barrios, que llegan justo hasta la costa).
const SHORE_PAD: float = 7.0
## Pasadas de suavizado del relieve de las colinas.
const SMOOTH_PASSES: int = 2

var map: CityMap
var heights: PackedFloat32Array = PackedFloat32Array()
var land: PackedByteArray = PackedByteArray()


func _init(m: CityMap) -> void:
	map = m


## Cerca del río el suelo queda llano (los puentes llegan a nivel): a menos de `RIVER_FLAT`
## metros del cauce la colina no sube, y se suaviza hasta `RIVER_FADE`.
const RIVER_FLAT: float = 45.0
const RIVER_FADE: float = 140.0


## Altura de las colinas en un punto (campana suave), sin allanar las carreteras.
static func hill_height(m: CityMap, p: Vector2) -> float:
	var h: float = 0.0
	for hill: Dictionary in m.hills:
		var d: float = p.distance_to(hill["center"] as Vector2) / float(hill["radius"])
		if d < 1.0:
			h += float(hill["height"]) * (0.5 + 0.5 * cos(PI * d))
	if h > 0.0:
		h *= smoothstep(RIVER_FLAT, RIVER_FADE, river_distance(m, p))
	return h


## Distancia al eje del río.
static func river_distance(m: CityMap, p: Vector2) -> float:
	var best: float = 1e9
	for i: int in m.river_line.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, m.river_line[i], m.river_line[i + 1])))
	return best


## Altura del suelo firme: la de la colina, pero llana a lo ancho de las carreteras (como un bancal).
func ground_height(p: Vector2) -> float:
	var raw: float = hill_height(map, p)
	if raw < 0.05:
		return raw
	var near: Array = map.closest_road(p, 30.0)
	if near.is_empty():
		return raw
	var i: int = near[0]
	var q: Vector2 = near[1]
	var edge: float = map.width(i) / 2.0 + map.sidewalk + 1.0
	var t: float = smoothstep(edge + 7.0, edge, p.distance_to(q))
	return lerpf(raw, hill_height(map, q), t)


## ¿Está el punto en la zona de alguna colina? (allí las calles siguen el relieve)
func on_hill(p: Vector2) -> bool:
	for hill: Dictionary in map.hills:
		if p.distance_to(hill["center"] as Vector2) < float(hill["radius"]) + 20.0:
			return true
	return false


func build() -> void:
	heights.resize(COLS * ROWS)
	land.resize(COLS * ROWS)
	var river: PackedVector2Array = map.river_polygon()
	for row: int in ROWS:
		var z: float = ORIGIN.y + row * CELL
		var land_iv: Array[Vector2] = []
		for dz: float in [-SHORE_PAD, 0.0, SHORE_PAD]:
			land_iv.append_array(_intervals(map.island, z + dz, SHORE_PAD))
			for pier: PackedVector2Array in map.piers:
				land_iv.append_array(_intervals(pier, z + dz, SHORE_PAD))
		var river_iv: Array[Vector2] = _intervals(river, z, -SHORE_PAD)
		for col: int in COLS:
			var x: float = ORIGIN.x + col * CELL
			var is_land: bool = _inside(land_iv, x) and not _inside(river_iv, x)
			var k: int = row * COLS + col
			land[k] = 1 if is_land else 0
			heights[k] = ground_height(Vector2(x, z)) if is_land else CityBuilder.FLOOR_Y
	_smooth_hills(SMOOTH_PASSES)


## Promedia cada vértice de la colina con sus vecinos: quita los escalones que quedan donde
## se juntan los bancales de dos carreteras a distinta altura.
func _smooth_hills(passes: int) -> void:
	for p: int in passes:
		var out: PackedFloat32Array = heights.duplicate()
		for row: int in range(1, ROWS - 1):
			for col: int in range(1, COLS - 1):
				var k: int = row * COLS + col
				if land[k] == 0 or heights[k] < 0.05:
					continue
				var sum: float = heights[k] * 4.0
				var count: float = 4.0
				for o: int in [k - 1, k + 1, k - COLS, k + COLS]:
					if land[o] == 1:
						sum += heights[o]
						count += 1.0
				out[k] = sum / count
		heights = out


## Altura de la superficie de la malla en un punto (la misma interpolación que sus triángulos).
func sample(p: Vector2) -> float:
	var fx: float = (p.x - ORIGIN.x) / CELL
	var fz: float = (p.y - ORIGIN.y) / CELL
	var col: int = clampi(floori(fx), 0, COLS - 2)
	var row: int = clampi(floori(fz), 0, ROWS - 2)
	var u: float = clampf(fx - col, 0.0, 1.0)
	var v: float = clampf(fz - row, 0.0, 1.0)
	var h00: float = heights[row * COLS + col]
	var h10: float = heights[row * COLS + col + 1]
	var h01: float = heights[(row + 1) * COLS + col]
	var h11: float = heights[(row + 1) * COLS + col + 1]
	if u + v <= 1.0:  # triángulo (00, 10, 01)
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


## Altura a la que se apoya lo que va sobre el suelo: relieve en las colinas, 0 en el llano.
func surface(p: Vector2) -> float:
	return maxf(sample(p), 0.0) if on_hill(p) else 0.0  # sin hundirse hacia la orilla


## Tramos [x0, x1] de la fila `z` dentro del polígono, ensanchados (o encogidos si pad < 0).
static func _intervals(poly: PackedVector2Array, z: float, pad: float) -> Array[Vector2]:
	var xs: Array[float] = []
	var n: int = poly.size()
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if (a.y > z) != (b.y > z):
			xs.append(a.x + (z - a.y) * (b.x - a.x) / (b.y - a.y))
	xs.sort()
	var out: Array[Vector2] = []
	for i: int in range(0, xs.size() - 1, 2):
		if xs[i + 1] - xs[i] + pad * 2.0 > 0.0:
			out.append(Vector2(xs[i] - pad, xs[i + 1] + pad))
	return out


static func _inside(iv: Array[Vector2], x: float) -> bool:
	for r: Vector2 in iv:
		if x >= r.x and x <= r.y:
			return true
	return false


# ---------------------------------------------------------------- malla y colisión

func make_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = _mesh()
	mi.material_override = _material()
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := HeightMapShape3D.new()
	shape.map_width = COLS
	shape.map_depth = ROWS
	var data := PackedFloat32Array()
	data.resize(heights.size())
	for k: int in heights.size():
		data[k] = heights[k] / CELL  # la forma se escala por CELL en los tres ejes
	shape.map_data = data
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3.ONE * CELL
	col.position = Vector3(ORIGIN.x + (COLS - 1) * CELL / 2.0, 0.0, ORIGIN.y + (ROWS - 1) * CELL / 2.0)
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.add_child(col)
	root.add_child(body)
	return root


func _mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(COLS * ROWS)
	normals.resize(COLS * ROWS)
	colors.resize(COLS * ROWS)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.004
	noise.seed = 5
	var golf: PackedVector2Array = map.zones.get("golf", PackedVector2Array()) as PackedVector2Array
	var golf_box: Rect2 = _bbox(golf)
	var beach_box: Rect2 = _bbox(map.beach)
	for row: int in ROWS:
		for col: int in COLS:
			var k: int = row * COLS + col
			var x: float = ORIGIN.x + col * CELL
			var z: float = ORIGIN.y + row * CELL
			var h: float = heights[k]
			verts[k] = Vector3(x, h, z)
			var hl: float = heights[k - 1] if col > 0 else h
			var hr: float = heights[k + 1] if col < COLS - 1 else h
			var hu: float = heights[k - COLS] if row > 0 else h
			var hd: float = heights[k + COLS] if row < ROWS - 1 else h
			var nrm := Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()
			normals[k] = nrm
			var p := Vector2(x, z)
			var n: float = noise.get_noise_2d(x, z) * 0.5 + 0.5
			var c: Color = Color(0.25, 0.38, 0.18).lerp(Color(0.47, 0.5, 0.28), n)
			if land[k] == 0 or h < -0.3:
				c = Color(0.62, 0.57, 0.42)  # arena y fondo de la orilla
			elif beach_box.has_point(p) and Geometry2D.is_point_in_polygon(p, map.beach):
				c = Color(0.86, 0.78, 0.58)
			elif golf_box.has_point(p) and Geometry2D.is_point_in_polygon(p, golf):
				c = Color(0.3, 0.55, 0.22) if fmod(x + z, 40.0) < 20.0 else Color(0.27, 0.5, 0.2)
			elif nrm.y < 0.93:
				c = c.lerp(Color(0.45, 0.4, 0.33), 0.5)  # ladera empinada: tierra
			colors[k] = c
	var idx := PackedInt32Array()
	for row: int in ROWS - 1:
		for col: int in COLS - 1:
			var k: int = row * COLS + col
			if land[k] + land[k + 1] + land[k + COLS] + land[k + COLS + 1] == 0:
				continue  # fondo del mar: no se ve
			idx.append_array([k, k + 1, k + COLS, k + COLS + 1, k + COLS, k + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _material() -> StandardMaterial3D:
	var detail := NoiseTexture2D.new()
	detail.width = 256
	detail.height = 256
	detail.seamless = true
	var dn := FastNoiseLite.new()
	dn.frequency = 0.05
	detail.noise = dn
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.78, 0.78))
	grad.set_color(1, Color(1, 1, 1))
	detail.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = detail
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 24.0
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _bbox(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		r = r.expand(p)
	return r
