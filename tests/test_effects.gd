extends GutTest


func test_una_explosion_cercana_sacude_mas_que_una_lejana() -> void:
	assert_gt(CameraLogic.shake_amount(7.0, 10.0), CameraLogic.shake_amount(7.0, 200.0))


func test_una_explosion_grande_sacude_mas_que_una_pequena() -> void:
	assert_gt(CameraLogic.shake_amount(16.0, 100.0), CameraLogic.shake_amount(3.0, 100.0))


func test_la_sacudida_tiene_tope() -> void:
	assert_eq(CameraLogic.shake_amount(100.0, 0.0), CameraLogic.MAX_SHAKE)
	assert_eq(CameraLogic.add(0.7, 0.7), CameraLogic.MAX_SHAKE)


func test_el_lanzamiento_de_un_misil_lejano_casi_no_sacude() -> void:
	assert_lt(CameraLogic.shake_amount(3.0, 1000.0), 0.01)


func test_la_sacudida_se_apaga() -> void:
	var s: float = CameraLogic.MAX_SHAKE
	for i: int in 120:
		s = CameraLogic.decay(s, 1.0 / 60.0)
	assert_eq(s, 0.0)


func test_un_vehiculo_sano_no_echa_humo() -> void:
	assert_false(Vehicle.smokes(100.0, 100.0, false))
	assert_false(Vehicle.smokes(41.0, 100.0, false))


func test_un_vehiculo_tocado_o_destruido_echa_humo() -> void:
	assert_true(Vehicle.smokes(39.0, 100.0, false))
	assert_true(Vehicle.smokes(0.0, 100.0, true))


func test_el_motor_suena_mas_agudo_cuanto_mas_rapido() -> void:
	assert_gt(Sfx.engine_pitch(1.0), Sfx.engine_pitch(0.5))
	assert_gt(Sfx.engine_pitch(0.5), Sfx.engine_pitch(0.0))
	assert_eq(Sfx.engine_pitch(5.0), Sfx.engine_pitch(1.0))


func test_la_alarma_se_oye_a_tope_cerca_y_nada_lejos() -> void:
	assert_almost_eq(Sfx.fade_db(100.0, 400.0, 1500.0), 0.0, 0.001)
	assert_lt(Sfx.fade_db(1000.0, 400.0, 1500.0), 0.0)
	assert_lt(Sfx.fade_db(2000.0, 400.0, 1500.0), -50.0)


func test_existen_todos_los_archivos_de_sonido() -> void:
	for n: String in Sfx.ONE_SHOTS + Sfx.LOOPS:
		assert_true(ResourceLoader.exists(Sfx.SFX_DIR + n + ".ogg"), "falta %s.ogg" % n)
	assert_true(ResourceLoader.exists(Sfx.MUSIC_PATH))


func test_el_volumen_cero_silencia_el_bus() -> void:
	var before: float = Settings.volume
	Settings.volume = 0.0
	Sfx.apply_volume()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))
	Settings.volume = 0.5
	Sfx.apply_volume()
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")), linear_to_db(0.5), 0.01)
	Settings.volume = before
	Sfx.apply_volume()
