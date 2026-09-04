extends "res://addons/gut/test.gd"

## El logro "Viajero Volcánico" se gana cruzando de un volcán al otro.
##
## No es llegar a la cima del Ojos del Salado: es CRUZAR por el portal hasta el
## Isluga y salir de él. Antes se concedía en la cima, que es antes de tiempo —y
## además la cima no sabe si después vas a cruzar o a volverte por donde
## entraste—. La cuenta la lleva TravelManager, que es quien sabe de dónde
## vienes.

const ID := "ojos_salado"


func before_each() -> void:
	GameManager.reset_progress()
	TravelManager.current_region = ""
	TravelManager._cruzo_por_el_portal = false


func after_all() -> void:
	GameManager.reset_progress()
	TravelManager.current_region = ""


## Se simula el recorrido moviendo la región a mano: instanciar los puzzles
## enteros para esto sería cargar dos escenas grandes por un booleano.
func _ir_a(region: String) -> void:
	TravelManager._anotar_el_cruce(region)
	TravelManager.current_region = region


func test_el_camino_completo_lo_concede() -> void:
	_ir_a("OjosDelSalado")
	assert_false(GameManager.tiene_logro(ID), "llegar a la cima no basta")
	_ir_a("Isluga")
	assert_false(GameManager.tiene_logro(ID), "cruzar tampoco: falta salir")
	_ir_a("")
	assert_true(GameManager.tiene_logro(ID), "al salir del Isluga, sí")


## Ir al Isluga por su cuenta —al principio del juego, subiendo desde
## Tarapacá— y salir de él no cuenta: no hubo cruce entre volcanes.
func test_entrar_y_salir_del_isluga_solo_no_cuenta() -> void:
	_ir_a("Isluga")
	_ir_a("")
	assert_false(GameManager.tiene_logro(ID),
		"sin venir del Ojos del Salado no hay viaje entre volcanes")


## Y volverse del Ojos del Salado por donde se entró tampoco.
func test_volverse_del_salado_sin_cruzar_no_cuenta() -> void:
	_ir_a("OjosDelSalado")
	_ir_a("")
	assert_false(GameManager.tiene_logro(ID))
