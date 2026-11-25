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
var _smoke: CPUParticles3D


## ¿Echa humo? Cuando le queda menos del 40 % de resistencia, o ya es chatarra.
static func smokes(hp_left: float, max_hp: float, is_dead: bool) -> bool:
	return is_dead or hp_left < max_hp * 0.4


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


## Enciende o apaga el humo de avería, que sale del punto `at` (en coordenadas del vehículo).
func update_smoke(max_hp: float, at: Vector3) -> void:
	var on: bool = smokes(hp, max_hp, dead)
	if _smoke == null:
		if not on:
			return
		_smoke = CPUParticles3D.new()
		_smoke.amount = 24
		_smoke.lifetime = 1.6
		_smoke.local_coords = false
		_smoke.direction = Vector3.UP
		_smoke.spread = 15.0
		_smoke.initial_velocity_min = 2.0
		_smoke.initial_velocity_max = 4.0
		_smoke.gravity = Vector3(0, 1, 0)
		_smoke.scale_amount_min = 0.5
		_smoke.scale_amount_max = 1.3
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 8
		sm.rings = 4
		sm.material = Build.mat(Color(0.12, 0.12, 0.12, 0.55))
		_smoke.mesh = sm
		_smoke.position = at
		add_child(_smoke)
	_smoke.emitting = on


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
