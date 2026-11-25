extends GutTest

const FAR: float = 9000.0

var m: MissionState


func before_each() -> void:
	m = MissionState.new()


func test_empieza_buscando_coche_sin_estrellas() -> void:
	assert_eq(m.stage, MissionState.Stage.GET_CAR)
	assert_eq(m.wanted, 0)
	assert_false(m.base_alert)


func test_subir_a_un_coche_pasa_a_ir_a_la_base_con_una_estrella() -> void:
	m.step(true, false, false, 2, FAR)
	assert_eq(m.stage, MissionState.Stage.GO_BASE)
	assert_eq(m.wanted, MissionState.WANTED_CAR)


func test_entrar_en_la_base_a_pie_salta_la_fase_del_coche() -> void:
	m.step(false, false, true, 2, FAR)
	assert_eq(m.stage, MissionState.Stage.GET_JET)


func test_entrar_en_la_base_dispara_la_alarma_una_sola_vez() -> void:
	watch_signals(m)
	m.step(true, false, true, 2, FAR)
	m.step(true, false, true, 2, FAR)
	assert_true(m.base_alert)
	assert_eq(m.wanted, MissionState.WANTED_ALERT)
	assert_signal_emit_count(m, "alert_raised", 1)


func test_robar_el_caza_pasa_a_huir_con_cinco_estrellas() -> void:
	watch_signals(m)
	m.step(true, true, true, 2, FAR)
	assert_eq(m.stage, MissionState.Stage.ESCAPE)
	assert_eq(m.wanted, MissionState.WANTED_JET)
	assert_true(m.base_alert)
	assert_signal_emit_count(m, "jet_stolen", 1)


func test_bajar_del_caza_vuelve_a_robar_caza() -> void:
	m.step(true, true, true, 2, FAR)
	m.step(false, false, true, 2, FAR)
	assert_eq(m.stage, MissionState.Stage.GET_JET)


func test_sin_cazas_se_pierde() -> void:
	watch_signals(m)
	m.step(false, false, true, 2, FAR)
	m.step(false, false, true, 0, FAR)
	assert_true(m.over)
	assert_signal_emitted_with_parameters(m, "failed", ["NO QUEDAN CAZAS"])


func test_llegar_al_aerodromo_en_caza_gana() -> void:
	watch_signals(m)
	m.step(true, true, false, 2, FAR)
	m.step(true, true, false, 2, MissionState.WIN_RADIUS - 1.0)
	assert_eq(m.stage, MissionState.Stage.WON)
	assert_true(m.over)
	assert_eq(m.wanted, 0)
	assert_signal_emit_count(m, "completed", 1)


func test_llegar_al_aerodromo_en_coche_no_gana() -> void:
	m.step(true, false, false, 2, 10.0)
	assert_false(m.over)


func test_tras_terminar_no_cambia_nada() -> void:
	watch_signals(m)
	m.fail("X")
	m.fail("Y")
	m.step(true, true, true, 2, 0.0)
	m.raise_alert()
	assert_eq(m.stage, MissionState.Stage.GET_CAR)
	assert_false(m.base_alert)
	assert_signal_emit_count(m, "failed", 1)


func test_cada_fase_tiene_texto_de_objetivo() -> void:
	for s: MissionState.Stage in [MissionState.Stage.GET_CAR, MissionState.Stage.GO_BASE, MissionState.Stage.GET_JET, MissionState.Stage.ESCAPE]:
		m.stage = s
		assert_ne(m.objective_text(), "")
