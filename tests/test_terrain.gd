extends GutTest
## Relieve de la isla: colinas, carreteras allanadas y orillas.

var m: CityMap = CityMap.get_default()
var t: Terrain


func before_all() -> void:
	t = Terrain.new(m)
	t.build()


func test_la_colina_es_mas_alta_en_el_centro_y_nula_fuera() -> void:
	var hill: Dictionary = m.hills[0]
	var c: Vector2 = hill["center"]
	assert_almost_eq(Terrain.hill_height(m, c), float(hill["height"]), 0.01)
	assert_eq(Terrain.hill_height(m, c + Vector2(float(hill["radius"]) + 1.0, 0)), 0.0)
	assert_gt(Terrain.hill_height(m, c + Vector2(100, 0)), Terrain.hill_height(m, c + Vector2(300, 0)))


func test_el_llano_de_la_ciudad_esta_a_cero() -> void:
	assert_eq(t.surface(Vector2(-30, 380)), 0.0, "casco viejo")
	assert_eq(t.surface(Vector2(2100, 470)), 0.0, "aeropuerto")


func test_las_calles_de_la_colina_estan_allanadas_a_lo_ancho() -> void:
	# En las curvas cerradas queda algo de peralte; en conjunto, mucho más llanas que la ladera.
	var flat: float = 0.0
	var raw: float = 0.0
	var checked: int = 0
	for i: int in m.road_count():
		var a: Vector2 = m.road_start(i)
		var b: Vector2 = m.road_end(i)
		var mid: Vector2 = (a + b) / 2.0
		if Terrain.hill_height(m, mid) < 20.0 or m.road_bridge[i]:
			continue
		var n: Vector2 = (b - a).normalized().orthogonal() * (m.width(i) / 2.0)
		flat += absf(t.ground_height(mid + n) - t.ground_height(mid - n))
		raw += absf(Terrain.hill_height(m, mid + n) - Terrain.hill_height(m, mid - n))
		checked += 1
	assert_gt(checked, 10)
	assert_lt(flat / checked, 1.0, "desnivel medio a lo ancho (m)")
	assert_lt(flat, raw * 0.5, "al menos la mitad de desnivel que sin allanar")


func test_el_mar_y_el_rio_estan_al_fondo() -> void:
	assert_almost_eq(t.sample(Vector2(0, 1500)), CityBuilder.FLOOR_Y, 0.01)
	assert_lt(t.sample(m.river_line[2]), CityBuilder.WATER_Y)


func test_la_muestra_coincide_con_los_vertices_de_la_rejilla() -> void:
	var p := Terrain.ORIGIN + Vector2(Terrain.CELL * 150, Terrain.CELL * 120)
	assert_almost_eq(t.sample(p), t.heights[120 * Terrain.COLS + 150], 0.001)
