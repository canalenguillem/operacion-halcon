class_name Radar
extends Control
## Radar redondo: el mapa gira con la cámara (lo que tienes delante queda arriba) y se aleja
## al ir rápido. Lo que se sale del círculo (el objetivo) se queda pegado al borde.

const SIZE: float = 210.0

var main: Main
var map: CityMap = CityMap.get_default()
var _mask: Control
var _view: Layer
var _overlay: Layer
## Metros del centro al borde, suavizado.
var _reach: float = 200.0


## Capa que se dibuja con una función (para no crear una clase por capa).
class Layer extends Control:
	var draw_fn: Callable

	func _draw() -> void:
		draw_fn.call(self)


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask = Layer.new()
	(_mask as Layer).draw_fn = func(ci: Control) -> void: ci.draw_circle(Vector2(SIZE, SIZE) / 2.0, SIZE / 2.0, Color.WHITE)
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_view = Layer.new()
	_view.draw_fn = _draw_view
	_overlay = Layer.new()
	_overlay.draw_fn = _draw_overlay
	for c: Control in [_mask, _view, _overlay]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size = Vector2(SIZE, SIZE)
	add_child(_mask)
	_mask.add_child(_view)
	add_child(_overlay)


func _process(dt: float) -> void:
	var want: float = 200.0
	var v: Vehicle = main.vehicle
	if v != null:
		want = 2600.0 if v.is_jet else clampf(260.0 + absf(v.speed) * 7.0, 260.0, 560.0)
	_reach = lerpf(_reach, want, clampf(dt * 2.0, 0.0, 1.0))
	_view.queue_redraw()
	_overlay.queue_redraw()


func _me() -> Vector2:
	var p: Vector3 = main.target_pos()
	return Vector2(p.x, p.z)


func _xf() -> Transform2D:
	return MapDraw.view_transform(_me(), Vector2(SIZE, SIZE) / 2.0, (SIZE / 2.0) / _reach, main.camera.yaw)


func _draw_view(ci: Control) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), UiStyle.MAP_SEA)
	var me: Vector2 = _me()
	var xf: Transform2D = _xf()
	MapDraw.draw_world(ci, map, xf, Rect2(me - Vector2(_reach, _reach), Vector2(_reach, _reach) * 2.0), true)
	MapDraw.draw_route(ci, main.gps.route, xf, 4.0)
	var r: float = SIZE / 2.0
	var c: Vector2 = Vector2(r, r)
	for p: Dictionary in (map.pois if _reach < 1200.0 else []):
		var sp: Vector2 = xf * (p["pos"] as Vector2)
		if sp.distance_to(c) < r - 6.0 and UiStyle.POI_ICONS.has(str(p["id"])):
			UiStyle.poi_icon(ci, sp, str(p["id"]), 6.5)
	for sam: Vector3 in main.world.sam_positions:
		var bp: Vector2 = xf * Vector2(sam.x, sam.z)
		ci.draw_rect(Rect2(bp - Vector2(3.5, 3.5), Vector2(7, 7)), Color(1, 0.45, 0.1))
	for veh: Vehicle in main.vehicles():
		if not veh.dead and veh != main.vehicle:
			ci.draw_circle(xf * Vector2(veh.global_position.x, veh.global_position.z), 3.5, Color(0.35, 0.8, 1.0))
	for so: Soldier in main.soldiers:
		if not so.dead:
			ci.draw_circle(xf * Vector2(so.global_position.x, so.global_position.z), 3.0, UiStyle.DANGER)
	for m: Missile in main.air_defense.missiles:
		if is_instance_valid(m):
			ci.draw_circle(xf * Vector2(m.global_position.x, m.global_position.z), 3.5, Color(1, 0.92, 0.2))


func _draw_overlay(ci: Control) -> void:
	var r: float = SIZE / 2.0
	var c := Vector2(r, r)
	var yaw: float = main.camera.yaw
	ci.draw_arc(c, r - 1.0, 0.0, TAU, 64, Color(0, 0, 0, 0.9), 4.0)
	ci.draw_arc(c, r - 3.5, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 1.5)
	# norte en el borde
	var north: Vector2 = c + Vector2(0, -1).rotated(yaw) * (r - 2.0)
	ci.draw_circle(north, 9.0, Color(0.08, 0.08, 0.1))
	UiStyle.text(ci, north + Vector2(0, 5), "N", 13, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER, UiStyle.title_font(), 0)
	# objetivo (pegado al borde si está lejos)
	var xf: Transform2D = _xf()
	var o3: Vector3 = main.halcon.objective_pos()
	var o: Vector2 = xf * Vector2(o3.x, o3.z)
	if not main.game_over:
		var off: Vector2 = o - c
		if off.length() > r - 10.0:
			var dir: Vector2 = off.normalized()
			var tip: Vector2 = c + dir * (r - 4.0)
			ci.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 13.0 + dir.orthogonal() * 7.0, tip - dir * 13.0 - dir.orthogonal() * 7.0]), Color(0, 0, 0))
			ci.draw_colored_polygon(PackedVector2Array([tip - dir * 2.0, tip - dir * 11.0 + dir.orthogonal() * 5.0, tip - dir * 11.0 - dir.orthogonal() * 5.0]), UiStyle.ACCENT)
		else:
			ci.draw_circle(o, 7.0, Color(0, 0, 0))
			ci.draw_circle(o, 5.0, UiStyle.ACCENT)
	# el jugador, en el centro
	var h: float = main.heading()
	UiStyle.arrow(ci, c, Vector2(-sin(h), -cos(h)).rotated(yaw), 9.0, Color.WHITE)
