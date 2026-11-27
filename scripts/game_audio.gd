class_name GameAudio
extends Node
## Ajusta cada fotograma los bucles de sonido según el juego: motores, alarma de la base y aviso de misil.

var main: Main


func tick() -> void:
	var sfx: Sfx = main.sfx
	var car: Car = main.vehicle as Car
	var jet: Jet = main.vehicle as Jet
	if car != null and not car.dead:
		sfx.set_loop("car_engine", true, -12.0, Sfx.engine_pitch(absf(car.speed) / car.data.max_speed))
	else:
		sfx.set_loop("car_engine", false)
	if jet != null and not jet.dead:
		sfx.set_loop("jet_engine", true, lerpf(-24.0, -8.0, jet.throttle), Sfx.engine_pitch(jet.speed / jet.data.max_speed))
	else:
		sfx.set_loop("jet_engine", false)
	var base_dist: float = main.target_pos().distance_to(World.BASE_CENTER)
	var alarm: bool = main.mission.base_alert and not main.game_over and base_dist < 1500.0
	sfx.set_loop("alarm", alarm, Sfx.fade_db(base_dist, 400.0, 1500.0) - 16.0)
	sfx.set_loop("missile_warning", not main.game_over and main.air_defense.nearest_missile() < 1e8, -8.0)
