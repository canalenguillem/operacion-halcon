class_name CityMap
extends RefCounted
## La isla y su ciudad tal como las describe `data/map/city.json` (lo genera `tools/map/layout.py`).
## Solo datos y consultas (sin nodos), con tests en `tests/test_city_map.gd`.
## Coordenadas 2D: `Vector2(x, z)` del mundo, en metros (el norte es -z).

const PATH: String = "res://data/map/city.json"
## Tamaño de las celdas del índice espacial de calles.
const CELL: float = 100.0

var nodes: PackedVector2Array = PackedVector2Array()
var road_a: PackedInt32Array = PackedInt32Array()
var road_b: PackedInt32Array = PackedInt32Array()
var road_type: PackedStringArray = PackedStringArray()
var road_bridge: Array[bool] = []
var road_widths: Dictionary = {}
var sidewalk: float = 3.0
var player_start: Vector2 = Vector2.ZERO
var island: PackedVector2Array = PackedVector2Array()
## Islotes: {id, center: Vector2, radius}.
var islets: Array[Dictionary] = []
var river_line: PackedVector2Array = PackedVector2Array()
var river_width: float = 40.0
var beach: PackedVector2Array = PackedVector2Array()
var piers: Array[PackedVector2Array] = []
## Colinas: {id, center: Vector2, radius, height}.
var hills: Array[Dictionary] = []
var railway: PackedVector2Array = PackedVector2Array()
## Barrios: {id, name, style, poly: PackedVector2Array}.
var districts: Array[Dictionary] = []
## Zonas sin calles (parque, golf, estadio…): id → polígono.
var zones: Dictionary = {}
## Aeropuerto civil: runway, taxiway, apron, terminal, parking → polígono.
var airport: Dictionary = {}
## Lugares de interés: {id, name, pos: Vector2}.
var pois: Array[Dictionary] = []

## Edificios (en paralelo): centro, giro (yaw de Godot: el eje X local va a lo largo de la calle
## y la fachada, -Z local, mira a la calle), tamaño (ancho, alto, fondo), tipo y variante (0-99).
var b_pos: PackedVector2Array = PackedVector2Array()
var b_yaw: PackedFloat32Array = PackedFloat32Array()
var b_size: PackedVector3Array = PackedVector3Array()
var b_kind: PackedStringArray = PackedStringArray()
var b_var: PackedInt32Array = PackedInt32Array()
## Edificios singulares: {id, kind, pos: Vector2, yaw, w, d}.
var landmarks: Array[Dictionary] = []

var _cells: Dictionary = {}
var _river_poly: PackedVector2Array = PackedVector2Array()

static var _default: CityMap = null


## El mapa del juego (se carga una vez).
static func get_default() -> CityMap:
	if _default == null:
		_default = CityMap.load_file(PATH)
	return _default


static func load_file(path: String) -> CityMap:
	var text: String = FileAccess.get_file_as_string(path)
	var data: Dictionary = JSON.parse_string(text) as Dictionary
	var m := CityMap.new()
	m._read(data)
	return m


static func _vec(v: Variant) -> Vector2:
	var a: Array = v as Array
	return Vector2(float(a[0]), float(a[1]))


