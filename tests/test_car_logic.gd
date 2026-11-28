extends GutTest

var d: CarData


func before_each() -> void:
	d = CarData.new()


func _run(speed: float, throttle: float, handbrake: bool, seconds: float) -> float:
	var s: float = speed
	for i: int in int(seconds * 60.0):
		s = CarLogic.next_speed(s, throttle, handbrake, 1.0 / 60.0, d)
	return s


func test_acelera_hasta_la_maxima_y_no_mas() -> void:
	assert_gt(_run(0.0, 1.0, false, 1.0), 0.0)
	assert_almost_eq(_run(0.0, 1.0, false, 30.0), d.max_speed, 0.001)


func test_marcha_atras_tiene_tope() -> void:
	assert_almost_eq(_run(0.0, -1.0, false, 30.0), -d.reverse_speed, 0.001)


func test_sin_acelerar_se_para() -> void:
	assert_almost_eq(_run(20.0, 0.0, false, 30.0), 0.0, 0.001)


func test_frenar_para_antes_que_soltar() -> void:
	assert_lt(_run(30.0, -1.0, false, 0.5), _run(30.0, 0.0, false, 0.5))


func test_el_freno_de_mano_para_antes_que_soltar() -> void:
	assert_lt(_run(30.0, 0.0, true, 0.5), _run(30.0, 0.0, false, 0.5))


func test_parado_no_gira() -> void:
	assert_eq(CarLogic.turn_rate(0.0, 1.0, d), 0.0)


func test_gira_hacia_donde_se_pide() -> void:
	assert_gt(CarLogic.turn_rate(15.0, 1.0, d), 0.0)
	assert_lt(CarLogic.turn_rate(15.0, -1.0, d), 0.0)


func test_marcha_atras_invierte_el_giro() -> void:
	assert_lt(CarLogic.turn_rate(-8.0, 1.0, d), 0.0)


func test_a_tope_gira_menos_que_a_media_velocidad() -> void:
	assert_lt(CarLogic.turn_rate(d.max_speed, 1.0, d), CarLogic.turn_rate(d.grip_speed, 1.0, d))


func test_en_una_cuesta_avanza_siguiendo_la_pendiente() -> void:
	var n: Vector3 = Vector3(0, 1, 1).normalized()  # cuesta que sube hacia -z
	var d: Vector3 = CarLogic.along_slope(Vector3.FORWARD, n)
	assert_almost_eq(d.length(), 1.0, 0.001)
	assert_gt(d.y, 0.5, "sube")
	assert_almost_eq(d.dot(n), 0.0, 0.001, "paralela al suelo")


func test_en_llano_no_cambia_la_direccion() -> void:
	assert_eq(CarLogic.along_slope(Vector3.FORWARD, Vector3.UP), Vector3.FORWARD)
