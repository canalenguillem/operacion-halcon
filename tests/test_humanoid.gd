extends GutTest


func test_parado_no_balancea() -> void:
	assert_eq(Humanoid.swing(1.0, 0.0), 0.0)


func test_el_balanceo_crece_con_la_velocidad_y_tiene_tope() -> void:
	var slow: float = Humanoid.swing(PI / 2.0, 1.0)
	var fast: float = Humanoid.swing(PI / 2.0, 4.0)
	assert_gt(fast, slow)
	assert_almost_eq(Humanoid.swing(PI / 2.0, 40.0), Humanoid.MAX_SWING, 0.001)


func test_el_balanceo_cambia_de_signo_en_media_zancada() -> void:
	assert_almost_eq(Humanoid.swing(0.7, 3.0), -Humanoid.swing(0.7 + PI, 3.0), 0.001)


func test_animar_mueve_las_piernas_opuestas_y_apuntar_sube_el_brazo() -> void:
	var h := Humanoid.new()
	add_child_autofree(h)
	h.build(Color.RED, Color.BLUE, Color.WHITE, Color(0, 0, 0, 0), 0.3)
	for i: int in 30:
		h.animate(4.0, 1.0 / 60.0, true)
	assert_almost_eq(h.leg_l.rotation.x, -h.leg_r.rotation.x, 0.001)
	assert_ne(h.leg_l.rotation.x, 0.0)
	assert_almost_eq(h.arm_r.rotation.x, PI / 2.0, 0.05)
