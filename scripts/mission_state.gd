class_name MissionState
extends RefCounted
## Estado de la misión y nivel de búsqueda (lógica pura), con tests en `tests/test_mission_state.gd`.

signal alert_raised
signal jet_stolen
signal failed(reason: String)
signal completed

enum Stage { GET_CAR, GO_BASE, GET_JET, ESCAPE, WON }

## Se gana al pasar a esta distancia (en horizontal) del aeródromo.
const WIN_RADIUS: float = 220.0
const WANTED_CAR: int = 1
const WANTED_ALERT: int = 4
const WANTED_JET: int = 5

var stage: Stage = Stage.GET_CAR
## Estrellas de búsqueda, de 0 a 5.
var wanted: int = 0
var base_alert: bool = false
## La misión ha terminado (ganada o perdida).
var over: bool = false


func raise_alert() -> void:
	if base_alert or over:
		return
	base_alert = true
	wanted = maxi(wanted, WANTED_ALERT)
	alert_raised.emit()


func fail(reason: String) -> void:
	if over:
		return
	over = true
	failed.emit(reason)


## Avanza la misión según dónde está el jugador. Llamar cada fotograma de física.
func step(in_vehicle: bool, in_jet: bool, in_base: bool, jets_alive: int, dest_distance: float) -> void:
	if over:
		return
	if in_base and stage < Stage.ESCAPE:
		raise_alert()
	if in_jet and stage < Stage.ESCAPE:
		stage = Stage.ESCAPE
		wanted = WANTED_JET
		raise_alert()
		jet_stolen.emit()
	match stage:
		Stage.GET_CAR:
			if in_vehicle:
				stage = Stage.GO_BASE
				wanted = maxi(wanted, WANTED_CAR)
			elif in_base:
				stage = Stage.GET_JET
		Stage.GO_BASE:
			if in_base:
				stage = Stage.GET_JET
		Stage.GET_JET:
			if jets_alive <= 0:
				fail("NO QUEDAN CAZAS")
		Stage.ESCAPE:
			if not in_jet:
				stage = Stage.GET_JET
			elif dest_distance < WIN_RADIUS:
				stage = Stage.WON
				wanted = 0
				over = true
				completed.emit()


func objective_text() -> String:
	match stage:
		Stage.GET_CAR:
			return "Consigue un coche"
		Stage.GO_BASE:
			return "Conduce hasta la base aérea"
		Stage.GET_JET:
			return "Entra en la base y roba un caza"
		Stage.ESCAPE:
			return "Despega y huye al aeródromo clandestino"
	return ""
