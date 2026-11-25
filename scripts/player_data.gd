class_name PlayerData
extends Resource
## Ajustes del jugador a pie. Se editan en `data/player.tres`.

@export_group("Movimiento")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 50.0
@export var jump_speed: float = 8.0
@export var gravity: float = 25.0
@export var turn_speed: float = 12.0

@export_group("Salud")
@export var max_health: float = 100.0
## Segundos sin recibir daño antes de empezar a recuperar salud.
@export var regen_delay: float = 6.0
## Salud recuperada por segundo.
@export var regen_rate: float = 4.0

@export_group("Pistola")
@export var damage: float = 25.0
## Segundos entre disparos.
@export var fire_interval: float = 0.22
@export var fire_range: float = 250.0
## Radio en el que los soldados oyen un disparo.
@export var noise_radius: float = 120.0
## Grados alrededor de la mira en los que el disparo se corrige hacia un soldado (0 = sin ayuda).
@export var aim_assist_degrees: float = 3.0

@export_group("Cámara")
## Radianes por píxel de ratón.
@export var mouse_sensitivity: float = 0.003
## Posición de la cámara respecto al jugador (derecha, arriba, atrás).
@export var cam_offset: Vector3 = Vector3(0.7, 0.25, 4.2)
@export var cam_pivot_height: float = 1.6
@export var pitch_min: float = -1.2
@export var pitch_max: float = 0.6
