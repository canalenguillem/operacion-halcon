class_name Sfx
extends Node
## Sonido: efectos sueltos, bucles (motores, alarma, aviso de misil) y música.
## Los archivos están en `assets/audio/` (ver `docs/CREDITS.md`).

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_PATH: String = "res://assets/audio/music/mission.ogg"
const ONE_SHOTS: Array[String] = ["pistol", "rifle", "explosion", "launch", "flare", "hit", "door", "click", "win", "fail"]
const LOOPS: Array[String] = ["car_engine", "jet_engine", "alarm", "missile_warning"]
const BUS_SFX: StringName = &"SFX"
const BUS_MUSIC: StringName = &"Music"

## Segundo por el que iba la música, para que no vuelva a empezar al reiniciar la misión.
static var music_position: float = 0.0

var _streams: Dictionary[String, AudioStream] = {}
var _loops: Dictionary[String, AudioStreamPlayer] = {}
var _music: AudioStreamPlayer


## Crea los buses «SFX» y «Music» si no existen.
static func ensure_buses() -> void:
	for bus: StringName in [BUS_SFX, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")


## Aplica los volúmenes de `Settings` a los buses.
static func apply_volume() -> void:
	ensure_buses()
	_set_bus(&"Master", Settings.volume)
	_set_bus(BUS_MUSIC, Settings.music_volume)


static func _set_bus(bus: StringName, linear: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))


## Tono del motor según la fracción de velocidad máxima (0..1).
static func engine_pitch(ratio: float) -> float:
	return lerpf(0.7, 1.7, clampf(ratio, 0.0, 1.0))


## Volumen (dB) de algo que se oye a tope hasta `full` metros y deja de oírse a `silent`.
static func fade_db(dist: float, full: float, silent: float) -> float:
	var k: float = 1.0 - clampf((dist - full) / (silent - full), 0.0, 1.0)
	return linear_to_db(maxf(k, 0.001))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_volume()
	for n: String in ONE_SHOTS:
		_streams[n] = load(SFX_DIR + n + ".ogg") as AudioStream
	for n: String in LOOPS:
		var stream: AudioStreamOggVorbis = load(SFX_DIR + n + ".ogg") as AudioStreamOggVorbis
		stream.loop = true
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = BUS_SFX
		add_child(p)
		_loops[n] = p
	var music: AudioStreamOggVorbis = load(MUSIC_PATH) as AudioStreamOggVorbis
	music.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = music
	_music.bus = BUS_MUSIC
	add_child(_music)
	_music.play(music_position)


func _exit_tree() -> void:
	music_position = _music.get_playback_position()
	_music.stop()
	for n: String in _loops:
		_loops[n].stop()


func _process(_dt: float) -> void:
	var paused: bool = get_tree().paused
	for n: String in _loops:
		_loops[n].stream_paused = paused


## Efecto sin posición (interfaz, cabina, lo que hace el jugador).
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	p.bus = BUS_SFX
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


## Efecto en un punto del mundo. `unit_size` grande = se oye desde más lejos.
func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, unit_size: float = 20.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound]
	p.bus = BUS_SFX
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_db = 3.0
	p.position = pos
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


## Enciende, apaga o ajusta un bucle.
func set_loop(sound: String, on: bool, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _loops[sound]
	if not on:
		if p.playing:
			p.stop()
		return
	p.volume_db = volume_db
	p.pitch_scale = pitch
	if not p.playing:
		p.play()


func loop_playing(sound: String) -> bool:
	return _loops[sound].playing
