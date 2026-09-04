extends "res://addons/gut/test.gd"

## El clic con el que se cierra un globo de diálogo no debe salir como un golpe.
##
## Pasaba por dos sitios a la vez:
##
##  1. `DialogueManager.dialogue_ended` llega MIENTRAS se está repartiendo el
##     clic que cerró el globo. Devolviendo el control ahí mismo, esa misma
##     pulsación bajaba hasta el jugador con el control ya devuelto: Benjamín
##     empezaba a tensar y al soltar salía la flecha.
##  2. Emilia no pega al pulsar sino al SOLTAR, y el soltar no comprobaba que
##     hubiera habido pulsación. Aunque la pulsación se bloqueara, la soltada
##     sacaba un golpe de la nada.

const PLAYER := preload("res://scenes/actors/Player.tscn")


func before_each() -> void:
	GameManager.reset_progress()


func after_all() -> void:
	GameManager.reset_progress()


func _accion(nombre: String, pulsada: bool) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = nombre
	e.pressed = pulsada
	return e


func _emilia() -> CharacterBody3D:
	var p: CharacterBody3D = PLAYER.instantiate()
	p.is_archer = false
	add_child_autofree(p)
	p.set_active(true)
	p.input_locked = false
	await wait_physics_frames(2)
	return p


## Soltar sin haber pulsado no es un golpe.
func test_soltar_sin_haber_pulsado_no_pega() -> void:
	var p := await _emilia()
	var golpes := [0]
	p.melee_hit.connect(func(_paso: int) -> void: golpes[0] += 1)

	p._unhandled_input(_accion("attack", false))
	assert_eq(golpes[0], 0, "una soltada suelta no saca golpe")


## …y el ciclo entero sí, que si no la guarda habría roto el combate.
func test_pulsar_y_soltar_si_pega() -> void:
	var p := await _emilia()
	var golpes := [0]
	p.melee_hit.connect(func(_paso: int) -> void: golpes[0] += 1)

	p._unhandled_input(_accion("attack", true))
	p._unhandled_input(_accion("attack", false))
	assert_eq(golpes[0], 1, "pulsar y soltar sigue pegando")


## Con el control quitado no pasa nada, ni pulsando ni soltando.
func test_con_el_control_quitado_no_pega() -> void:
	var p := await _emilia()
	var golpes := [0]
	p.melee_hit.connect(func(_paso: int) -> void: golpes[0] += 1)

	p.input_locked = true
	p._unhandled_input(_accion("attack", true))
	p._unhandled_input(_accion("attack", false))
	assert_eq(golpes[0], 0, "hablando no se pega")

	# Y la soltada que llega DESPUÉS de recuperar el control tampoco: su
	# pulsación se quedó fuera.
	p.input_locked = false
	p._unhandled_input(_accion("attack", false))
	assert_eq(golpes[0], 0, "ni la soltada que sobrevive al bloqueo")


## El control vuelve al cuadro SIGUIENTE, no en el mismo en que se cierra el
## globo: para entonces el clic que lo cerró ya no existe.
func test_el_control_vuelve_un_cuadro_despues() -> void:
	var p := await _emilia()
	p.input_locked = true
	DialogueManager.dialogue_ended.emit(null)
	assert_true(p.input_locked,
		"el clic que cierra el globo todavía encuentra el control quitado")
	await get_tree().process_frame
	assert_false(p.input_locked, "y en el cuadro siguiente ya se juega")


## Y si un diálogo encadena con otro, el control no vuelve por el hueco.
func test_si_encadena_otro_dialogo_el_control_no_vuelve() -> void:
	var p := await _emilia()
	p.input_locked = true
	DialogueManager.dialogue_ended.emit(null)
	DialogueManager.dialogue_started.emit(null)      # arranca el siguiente
	await get_tree().process_frame
	assert_true(p.input_locked, "sigue sin control durante el segundo diálogo")

	DialogueManager.dialogue_ended.emit(null)
	await get_tree().process_frame
	assert_false(p.input_locked, "y vuelve cuando de verdad se acabaron")


## El arquero tensa al pulsar: si la pulsación no entró, soltar no dispara.
func test_el_arquero_no_dispara_por_una_soltada_suelta() -> void:
	var b: CharacterBody3D = PLAYER.instantiate()
	b.is_archer = true
	add_child_autofree(b)
	b.set_active(true)
	b.input_locked = false
	await wait_physics_frames(2)

	b._unhandled_input(_accion("attack", false))
	assert_false(b._charging, "no se queda tensando de la nada")
	var e0: float = b.energy
	b._unhandled_input(_accion("attack", false))
	assert_eq(b.energy, e0, "ni gasta energía disparando")
