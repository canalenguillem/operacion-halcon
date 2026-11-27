class_name BuildingsBuilder
extends RefCounted
## Edificios de la ciudad (datos de `CityMap`) con `MultiMesh`: una llamada de dibujo por pieza
## (cuerpo, tejado, extras) aunque haya miles. Cada edificio lleva una caja de colisión.
## Los edificios singulares (catedral, casino…) se montan aparte con piezas sueltas.

## Paletas por tipo de edificio (la variante 0-99 elige el color).
const PALETTES: Dictionary = {
	"casa": [Color(0.86, 0.74, 0.55), Color(0.82, 0.62, 0.45), Color(0.9, 0.85, 0.72), Color(0.75, 0.5, 0.38), Color(0.88, 0.8, 0.6), Color(0.7, 0.62, 0.5)],
	"bloque": [Color(0.78, 0.74, 0.66), Color(0.68, 0.64, 0.6), Color(0.85, 0.82, 0.75), Color(0.62, 0.58, 0.52), Color(0.74, 0.7, 0.72)],
	"torre": [Color(0.72, 0.82, 0.95), Color(0.6, 0.72, 0.78), Color(0.82, 0.78, 0.7), Color(0.55, 0.62, 0.72), Color(0.75, 0.88, 0.85)],
	"hotel": [Color(0.95, 0.9, 0.85), Color(0.9, 0.75, 0.8), Color(0.8, 0.88, 0.95), Color(0.95, 0.85, 0.65)],
	"chabola": [Color(0.55, 0.45, 0.35), Color(0.62, 0.55, 0.42), Color(0.45, 0.5, 0.52), Color(0.68, 0.42, 0.3), Color(0.5, 0.55, 0.4), Color(0.72, 0.68, 0.6)],
	"bloque_pobre": [Color(0.6, 0.56, 0.5), Color(0.55, 0.52, 0.5), Color(0.66, 0.6, 0.52)],
	"nave": [Color(0.7, 0.72, 0.74), Color(0.55, 0.62, 0.68), Color(0.75, 0.7, 0.6), Color(0.62, 0.64, 0.6)],
	"almacen": [Color(0.72, 0.55, 0.42), Color(0.5, 0.58, 0.5), Color(0.6, 0.6, 0.65)],
	"mansion": [Color(0.96, 0.95, 0.92), Color(0.92, 0.88, 0.8), Color(0.95, 0.9, 0.85), Color(0.85, 0.82, 0.78)],
	"casa_campo": [Color(0.95, 0.93, 0.86), Color(0.88, 0.78, 0.6), Color(0.8, 0.7, 0.55)],
}
## Colores de los contenedores.
const CONTAINER_COLORS: Array[Color] = [Color(0.75, 0.2, 0.15), Color(0.15, 0.35, 0.65), Color(0.2, 0.5, 0.3),
	Color(0.85, 0.6, 0.15), Color(0.55, 0.55, 0.58), Color(0.45, 0.25, 0.5), Color(0.85, 0.85, 0.82)]
## Medidas de un contenedor de 40 pies (m).
const CONTAINER: Vector3 = Vector3(12.2, 2.6, 2.45)
const FACADE: Dictionary = {
	"casa": "windows", "bloque": "windows", "bloque_pobre": "windows", "hotel": "windows", "mansion": "windows",
	"torre": "glass", "chabola": "plain", "nave": "plain", "almacen": "plain", "casa_campo": "windows",
}
const NEON: Array[Color] = [Color(1.0, 0.2, 0.6), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2), Color(0.6, 0.3, 1.0)]

var map: CityMap
var terrain: Terrain
var parent: Node3D
## Instancias por pieza: nombre → {mesh, material, transforms, colors}.
var _parts: Dictionary = {}
var _body: StaticBody3D


func _init(m: CityMap, t: Terrain, p: Node3D) -> void:
	map = m
	terrain = t
	parent = p


func build() -> void:
	_body = StaticBody3D.new()
	_body.name = "BuildingsBody"
	parent.add_child(_body)
	for i: int in map.building_count():
		_building(i)
	for i: int in map.c_pos.size():
		_containers(i)
	for lm: Dictionary in map.landmarks:
		_landmark(lm)
	_flush()


