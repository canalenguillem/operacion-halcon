class_name HalconMission
extends Node
## La misión «Operación Halcón»: le pasa a `MissionState` los hechos de cada fotograma,
## decide dónde está el objetivo (haz de luz y minimapa) y muestra los mensajes de sus señales.

var main: Main


func setup() -> void:
	var m: MissionState = main.mission
	m.alert_raised.connect(_on_alert_raised)
	m.jet_stolen.connect(_on_jet_stolen)
	m.failed.connect(_on_failed)
	m.completed.connect(_on_completed)


func tick() -> void:
	var m: MissionState = main.mission
	if not m.over:
		_step()
	main.world.set_marker(objective_pos(), m.stage == MissionState.Stage.ESCAPE, m.stage != MissionState.Stage.WON)


func _step() -> void:
	var tp: Vector3 = main.target_pos()
	if tp.distance_to(World.GATE) < 14.0:
		main.world.open_barrier()
	var jets_alive: int = 0
	for j: Jet in main.jets:
		if not j.dead:
			jets_alive += 1
	var vehicle: Vehicle = main.vehicle
	var in_jet: bool = vehicle != null and vehicle.is_jet
	main.mission.step(vehicle != null, in_jet, World.in_base(tp), jets_alive, World.dest_distance(tp))


func objective_pos() -> Vector3:
	match main.mission.stage:
		MissionState.Stage.GET_CAR:
			var list: Array[Vehicle] = []
			list.append_array(main.cars)
			return _nearest_alive(list)
		MissionState.Stage.GO_BASE:
			return World.GATE
		MissionState.Stage.GET_JET:
			var list: Array[Vehicle] = []
			list.append_array(main.jets)
			return _nearest_alive(list)
	return World.DEST


func objective_text() -> String:
	var text: String = main.mission.objective_text()
	if main.mission.stage == MissionState.Stage.ESCAPE:
		text += "  ·  %.1f km" % (World.dest_distance(main.target_pos()) / 1000.0)
	return text


func _nearest_alive(list: Array[Vehicle]) -> Vector3:
	var best: Vector3 = World.GATE
	var best_dist: float = 1e9
	for v: Vehicle in list:
		if v.dead:
			continue
		var d: float = v.global_position.distance_to(main.player.global_position)
		if d < best_dist:
			best_dist = d
			best = v.global_position
	return best


func _on_alert_raised() -> void:
	main.hud.flash("¡Zona restringida! Te han detectado")


func _on_jet_stolen() -> void:
	main.hud.flash("¡Caza robado! Despega antes de que te acribillen")


func _on_failed(reason: String) -> void:
	main.sfx.play("fail")
	main.hud.big(reason, "Pulsa R para reintentar", Color(1, 0.25, 0.2))


func _on_completed() -> void:
	main.sfx.play("win")
	var t: float = main.elapsed
	var record: String = "  ·  ¡NUEVO RÉCORD!" if Settings.submit_time(t) else ""
	main.hud.big("MISIÓN CUMPLIDA", "Tiempo %s%s  ·  Bajas %d  ·  R para volver a jugar" % [Settings.format_time(t), record, main.combat.kills], Color(0.4, 1.0, 0.5))
