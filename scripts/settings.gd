class_name Settings
extends RefCounted
## Opciones y récord del jugador, guardados en `user://settings.cfg`.

const DIFFICULTY_NAMES: Array[String] = ["Fácil", "Normal", "Difícil"]
## Multiplicador del daño de los soldados según la dificultad.
const SOLDIER_DAMAGE: Array[float] = [0.5, 1.0, 1.6]
## Multiplicador del tiempo de recarga de las baterías según la dificultad.
const SAM_RELOAD: Array[float] = [1.6, 1.0, 0.65]
const SHADOW_NAMES: Array[String] = ["Sin sombras", "Medias", "Altas"]
## Distancia a la que llegan las sombras del sol según la calidad (m).
const SHADOW_DISTANCE: Array[float] = [0.0, 150.0, 350.0]
const SENSITIVITY_MIN: float = 0.3
const SENSITIVITY_MAX: float = 3.0

static var path: String = "user://settings.cfg"
## Multiplicador de la sensibilidad del ratón.
static var mouse_scale: float = 1.0
## 0 fácil, 1 normal, 2 difícil.
static var difficulty: int = 1
## Mejor tiempo de la misión en segundos (0 = aún no se ha completado).
static var best_time: float = 0.0
## Volumen general, de 0 a 1.
static var volume: float = 0.8
## Volumen de la música, de 0 a 1 (además del general).
static var music_volume: float = 0.5
static var fullscreen: bool = false
static var vsync: bool = true
## Calidad de las sombras: 0 sin sombras, 1 medias, 2 altas.
static var shadows: int = 2


static func reset() -> void:
	volume = 0.8
	music_volume = 0.5
	mouse_scale = 1.0
	difficulty = 1
	best_time = 0.0
	fullscreen = false
	vsync = true
	shadows = 2


static func load_file() -> void:
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	mouse_scale = clampf(float(cfg.get_value("options", "mouse_scale", 1.0)), SENSITIVITY_MIN, SENSITIVITY_MAX)
	difficulty = clampi(int(cfg.get_value("options", "difficulty", 1)), 0, DIFFICULTY_NAMES.size() - 1)
	best_time = maxf(0.0, float(cfg.get_value("records", "best_time", 0.0)))
	volume = clampf(float(cfg.get_value("options", "volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("options", "music_volume", 0.5)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", false))
	vsync = bool(cfg.get_value("graphics", "vsync", true))
	shadows = clampi(int(cfg.get_value("graphics", "shadows", 2)), 0, SHADOW_NAMES.size() - 1)


static func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("options", "mouse_scale", mouse_scale)
	cfg.set_value("options", "difficulty", difficulty)
	cfg.set_value("records", "best_time", best_time)
	cfg.set_value("options", "volume", volume)
	cfg.set_value("options", "music_volume", music_volume)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "shadows", shadows)
	cfg.save(path)


## Apunta un tiempo de misión. Devuelve true (y lo guarda) si es récord.
static func submit_time(time: float) -> bool:
	if not is_record(time, best_time):
		return false
	best_time = time
	save_file()
	return true


static func is_record(time: float, best: float) -> bool:
	return time > 0.0 and (best <= 0.0 or time < best)


## «m:ss».
static func format_time(time: float) -> String:
	var t: int = int(time)
	@warning_ignore("integer_division")
	return "%d:%02d" % [t / 60, t % 60]


static func soldier_damage_scale() -> float:
	return SOLDIER_DAMAGE[difficulty]


static func sam_reload_scale() -> float:
	return SAM_RELOAD[difficulty]


## Aplica pantalla completa y sincronización vertical a la ventana (no hace nada sin pantalla).
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
