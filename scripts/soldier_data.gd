class_name SoldierData
extends Resource
## Ajustes de los soldados. Se editan en `data/soldier.tres`.

@export var max_hp: float = 40.0

@export_group("Alerta y persecución")
## Distancia a la que te ve sin alarma.
@export var sight: float = 45.0
## Con la alarma, distancia a la que se entera.
@export var alarm_radius: float = 500.0
@export var chase_speed: float = 4.5
## Se para a esta distancia de ti.
@export var keep_distance: float = 25.0
## No te persigue si estás más lejos que esto.
@export var chase_distance: float = 300.0
## No se aleja más que esto de su puesto.
@export var leash: float = 350.0
@export var turn_speed: float = 8.0

@export_group("Disparo")
@export var fire_range: float = 95.0
## No dispara a blancos por encima de esta altura.
@export var max_target_height: float = 25.0
@export var fire_interval_min: float = 1.0
@export var fire_interval_max: float = 1.8
## Probabilidad de acertar: `aim_base - distancia / aim_falloff`, entre `aim_min` y `aim_max`.
@export var aim_base: float = 0.75
@export var aim_falloff: float = 130.0
@export var aim_min: float = 0.1
@export var aim_max: float = 0.7
@export var damage_player: float = 5.0
@export var damage_car: float = 2.0
@export var damage_jet: float = 1.2