static func _poly(v: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Variant in (v as Array):
		out.append(_vec(p))
	return out


func _read(d: Dictionary) -> void:
	for p: Variant in (d["nodes"] as Array):
		nodes.append(_vec(p))
	for r: Variant in (d["roads"] as Array):
		var rd: Dictionary = r as Dictionary
		road_a.append(int(rd["a"]))
		road_b.append(int(rd["b"]))
		road_type.append(str(rd["type"]))
		road_bridge.append(bool(rd["bridge"]))
	road_widths = d["road_width"] as Dictionary
	sidewalk = float(d["sidewalk"])
	player_start = _vec(d["player_start"])
	island = _poly(d["island"])
	for i: Variant in (d["islets"] as Array):
		var idict: Dictionary = i as Dictionary
		islets.append({"id": str(idict["id"]), "center": _vec(idict["center"]), "radius": float(idict["radius"])})
	var river: Dictionary = d["river"] as Dictionary
	river_line = _poly(river["line"])
	river_width = float(river["width"])
	_river_poly = river_polygon()
	beach = _poly(d["beach"])
	for p: Variant in (d["piers"] as Array):
		piers.append(_poly(p))
	for h: Variant in (d["hills"] as Array):
		var hd: Dictionary = h as Dictionary
		hills.append({"id": str(hd["id"]), "center": _vec(hd["center"]), "radius": float(hd["radius"]), "height": float(hd["height"])})
	railway = _poly(d["railway"])
	for dist: Variant in (d["districts"] as Array):
		var dd: Dictionary = dist as Dictionary
		districts.append({"id": str(dd["id"]), "name": str(dd["name"]), "style": str(dd["style"]), "poly": _poly(dd["poly"])})
	var zd: Dictionary = d["zones"] as Dictionary
	for k: Variant in zd:
		zones[str(k)] = _poly(zd[k])
	var ad: Dictionary = d["airport"] as Dictionary
	for k: Variant in ad:
		airport[str(k)] = _poly(ad[k])
	for p: Variant in (d["pois"] as Array):
		var pd: Dictionary = p as Dictionary
		pois.append({"id": str(pd["id"]), "name": str(pd["name"]), "pos": _vec(pd["pos"])})
	for b: Variant in (d.get("buildings", []) as Array):
		var ba: Array = b as Array
		b_pos.append(Vector2(float(ba[0]), float(ba[1])))
		b_yaw.append(float(ba[2]))
		b_size.append(Vector3(float(ba[3]), float(ba[5]), float(ba[4])))
		b_kind.append(str(ba[6]))
		b_var.append(int(ba[7]))
	for l: Variant in (d.get("landmarks", []) as Array):
		var ld: Dictionary = l as Dictionary
		landmarks.append({"id": str(ld["id"]), "kind": str(ld["kind"]), "pos": Vector2(float(ld["x"]), float(ld["z"])),
			"yaw": float(ld["yaw"]), "w": float(ld["w"]), "d": float(ld["d"])})
	_index_roads()


func road_count() -> int:
	return road_a.size()


## Anchura de la calzada de la calle `i` (sin aceras).
func width(i: int) -> float:
	return float(road_widths[road_type[i]])


func road_start(i: int) -> Vector2:
	return nodes[road_a[i]]


func road_end(i: int) -> Vector2:
	return nodes[road_b[i]]


## Polígono del río (la línea engordada a su anchura), para recortarlo del suelo.
func river_polygon() -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var half: float = river_width / 2.0
	for i: int in river_line.size():
		var prev: Vector2 = river_line[maxi(i - 1, 0)]
		var next: Vector2 = river_line[mini(i + 1, river_line.size() - 1)]
		var n: Vector2 = (next - prev).normalized().orthogonal()
		left.append(river_line[i] + n * half)
		right.append(river_line[i] - n * half)
	right.reverse()
	left.append_array(right)
	return left


## ¿Es tierra firme? (isla o islote, fuera del río).
func on_land(p: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(p, _river_poly):
		return false
	if Geometry2D.is_point_in_polygon(p, island):
		return true
	for p2: PackedVector2Array in piers:
		if Geometry2D.is_point_in_polygon(p, p2):
			return true
	for i: Dictionary in islets:
		if p.distance_to(i["center"] as Vector2) < float(i["radius"]):
			return true
	return false


## Id del barrio en el que está el punto ("" si es campo).
func district_at(p: Vector2) -> String:
	for d: Dictionary in districts:
		if Geometry2D.is_point_in_polygon(p, d["poly"] as PackedVector2Array):
			return str(d["id"])
	return ""


func in_zone(p: Vector2) -> bool:
	for k: String in zones:
		if Geometry2D.is_point_in_polygon(p, zones[k] as PackedVector2Array):
			return true
	return false


## Posición de un lugar de interés por su id.
func poi(id: String) -> Vector2:
	for p: Dictionary in pois:
		if p["id"] == id:
			return p["pos"] as Vector2
	return Vector2.ZERO


## Distancia del punto al borde de la calzada más cercana (negativa si está sobre una calzada).
func road_clearance(p: Vector2) -> float:
	var best: float = 1e9
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			for i: int in (_cells.get(key + Vector2i(dx, dz), []) as Array):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, road_start(i), road_end(i))
				best = minf(best, p.distance_to(q) - width(i) / 2.0)
	return best


## La calle más cercana a menos de `max_dist` metros (de su eje): [índice, punto del eje], o [] si no hay.
func closest_road(p: Vector2, max_dist: float) -> Array:
	var best: float = max_dist
	var out: Array = []
	var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			for i: int in (_cells.get(key + Vector2i(dx, dz), []) as Array):
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, road_start(i), road_end(i))
				var dd: float = p.distance_to(q)
				if dd < best:
					best = dd
					out = [i, q]
	return out


func building_count() -> int:
	return b_pos.size()


## Esquinas de un rectángulo girado `yaw` (convención de Godot) de `w` × `d` metros.
static func rect_corners(c: Vector2, yaw: float, w: float, d: float) -> PackedVector2Array:
	var u := Vector2(cos(yaw), -sin(yaw)) * (w / 2.0)
	var v := Vector2(sin(yaw), cos(yaw)) * (d / 2.0)
	return PackedVector2Array([c - u - v, c + u - v, c + u + v, c - u + v])


func _index_roads() -> void:
	for i: int in road_count():
		var a: Vector2 = road_start(i)
		var b: Vector2 = road_end(i)
		var steps: int = maxi(1, ceili(a.distance_to(b) / (CELL * 0.5)))
		var seen: Dictionary = {}
		for s: int in steps + 1:
			var p: Vector2 = a.lerp(b, float(s) / steps)
			var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
			if not seen.has(key):
				seen[key] = true
				if not _cells.has(key):
					_cells[key] = []
				(_cells[key] as Array).append(i)
