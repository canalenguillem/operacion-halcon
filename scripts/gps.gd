class_name Gps
extends Node
## GPS: ruta por las calles hasta el destino marcado en el mapa o, si no hay, hasta el objetivo.
## En el caza no hay ruta (se vuela recto), y a pie solo si el destino está lejos.

## Cada cuánto se recalcula la ruta (s).
const REFRESH: float = 0.4
## Al llegar a menos de esta distancia del destino marcado, se borra.
const ARRIVE: float = 30.0
## A pie, más cerca de esto se va en línea recta (sin ruta).
const WALK_DIRECT: float = 250.0

var main: Main
var router: RoadRouter = RoadRouter.new(CityMap.get_default())
## Ruta actual en coordenadas (x, z) del mundo; vacía si no hay.
var route: PackedVector2Array = PackedVector2Array()
var has_waypoint: bool = false
var waypoint: Vector2 = Vector2.ZERO
var _t: float = 0.0


func set_waypoint(p: Vector2) -> void:
	has_waypoint = true
	waypoint = p
	_t = 0.0


func clear_waypoint() -> void:
	has_waypoint = false
	_t = 0.0


## Adónde lleva el GPS ahora mismo, o null si a ningún sitio.
func destination() -> Variant:
	if has_waypoint:
		return waypoint
	var m: MissionState = main.mission
	if m.over or m.stage == MissionState.Stage.ESCAPE:
		return null
	var o: Vector3 = main.halcon.objective_pos()
	return Vector2(o.x, o.z)


func tick(dt: float) -> void:
	var me3: Vector3 = main.target_pos()
	var me := Vector2(me3.x, me3.z)
	if has_waypoint and me.distance_to(waypoint) < ARRIVE:
		clear_waypoint()
	_t -= dt
	if _t > 0.0:
		return
	_t = REFRESH
	var dest: Variant = destination()
	var v: Vehicle = main.vehicle
	var near: float = 25.0 if v != null else WALK_DIRECT
	if dest == null or (v != null and v.is_jet) or me.distance_to(dest as Vector2) < near:
		route = PackedVector2Array()
		return
	route = router.route(me, dest as Vector2)
