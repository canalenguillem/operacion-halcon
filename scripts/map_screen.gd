class_name MapScreen
extends Control
## Mapa de la isla a pantalla completa (tecla M o desde la pausa). Mientras está abierto, el juego
## está en pausa. Arrastrar mueve, la rueda acerca, clic marca destino (el GPS lleva hasta él),
## clic derecho lo quita.

## Se ha cerrado; `to_pause` si hay que volver al menú de pausa.
signal closed(to_pause: bool)

const ZOOM_MIN: float = 0.08
const ZOOM_MAX: float = 1.6
const LEGEND_W: float = 270.0

var main: Main
var map: CityMap = CityMap.get_default()
## Centro de la vista en el mundo (x, z) y píxeles por metro.
var center: Vector2 = Vector2.ZERO
var zoom: float = 0.22
var _from_pause: bool = false
var _dragging: bool = false
var _drag_moved: float = 0.0
var _hover: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(from_pause: bool) -> void:
	_from_pause = from_pause
	var p: Vector3 = main.target_pos()
	center = Vector2(p.x, p.z)
	zoom = 0.22
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func close() -> void:
	visible = false
	_dragging = false
	if _from_pause:
		closed.emit(true)
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit(false)


## Transformación mundo → pantalla de la vista actual (el norte arriba).
func xf() -> Transform2D:
	return MapDraw.view_transform(center, _map_rect().get_center(), zoom, 0.0)


func screen_to_world(p: Vector2) -> Vector2:
	return xf().affine_inverse() * p


func _map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x - LEGEND_W, size.y))


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before: Vector2 = screen_to_world(screen_pos)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var after: Vector2 = screen_to_world(screen_pos)
	center += before - after
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var mb: InputEventMouseButton = e as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			_drag_moved = 0.0
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			main.gps.clear_waypoint()
			main.gps.tick(0.0)
			queue_redraw()
	elif mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
		if _drag_moved < 6.0 and _map_rect().has_point(mb.position):
			var w: Vector2 = screen_to_world(mb.position)
			if map.on_land(w):
				main.gps.set_waypoint(w)
				main.gps.tick(0.0)
		queue_redraw()
	var mm: InputEventMouseMotion = e as InputEventMouseMotion
	if mm != null:
		if _dragging:
			_drag_moved += mm.relative.length()
			center -= mm.relative / zoom
		_hover = _poi_at(mm.position)
		queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		close()
	elif e.is_action_pressed("ui_page_up") or (e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode in [KEY_PLUS, KEY_KP_ADD]):
		_zoom_at(_map_rect().get_center(), 1.3)
	elif e.is_action_pressed("ui_page_down") or (e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode in [KEY_MINUS, KEY_KP_SUBTRACT]):
		_zoom_at(_map_rect().get_center(), 1.0 / 1.3)


func _process(dt: float) -> void:
	if not visible:
		return
	var pan := Input.get_vector("left", "right", "forward", "back")
	if pan != Vector2.ZERO:
		center += pan * 500.0 * dt / zoom * 0.25
		queue_redraw()


func _poi_at(p: Vector2) -> int:
	var t: Transform2D = xf()
	for i: int in map.pois.size():
		if (t * (map.pois[i]["pos"] as Vector2)).distance_to(p) < 12.0:
			return i
	return -1


