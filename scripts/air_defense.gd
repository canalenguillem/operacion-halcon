class_name AirDefense
extends Node
## Baterías antiaéreas y misiles en vuelo. Las baterías solo disparan al caza que pilota el jugador.
## La lógica de disparo y guiado está en `MissileLogic`; los ajustes, en `data/missile.tres`.

var main: Main
var data: MissileData = preload("res://data/missile.tres")
var missiles: Array[Missile] = []
## Segundos hasta el próximo disparo de cada batería (mismo orden que `world.sam_positions`).
var cooldowns: Array[float] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Prepara las baterías del mundo. Llamar después de construir el mundo.
func setup() -> void:
	rng.seed = 7
	cooldowns.clear()
	for i: int in main.world.sam_positions.size():
		cooldowns.append(rng.randf_range(data.first_shot_min, data.first_shot_max))


func tick(dt: float) -> void:
	missiles = missiles.filter(func(m: Missile) -> bool: return is_instance_valid(m) and not m.dead)
	var jet: Jet = main.vehicle as Jet
	if jet == null or jet.dead:
		return
	var jp: Vector3 = jet.global_position
	for i: int in main.world.sam_positions.size():
		var pos: Vector3 = main.world.sam_positions[i]
		cooldowns[i] -= dt
		if cooldowns[i] <= 0.0 and MissileLogic.can_fire(pos.distance_to(jp), jp.y, missiles.size(), data):
			cooldowns[i] = rng.randf_range(data.reload_min, data.reload_max) * Settings.sam_reload_scale()
			_launch(pos, jet)


func _launch(pos: Vector3, jet: Jet) -> void:
	var m := Missile.new()
	m.main = main
	m.data = data
	m.target = jet
	m.position = pos + Vector3(0, 5, 0)
	main.add_child(m)
	missiles.append(m)
	main.effects.explosion(pos + Vector3(0, 4, 0), 3.0)
	main.sfx.play_at("launch", pos, 0.0, 500.0)


## El caza suelta bengalas: cada misil cercano tiene `flare_chance` de quedar despistado.
func drop_flares(pos: Vector3, vel: Vector3) -> void:
	main.effects.flares(pos, vel)
	for m: Missile in missiles:
		if is_instance_valid(m) and m.global_position.distance_to(pos) < data.flare_radius and rng.randf() < data.flare_chance:
			m.decoyed = true


## Distancia del misil más cercano que aún persigue al caza (1e9 si no hay).
func nearest_missile() -> float:
	var best: float = 1e9
	for m: Missile in missiles:
		if is_instance_valid(m) and not m.dead and not m.decoyed:
			best = minf(best, m.distance())
	return best
