extends GutTest


func test_los_cazas_estan_dentro_de_la_base() -> void:
	for p: Vector3 in World.JET_SPOTS:
		assert_true(World.in_base(p))


func test_el_jugador_y_los_coches_empiezan_fuera_de_la_base() -> void:
	assert_false(World.in_base(World.PLAYER_START))
	for p: Vector3 in World.CAR_SPOTS:
		assert_false(World.in_base(p))


func test_justo_pasada_la_puerta_ya_es_base() -> void:
	assert_true(World.in_base(World.GATE + Vector3(0, 0, -1)))
	assert_false(World.in_base(World.GATE + Vector3(0, 0, 1)))


func test_hay_un_color_por_coche() -> void:
	assert_eq(World.CAR_COLORS.size(), World.CAR_SPOTS.size())


func test_la_distancia_al_aerodromo_ignora_la_altura() -> void:
	assert_eq(World.dest_distance(World.DEST + Vector3(0, 500, 0)), 0.0)
	assert_almost_eq(World.dest_distance(World.DEST + Vector3(300, 0, 400)), 500.0, 0.01)


func test_no_se_plantan_arboles_en_la_base_ni_en_calles_ni_en_el_mar_ni_en_el_aerodromo() -> void:
	assert_false(World.clear_spot(0.0, -1000.0), "base")
	assert_false(World.clear_spot(-30.0, -300.0), "Gran Vía")
	assert_false(World.clear_spot(-3000.0, 3000.0), "mar")
	assert_false(World.clear_spot(World.DEST.x, World.DEST.z), "aeródromo")
	assert_false(World.clear_spot(500.0, 450.0), "distrito financiero")
	assert_true(World.clear_spot(-1300.0, -950.0), "campo al norte de la colina")


func test_el_jugador_los_coches_la_base_y_las_baterias_estan_en_tierra() -> void:
	var m: CityMap = CityMap.get_default()
	assert_true(m.on_land(Vector2(World.PLAYER_START.x, World.PLAYER_START.z)))
	for p: Vector3 in World.CAR_SPOTS + World.JET_SPOTS + World.BASE_SAMS + World.ROUTE_SAMS:
		assert_true(m.on_land(Vector2(p.x, p.z)), "en tierra: %s" % p)
	assert_true(m.on_land(Vector2(World.DEST.x, World.DEST.z)))


func test_las_baterias_de_la_base_estan_dentro_y_las_de_ruta_fuera() -> void:
	for p: Vector3 in World.BASE_SAMS:
		assert_true(World.in_base(p))
	for p: Vector3 in World.ROUTE_SAMS:
		assert_false(World.in_base(p))
