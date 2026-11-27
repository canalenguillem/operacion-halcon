extends GutTest
## El mapa de la isla (data/map/city.json) es coherente.

var m: CityMap = CityMap.get_default()


func test_hay_calles_y_cada_una_une_dos_cruces_validos() -> void:
	assert_gt(m.road_count(), 500)
	for i: int in m.road_count():
		assert_true(m.road_a[i] >= 0 and m.road_a[i] < m.nodes.size())
		assert_true(m.road_b[i] >= 0 and m.road_b[i] < m.nodes.size())
		assert_ne(m.road_a[i], m.road_b[i])
		assert_true(m.road_widths.has(m.road_type[i]), "tipo conocido: %s" % m.road_type[i])


func test_la_red_de_calles_esta_toda_conectada() -> void:
	var adj: Dictionary = {}
	for i: int in m.road_count():
		for pair: Array in [[m.road_a[i], m.road_b[i]], [m.road_b[i], m.road_a[i]]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			(adj[pair[0]] as Array).append(pair[1])
	var seen: Dictionary = {m.road_a[0]: true}
	var stack: Array[int] = [m.road_a[0]]
	while not stack.is_empty():
		var n: int = stack.pop_back()
		for o: int in (adj[n] as Array):
			if not seen.has(o):
				seen[o] = true
				stack.append(o)
	assert_eq(seen.size(), adj.size())


func test_las_calles_estan_en_tierra_salvo_los_puentes() -> void:
	var wet: int = 0
	for i: int in m.road_count():
		var mid: Vector2 = (m.road_start(i) + m.road_end(i)) / 2.0
		if not m.road_bridge[i] and not m.on_land(mid):
			wet += 1
	assert_eq(wet, 0)


func test_hay_puentes_sobre_el_rio() -> void:
	assert_gt(m.road_bridge.count(true), 4)


func test_el_rio_no_es_tierra_y_la_isla_si() -> void:
	assert_false(m.on_land(m.river_line[2]))
	assert_true(m.on_land(Vector2(-30, 380)), "casco viejo")
	assert_false(m.on_land(Vector2(0, 1500)), "mar")


func test_cada_lugar_conocido_esta_en_tierra() -> void:
	for p: Dictionary in m.pois:
		assert_true(m.on_land(p["pos"] as Vector2), "%s en tierra" % p["id"])


func test_barrio_de_un_punto() -> void:
	assert_eq(m.district_at(Vector2(-30, 380)), "casco")
	assert_eq(m.district_at(Vector2(2100, 470)), "aeropuerto")
	assert_eq(m.district_at(Vector2(-1300, -950)), "")


func test_distancia_a_la_calzada() -> void:
	var a: Vector2 = m.road_start(0)
	var b: Vector2 = m.road_end(0)
	assert_lt(m.road_clearance((a + b) / 2.0), 0.0, "en mitad de una calzada")
	assert_gt(m.road_clearance(Vector2(-1300, -950)), 50.0, "en el campo")


func test_hay_edificios_en_tierra_y_fuera_de_las_calzadas() -> void:
	assert_gt(m.building_count(), 1500)
	var bad: int = 0
	for i: int in m.building_count():
		var c: Vector2 = m.b_pos[i]
		if not m.on_land(c) or m.road_clearance(c) < 0.0:
			bad += 1
	assert_eq(bad, 0)


func test_los_edificios_singulares_estan_cerca_de_su_lugar() -> void:
	var ids: Array[String] = []
	for lm: Dictionary in m.landmarks:
		ids.append(str(lm["id"]))
	for id: String in ["catedral", "casino", "hospital", "comisaria", "banco", "gasolinera"]:
		assert_has(ids, id)


func test_esquinas_de_un_rectangulo_girado() -> void:
	var cs: PackedVector2Array = CityMap.rect_corners(Vector2.ZERO, 0.0, 4.0, 2.0)
	assert_eq(cs[0], Vector2(-2, -1))
	assert_eq(cs[2], Vector2(2, 1))
	var r: PackedVector2Array = CityMap.rect_corners(Vector2.ZERO, PI / 2.0, 4.0, 2.0)
	assert_almost_eq(r[0].x, -1.0, 0.001, "girado 90°, el ancho va a lo largo de z")
	assert_almost_eq(r[0].y, 2.0, 0.001)
