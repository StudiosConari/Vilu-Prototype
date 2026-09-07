extends GutTest

## Al volver al cráter del Isluga, el camino de salida ya está puesto.
##
## EL FALLO. El camino nace escondido, lo abre el guardián y se derrumba detrás
## tuyo. Está bien la primera vez. Pero al regresar por el portal del Ojos del
## Salado la escena se monta de cero —camino escondido otra vez— y el guardián
## ya no tiene nada que decir: quedabas encerrado en el cráter sin puente por el
## que irte.

const CAMINO := preload("res://scenes/actors/CaminoDeSalida.gd")


func _camino_con(cuantos: int) -> Node3D:
	var c: Node3D = CAMINO.new()
	for i in cuantos:
		var b := Node3D.new()
		b.name = "Bloque%d" % i
		b.position = Vector3(0, 3.0, i * 4.0)
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = 1
		b.add_child(cuerpo)
		c.add_child(b)
	add_child_autofree(c)
	return c


func test_al_arrancar_no_hay_camino() -> void:
	# La primera visita sigue igual: el cráter se gana, no se regala.
	var c := _camino_con(3)
	for b in c.get_children():
		assert_false((b as Node3D).visible, "%s escondido hasta que abra el guardián" % b.name)


func test_dejar_abierto_pone_todos_los_bloques() -> void:
	var c := _camino_con(4)
	c.call("dejar_abierto")
	for b in c.get_children():
		assert_true((b as Node3D).visible, "%s puesto al volver" % b.name)
		assert_almost_eq((b as Node3D).position.y, 3.0, 0.01,
			"%s a su altura, no brotando" % b.name)


func test_al_volver_los_bloques_sostienen() -> void:
	# Visibles pero sin colisión serían un decorado: se cruzaría de largo hacia
	# la lava.
	var c := _camino_con(3)
	c.call("dejar_abierto")
	for b in c.get_children():
		var cuerpo: StaticBody3D = null
		for h in b.get_children():
			if h is StaticBody3D:
				cuerpo = h
		assert_eq(cuerpo.collision_layer, 1, "%s vuelve a su capa" % b.name)


func test_al_volver_no_se_puede_derrumbar_otra_vez() -> void:
	# Las zonas de borde son las que disparan el derrumbe. Si se montaran en la
	# segunda visita, cruzar el camino volvería a encerrar al jugador.
	var c := _camino_con(3)
	c.call("dejar_abierto")
	for b in c.get_children():
		assert_null(b.get_node_or_null("Borde"),
			"%s sin zona de derrumbe al volver" % b.name)


func test_abrirlo_dos_veces_no_hace_nada() -> void:
	var c := _camino_con(2)
	c.call("dejar_abierto")
	c.call("dejar_abierto")
	assert_true((c.get_child(0) as Node3D).visible, "sigue puesto")
