extends GutTest
## Prueba de integración: carga la misión entera y dispara de verdad.

var main: Main


func before_each() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate() as Main
	main.show_menu = false
	add_child_autofree(main)
	await get_tree().physics_frame
	main.player.global_position = Vector3(150, 0.2, -1125)
	await _frames(5)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _nearest_soldier() -> Soldier:
	var best: Soldier = null
	for s: Soldier in main.soldiers:
		if not s.dead and (best == null or s.global_position.distance_to(main.player.global_position) < best.global_position.distance_to(main.player.global_position)):
			best = s
	return best


## Apunta la cámara al pecho del soldado desplazado `offset` metros y dispara.
func _aim_and_shoot(s: Soldier, offset: Vector3) -> void:
	for i: int in 6:
		var d: Vector3 = (s.global_position + Vector3(0, 1.0, 0) + offset - main.cam.global_position).normalized()
		main.cam_yaw = PlayerLogic.facing_yaw(d)
		main.cam_pitch = asin(d.y)
		await get_tree().physics_frame
	main.player_shoot()


func test_dos_disparos_bien_apuntados_abaten_a_un_soldado() -> void:
	var s: Soldier = _nearest_soldier()
	await _aim_and_shoot(s, Vector3.ZERO)
	assert_false(s.dead, "un disparo no basta")
	assert_gt(main.hit_t, 0.0, "debe verse la marca de impacto")
	await _aim_and_shoot(s, Vector3.ZERO)
	assert_true(s.dead)
	assert_eq(main.kills, 1)
	assert_true(main.hit_kill)


func test_la_ayuda_de_punteria_corrige_un_tiro_que_pasa_rozando() -> void:
	var s: Soldier = _nearest_soldier()
	await _aim_and_shoot(s, Vector3(1.2, 0, 0))
	await _aim_and_shoot(s, Vector3(1.2, 0, 0))
	assert_true(s.dead)


func test_un_tiro_muy_desviado_no_da() -> void:
	var s: Soldier = _nearest_soldier()
	await _aim_and_shoot(s, Vector3(0, 12, 0))
	await _aim_and_shoot(s, Vector3(0, 12, 0))
	assert_false(s.dead)
	assert_eq(s.hp, s.data.max_hp)


func test_disparar_en_la_base_dispara_la_alarma() -> void:
	main.player_shoot()
	assert_true(main.mission.base_alert)
