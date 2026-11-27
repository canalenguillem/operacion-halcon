class_name Effects
extends Node3D
## Efectos visuales efímeros: trazadoras, explosiones (con sonido y sacudida si son grandes) y bengalas.

var main: Main
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func tracer(a: Vector3, b: Vector3, color: Color) -> void:
	var length: float = a.distance_to(b)
	if length < 0.5:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, length)
	var mi: MeshInstance3D = Build.mesh(self, bm, (a + b) / 2.0, color, Vector3.ZERO, 4.0)
	var d: Vector3 = (b - a) / length
	mi.look_at(b, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.07).timeout.connect(mi.queue_free)


## Bola de fuego y humo. Con radio ≥ 3 añade sonido, metralla y sacudida de cámara.
func explosion(pos: Vector3, radius: float) -> void:
	var s: MeshInstance3D = Build.sphere(self, 1.0, pos, Color(1.0, 0.55, 0.1), 5.0)
	s.scale = Vector3.ONE * 0.2
	var tw: Tween = create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * radius, 0.3)
	tw.tween_property(s, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(s.queue_free)
	var smoke: MeshInstance3D = Build.sphere(self, 1.0, pos, Color(0.15, 0.15, 0.15, 0.6))
	smoke.scale = Vector3.ONE * 0.2
	var tw2: Tween = create_tween()
	tw2.tween_property(smoke, "scale", Vector3.ONE * radius * 1.3, 0.9)
	tw2.parallel().tween_property(smoke, "position", pos + Vector3(0, radius, 0), 1.6)
	tw2.tween_property(smoke, "scale", Vector3.ONE * 0.01, 0.7)
	tw2.tween_callback(smoke.queue_free)
	if radius < 3.0:
		return  # chispazo de impacto: sin ruido, metralla ni sacudida
	main.sfx.play_at("explosion", pos, 0.0, radius * 14.0)
	main.camera.add_shake(CameraLogic.shake_amount(radius, main.camera.global_position.distance_to(pos)))
	var debris := CPUParticles3D.new()
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 18
	debris.lifetime = 1.4
	debris.direction = Vector3.UP
	debris.spread = 70.0
	debris.initial_velocity_min = radius * 1.5
	debris.initial_velocity_max = radius * 3.5
	debris.gravity = Vector3(0, -20, 0)
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * clampf(radius * 0.05, 0.15, 0.6)
	chunk.material = Build.mat(Color(1.0, 0.5, 0.1), 3.0)
	debris.mesh = chunk
	debris.position = pos
	add_child(debris)
	debris.emitting = true
	get_tree().create_timer(2.0, false).timeout.connect(debris.queue_free)


## Tres bengalas que caen desde `pos` arrastradas por la velocidad `vel`.
func flares(pos: Vector3, vel: Vector3) -> void:
	for i: int in 3:
		var f: MeshInstance3D = Build.sphere(self, 0.9, pos, Color(1.0, 0.95, 0.6), 6.0)
		var end: Vector3 = pos + vel * 0.6 + Vector3(rng.randf_range(-30, 30), -70, rng.randf_range(-30, 30))
		var tw: Tween = create_tween()
		tw.tween_property(f, "position", end, 2.5)
		tw.tween_callback(f.queue_free)
	main.sfx.play("flare", -4.0)
