class_name Build
extends RefCounted
## Helpers to build the whole game out of primitive meshes (no external assets).

static var _mats := {}


static func mat(color: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func mesh(parent: Node, m: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, glow)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, solid := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := mesh(parent, bm, pos, color, rot)
	if solid:
		var sb := StaticBody3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		collider(sb, sh)
		mi.add_child(sb)
	return mi


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, top_radius := -1.0, glow := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = 16
	return mesh(parent, cm, pos, color, rot, glow)


static func sphere(parent: Node, radius: float, pos: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	return mesh(parent, sm, pos, color, Vector3.ZERO, glow)


static func collider(body: Node, shape: Shape3D, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	return cs


## Prisma: polígono convexo `pts` (x, z) extruido `thickness` en Y y centrado en Y.
## Sirve para alas, derivas y perfiles de carrocería (girándolo con `rot`).
static func extrude(parent: Node, pts: PackedVector2Array, thickness: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = thickness / 2.0
	var n: int = pts.size()
	var centre := Vector2.ZERO
	for p: Vector2 in pts:
		centre += p / float(n)
	for i: int in range(1, n - 1):
		_tri(st, _v(pts[0], h), _v(pts[i], h), _v(pts[i + 1], h), Vector3.UP)
		_tri(st, _v(pts[0], -h), _v(pts[i], -h), _v(pts[i + 1], -h), Vector3.DOWN)
	for i: int in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var edge: Vector2 = b - a
		var out := Vector3(edge.y, 0, -edge.x).normalized()
		var mid: Vector2 = (a + b) / 2.0 - centre
		if out.dot(Vector3(mid.x, 0, mid.y)) < 0.0:
			out = -out
		_tri(st, _v(a, h), _v(b, h), _v(b, -h), out)
		_tri(st, _v(a, h), _v(b, -h), _v(a, -h), out)
	return mesh(parent, st.commit(), pos, color, rot)


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## Añade un triángulo con la cara vista hacia `normal` (Godot: sentido horario).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var order: Array[Vector3] = [a, b, c]
	if (c - a).cross(b - a).dot(normal) < 0.0:
		order = [a, c, b]
	for p: Vector3 in order:
		st.set_normal(normal)
		st.add_vertex(p)


## Material de fachada: rejilla de ventanas repetida en coordenadas del mundo (una cada 3 m).
static func windows_mat(color: Color) -> StandardMaterial3D:
	var key := "win|%s" % color.to_html()
	if _mats.has(key):
		return _mats[key]
	if _window_tex == null:
		_window_tex = _make_window_tex()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _window_tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 12.0
	m.roughness = 0.8
	_mats[key] = m
	return m


static var _window_tex: ImageTexture


## Baldosa de 4×4 ventanas: pared blanca (se tiñe con el color del edificio) y cristales oscuros.
static func _make_window_tex() -> ImageTexture:
	var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for cx: int in 4:
		for cy: int in 4:
			var v: float = rng.randf_range(0.18, 0.42)
			var glass := Color(v * 0.8, v, v * 1.35)
			if rng.randf() < 0.15:
				glass = Color(1.0, 0.9, 0.6)  # luz encendida
			img.fill_rect(Rect2i(cx * 16 + 3, cy * 16 + 4, 10, 8), glass)
			img.fill_rect(Rect2i(cx * 16 + 2, cy * 16 + 12, 12, 1), Color(0.8, 0.8, 0.8))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
