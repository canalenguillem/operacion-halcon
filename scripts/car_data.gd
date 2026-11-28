class_name CarData
extends Resource
## Ajustes del coche. Se editan en `data/car.tres`. Velocidades en m/s.

@export_group("Motor")
@export var max_speed: float = 40.0
@export var reverse_speed: float = 12.0
@export var acceleration: float = 14.0
@export var reverse_acceleration: float = 9.0
## Frenada al pedir la dirección contraria a la que llevas.
@export var brake: float = 30.0
## Frenada sin tocar nada.
@export var coast: float = 6.0
@export var handbrake: float = 45.0

@export_group("Dirección")
## Giro máximo en radianes por segundo.
@export var steer: float = 2.0
## Por debajo de esta velocidad gira proporcionalmente menos.
@export var grip_speed: float = 8.0
## Cuanto más bajo, menos gira a alta velocidad.
@export var understeer_speed: float = 45.0

@export_group("Suelo")
## Gravedad en el aire (m/s²).
@export var gravity: float = 25.0
## Distancia a la que el coche se «pega» al suelo al bajar una cuesta.
@export var floor_snap: float = 1.2
## Rapidez con la que la carrocería se inclina con la pendiente.
@export var tilt_speed: float = 8.0

@export_group("Daño")
@export var max_hp: float = 100.0
## Velocidad de choque frontal a partir de la cual se daña.
@export var min_impact: float = 12.0
## Daño por cada m/s de choque.
@export var impact_damage: float = 0.5
@export var run_over_speed: float = 6.0
## Daño al conductor cuando el coche explota.
@export var eject_damage: float = 40.0

@export_group("Subir y bajar")
@export var enter_range: float = 4.5
## Velocidad máxima a la que se puede bajar.
@export var exit_speed: float = 6.0

@export_group("Cámara")
@export var cam_offset: Vector3 = Vector3(0, 0.4, 9.5)
@export var cam_pivot_height: float = 1.9
## Cabeceo al que vuelve la cámara al conducir.
@export var cam_pitch: float = -0.22
## Rapidez con la que la cámara se recoloca detrás.
@export var cam_follow: float = 3.0
## Segundos sin mover el ratón antes de recolocarse.
@export var cam_idle: float = 1.0
