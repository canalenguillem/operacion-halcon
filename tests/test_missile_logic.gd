extends GutTest

var d: MissileData


func before_each() -> void:
	d = MissileData.new()


func test_no_gira_mas_que_su_limite() -> void:
	var dir: Vector3 = MissileLogic.steer(Vector3.FORWARD, Vector3.ZERO, Vector3(100, 0, 0), 0.1, d)
	assert_almost_eq(Vector3.FORWARD.angle_to(dir), d.turn_rate * 0.1, 0.0001)


func test_gira_hacia_el_blanco() -> void:
	var dir: Vector3 = MissileLogic.steer(Vector3.FORWARD, Vector3.ZERO, Vector3(100, 0, 0), 0.1, d)
	assert_gt(dir.x, 0.0)


func test_no_se_pasa_del_blanco_al_girar() -> void:
	var aim := Vector3(1, 0, -100)
	var dir: Vector3 = MissileLogic.steer(Vector3.FORWARD, Vector3.ZERO, aim, 1.0, d)
	assert_almost_eq(dir.angle_to(aim.normalized()), 0.0, 0.0001)


func test_la_direccion_sigue_siendo_unitaria() -> void:
	var dir := Vector3.UP
	for i: int in 200:
		dir = MissileLogic.steer(dir, Vector3.ZERO, Vector3(50, 20, -80), 1.0 / 60.0, d)
	assert_almost_eq(dir.length(), 1.0, 0.0001)


func test_ya_alineado_no_cambia() -> void:
	assert_eq(MissileLogic.steer(Vector3.FORWARD, Vector3.ZERO, Vector3(0, 0, -50), 0.1, d), Vector3.FORWARD)


func test_acelera_hasta_su_maxima() -> void:
	assert_gt(MissileLogic.next_speed(d.launch_speed, 0.1, d), d.launch_speed)
	assert_eq(MissileLogic.next_speed(d.top_speed, 1.0, d), d.top_speed)


func test_apunta_por_delante_de_un_blanco_que_se_mueve() -> void:
	var aim: Vector3 = MissileLogic.aim_point(Vector3.ZERO, 100.0, Vector3(0, 0, -1000), Vector3(100, 0, 0), d)
	assert_gt(aim.x, 0.0)
	assert_eq(MissileLogic.aim_point(Vector3.ZERO, 100.0, Vector3(0, 0, -1000), Vector3.ZERO, d), Vector3(0, 0, -1000))


func test_un_misil_alcanza_a_un_caza_que_vuela_recto() -> void:
	var pos := Vector3.ZERO
	var dir := Vector3.UP
	var speed: float = d.launch_speed
	var jet := Vector3(800, 300, -600)
	var jet_vel := Vector3(-120, 0, 0)
	var hit: bool = false
	for i: int in int(d.lifetime * 60.0):
		var dt: float = 1.0 / 60.0
		jet += jet_vel * dt
		speed = MissileLogic.next_speed(speed, dt, d)
		dir = MissileLogic.steer(dir, pos, MissileLogic.aim_point(pos, speed, jet, jet_vel, d), dt, d)
		pos += dir * speed * dt
		if pos.distance_to(jet) < d.hit_radius:
			hit = true
			break
	assert_true(hit, "sin bengalas ni maniobras, el misil debe alcanzar al caza")


func test_la_bateria_no_dispara_a_ras_de_suelo_ni_muy_cerca_ni_muy_lejos() -> void:
	assert_true(MissileLogic.can_fire(1000.0, 100.0, 0, d))
	assert_false(MissileLogic.can_fire(1000.0, d.min_altitude - 1.0, 0, d))
	assert_false(MissileLogic.can_fire(d.min_range - 1.0, 100.0, 0, d))
	assert_false(MissileLogic.can_fire(d.max_range + 1.0, 100.0, 0, d))


func test_hay_un_maximo_de_misiles_en_el_aire() -> void:
	assert_false(MissileLogic.can_fire(1000.0, 100.0, d.max_airborne, d))