func _draw() -> void:
	var r: Rect2 = _map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.MAP_SEA)
	var t: Transform2D = xf()
	var inv: Transform2D = t.affine_inverse()
	var view := Rect2(inv * r.position, Vector2.ZERO).expand(inv * r.end)
	MapDraw.draw_world(self, map, t, view, true)
	MapDraw.draw_route(self, main.gps.route, t, 4.0)
	# nombres de los barrios
	var seen: Dictionary = {}
	for d: Dictionary in map.districts:
		var name: String = str(d["name"])
		if seen.has(name):
			continue
		seen[name] = true
		var poly: PackedVector2Array = d["poly"]
		var c := Vector2.ZERO
		for p: Vector2 in poly:
			c += p / float(poly.size())
		UiStyle.text(self, t * c, name.to_upper(), int(clampf(zoom * 70.0, 12.0, 30.0)), Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, UiStyle.title_font(), 5)
	# lugares
	for i: int in map.pois.size():
		var id: String = str(map.pois[i]["id"])
		if UiStyle.POI_ICONS.has(id):
			UiStyle.poi_icon(self, t * (map.pois[i]["pos"] as Vector2), id, 8.5 if i == _hover else 7.0)
	if _hover >= 0:
		var hp: Vector2 = t * (map.pois[_hover]["pos"] as Vector2)
		var label: String = str(map.pois[_hover]["name"])
		var w: float = UiStyle.text_width(label, 16) + 20.0
		draw_rect(Rect2(hp + Vector2(12, -32), Vector2(w, 26)), UiStyle.PANEL)
		UiStyle.text(self, hp + Vector2(22, -13), label, 16, UiStyle.TEXT)
	# objetivo, destino marcado y jugador
	var o: Vector3 = main.halcon.objective_pos()
	_marker(t * Vector2(o.x, o.z), UiStyle.ACCENT, r)
	if main.gps.has_waypoint:
		_marker(t * main.gps.waypoint, UiStyle.ROUTE, r)
	var me: Vector3 = main.target_pos()
	var h: float = main.heading()
	UiStyle.arrow(self, t * Vector2(me.x, me.z), Vector2(-sin(h), -cos(h)), 11.0, Color.WHITE)
	_draw_legend()
	_draw_header()


## Marca de destino; si queda fuera de la vista, una flecha en el borde.
func _marker(p: Vector2, color: Color, r: Rect2) -> void:
	var inner: Rect2 = r.grow(-18.0)
	if inner.has_point(p):
		draw_line(p, p + Vector2(0, -22), Color(0, 0, 0), 4.0)
		draw_line(p, p + Vector2(0, -22), color, 2.0)
		draw_circle(p + Vector2(0, -24), 8.0, Color(0, 0, 0))
		draw_circle(p + Vector2(0, -24), 6.0, color)
		draw_circle(p, 3.0, color)
		return
	var c: Vector2 = r.get_center()
	var dir: Vector2 = (p - c).normalized()
	var edge: Vector2 = Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
	draw_colored_polygon(PackedVector2Array([edge + dir * 10.0, edge - dir * 8.0 + dir.orthogonal() * 8.0, edge - dir * 8.0 - dir.orthogonal() * 8.0]), color)


func _draw_header() -> void:
	draw_rect(Rect2(0, 0, size.x - LEGEND_W, 56), Color(0, 0, 0, 0.55))
	UiStyle.text(self, Vector2(24, 40), "MAPA", 30, UiStyle.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.title_font())
	var help: String = "Arrastra o %s para mover · Rueda o +/−: zoom · Clic: marcar destino · Clic derecho: quitarlo · %s o Esc: cerrar" % [
		Menu.keys_text("forward left back right"), Menu.key_name("map")]
	UiStyle.text(self, Vector2(130, 35), help, 15, UiStyle.TEXT)


func _draw_legend() -> void:
	var x: float = size.x - LEGEND_W
	draw_rect(Rect2(x, 0, LEGEND_W, size.y), Color(0.03, 0.04, 0.06, 0.95))
	draw_rect(Rect2(x, 0, 4, size.y), UiStyle.ACCENT)
	UiStyle.text(self, Vector2(x + 20, 40), "LUGARES", 22, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, UiStyle.title_font())
	var y: float = 70.0
	for i: int in map.pois.size():
		var id: String = str(map.pois[i]["id"])
		if not UiStyle.POI_ICONS.has(id):
			continue
		UiStyle.poi_icon(self, Vector2(x + 30, y), id, 8.0)
		UiStyle.text(self, Vector2(x + 48, y + 5), str(map.pois[i]["name"]), 14, UiStyle.ACCENT if i == _hover else UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, null, 4)
		y += 23.0
	y += 12.0
	for row: Array in [[UiStyle.ACCENT, "Objetivo"], [UiStyle.ROUTE, "Destino marcado y ruta"], [Color.WHITE, "Tú"]]:
		draw_circle(Vector2(x + 30, y), 6.0, row[0] as Color)
		UiStyle.text(self, Vector2(x + 48, y + 5), str(row[1]), 14, UiStyle.TEXT)
		y += 23.0
