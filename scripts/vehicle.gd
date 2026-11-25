class_name Vehicle
extends CharacterBody3D
## Base de coche y caza: lo que `Main`, el HUD y los soldados necesitan saber de un vehículo.

var main: Main
var is_jet: bool = false
var enter_range: float = 4.5
## Hay alguien al volante.
var driver: bool = false
var dead: bool = false
var hp: float = 100.0
## Velocidad hacia delante en m/s (negativa marcha atrás).
var speed: float = 0.0


func _init() -> void:
	collision_layer = Layers.VEHICLES
	collision_mask = Layers.ALL


func can_exit() -> bool:
	return true


func hurt(_d: float) -> void:
	pass


## El jugador lo conduce y la misión sigue en marcha.
func controlled() -> bool:
	return driver and not dead and not main.game_over


## Tras `move_and_slide`: atropella soldados y pierde velocidad (y resistencia) al chocar de frente.
func resolve_bumps(forward: Vector3, min_impact: float, impact_damage: float, run_over_speed: float) -> void:
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var n: Vector3 = c.get_normal()
		if absf(n.y) > 0.5:
			continue
		var soldier: Soldier = c.get_collider() as Soldier
		if soldier != null:
			if absf(speed) > run_over_speed:
				soldier.hurt(999.0)
			continue
		var head_on: float = absf(n.dot(forward))
		var impact: float = absf(speed) * head_on
		if impact > min_impact:
			hurt(impact * impact_damage)
		speed *= 1.0 - head_on
