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
