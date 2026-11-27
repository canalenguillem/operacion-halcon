extends GutTest
## Mapa a pantalla completa: conversión entre pantalla y mundo.

var ms: MapScreen


func before_each() -> void:
	ms = MapScreen.new()
	add_child_autofree(ms)
	ms.size = Vector2(1280, 720)
	ms.center = Vector2(100, -200)
	ms.zoom = 0.5


func test_el_centro_de_la_vista_es_el_centro_del_mapa() -> void:
	var c: Vector2 = Vector2(1280 - MapScreen.LEGEND_W, 720) / 2.0
	assert_almost_eq(ms.screen_to_world(c).distance_to(ms.center), 0.0, 0.01)


func test_ida_y_vuelta_pantalla_mundo() -> void:
	var w := Vector2(-350, 420)
	assert_almost_eq(ms.screen_to_world(ms.xf() * w).distance_to(w), 0.0, 0.01)


func test_el_norte_queda_arriba() -> void:
	var up: Vector2 = ms.xf() * (ms.center + Vector2(0, -100))
	var mid: Vector2 = ms.xf() * ms.center
	assert_lt(up.y, mid.y)
