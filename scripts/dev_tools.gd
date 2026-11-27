class_name DevTools
extends Node
## Ayudas de desarrollo por línea de órdenes:
## godot --path . -- [--play] [--at=x,y,z] [--yaw=grados] [--test-jet] [--test-takeoff]
##                   [--menu] [--pause] [--controls] [--options] [--map] [--shot=/ruta/captura.png] [--fps]

var main: Main
## Imprime el estado del caza cada segundo (lo usa `tools/check.sh`).
var debug: bool = false
## Imprime los fotogramas por segundo cada segundo.
var show_fps: bool = false


## Lee los argumentos de desarrollo. Devuelve true si hay que saltarse el menú principal.
func parse_args() -> bool:
	var dev: bool = false
	var force_menu: bool = false
	for a: String in OS.get_cmdline_user_args():
		dev = true
		if a.begins_with("--shot="):
			# captura a los 2,5 s (también con el juego en pausa) y sale
			get_tree().create_timer(2.5).timeout.connect(_take_shot.bind(a.trim_prefix("--shot=")))
		elif a.begins_with("--at="):
			var p: PackedFloat64Array = a.trim_prefix("--at=").split_floats(",")
			main.player.position = Vector3(p[0], p[1], p[2])
		elif a.begins_with("--yaw="):
			main.camera.yaw = deg_to_rad(float(a.trim_prefix("--yaw=")))
		elif a == "--map":
			main.map_screen.open.call_deferred(false)
		elif a == "--fps":
			show_fps = true
		elif a == "--menu":
			force_menu = true
		elif a == "--pause":
			main.menu.open.call_deferred(Menu.Screen.PAUSE)
		elif a == "--controls" or a == "--options":
			main.menu.open.call_deferred(Menu.Screen.PAUSE)
			main.menu.show_screen.call_deferred(Menu.Screen.CONTROLS if a == "--controls" else Menu.Screen.OPTIONS)
		elif a == "--test-takeoff":
			main.driving.enter(main.jets[1])
			Input.action_press("forward")  # lo que hace un jugador nuevo: solo W, sin soltarla
			debug = true
		elif a == "--test-jet":
			var j: Jet = main.jets[0]
			main.driving.enter(j)
			j.position = Vector3(250, 220, -1200)
			j.rotation.y = PI / 2.0
			j.grounded = false
			j.gear.visible = false
			j.throttle = 1.0
			j.speed = 120.0
	return dev and not force_menu


func _take_shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func tick() -> void:
	if show_fps and Engine.get_physics_frames() % 60 == 0:
		print("fps=%d dibujos=%d" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	var jet: Jet = main.vehicle as Jet
	if debug and jet != null and Engine.get_physics_frames() % 60 == 0:
		print("t=%.0f pos=%s speed=%.0f grounded=%s hp=%.0f stage=%d over=%s" % [main.elapsed, jet.global_position.round(), jet.speed, jet.grounded, jet.hp, main.mission.stage, main.game_over])
