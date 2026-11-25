extends GutTest


func test_las_teclas_salen_del_input_map() -> void:
	assert_eq(Menu.key_name("forward"), "W")
	assert_eq(Menu.key_name("interact"), "E")
	assert_eq(Menu.key_name("jump"), "Espacio")
	assert_eq(Menu.key_name("shoot"), "Clic")


func test_un_texto_literal_se_muestra_tal_cual() -> void:
	assert_eq(Menu.key_name("=Ratón"), "Ratón")


func test_varias_acciones_se_juntan() -> void:
	assert_eq(Menu.keys_text("forward left back right"), "W A S D")


func test_todas_las_acciones_de_la_pantalla_de_controles_existen() -> void:
	for row: Array in Menu.CONTROLS:
		assert_eq(row.size(), 3)
		var actions: String = row[1]
		if actions.begins_with("="):
			continue
		for a: String in actions.split(" ", false):
			assert_true(InputMap.has_action(a), "falta la acción «%s»" % a)
			assert_ne(Menu.key_name(a), "?", "la acción «%s» no tiene tecla" % a)
