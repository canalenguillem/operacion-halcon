class_name Driving
extends Node
## Subir y bajar de vehículos. `vehicle` es el que conduce el jugador (null si va a pie).

var main: Main
var vehicle: Vehicle = null


## El vehículo más cercano al que el jugador puede subir, o null.
func nearby() -> Vehicle:
	var best: Vehicle = null
	var best_dist: float = 1e9
	for v: Vehicle in main.vehicles():
		if v.dead:
			continue
		var d: float = v.global_position.distance_to(main.player.global_position)
		if d < v.enter_range and d < best_dist:
			best = v
			best_dist = d
	return best


## Tecla de interactuar: baja si vas en un vehículo parado; si no, sube al más cercano.
func interact() -> void:
	if vehicle != null:
		if vehicle.can_exit():
			exit()
		else:
			main.hud.flash("Detén el vehículo para bajar")
		return
	var v: Vehicle = nearby()
	if v != null:
		enter(v)


func enter(v: Vehicle) -> void:
	var player: Player = main.player
	vehicle = v
	v.driver = true
	player.active = false
	player.visible = false
	player.col.set_deferred("disabled", true)
	main.camera.snap_behind(v)
	main.sfx.play("door", -4.0)


func exit() -> void:
	var player: Player = main.player
	var v: Vehicle = vehicle
	var side: float = 4.5 if v.is_jet else 2.6
	player.global_position = v.global_position - v.global_transform.basis.x * side + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.active = true
	player.visible = true
	player.col.set_deferred("disabled", false)
	v.driver = false
	vehicle = null
	main.sfx.play("door", -4.0)


## Saca al jugador del vehículo (porque ha explotado) y le hace daño.
func eject(dmg: float) -> void:
	if vehicle != null:
		exit()
	main.player.hurt(dmg)


## Mientras conduce, el jugador (invisible) viaja con el vehículo.
func tick() -> void:
	if vehicle != null:
		main.player.global_position = vehicle.global_position