func _containers(i: int) -> void:
	var c: Vector2 = map.c_pos[i]
	var yaw: float = map.c_yaw[i]
	var levels: int = map.c_levels[i]
	var base := Vector3(c.x, _base_y(c, yaw, CONTAINER.x, CONTAINER.z), c.y)
	var box: Mesh = _unit_box()
	var mat: Material = Build.facade_mat("plain")
	for k: int in levels:
		var col: Color = CONTAINER_COLORS[(map.c_var[i] + k * 3) % CONTAINER_COLORS.size()]
		var off: Vector3 = _local(yaw, (float((map.c_var[i] + k) % 3) - 1.0) * 0.15, 0.0)
		_add("container", box, mat, _box_t(base + off + Vector3(0, k * CONTAINER.y, 0), yaw, CONTAINER), col)
	_collide(base, yaw, Vector3(CONTAINER.x, CONTAINER.y * levels, CONTAINER.z))


## Altura del suelo bajo un rectángulo (la esquina más baja: en pendiente, el resto queda enterrado).
func _base_y(c: Vector2, yaw: float, w: float, d: float) -> float:
	var y: float = 1e9
	for p: Vector2 in CityMap.rect_corners(c, yaw, w, d):
		y = minf(y, terrain.surface(p))
	return y


func _add(part: String, mesh: Mesh, mat: Material, t: Transform3D, color: Color) -> void:
	if not _parts.has(part):
		_parts[part] = {"mesh": mesh, "mat": mat, "t": [], "c": []}
	var entry: Dictionary = _parts[part]
	(entry["t"] as Array).append(t)
	(entry["c"] as Array).append(color)


## Caja de `size` con la base en `base` (centro de la base), girada `yaw`.
static func _box_t(base: Vector3, yaw: float, size: Vector3) -> Transform3D:
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	return Transform3D(b, base + Vector3(0, size.y / 2.0, 0))


## Desplazamiento en el plano girado `yaw`: `x` a lo largo de la fachada, `z` hacia el fondo.
static func _local(yaw: float, x: float, z: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3(x, 0, z)


func _collide(base: Vector3, yaw: float, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), base + Vector3(0, size.y / 2.0, 0))
	_body.add_child(cs)


func _building(i: int) -> void:
	var c: Vector2 = map.b_pos[i]
	var yaw: float = map.b_yaw[i]
	var size: Vector3 = map.b_size[i]
	var kind: String = map.b_kind[i]
	var v: int = map.b_var[i]
	var y: float = _base_y(c, yaw, size.x, size.z)
	var base := Vector3(c.x, y, c.y)
	var pal: Array = PALETTES.get(kind, PALETTES["bloque"]) as Array
	var col: Color = pal[v % pal.size()] as Color
	var box: Mesh = _unit_box()
	_add("body_" + str(FACADE.get(kind, "windows")), box, Build.facade_mat(str(FACADE.get(kind, "windows"))), _box_t(base, yaw, size), col)
	_collide(base, yaw, size)
	var top: Vector3 = base + Vector3(0, size.y, 0)
	var plain: Material = Build.facade_mat("plain")
	match kind:
		"casa", "casa_campo":
			var roof_col: Color = [Color(0.62, 0.3, 0.2), Color(0.55, 0.27, 0.18), Color(0.68, 0.38, 0.25)][v % 3]
			var t := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size.x + 0.6, 2.4, size.z + 0.8)), top)
			_add("roof_gable", _prism(), plain, t, roof_col)
		"chabola":
			var tilt := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.08) * Basis.from_scale(Vector3(size.x + 0.8, 0.15, size.z + 0.8))
			_add("roof_sheet", box, plain, Transform3D(tilt, top + Vector3(0, 0.15, 0)), [Color(0.55, 0.55, 0.58), Color(0.6, 0.38, 0.25), Color(0.45, 0.5, 0.55)][v % 3])
			if v % 4 == 0:  # bidón o trastos al lado
				_add("prop", box, plain, _box_t(base + _local(yaw, size.x / 2.0 + 0.8, 0.0), yaw, Vector3(0.8, 1.0, 0.8)), Color(0.3, 0.35, 0.45))
		"nave", "almacen":
			_add("roof_flat", box, plain, _box_t(top, yaw, Vector3(size.x + 0.4, 0.4, size.z + 0.4)), col.darkened(0.25))
			var door := Vector3(minf(8.0, size.x * 0.4), minf(6.0, size.y * 0.7), 0.3)
			_add("door", box, plain, _box_t(base + _local(yaw, 0.0, -size.z / 2.0 - 0.1), yaw, door), Color(0.25, 0.27, 0.3))
		"mansion":
			_add("roof_flat", box, plain, _box_t(top, yaw, Vector3(size.x + 1.6, 0.5, size.z + 1.6)), Color(0.35, 0.33, 0.32))
			var pool_at: Vector3 = base + _local(yaw, size.x * 0.15, size.z / 2.0 + 6.0)
			_add("pool_edge", box, plain, _box_t(pool_at, yaw, Vector3(10.0, 0.3, 5.0)), Color(0.9, 0.9, 0.88))
			_add("pool_water", box, Build.glow_mat(), _box_t(pool_at + Vector3(0, 0.05, 0), yaw, Vector3(9.0, 0.3, 4.0)), Color(0.25, 0.7, 0.9))
		_:
			_add("roof_flat", box, plain, _box_t(top, yaw, Vector3(size.x + 0.6, 0.7, size.z + 0.6)), col.darkened(0.35))
			if kind == "torre" and v % 5 < 2:  # remate escalonado
				_add("body_glass", box, Build.facade_mat("glass"), _box_t(top + Vector3(0, 0.7, 0), yaw, Vector3(size.x * 0.6, size.y * 0.12, size.z * 0.6)), col)
			if kind != "bloque_pobre" and size.y > 12.0:
				for k: int in 1 + v % 3:  # máquinas en la azotea
					var off: Vector3 = _local(yaw, (float(k) - 1.0) * size.x * 0.25, size.z * 0.15 * (1 if k % 2 == 0 else -1))
					_add("roof_unit", box, plain, _box_t(top + Vector3(0, 0.7, 0) + off, yaw, Vector3(3.0, 1.8, 2.2)), Color(0.6, 0.6, 0.62))
			if kind == "hotel":
				var neon: Color = NEON[v % NEON.size()]
				for s: float in [-1.0, 1.0]:
					var at: Vector3 = base + _local(yaw, s * (size.x / 2.0 + 0.15), -size.z / 2.0 - 0.15)
					_add("neon", box, Build.glow_mat(), _box_t(at + Vector3(0, 3.0, 0), yaw, Vector3(0.35, size.y - 4.0, 0.35)), neon)
				_add("neon", box, Build.glow_mat(), _box_t(base + _local(yaw, 0.0, -size.z / 2.0 - 0.2) + Vector3(0, 3.2, 0), yaw, Vector3(size.x * 0.8, 0.4, 0.3)), neon)


