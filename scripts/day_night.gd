class_name DayNight
extends Node
## Ciclo de día y noche: mueve el sol y la luna, cambia el cielo, la niebla y la luz ambiente,
## enciende las ventanas de noche y da luz de verdad a las farolas más cercanas a la cámara.
## La lógica está en `DayNightLogic`; los ajustes, en `data/day_night.tres`.

var main: Main
var data: DayNightData = preload("res://data/day_night.tres")
## Hora del juego (0-24).
var hour: float = 10.0
var _lights: Array[OmniLight3D] = []
var _pick_t: float = 0.0


func setup() -> void:
	hour = data.start_hour
	for i: int in data.lamp_lights:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.55)
		l.omni_range = data.lamp_range
		l.shadow_enabled = false
		l.visible = false
		main.world.add_child(l)
		_lights.append(l)
	apply()


func tick(dt: float) -> void:
	hour = DayNightLogic.advance(hour, dt, data.day_minutes)
	apply()
	_pick_t -= dt
	if _pick_t <= 0.0:
		_pick_t = 0.5
		_place_lamp_lights()


## Aplica la hora actual al cielo, las luces y los materiales.
func apply() -> void:
	var w: World = main.world
	var day: float = DayNightLogic.daylight(hour)
	var night: float = DayNightLogic.lights_on(hour)
	var elevation: float = DayNightLogic.sun_elevation(hour)
	w.sun.rotation_degrees = Vector3(-maxf(elevation, -10.0), DayNightLogic.sun_azimuth(hour), 0)
	w.sun.light_energy = 1.25 * day
	w.sun.light_color = Color(1, 1, 1).lerp(Color(1.0, 0.7, 0.45), DayNightLogic.dusk(hour))
	w.sun.visible = elevation > -8.0
	w.moon.light_energy = 0.22 * (1.0 - day)
	w.moon.visible = day < 0.95
	var top: Color = DayNightLogic.sky_top(hour)
	var horizon: Color = DayNightLogic.sky_horizon(hour)
	w.sky_mat.sky_top_color = top
	w.sky_mat.sky_horizon_color = horizon
	w.sky_mat.ground_horizon_color = horizon
	w.sky_mat.ground_bottom_color = Color(0.35, 0.4, 0.35) * maxf(day, 0.12)
	w.env.fog_light_color = horizon
	w.env.ambient_light_energy = lerpf(2.4, 1.0, day)
	w.env.glow_intensity = lerpf(0.8, 1.0, night)
	Build.set_night(night)
	var on: bool = night > 0.3
	for l: OmniLight3D in _lights:
		l.light_energy = data.lamp_energy * night
		if not on:
			l.visible = false


## Pone las luces de verdad en las farolas más cercanas a la cámara.
func _place_lamp_lights() -> void:
	if DayNightLogic.lights_on(hour) <= 0.3:
		return
	var cam: Vector3 = main.camera.global_position
	var lamps: PackedVector3Array = main.world.lamp_positions
	var best: Array[Vector2] = []  # (distancia², índice)
	for i: int in lamps.size():
		var d: float = cam.distance_squared_to(lamps[i])
		if d < 160000.0:
			best.append(Vector2(d, i))
	best.sort()
	for k: int in _lights.size():
		var l: OmniLight3D = _lights[k]
		l.visible = k < best.size()
		if l.visible:
			l.global_position = lamps[int(best[k].y)] - Vector3(0, 0.6, 0)
