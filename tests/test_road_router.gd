extends GutTest
## Rutas del GPS por la red de calles.

var m: CityMap = CityMap.get_default()
var r: RoadRouter = RoadRouter.new(m)


func test_hay_ruta_del_aeropuerto_al_casco_viejo() -> void:
	var route: PackedVector2Array = r.route(Vector2(2100, 470), Vector2(-30, 380))
	assert_gt(route.size(), 3)
	assert_eq(route[0], Vector2(2100, 470))
	assert_eq(route[route.size() - 1], Vector2(-30, 380))


func test_cada_paso_de_la_ruta_es_una_calle() -> void:
	var a: int = r.nearest_node(Vector2(2100, 470))
	var b: int = r.nearest_node(Vector2(0, -700))
	var path: PackedInt32Array = r.node_path(a, b)
	assert_gt(path.size(), 2)
	var roads: Dictionary = {}
	for i: int in m.road_count():
		roads[Vector2i(mini(m.road_a[i], m.road_b[i]), maxi(m.road_a[i], m.road_b[i]))] = true
	for k: int in path.size() - 1:
		var key := Vector2i(mini(path[k], path[k + 1]), maxi(path[k], path[k + 1]))
		assert_true(roads.has(key), "tramo %d-%d" % [path[k], path[k + 1]])


func test_la_ruta_no_es_mucho_mas_larga_que_la_linea_recta() -> void:
	var from := Vector2(-30, 380)
	var to := Vector2(2100, 470)
	var route: PackedVector2Array = r.route(from, to)
	var length: float = 0.0
	for k: int in route.size() - 1:
		length += route[k].distance_to(route[k + 1])
	assert_lt(length, from.distance_to(to) * 1.8)


func test_ruta_al_mismo_cruce() -> void:
	var n: int = r.nearest_node(Vector2(-30, 380))
	assert_eq(r.node_path(n, n), PackedInt32Array([n]))


func test_el_cruce_mas_cercano_esta_cerca() -> void:
	var n: int = r.nearest_node(Vector2(-30, 380))
	assert_lt(m.nodes[n].distance_to(Vector2(-30, 380)), 120.0)