func _flush() -> void:
	for part: String in _parts:
		var entry: Dictionary = _parts[part]
		var ts: Array = entry["t"]
		var cs: Array = entry["c"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = entry["mesh"] as Mesh
		mm.instance_count = ts.size()
		for k: int in ts.size():
			mm.set_instance_transform(k, ts[k] as Transform3D)
			mm.set_instance_color(k, cs[k] as Color)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Buildings_" + part
		mmi.multimesh = mm
		mmi.material_override = entry["mat"] as Material
		if part in ["neon", "pool_water", "door", "prop"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


static var _box_mesh: BoxMesh
static var _prism_mesh: ArrayMesh


static func _unit_box() -> BoxMesh:
	if _box_mesh == null:
		_box_mesh = BoxMesh.new()
	return _box_mesh


## Tejado a dos aguas de 1×1×1: la base en y = 0 y la cumbrera a lo largo del eje X.
static func _prism() -> ArrayMesh:
	if _prism_mesh != null:
		return _prism_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0, -0.5)
	var b := Vector3(0.5, 0, -0.5)
	var c := Vector3(0.5, 0, 0.5)
	var d := Vector3(-0.5, 0, 0.5)
	var r0 := Vector3(-0.5, 1, 0)
	var r1 := Vector3(0.5, 1, 0)
	for tri: Array in [[a, b, r1], [a, r1, r0], [c, d, r0], [c, r0, r1], [a, r0, d], [b, c, r1]]:
		for p: Variant in tri:
			st.add_vertex(p as Vector3)
	st.generate_normals()
	_prism_mesh = st.commit()
	return _prism_mesh


# ---------------------------------------------------------------- edificios singulares

func _landmark(lm: Dictionary) -> void:
	var c: Vector2 = lm["pos"] as Vector2
	var yaw: float = float(lm["yaw"])
	var w: float = float(lm["w"])
	var d: float = float(lm["d"])
	var base := Vector3(c.x, _base_y(c, yaw, w, d), c.y)
	var root := Node3D.new()
	root.name = "Landmark_" + str(lm["id"])
	root.position = base
	root.rotation.y = yaw
	parent.add_child(root)
	var kind: String = str(lm["kind"])
	match kind:
		"catedral":
			_part(root, Vector3(w, 22, d), Vector3.ZERO, Color(0.78, 0.72, 0.6), "windows")
			var roof := MeshInstance3D.new()
			roof.mesh = _prism()
			roof.scale = Vector3(d + 1.0, 9.0, w + 1.0)
			roof.rotation.y = PI / 2.0
			roof.position.y = 22.0
			roof.material_override = Build.mat(Color(0.35, 0.33, 0.36))
			root.add_child(roof)
			for s: float in [-1.0, 1.0]:
				_part(root, Vector3(8, 46, 8), Vector3(s * (w / 2.0 - 4.0), 0, -d / 2.0 + 4.0), Color(0.8, 0.74, 0.62), "windows")
				Build.cyl(root, 4.6, 12.0, Vector3(s * (w / 2.0 - 4.0), 52.0, -d / 2.0 + 4.0), Color(0.3, 0.32, 0.35), Vector3.ZERO, 0.2)
			Build.cyl(root, 3.5, 0.4, Vector3(0, 15, -d / 2.0 - 0.2), Color(0.5, 0.3, 0.7), Vector3(PI / 2.0, 0, 0), -1.0, 1.5)
		"casino":
			_part(root, Vector3(w, 18, d), Vector3.ZERO, Color(0.55, 0.12, 0.12), "plain")
			Build.sphere(root, 13.0, Vector3(0, 18, 0), Color(0.85, 0.7, 0.3)).scale = Vector3(1, 0.6, 1)
			_neon_frame(root, w, d, 18.0, Color(1.0, 0.8, 0.2))
			_sign(root, "CASINO", Vector3(0, 21, -d / 2.0 - 0.5), 9.0, Color(1.0, 0.85, 0.3))
			_part(root, Vector3(20, 0.6, 10), Vector3(0, 6, -d / 2.0 - 5.0), Color(0.85, 0.7, 0.3), "plain")
		"hotel_alto":
			_part(root, Vector3(w, 78, d), Vector3.ZERO, Color(0.85, 0.9, 0.95), "glass")
			_neon_frame(root, w, d, 78.0, Color(0.2, 0.9, 1.0))
			_sign(root, "HOTEL", Vector3(0, 74, -d / 2.0 - 0.5), 6.0, Color(0.3, 0.95, 1.0))
		"hospital":
			_part(root, Vector3(w, 24, d), Vector3.ZERO, Color(0.95, 0.95, 0.95), "windows")
			_part(root, Vector3(3, 10, 0.4), Vector3(0, 9, -d / 2.0 - 0.2), Color(0.85, 0.1, 0.1), "plain")
			_part(root, Vector3(10, 3, 0.4), Vector3(0, 12.5, -d / 2.0 - 0.2), Color(0.85, 0.1, 0.1), "plain")
			Build.cyl(root, 7.0, 0.3, Vector3(0, 24.2, 4), Color(0.25, 0.5, 0.3))
			_sign(root, "HOSPITAL", Vector3(0, 20, -d / 2.0 - 0.5), 5.0, Color(1, 1, 1))
		"comisaria":
			_part(root, Vector3(w, 14, d), Vector3.ZERO, Color(0.72, 0.76, 0.82), "windows")
			_part(root, Vector3(w + 0.2, 1.4, d + 0.2), Vector3(0, 4, 0), Color(0.12, 0.25, 0.6), "plain")
			_sign(root, "POLICÍA", Vector3(0, 11, -d / 2.0 - 0.5), 4.5, Color(0.6, 0.8, 1.0))
		"banco":
			_part(root, Vector3(w, 22, d), Vector3.ZERO, Color(0.85, 0.82, 0.75), "windows")
			for k: int in 6:
				Build.cyl(root, 0.8, 12.0, Vector3(-w / 2.0 + 3.0 + k * (w - 6.0) / 5.0, 6.0, -d / 2.0 - 2.0), Color(0.9, 0.88, 0.82))
			_part(root, Vector3(w, 1.5, 4.5), Vector3(0, 12, -d / 2.0 - 1.5), Color(0.88, 0.85, 0.78), "plain")
			_sign(root, "BANCO", Vector3(0, 14.5, -d / 2.0 - 3.9), 4.0, Color(1, 0.9, 0.6))
		"estacion":
			_part(root, Vector3(w, 12, d), Vector3.ZERO, Color(0.72, 0.55, 0.42), "windows")
			var arch: MeshInstance3D = Build.cyl(root, d * 0.55, w + 2.0, Vector3(0, 12, 0), Color(0.45, 0.55, 0.6), Vector3(0, 0, PI / 2.0))
			arch.scale = Vector3(1, 1, 0.45)
			_sign(root, "ESTACIÓN", Vector3(0, 9.5, -d / 2.0 - 0.5), 4.0, Color(1, 1, 1))
		"centro_comercial":
			_part(root, Vector3(w, 14, d), Vector3.ZERO, Color(0.82, 0.8, 0.78), "plain")
			_part(root, Vector3(w * 0.6, 9, 0.5), Vector3(0, 0, -d / 2.0 - 0.2), Color(0.4, 0.55, 0.7), "glass")
			_sign(root, "CENTRO COMERCIAL", Vector3(0, 11, -d / 2.0 - 0.5), 4.0, Color(1.0, 0.4, 0.3))
		"motel":
			_part(root, Vector3(w, 6.5, d), Vector3.ZERO, Color(0.78, 0.66, 0.5), "windows")
			Build.cyl(root, 0.3, 9.0, Vector3(w / 2.0 + 4.0, 4.5, -d / 2.0 - 4.0), Color(0.3, 0.3, 0.3))
			_sign(root, "MOTEL", Vector3(w / 2.0 + 4.0, 10.0, -d / 2.0 - 4.0), 5.0, Color(1.0, 0.3, 0.6))
		"gasolinera":
			_part(root, Vector3(10, 4, 8), Vector3(0, 0, d / 2.0 - 4.0), Color(0.9, 0.9, 0.88), "plain")
			_part(root, Vector3(w, 0.8, d * 0.55), Vector3(0, 5.5, -d * 0.15), Color(0.85, 0.25, 0.15), "plain")
			for s: float in [-1.0, 1.0]:
				for t: float in [-1.0, 1.0]:
					Build.cyl(root, 0.25, 5.5, Vector3(s * w * 0.35, 2.75, -d * 0.15 + t * d * 0.18), Color(0.8, 0.8, 0.8))
				_part(root, Vector3(0.8, 1.6, 0.6), Vector3(s * w * 0.18, 0, -d * 0.15), Color(0.2, 0.4, 0.7), "plain")
			_sign(root, "GASOLINERA", Vector3(0, 7.0, -d * 0.15 - d * 0.28), 3.0, Color(1, 1, 1))
		"grua":
			var yellow := Color(0.92, 0.7, 0.12)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_part(root, Vector3(1.2, 34, 1.2), Vector3(sx * (w / 2.0 - 1.0), 0, sz * (d / 2.0 - 1.0)), yellow, "plain")
			_part(root, Vector3(w, 2.5, d), Vector3(0, 34, 0), yellow, "plain")
			_part(root, Vector3(3, 2, 70), Vector3(0, 33, d / 2.0 + 27.0), yellow, "plain")  # pluma sobre el agua
			_part(root, Vector3(3, 2, 22), Vector3(0, 33, -d / 2.0 - 9.0), yellow, "plain")  # contrapeso
			_part(root, Vector3(5, 4, 6), Vector3(0, 30, 6), Color(0.85, 0.85, 0.82), "plain")  # cabina
			_part(root, Vector3(0.3, 18, 0.3), Vector3(0, 15, d / 2.0 + 38.0), Color(0.2, 0.2, 0.2), "plain")  # cable
			_collide(base, yaw, Vector3(w, 6.0, d))
			return
		"mercado":
			_part(root, Vector3(w, 9, d), Vector3.ZERO, Color(0.7, 0.62, 0.5), "windows")
			var vault: MeshInstance3D = Build.cyl(root, w * 0.5, d + 1.0, Vector3(0, 9, 0), Color(0.45, 0.5, 0.48), Vector3(PI / 2.0, 0, 0))
			vault.scale = Vector3(1, 1, 0.3)
			_sign(root, "MERCADO", Vector3(0, 7.5, -d / 2.0 - 0.5), 4.0, Color(1, 0.95, 0.8))
	_collide(base, yaw, Vector3(w, 12.0, d))


## Bloque con la base en `at` (local al edificio singular) y su material de fachada.
func _part(root: Node3D, size: Vector3, at: Vector3, color: Color, facade: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Build.facade_part_mat(facade, color)
	mi.position = at + Vector3(0, size.y / 2.0, 0)
	root.add_child(mi)
	return mi


func _neon_frame(root: Node3D, w: float, d: float, h: float, color: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	for s: float in [-1.0, 1.0]:
		for t: float in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.4, h, 0.4)
			mi.mesh = bm
			mi.material_override = m
			mi.position = Vector3(s * (w / 2.0 + 0.2), h / 2.0, t * (d / 2.0 + 0.2))
			root.add_child(mi)


func _sign(root: Node3D, text: String, at: Vector3, size: float, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.rotation.y = PI  # el texto mira hacia -Z (la fachada)
	l.pixel_size = size / 64.0
	l.font_size = 64
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.shaded = false
	root.add_child(l)
