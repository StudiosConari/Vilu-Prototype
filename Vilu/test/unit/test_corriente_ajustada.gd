extends GutTest

## Que la zona que empuja sea EXACTAMENTE la columna que se ve.
##
## El área y la malla son hijos distintos del mismo nodo, así que mover o
## redimensionar uno sin el otro los separa, y en el editor eso pasa sin querer.
## Medido en el Ojos del Salado: de 18 corrientes, 11 estaban descuadradas —una
## con la zona casi tres veces más alta que la columna—.
##
## Un viento que empuja donde no se ve es de las cosas más injustas que hay en
## un plataformas: no se puede aprender una regla que no se ve.

const CORRIENTE := preload("res://scenes/actors/Updraft.gd")


## Una corriente con la malla y el disparador DESCUADRADOS a propósito.
func _descuadrada() -> Area3D:
	var a := Area3D.new()
	a.set_script(CORRIENTE)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.0, 8.0, 3.0)
	m.mesh = bm
	m.position = Vector3(0.0, 2.0, 0.0)      # la columna, subida 2 m
	a.add_child(m)
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(6.0, 2.0, 6.0)       # el disparador, ancho y bajo
	cs.shape = caja
	a.add_child(cs)
	add_child_autofree(a)
	return a


func test_el_disparador_se_ajusta_a_la_columna() -> void:
	var a := _descuadrada()
	await wait_frames(2)
	var m: MeshInstance3D = null
	var cs: CollisionShape3D = null
	for h in a.get_children():
		if h is MeshInstance3D: m = h
		if h is CollisionShape3D: cs = h
	var vista: AABB = m.transform * m.get_aabb()
	var empuja: AABB = (cs.shape as BoxShape3D).get_debug_mesh().get_aabb()
	empuja.position += cs.position
	assert_almost_eq(empuja.size, vista.size, Vector3.ONE * 0.01, "mismo tamaño")
	assert_almost_eq(empuja.get_center(), vista.get_center(), Vector3.ONE * 0.01, "mismo sitio")


func test_se_puede_desactivar_el_ajuste() -> void:
	# Por si alguna vez se quiere de verdad una zona distinta de lo que se ve.
	var a := _descuadrada()
	a.set("ajustar_disparador", false)
	var cs: CollisionShape3D = null
	for h in a.get_children():
		if h is CollisionShape3D: cs = h
	var antes: Vector3 = (cs.shape as BoxShape3D).size
	a.call("_refresh_visual")
	assert_almost_eq((cs.shape as BoxShape3D).size, antes, Vector3.ONE * 0.01,
		"destildado, no toca nada")


func test_no_pisa_la_forma_de_las_vecinas() -> void:
	# Duplicar un nodo en el editor COMPARTE sus recursos: redimensionar la caja
	# de una cambiaría también la de las otras.
	var compartida := BoxShape3D.new()
	compartida.size = Vector3(9.0, 9.0, 9.0)
	var a := _descuadrada()
	var cs: CollisionShape3D = null
	for h in a.get_children():
		if h is CollisionShape3D: cs = h
	cs.shape = compartida
	a.call("_refresh_visual")
	assert_almost_eq(compartida.size, Vector3(9.0, 9.0, 9.0), Vector3.ONE * 0.01,
		"la forma compartida queda intacta")
	assert_ne(cs.shape, compartida, "la corriente se quedó con una propia")
