class_name Combat
extends Node
## Disparo del jugador (con ayuda de puntería), daño que recibe y marcadores del HUD (impacto, fogonazo, bajas).

var main: Main
var kills: int = 0
## Segundos que queda visible la marca de impacto.
var hit_t: float = 0.0
var hit_kill: bool = false
## Segundos que queda visible el fogonazo rojo de daño.
var hurt_t: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func tick(dt: float) -> void:
	hit_t -= dt
	hurt_t -= dt


## Un soldado ha acertado a lo que conduces (o a ti).
func hurt_target(d: SoldierData) -> void:
	var k: float = Settings.soldier_damage_scale()
	var vehicle: Vehicle = main.vehicle
	if vehicle == null:
		main.player.hurt(d.damage_player * k)
	elif vehicle.is_jet:
		vehicle.hurt(d.damage_jet * k)
	else:
		vehicle.hurt(d.damage_car * k)


## El jugador ha recibido daño: fogonazo rojo y sacudida.
func on_player_hurt() -> void:
	hurt_t = 0.35
	main.camera.add_shake(0.12)


func on_soldier_killed() -> void:
	kills += 1


func player_shoot() -> void:
	var player: Player = main.player
	var cam: CameraRig = main.camera
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var fwd: Vector3 = -cam.global_transform.basis.z
	var reach: float = player.data.cam_offset.z + 0.3  # el rayo sale por delante del jugador
	var from: Vector3 = cam.global_position + fwd * reach
	var to: Vector3 = from + fwd * player.data.fire_range
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)

	# Ayuda de puntería: si no has dado a un soldado pero hay uno casi en la mira y a la vista, le das.
	if hit.is_empty() or not hit.collider is Soldier:
		var alive: Array[Soldier] = []
		var chests: Array[Vector3] = []
		for s: Soldier in main.soldiers:
			if not s.dead:
				alive.append(s)
				chests.append(s.global_position + Vector3(0, 1.1, 0))
		var i: int = PlayerLogic.aim_assist(cam.global_position, fwd, chests, player.data.aim_assist_degrees, reach, player.data.fire_range)
		if i >= 0:
			var q2 := PhysicsRayQueryParameters3D.create(from, chests[i])
			q2.exclude = [player.get_rid()]
			var hit2: Dictionary = space.intersect_ray(q2)
			if not hit2.is_empty() and hit2.collider == alive[i]:
				hit = hit2

	var end: Vector3 = to
	if not hit.is_empty():
		end = hit.position
		var soldier: Soldier = hit.collider as Soldier
		var veh: Vehicle = hit.collider as Vehicle
		if soldier != null:
			soldier.hurt(player.data.damage)
			main.sfx.play("hit", -3.0)
			hit_t = 0.18
			hit_kill = soldier.dead
			main.effects.explosion(end, 0.35)
		elif veh != null:
			veh.hurt(player.data.damage)
	main.effects.tracer(player.global_position + Vector3(0, 1.35, 0), end, Color(1, 0.9, 0.4))
	main.sfx.play("pistol", -6.0, rng.randf_range(0.94, 1.06))
	for s: Soldier in main.soldiers:
		if not s.dead and not s.alert and s.global_position.distance_to(player.global_position) < player.data.noise_radius:
			s.alert = true
			main.mission.raise_alert()
