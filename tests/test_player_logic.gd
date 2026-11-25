extends GutTest

var data: PlayerData


func before_each() -> void:
	data = PlayerData.new()


func test_adelante_sin_girar_la_camara_es_norte() -> void:
	var dir: Vector3 = PlayerLogic.move_dir(Vector2(0, -1), 0.0)
	assert_almost_eq(dir, Vector3(0, 0, -1), Vector3.ONE * 0.001)


func test_adelante_con_la_camara_a_la_izquierda_es_oeste() -> void:
	var dir: Vector3 = PlayerLogic.move_dir(Vector2(0, -1), PI / 2.0)
	assert_almost_eq(dir, Vector3(-1, 0, 0), Vector3.ONE * 0.001)


func test_derecha_es_este() -> void:
	var dir: Vector3 = PlayerLogic.move_dir(Vector2(1, 0), 0.0)
	assert_almost_eq(dir, Vector3(1, 0, 0), Vector3.ONE * 0.001)


func test_el_movimiento_no_tiene_componente_vertical() -> void:
	assert_eq(PlayerLogic.move_dir(Vector2(0.6, -0.8), 1.3).y, 0.0)


func test_mirar_hacia_donde_se_anda_coincide_con_la_camara() -> void:
	for yaw: float in [0.0, 0.7, -1.2, 2.5]:
		var dir: Vector3 = PlayerLogic.move_dir(Vector2(0, -1), yaw)
		assert_almost_eq(angle_difference(PlayerLogic.facing_yaw(dir), yaw), 0.0, 0.001)


func test_corre_mas_que_anda() -> void:
	assert_eq(PlayerLogic.target_speed(false, data), data.walk_speed)
	assert_eq(PlayerLogic.target_speed(true, data), data.sprint_speed)
	assert_gt(data.sprint_speed, data.walk_speed)


func test_no_recupera_salud_recien_herido() -> void:
	assert_eq(PlayerLogic.regen(50.0, data.regen_delay - 0.1, 1.0, data), 50.0)


func test_recupera_salud_pasado_el_retraso() -> void:
	assert_almost_eq(PlayerLogic.regen(50.0, data.regen_delay, 1.0, data), 50.0 + data.regen_rate, 0.001)


func test_la_salud_no_pasa_del_maximo() -> void:
	assert_eq(PlayerLogic.regen(data.max_health - 0.5, 99.0, 5.0, data), data.max_health)


func test_raton_a_la_derecha_gira_la_camara_a_la_derecha() -> void:
	var r: Vector2 = PlayerLogic.orbit(0.0, 0.0, Vector2(100, 0), data)
	assert_lt(r.x, 0.0)
	assert_eq(r.y, 0.0)


func test_el_cabeceo_de_la_camara_tiene_tope() -> void:
	assert_almost_eq(PlayerLogic.orbit(0.0, 0.0, Vector2(0, 100000), data).y, data.pitch_min, 0.0001)
	assert_almost_eq(PlayerLogic.orbit(0.0, 0.0, Vector2(0, -100000), data).y, data.pitch_max, 0.0001)


func test_la_ayuda_elige_al_objetivo_casi_en_la_mira() -> void:
	var targets: Array[Vector3] = [Vector3(20, 0, -30), Vector3(1, 0, -30), Vector3(-10, 0, -30)]
	assert_eq(PlayerLogic.aim_assist(Vector3.ZERO, Vector3.FORWARD, targets, 3.0, 1.0, 250.0), 1)


func test_la_ayuda_no_corrige_si_apuntas_lejos() -> void:
	var targets: Array[Vector3] = [Vector3(10, 0, -30)]
	assert_eq(PlayerLogic.aim_assist(Vector3.ZERO, Vector3.FORWARD, targets, 3.0, 1.0, 250.0), -1)


func test_la_ayuda_elige_el_de_menor_angulo() -> void:
	var targets: Array[Vector3] = [Vector3(1.2, 0, -30), Vector3(0.3, 0, -30)]
	assert_eq(PlayerLogic.aim_assist(Vector3.ZERO, Vector3.FORWARD, targets, 3.0, 1.0, 250.0), 1)


func test_la_ayuda_respeta_el_alcance() -> void:
	var targets: Array[Vector3] = [Vector3(0, 0, -300), Vector3(0, 0, -0.5), Vector3(0, 0, 30)]
	assert_eq(PlayerLogic.aim_assist(Vector3.ZERO, Vector3.FORWARD, targets, 3.0, 1.0, 250.0), -1)


func test_sin_grados_no_hay_ayuda_salvo_tiro_perfecto() -> void:
	var targets: Array[Vector3] = [Vector3(0.5, 0, -30)]
	assert_eq(PlayerLogic.aim_assist(Vector3.ZERO, Vector3.FORWARD, targets, 0.0, 1.0, 250.0), -1)
