class_name RoadRouter
extends RefCounted
## Rutas por la red de calles de `CityMap` (A*), con tests en `tests/test_road_router.gd`.
## Prefiere las vías grandes: recorrer un metro de autovía «cuesta» menos que uno de callejón.

const COST: Dictionary = {"autovia": 0.6, "avenida": 0.8, "calle": 1.0, "muelle": 1.2, "callejon": 1.35}

var map: CityMap
## Por cruce: cruces vecinos y coste de llegar a cada uno.
var _next: Array[PackedInt32Array] = []
var _cost: Array[PackedFloat32Array] = []


func _init(m: CityMap) -> void:
	map = m
	_next.resize(m.nodes.size())
	_cost.resize(m.nodes.size())
	for i: int in m.road_count():
		var a: int = m.road_a[i]
		var b: int = m.road_b[i]
		var c: float = m.nodes[a].distance_to(m.nodes[b]) * float(COST.get(m.road_type[i], 1.0))
		_next[a].append(b)
		_cost[a].append(c)
		_next[b].append(a)
		_cost[b].append(c)


## El cruce más cercano a un punto (a través de la calle más cercana).
func nearest_node(p: Vector2) -> int:
	var near: Array = map.closest_road(p, 250.0)
	if not near.is_empty():
		var i: int = near[0]
		var a: int = map.road_a[i]
		var b: int = map.road_b[i]
		return a if p.distance_to(map.nodes[a]) < p.distance_to(map.nodes[b]) else b
	var best: int = 0
	for n: int in map.nodes.size():
		if p.distance_squared_to(map.nodes[n]) < p.distance_squared_to(map.nodes[best]):
			best = n
	return best


## Cruces de la ruta más barata de `start` a `goal` (vacío si no hay camino).
func node_path(start: int, goal: int) -> PackedInt32Array:
	var n: int = map.nodes.size()
	var g := PackedFloat32Array()
	g.resize(n)
	g.fill(INF)
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	var heap_f := PackedFloat32Array()
	var heap_n := PackedInt32Array()
	g[start] = 0.0
	_push(heap_f, heap_n, _h(start, goal), start)
	while heap_n.size() > 0:
		var cur: int = _pop(heap_f, heap_n)
		if cur == goal:
			break
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		var nexts: PackedInt32Array = _next[cur]
		var costs: PackedFloat32Array = _cost[cur]
		for k: int in nexts.size():
			var o: int = nexts[k]
			var ng: float = g[cur] + costs[k]
			if ng < g[o]:
				g[o] = ng
				came[o] = cur
				_push(heap_f, heap_n, ng + _h(o, goal), o)
	if start != goal and came[goal] < 0:
		return PackedInt32Array()
	var out := PackedInt32Array([goal])
	var at: int = goal
	while at != start:
		at = came[at]
		out.append(at)
	out.reverse()
	return out


## Ruta de `from` a `to` como polilínea: el punto de salida, los cruces y el de llegada.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var nodes: PackedInt32Array = node_path(nearest_node(from), nearest_node(to))
	if nodes.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array([from])
	for i: int in nodes:
		out.append(map.nodes[i])
	out.append(to)
	return out


## Estimación optimista del coste que falta (la vía más barata en línea recta).
func _h(a: int, b: int) -> float:
	return map.nodes[a].distance_to(map.nodes[b]) * float(COST["autovia"])


static func _push(f: PackedFloat32Array, n: PackedInt32Array, priority: float, node: int) -> void:
	f.append(priority)
	n.append(node)
	var i: int = f.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var parent: int = (i - 1) / 2
		if f[parent] <= f[i]:
			break
		var tf: float = f[parent]
		f[parent] = f[i]
		f[i] = tf
		var tn: int = n[parent]
		n[parent] = n[i]
		n[i] = tn
		i = parent


static func _pop(f: PackedFloat32Array, n: PackedInt32Array) -> int:
	var top: int = n[0]
	var last: int = f.size() - 1
	f[0] = f[last]
	n[0] = n[last]
	f.resize(last)
	n.resize(last)
	var i: int = 0
	while true:
		var l: int = i * 2 + 1
		var r: int = l + 1
		var m: int = i
		if l < last and f[l] < f[m]:
			m = l
		if r < last and f[r] < f[m]:
			m = r
		if m == i:
			break
		var tf: float = f[m]
		f[m] = f[i]
		f[i] = tf
		var tn: int = n[m]
		n[m] = n[i]
		n[i] = tn
		i = m
	return top
