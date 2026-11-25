extends GutTest

const TEST_PATH: String = "user://test_settings.cfg"

var _real_path: String


func before_each() -> void:
	_real_path = Settings.path
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	Settings.reset()


func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	Settings.path = _real_path
	Settings.load_file()


func test_sin_archivo_quedan_los_valores_por_defecto() -> void:
	Settings.load_file()
	assert_eq(Settings.mouse_scale, 1.0)
	assert_eq(Settings.difficulty, 1)
	assert_eq(Settings.best_time, 0.0)


func test_guardar_y_cargar_conserva_las_opciones() -> void:
	Settings.mouse_scale = 2.0
	Settings.difficulty = 2
	Settings.best_time = 123.0
	Settings.volume = 0.25
	Settings.music_volume = 0.0
	Settings.save_file()
	Settings.reset()
	Settings.load_file()
	assert_eq(Settings.volume, 0.25)
	assert_eq(Settings.music_volume, 0.0)
	assert_eq(Settings.mouse_scale, 2.0)
	assert_eq(Settings.difficulty, 2)
	assert_eq(Settings.best_time, 123.0)


func test_cargar_corrige_valores_fuera_de_rango() -> void:
	Settings.mouse_scale = 99.0
	Settings.difficulty = 7
	Settings.best_time = -5.0
	Settings.save_file()
	Settings.load_file()
	assert_eq(Settings.mouse_scale, Settings.SENSITIVITY_MAX)
	assert_eq(Settings.difficulty, 2)
	assert_eq(Settings.best_time, 0.0)


func test_el_primer_tiempo_es_record() -> void:
	assert_true(Settings.is_record(200.0, 0.0))


func test_solo_un_tiempo_menor_es_record() -> void:
	assert_true(Settings.is_record(150.0, 200.0))
	assert_false(Settings.is_record(200.0, 200.0))
	assert_false(Settings.is_record(250.0, 200.0))


func test_apuntar_un_record_lo_guarda() -> void:
	assert_true(Settings.submit_time(180.0))
	assert_false(Settings.submit_time(190.0))
	Settings.reset()
	Settings.load_file()
	assert_eq(Settings.best_time, 180.0)


func test_formato_de_tiempo() -> void:
	assert_eq(Settings.format_time(0.0), "0:00")
	assert_eq(Settings.format_time(65.9), "1:05")
	assert_eq(Settings.format_time(600.0), "10:00")


func test_facil_hace_menos_dano_y_recarga_mas_lento_que_dificil() -> void:
	Settings.difficulty = 0
	var easy_damage: float = Settings.soldier_damage_scale()
	var easy_reload: float = Settings.sam_reload_scale()
	Settings.difficulty = 2
	assert_lt(easy_damage, Settings.soldier_damage_scale())
	assert_gt(easy_reload, Settings.sam_reload_scale())


func test_normal_no_cambia_nada() -> void:
	Settings.difficulty = 1
	assert_eq(Settings.soldier_damage_scale(), 1.0)
	assert_eq(Settings.sam_reload_scale(), 1.0)


func test_hay_un_valor_por_cada_dificultad() -> void:
	assert_eq(Settings.SOLDIER_DAMAGE.size(), Settings.DIFFICULTY_NAMES.size())
	assert_eq(Settings.SAM_RELOAD.size(), Settings.DIFFICULTY_NAMES.size())
