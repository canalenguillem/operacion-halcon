extends GutTest
## Ciclo de día y noche (lógica pura).


func test_el_reloj_avanza_y_da_la_vuelta() -> void:
	assert_almost_eq(DayNightLogic.advance(10.0, 60.0, 24.0), 11.0, 0.001, "un minuto real es una hora")
	assert_almost_eq(DayNightLogic.advance(23.5, 60.0, 24.0), 0.5, 0.001)


func test_el_sol_esta_alto_a_mediodia_y_bajo_a_medianoche() -> void:
	assert_almost_eq(DayNightLogic.sun_elevation(12.0), 70.0, 0.01)
	assert_lt(DayNightLogic.sun_elevation(0.0), -60.0)
	assert_almost_eq(DayNightLogic.sun_elevation(6.0), 0.0, 0.01)


func test_hay_luz_de_dia_solo_de_dia() -> void:
	assert_almost_eq(DayNightLogic.daylight(13.0), 1.0, 0.01)
	assert_almost_eq(DayNightLogic.daylight(1.0), 0.0, 0.01)


func test_las_luces_se_encienden_de_noche() -> void:
	assert_almost_eq(DayNightLogic.lights_on(23.0), 1.0, 0.01)
	assert_almost_eq(DayNightLogic.lights_on(12.0), 0.0, 0.01)


func test_el_atardecer_se_nota_al_ponerse_el_sol() -> void:
	assert_gt(DayNightLogic.dusk(18.0), 0.5)
	assert_eq(DayNightLogic.dusk(12.0), 0.0)


func test_formato_del_reloj() -> void:
	assert_eq(DayNightLogic.clock(9.5), "09:30")
	assert_eq(DayNightLogic.clock(0.0), "00:00")
	assert_eq(DayNightLogic.clock(23.99), "23:59")
