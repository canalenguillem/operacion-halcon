extends GutTest

var d: SoldierData


func before_each() -> void:
	d = SoldierData.new()


func test_te_ve_de_cerca_sin_alarma() -> void:
	assert_true(SoldierLogic.should_alert(d.sight - 1.0, false, d))
	assert_false(SoldierLogic.should_alert(d.sight + 1.0, false, d))


func test_con_alarma_se_entera_desde_lejos_pero_no_desde_cualquier_sitio() -> void:
	assert_true(SoldierLogic.should_alert(d.sight + 100.0, true, d))
	assert_false(SoldierLogic.should_alert(d.alarm_radius + 1.0, true, d))


func test_persigue_solo_a_media_distancia() -> void:
	assert_false(SoldierLogic.should_chase(d.keep_distance - 1.0, 0.0, d))
	assert_true(SoldierLogic.should_chase(d.keep_distance + 1.0, 0.0, d))
	assert_false(SoldierLogic.should_chase(d.chase_distance + 1.0, 0.0, d))


func test_no_se_aleja_de_su_puesto() -> void:
	assert_false(SoldierLogic.should_chase(100.0, d.leash + 1.0, d))


func test_no_dispara_fuera_de_alcance_ni_a_un_caza_alto() -> void:
	assert_true(SoldierLogic.can_fire(d.fire_range - 1.0, 0.0, d))
	assert_false(SoldierLogic.can_fire(d.fire_range + 1.0, 0.0, d))
	assert_false(SoldierLogic.can_fire(10.0, d.max_target_height + 1.0, d))


func test_acierta_mas_de_cerca() -> void:
	assert_gt(SoldierLogic.hit_chance(10.0, d), SoldierLogic.hit_chance(60.0, d))


func test_la_punteria_tiene_topes() -> void:
	assert_eq(SoldierLogic.hit_chance(0.0, d), d.aim_max)
	assert_eq(SoldierLogic.hit_chance(10000.0, d), d.aim_min)
