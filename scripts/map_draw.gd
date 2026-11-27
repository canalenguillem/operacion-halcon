class_name MapDraw
extends RefCounted
## Dibuja el mapa de la isla (lo usan el radar y el mapa grande) con una transformación
## mundo (x, z) → pantalla. Las calles se dibujan a su anchura real, con un mínimo en píxeles.


## Transformación mundo → pantalla: `center` en pantalla es `me` en el mundo, girado `yaw` y a `k` px/m.
static func view_transform(me: Vector2, center: Vector2, k: float, yaw: float) -> Transform2D:
	return Transform2D(yaw, Vector2(k, k), 0.0, center) * Transform2D(0.0, Vector2.ONE, 0.0, -me)


## Isla, barrios, agua, zonas y calles dentro de `view` (rectángulo del mundo visible).
static func draw_world(ci: CanvasItem, map: CityMap, xf: Transform2D, view: Rect2, districts: bool) -> void:
	var k: float = xf.get_scale().x
	ci.draw_set_transform_matrix(xf)
	ci.draw_colored_polygon(map.island, UiStyle.MAP_LAND)
	for i: Dictionary in map.islets:
		ci.draw_circle(i["center"] as Vector2, float(i["radius"]), UiStyle.MAP_LAND)
	for p: PackedVector2Array in map.piers:
		ci.draw_colored_polygon(p, UiStyle.MAP_LAND)
	if districts:
		for d: Dictionary in map.districts:
			var col: Color = UiStyle.MAP_DISTRICT.get(str(d["style"]), UiStyle.MAP_LAND) as Color
			ci.draw_colored_polygon(d["poly"] as PackedVector2Array, col)
	for id: String in ["parque", "golf", "estadio", "cementerio"]:
		if map.zones.has(id):
			ci.draw_colored_polygon(map.zones[id] as PackedVector2Array, Color(0.22, 0.42, 0.2))
	if map.zones.has("base_aerea"):
		ci.draw_colored_polygon(map.zones["base_aerea"] as PackedVector2Array, Color(0.42, 0.24, 0.24))
	if map.airport.has("runway"):
		ci.draw_colored_polygon(map.airport["runway"] as PackedVector2Array, Color(0.15, 0.15, 0.17))
	ci.draw_polyline(map.river_line, UiStyle.MAP_SEA, map.river_width)
	var min_w: float = 1.8 / k
	var big: Rect2 = view.grow(40.0)
	for i: int in map.road_count():
		var a: Vector2 = map.road_start(i)
		var b: Vector2 = map.road_end(i)
		if not big.intersects(Rect2(a, Vector2.ZERO).expand(b)):
			continue
		var highway: bool = map.road_type[i] == "autovia"
		ci.draw_line(a, b, UiStyle.MAP_HIGHWAY if highway else UiStyle.MAP_ROAD, maxf(map.width(i), min_w * (1.6 if highway else 1.0)))
	if k > 0.25:  # redondea los cruces cuando se ven grandes
		for n: int in map.nodes.size():
			if big.has_point(map.nodes[n]):
				ci.draw_circle(map.nodes[n], 5.5, UiStyle.MAP_ROAD)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Ruta del GPS (en coordenadas del mundo).
static func draw_route(ci: CanvasItem, route: PackedVector2Array, xf: Transform2D, width_px: float) -> void:
	if route.size() < 2:
		return
	var pts := PackedVector2Array()
	for p: Vector2 in route:
		pts.append(xf * p)
	ci.draw_polyline(pts, Color(0, 0, 0, 0.6), width_px + 3.0)
	ci.draw_polyline(pts, UiStyle.ROUTE, width_px)
