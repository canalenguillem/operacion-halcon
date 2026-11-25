class_name MissileData
extends Resource
## Ajustes de los misiles y de las baterías. Se editan en `data/missile.tres`.

@export_group("Misil")
@export var launch_speed: float = 60.0
@export var top_speed: float = 185.0
@export var acceleration: float = 90.0
## Giro máximo en rad/s: cuanto menor, más fácil de esquivar.
@export var turn_rate: float = 0.75
@export var lifetime: float = 16.0
@export var hit_radius: float = 10.0
@export var damage: float = 34.0
## Cuánto apunta por delante del caza (0 = va directo a él).
@export var lead: float = 0.4

@export_group("Baterías")
@export var min_range: float = 250.0
@export var max_range: float = 2600.0
## No disparan a un caza por debajo de esta altura.
@export var min_altitude: float = 25.0
@export var first_shot_min: float = 4.0
@export var first_shot_max: float = 9.0
@export var reload_min: float = 8.0
@export var reload_max: float = 12.0
## Misiles en el aire a la vez.
@export var max_airborne: int = 2

@export_group("Bengalas")
@export var flare_radius: float = 1200.0
## Probabilidad de que una bengala despiste a cada misil cercano.
@export var flare_chance: float = 0.75
