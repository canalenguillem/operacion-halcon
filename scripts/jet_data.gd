class_name JetData
extends Resource
## Ajustes del caza. Se editan en `data/jet.tres`. Velocidades en m/s, giros en rad/s.

@export_group("Motor")
@export var max_speed: float = 150.0
@export var ground_acceleration: float = 24.0
@export var ground_brake: float = 14.0
@export var air_acceleration: float = 18.0
## Potencia que sube por segundo al acelerar.
@export var throttle_up: float = 0.7
@export var throttle_down: float = 0.9

@export_group("Despegue")
## Velocidad mínima para despegar tirando del morro (S).
@export var takeoff_speed: float = 55.0
## Velocidad a la que despega solo.
@export var auto_lift_speed: float = 70.0
## Ángulo de morro al despegar, en radianes.
@export var liftoff_pitch: float = 0.14
@export var ground_steer: float = 0.9

@export_group("Vuelo")
@export var pitch_rate: float = 1.2
@export var roll_rate: float = 2.4
## Rapidez con la que se nivela solo al soltar A/D.
@export var auto_level: float = 1.2
## Cuánto gira por estar inclinado.
@export var bank_turn: float = 1.1
## Velocidad que pierde al subir (y gana al bajar).
@export var climb_drag: float = 20.0
## Caída en pérdida (por debajo de `takeoff_speed`).
@export var stall_sink: float = 40.0
@export var stall_nose_drop: float = 0.6

@export_group("Daño y bengalas")
@export var max_hp: float = 100.0
@export var min_impact: float = 8.0
@export var impact_damage: float = 0.8
@export var flares: int = 12
@export var flare_cooldown: float = 1.0

@export_group("Subir y bajar")
@export var enter_range: float = 9.0
@export var exit_speed: float = 3.0

@export_group("Cámara")
@export var cam_distance: float = 26.0
@export var cam_height: float = 7.0
@export var cam_follow: float = 5.0
