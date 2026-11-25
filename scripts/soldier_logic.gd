class_name SoldierLogic
extends RefCounted
## Lógica pura de los soldados, con tests en `tests/test_soldier_logic.gd`.


## ¿Se pone en alerta? Si te ve de cerca, o si ya ha saltado la alarma y está dentro de su radio.
static func should_alert(dist: float, base_alert: bool, d: SoldierData) -> bool:
	return dist < d.sight or (base_alert and dist < d.alarm_radius)


## ¿Te persigue? Solo si estás ni muy cerca ni muy lejos y él no se ha alejado de su puesto.
static func should_chase(dist: float, home_dist: float, d: SoldierData) -> bool:
	return dist > d.keep_distance and dist < d.chase_distance and home_dist < d.leash


## ¿Puede dispararte? En alcance y sin que vueles alto.
static func can_fire(dist: float, target_height: float, d: SoldierData) -> bool:
	return dist < d.fire_range and target_height < d.max_target_height


## Probabilidad de acertar a esa distancia.
static func hit_chance(dist: float, d: SoldierData) -> float:
	return clampf(d.aim_base - dist / d.aim_falloff, d.aim_min, d.aim_max)
