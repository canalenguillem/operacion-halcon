extends SceneTree
## Recorre todas las calles buscando obstáculos sólidos en la calzada (paredes invisibles,
## edificios, barandillas o relieve que cortan el paso). Lanza rayos a 0,9 m del suelo por el
## eje y por los dos carriles de cada calle, en tramos de 8 m que siguen el relieve.
## Uso: godot --headless --path . -s res://tools/road_audit.gd

const STEP: float = 8.0
const HEIGHT: float = 0.9


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	main.show_menu = false
	root.add_child(main)
	for i: int in 4:
		await physics_frame
	var map: CityMap = main.world.map
	var terrain: Terrain = main.world.terrain
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var hits: Dictionary = {}  # celda de 20 m → descripción
	for i: int in map.road_count():
		var a: Vector2 = map.road_start(i)
		var b: Vector2 = map.road_end(i)
		var length: float = a.distance_to(b)
		if length < 1.0:
			continue
		var n: Vector2 = (b - a).normalized().orthogonal()
		# en los puentes solo el tablero (sobre el agua) es plano; el resto sigue el relieve
		var spans: Array[PackedVector2Array] = []
		if map.road_bridge[i]:
			spans = CityBuilder.bridge_spans(a, b, map.river_polygon(), CityBuilder.BRIDGE_PAD)
		var lanes: Array[float] = [0.0]
		if map.width(i) > 8.0:
			lanes = [0.0, map.width(i) / 2.0 - 1.5, -map.width(i) / 2.0 + 1.5]
		for lane: float in lanes:
			var steps: int = maxi(1, ceili(length / STEP))
			for s: int in steps:
				var p0: Vector2 = a.lerp(b, float(s) / steps) + n * lane
				var p1: Vector2 = a.lerp(b, float(s + 1) / steps) + n * lane
				var y0: float = _road_y(p0, spans, terrain) + HEIGHT
				var y1: float = _road_y(p1, spans, terrain) + HEIGHT
				var q := PhysicsRayQueryParameters3D.create(Vector3(p0.x, y0, p0.y), Vector3(p1.x, y1, p1.y))
				q.collision_mask = Layers.WORLD
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					continue
				var at: Vector3 = hit["position"]
				var key := Vector2i(floori(at.x / 20.0), floori(at.z / 20.0))
				if hits.has(key):
					continue
				var col: Object = hit["collider"]
				var what: String = (col as Node).name if col is Node else str(col)
				if col is Node and (col as Node).get_parent() != null:
					what = "%s/%s" % [(col as Node).get_parent().name, what]
				hits[key] = "(%d, %d) calle %d %s · %s · barrio «%s»" % [at.x, at.z, i, map.road_type[i], what, map.district_at(Vector2(at.x, at.z))]
	for k: Vector2i in hits:
		print(hits[k])
	print("road_audit: %d obstáculos en calzada" % hits.size())
	var bad_lamps: int = 0
	for i: int in main.world.lamp_poles.size():
		var pole: Vector2 = main.world.lamp_poles[i]
		if map.road_clearance(pole) < 0.5:
			bad_lamps += 1
			if bad_lamps <= 10:
				print("farola en calzada: (%d, %d)" % [pole.x, pole.y])
	print("road_audit: %d farolas o semáforos sobre una calzada" % bad_lamps)
	quit()


## Altura de la calzada en `p` (la misma regla que `CityBuilder._y`).
func _road_y(p: Vector2, spans: Array[PackedVector2Array], terrain: Terrain) -> float:
	for span: PackedVector2Array in spans:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, span[0], span[1])) < 16.0:
			return 0.05
	return terrain.surface(p)
