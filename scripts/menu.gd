class_name Menu
extends Control
## Menú principal, pausa, controles y opciones. Mientras está abierto, el juego está en pausa.

signal play_pressed
signal restart_pressed
signal main_menu_pressed
## Se ha pulsado cualquier botón (para el sonido).
signal clicked

enum Screen { MAIN, PAUSE, CONTROLS, OPTIONS }

## Filas de la pantalla de controles: [sección, acciones del InputMap (o «=texto» literal), qué hace].
const CONTROLS: Array[Array] = [
	["A pie", "forward left back right", "Moverse"],
	["A pie", "=Ratón", "Cámara"],
	["A pie", "shoot", "Disparar"],
	["A pie", "sprint", "Correr"],
	["A pie", "jump", "Saltar"],
	["A pie", "interact", "Subir a un vehículo"],
	["Coche", "forward back", "Acelerar y marcha atrás"],
	["Coche", "left right", "Girar"],
	["Coche", "jump", "Freno"],
	["Coche", "interact", "Bajar"],
	["Caza en tierra", "forward back", "Acelerar y frenar (despega solo)"],
	["Caza en tierra", "left right", "Girar"],
	["Caza en vuelo", "back forward", "Subir y bajar el morro"],
	["Caza en vuelo", "left right", "Girar"],
	["Caza en vuelo", "throttle_up throttle_down", "Más y menos potencia"],
	["Caza en vuelo", "flare", "Bengalas contra los misiles"],
	["General", "=Esc", "Pausa"],
	["General", "restart", "Reiniciar la misión"],
]
const KEY_NAMES: Dictionary[String, String] = {"Space": "Espacio", "Up": "Arriba", "Down": "Abajo", "Left": "Izquierda", "Right": "Derecha"}

var screen: Screen = Screen.MAIN
## Pantalla a la que vuelve «Volver»: MAIN o PAUSE.
var _home: Screen = Screen.MAIN
var _box: VBoxContainer


## Nombre de la primera tecla (o botón) de una acción del InputMap.
static func key_name(action: String) -> String:
	if action.begins_with("="):
		return action.trim_prefix("=")
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			var name: String = OS.get_keycode_string((e as InputEventKey).physical_keycode)
			return KEY_NAMES.get(name, name)
		if e is InputEventMouseButton:
			return "Clic"
	return "?"


## Teclas de varias acciones separadas por espacios: «W A S D».
static func keys_text(actions: String) -> String:
	var names := PackedStringArray()
	for a: String in actions.split(" ", false):
		names.append(key_name(a))
	return " ".join(names)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 32)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.custom_minimum_size.x = 440
	_box.add_theme_constant_override("separation", 10)
	margin.add_child(_box)
	visible = false


## Abre el menú principal o la pausa y detiene el juego.
func open(home: Screen) -> void:
	_home = home
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_screen(home)


## Cierra el menú y reanuda el juego.
func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not e.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if screen == Screen.CONTROLS or screen == Screen.OPTIONS:
		show_screen(_home)
	elif screen == Screen.PAUSE:
		close()


func show_screen(s: Screen) -> void:
	screen = s
	for c: Node in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	match s:
		Screen.MAIN:
			_build_main()
		Screen.PAUSE:
			_build_pause()
		Screen.CONTROLS:
			_build_controls()
		Screen.OPTIONS:
			_build_options()


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_box.add_child(l)
	return l


func _button(text: String, action: Callable, focus: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(clicked.emit)
	b.pressed.connect(action)
	_box.add_child(b)
	if focus:
		(func() -> void:
			if is_instance_valid(b) and b.is_inside_tree():
				b.grab_focus()).call_deferred()
	return b


func _build_main() -> void:
	_label("OPERACIÓN HALCÓN", 46, Color(1, 0.9, 0.35))
	_label("Roba un caza de la base aérea y huye de los misiles", 18)
	if Settings.best_time > 0.0:
		_label("Mejor tiempo: %s" % Settings.format_time(Settings.best_time), 18, Color(0.5, 1, 0.6))
	_button("Jugar", _on_play, true)
	_button("Controles", show_screen.bind(Screen.CONTROLS))
	_button("Opciones", show_screen.bind(Screen.OPTIONS))
	_button("Salir", get_tree().quit)


func _build_pause() -> void:
	_label("PAUSA", 40, Color(1, 0.9, 0.35))
	_button("Continuar", close, true)
	_button("Reiniciar misión", restart_pressed.emit)
	_button("Controles", show_screen.bind(Screen.CONTROLS))
	_button("Opciones", show_screen.bind(Screen.OPTIONS))
	_button("Menú principal", main_menu_pressed.emit)


func _build_controls() -> void:
	_label("CONTROLES", 26, Color(1, 0.9, 0.35))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 0)
	_box.add_child(grid)
	var section: String = ""
	for row: Array in CONTROLS:
		if (row[0] as String) != section:
			section = row[0]
			for text: String in [section, ""]:
				var head := Label.new()
				head.text = text
				head.add_theme_font_size_override("font_size", 15)
				head.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
				grid.add_child(head)
		for text: String in [keys_text(row[1] as String), row[2] as String]:
			var cell := Label.new()
			cell.text = text
			cell.add_theme_font_size_override("font_size", 14)
			grid.add_child(cell)
	_button("Volver", show_screen.bind(_home), true)


## Deslizador con su etiqueta. `text` recibe el valor y devuelve la etiqueta; `changed` lo guarda.
func _slider(min_value: float, max_value: float, step: float, value: float, text: Callable, changed: Callable) -> void:
	var l: Label = _label(text.call(value) as String, 18)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.y = 26
	_box.add_child(slider)
	slider.value_changed.connect(func(v: float) -> void:
		changed.call(v)
		Settings.save_file()
		l.text = text.call(v) as String)


func _build_options() -> void:
	_label("OPCIONES", 32, Color(1, 0.9, 0.35))
	_slider(0.0, 1.0, 0.05, Settings.volume,
		func(v: float) -> String: return "Volumen: %d %%" % roundi(v * 100.0),
		func(v: float) -> void:
			Settings.volume = v
			Sfx.apply_volume())
	_slider(0.0, 1.0, 0.05, Settings.music_volume,
		func(v: float) -> String: return "Música: %d %%" % roundi(v * 100.0),
		func(v: float) -> void:
			Settings.music_volume = v
			Sfx.apply_volume())
	_slider(Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX, 0.1, Settings.mouse_scale,
		func(v: float) -> String: return "Sensibilidad del ratón: ×%.1f" % v,
		func(v: float) -> void: Settings.mouse_scale = v)

	_label("Dificultad (soldados y misiles)", 18)
	var option := OptionButton.new()
	option.add_theme_font_size_override("font_size", 20)
	option.custom_minimum_size.y = 40
	for n: String in Settings.DIFFICULTY_NAMES:
		option.add_item(n)
	option.selected = Settings.difficulty
	option.item_selected.connect(func(i: int) -> void:
		Settings.difficulty = i
		Settings.save_file())
	_box.add_child(option)
	_button("Volver", show_screen.bind(_home), true)


func _on_play() -> void:
	close()
	play_pressed.emit()
