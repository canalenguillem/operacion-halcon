class_name Main
extends Node3D
## Raíz de la partida: crea el mundo, los sistemas y los actores, reparte el input
## y actualiza los sistemas en orden en cada fotograma de física.
##
## Cada sistema es un nodo hijo con una referencia a `Main` (ver docs/ARCHITECTURE.md):
## `camera` (CameraRig), `driving` (Driving), `combat` (Combat), `effects` (Effects),
## `air_defense` (AirDefense), `halcon` (HalconMission), `gps` (Gps), `game_audio` (GameAudio), `dev` (DevTools).

var mission: MissionState = MissionState.new()
var world: World
var sfx: Sfx
var camera: CameraRig
var driving: Driving
var combat: Combat
var effects: Effects
var air_defense: AirDefense
var halcon: HalconMission
var gps: Gps
var game_audio: GameAudio
var dev: DevTools
var hud: Hud
var menu: Menu
var map_screen: MapScreen
var elapsed: float = 0.0

var player: Player
var cars: Array[Car] = []
var jets: Array[Jet] = []
var soldiers: Array[Soldier] = []
## Ponlo a false antes de añadir la escena para arrancar sin menú (tests).
var show_menu: bool = true
## Al reiniciar la misión no se vuelve a pasar por el menú principal.
static var skip_menu: bool = false

## Vehículo que conduce el jugador, o null si va a pie.
var vehicle: Vehicle:
	get:
		return driving.vehicle

var game_over: bool:
	get:
		return mission.over


func _ready() -> void:
	process_physics_priority = 10  # después de los actores, para que la cámara vea posiciones ya actualizadas
	Settings.load_file()
	Settings.apply_display()
	var loading: LoadingScreen = null
	if show_menu:  # pantalla de carga mientras se construye la isla (los tests la saltan)
		set_physics_process(false)
		set_process_unhandled_input(false)
		loading = LoadingScreen.new()
		add_child(loading)
		await get_tree().process_frame
		await get_tree().process_frame
	world = World.new()
	add_child(world)
	world.build()
	sfx = Sfx.new()
	add_child(sfx)

	effects = _system(Effects.new()) as Effects
	driving = _system(Driving.new()) as Driving
	combat = _system(Combat.new()) as Combat
	air_defense = _system(AirDefense.new()) as AirDefense
	air_defense.setup()
	halcon = _system(HalconMission.new()) as HalconMission
	halcon.setup()
	gps = _system(Gps.new()) as Gps
	game_audio = _system(GameAudio.new()) as GameAudio
	dev = _system(DevTools.new()) as DevTools
	_spawn_actors()

	camera = _system(CameraRig.new()) as CameraRig
	camera.make_current()

	hud = Hud.new()
	hud.main = self
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)

	menu = Menu.new()
	menu.play_pressed.connect(_on_play_pressed)
	menu.restart_pressed.connect(restart)
	menu.main_menu_pressed.connect(_on_main_menu_pressed)
	menu.clicked.connect(sfx.play.bind("click", -6.0))
	menu.map_pressed.connect(_on_map_pressed)
	menu.options_changed.connect(world.apply_graphics)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu_layer.add_child(menu)
	map_screen = MapScreen.new()
	map_screen.main = self
	map_screen.closed.connect(_on_map_closed)
	menu_layer.add_child(map_screen)

	var dev_args: bool = dev.parse_args()
	camera.tick(0.0)
	if show_menu and not skip_menu and not dev_args:
		hud.visible = false
		camera.cinematic = true
		menu.open(Menu.Screen.MAIN)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	skip_menu = false
	if loading != null:
		loading.queue_free()
		set_physics_process(true)
		set_process_unhandled_input(true)


## Añade un sistema como hijo y le da la referencia a `Main`.
func _system(node: Node) -> Node:
	node.set("main", self)
	add_child(node)
	return node


func _spawn_actors() -> void:
	player = Player.new()
	player.main = self
	player.position = World.PLAYER_START
	add_child(player)
	for i: int in World.CAR_SPOTS.size():
		var c := Car.new()
		c.main = self
		c.color = World.CAR_COLORS[i]
		c.position = World.CAR_SPOTS[i]
		add_child(c)
		cars.append(c)
	for p: Vector3 in World.JET_SPOTS:
		var j := Jet.new()
		j.main = self
		j.position = p
		add_child(j)
		jets.append(j)
	for p: Vector2 in World.SOLDIER_POSTS:
		var s := Soldier.new()
		s.main = self
		s.position = Vector3(p.x, 0.1, p.y)
		add_child(s)
		soldiers.append(s)


func _physics_process(dt: float) -> void:
	elapsed += dt
	combat.tick(dt)
	driving.tick()
	if not game_over:
		air_defense.tick(dt)
	halcon.tick()
	gps.tick(dt)
	camera.tick(dt)
	game_audio.tick()
	dev.tick()


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			camera.orbit((e as InputEventMouseMotion).relative)
	elif e is InputEventMouseButton:
		if e.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu.open(Menu.Screen.PAUSE)
	elif e.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		map_screen.open(false)
	elif e.is_action_pressed("restart"):
		restart()
	elif e.is_action_pressed("interact") and not game_over:
		driving.interact()


## Vuelve a empezar la misión sin pasar por el menú principal.
func restart() -> void:
	skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_map_pressed() -> void:
	menu.visible = false
	map_screen.open(true)


func _on_map_closed(to_pause: bool) -> void:
	if to_pause:
		menu.open(Menu.Screen.PAUSE)


func _on_play_pressed() -> void:
	hud.visible = true
	camera.cinematic = false
	camera.tick(0.0)


func _on_main_menu_pressed() -> void:
	skip_menu = false
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- consultas

func vehicles() -> Array[Vehicle]:
	var out: Array[Vehicle] = []
	out.append_array(cars)
	out.append_array(jets)
	return out


## Lo que los enemigos persiguen: el vehículo que conduces o, a pie, el jugador.
func target_node() -> Node3D:
	return vehicle if vehicle != null else player


func target_pos() -> Vector3:
	return target_node().global_position


## Hacia dónde mira el jugador (o su vehículo), para la flecha del minimapa.
func heading() -> float:
	if vehicle != null:
		return PlayerLogic.facing_yaw(-vehicle.global_transform.basis.z)
	return player.model.rotation.y
