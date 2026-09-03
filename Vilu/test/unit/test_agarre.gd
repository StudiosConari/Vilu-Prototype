extends GutTest

## El agarre del golpe cargado de Emilia.
##
## La regla que importa: a los enemigos chicos les entra siempre; a los jefes
## SÓLO mientras están aturdidos, que es la ventana que se abre cuando fallan un
## especial. Fuera de esa ventana el agarre rebota y queda un golpe normal.

const MINERO := preload("res://scenes/enemies/MineroCorrupto.tscn")


func _enemigo(jefe: bool) -> Node3D:
	var e: Node3D = MINERO.instantiate()
	e.is_boss = jefe
	add_child_autofree(e)
	return e


func test_al_enemigo_chico_el_agarre_le_entra_siempre() -> void:
	var e := _enemigo(false)
	assert_true(e.puede_ser_agarrado(), "un enemigo chico se deja agarrar sin más")
	assert_true(e.agarrar(0.9), "el agarre prende")
	assert_true(e.esta_agarrado(), "queda inmovilizado")


func test_al_jefe_entero_el_agarre_no_le_entra() -> void:
	var e := _enemigo(true)
	assert_false(e.esta_aturdido(), "un jefe no arranca aturdido")
	assert_false(e.puede_ser_agarrado(), "con la guardia alta no se lo puede agarrar")
	assert_false(e.agarrar(0.9), "el agarre rebota")
	assert_false(e.esta_agarrado(), "y no queda inmovilizado")


func test_al_jefe_aturdido_si() -> void:
	var e := _enemigo(true)
	e._aturdir()
	assert_true(e.esta_aturdido(), "queda abierto tras fallar el especial")
	assert_true(e.puede_ser_agarrado(), "y ahí sí se lo puede agarrar")
	assert_true(e.agarrar(0.9), "el agarre prende")


func test_el_aturdimiento_se_acaba() -> void:
	var e := _enemigo(true)
	e.aturdimiento_tras_fallar = 0.05
	e._aturdir()
	assert_true(e.puede_ser_agarrado(), "abierto al principio")
	# Se descuenta el tiempo a mano en vez de esperarlo: el test no depende de
	# cuántos frames tarde la máquina en correr.
	e._aturdido = 0.0
	assert_false(e.puede_ser_agarrado(), "cerrado al pasarse la ventana")


func test_los_enemigos_chicos_no_se_aturden_como_los_jefes() -> void:
	var e := _enemigo(false)
	e._aturdir()
	assert_false(e.esta_aturdido(),
		"el aturdimiento de ventana es cosa de jefes; los chicos ya se frenan con cada golpe")


## Matar a la presa a mitad del agarre no puede reventar la tanda de golpes.
##
## Regresión: `_golpe_de_agarre` declaraba `presa: Node3D`, y los golpes que
## quedaban pendientes llegaban con la presa ya liberada. GDScript convierte los
## argumentos ANTES de entrar en la función, así que la llamada moría en la
## conversión —"Cannot convert argument 1 from Object to Object"— sin llegar
## siquiera al `is_instance_valid` que estaba puesto para este caso.
func test_soltar_los_golpes_con_la_presa_muerta_no_falla() -> void:
	var p: CharacterBody3D = load("res://scenes/actors/Player.tscn").instantiate()
	p.is_archer = false
	add_child_autofree(p)
	# A mano y NO con `_enemigo`: ese usa add_child_autofree, y acÃ¡ la presa se
	# libera dentro de la prueba a propÃ³sito.
	var presa: Node3D = MINERO.instantiate()
	add_child(presa)
	await wait_physics_frames(2)

	p._agarrar(presa)
	presa.free()   # muere en el primer golpe; quedan tres temporizadores vivos
	# Los golpes se reparten a lo largo de AGARRE_DURACION: se espera de sobra.
	await wait_seconds(p.AGARRE_DURACION + 0.3)

	assert_eq(get_errors().size(), 0,
		"los golpes pendientes con la presa liberada no dan error")
