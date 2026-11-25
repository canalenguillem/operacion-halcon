extends GutTest

var d: JetData


func before_each() -> void:
	d = JetData.new()


func test_w_en_tierra_sube_la_potencia() -> void:
	assert_gt(JetLogic.ground_throttle(0.0, -1.0, 0.0, 0.1, d), 0.0)


func test_la_potencia_no_pasa_de_uno() -> void:
	assert_eq(JetLogic.ground_throttle(0.99, -1.0, 0.0, 1.0, d), 1.0)


func test_s_en_tierra_frena_si_va_lento() -> void:
	assert_lt(JetLogic.ground_throttle(0.5, 1.0, 10.0, 0.1, d), 0.5)


func test_s_a_velocidad_de_despegue_no_frena() -> void:
	assert_eq(JetLogic.ground_throttle(0.5, 1.0, d.takeoff_speed, 0.1, d), 0.5)


func test_sin_tocar_nada_la_potencia_se_queda() -> void:
	assert_eq(JetLogic.ground_throttle(0.5, 0.0, 10.0, 0.1, d), 0.5)


func test_no_despega_lento() -> void:
	assert_false(JetLogic.should_lift(1.0, d.takeoff_speed - 1.0, d))


func test_despega_tirando_del_morro_a_velocidad_de_despegue() -> void:
	assert_true(JetLogic.should_lift(1.0, d.takeoff_speed, d))


func test_no_despega_solo_entre_las_dos_velocidades() -> void:
	assert_false(JetLogic.should_lift(-1.0, d.auto_lift_speed - 1.0, d))


func test_despega_solo_con_w_pulsada() -> void:
	assert_true(JetLogic.should_lift(-1.0, d.auto_lift_speed, d))


func test_solo_con_w_llega_a_despegar() -> void:
	var throttle: float = 0.0
	var speed: float = 0.0
	var lifted: bool = false
	for i: int in 600:
		throttle = JetLogic.ground_throttle(throttle, -1.0, speed, 1.0 / 60.0, d)
		speed = move_toward(speed, throttle * d.max_speed, d.ground_acceleration / 60.0)
		if JetLogic.should_lift(-1.0, speed, d):
			lifted = true
			break
	assert_true(lifted, "acelerando solo con W debe despegar en menos de 10 s")


func test_no_hay_perdida_por_encima_de_la_velocidad_de_despegue() -> void:
	assert_eq(JetLogic.stall(d.takeoff_speed, d), 0.0)
	assert_eq(JetLogic.stall(d.max_speed, d), 0.0)


func test_perdida_total_parado() -> void:
	assert_eq(JetLogic.stall(0.0, d), 1.0)


func test_subir_frena_y_bajar_acelera() -> void:
	var level: float = JetLogic.air_speed(100.0, 100.0 / d.max_speed, 0.0, 1.0, d)
	assert_lt(JetLogic.air_speed(100.0, 100.0 / d.max_speed, 1.0, 1.0, d), level)
	assert_gt(JetLogic.air_speed(100.0, 100.0 / d.max_speed, -1.0, 1.0, d), level)


func test_aterriza_plano_y_nivelado() -> void:
	assert_true(JetLogic.can_land(Vector3.UP, Vector3(0, -0.1, -1).normalized(), 0.0))


func test_no_aterriza_en_picado_ni_de_lado_ni_contra_una_pared() -> void:
	assert_false(JetLogic.can_land(Vector3.UP, Vector3(0, -0.6, -0.8), 0.0))
	assert_false(JetLogic.can_land(Vector3.UP, Vector3.FORWARD, 0.7))
	assert_false(JetLogic.can_land(Vector3.BACK, Vector3.FORWARD, 0.0))
