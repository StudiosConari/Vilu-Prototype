extends GutTest

## Corrientes que arrastran hacia abajo.
##
## La ascendente es una AYUDA: pide alas y pide mantener el salto, o sea que hay
## que quererla. La descendente es una TRAMPA: agarra a quien entre, tenga alas
## o no, y no se sale planeando —una trampa de la que se sale planeando no es
## una trampa—.

const CORRIENTE := preload("res://scenes/actors/Updraft.gd")
const JUGADOR := preload("res://scenes/actors/PlayerController.gd")
const ROJO := preload("res://art_placeholders/mat_viento_descendente.tres")


class Munieco extends Node3D:
	var in_updraft := false
	var in_downdraft := false


func _corriente(abajo: bool) -> Area3D:
	var a := Area3D.new()
	a.set_script(CORRIENTE)
	var m := MeshInstance3D.new()
	m.name = "Mesh"
	m.mesh = BoxMesh.new()
	a.add_child(m)
	add_child_autofree(a)
	a.set("hacia_abajo", abajo)
	return a


func _munieco() -> Node3D:
	var b := Munieco.new()
	b.add_to_group("player")
	add_child_autofree(b)
	return b


func test_la_descendente_marca_su_bandera() -> void:
	var c := _corriente(true)
	var b := _munieco()
	c.call("_on_enter", b)
	assert_true(b.in_downdraft, "arrastra hacia abajo")
	assert_false(b.in_updraft, "y no eleva")


func test_la_ascendente_sigue_elevando() -> void:
	var c := _corriente(false)
	var b := _munieco()
	c.call("_on_enter", b)
	assert_true(b.in_updraft, "las de siempre no cambiaron")
	assert_false(b.in_downdraft, "y no arrastran")


func test_al_salir_se_apagan_las_dos() -> void:
	# Una corriente puede cambiar de sentido en el editor con alguien dentro, y
	# entonces quedaría encendida la bandera vieja para siempre.
	var c := _corriente(true)
	var b := _munieco()
	c.call("_on_enter", b)
	c.set("hacia_abajo", false)
	c.call("_on_exit", b)
	assert_false(b.in_downdraft, "no queda ninguna encendida")
	assert_false(b.in_updraft, "ninguna de las dos")


func test_la_descendente_se_pinta_de_rojo() -> void:
	# Una corriente que tira hacia abajo idéntica a una que eleva es una trampa
	# invisible: el jugador se mete creyendo que le conviene.
	var c := _corriente(true)
	var m: MeshInstance3D = c.get_node("Mesh")
	assert_eq(m.material_override, ROJO, "lleva el material rojo")


func test_arrastra_mucho_mas_rapido_de_lo_que_eleva() -> void:
	var p: Node = JUGADOR.new()
	assert_gt(float(p.get("downdraft_speed")), float(p.get("updraft_speed")) * 2.0,
		"a la velocidad de subida se saldría caminando")
	p.free()


func test_dentro_de_una_descendente_no_se_planea() -> void:
	# `_planeando` decide si salen las alas y si la gravedad se reduce. Dentro de
	# una descendente tiene que dar false o la trampa no atrapa.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/PlayerController.gd")
	assert_true(texto.contains("and not in_downdraft"),
		"el planeo se apaga dentro de una corriente descendente")


func test_la_descendente_manda_sobre_la_ascendente() -> void:
	# En el orden del código va primero: si fuera al revés, tener alas y
	# mantener el salto anularía la trampa.
	var texto := FileAccess.get_file_as_string("res://scenes/actors/PlayerController.gd")
	var i_abajo := texto.find("if in_downdraft:")
	var i_arriba := texto.find("elif active and in_updraft")
	assert_gt(i_abajo, 0, "está la rama de la descendente")
	assert_lt(i_abajo, i_arriba, "y se comprueba antes que la ascendente")


func test_las_rafagas_de_la_roja_bajan() -> void:
	# Una corriente que arrastra hacia abajo con las vetas subiendo dice lo
	# contrario de lo que hace.
	assert_lt(float(ROJO.get_shader_parameter("sentido")), 0.0, "las vetas van hacia abajo")
	var c: Color = ROJO.get_shader_parameter("color_abajo")
	assert_gt(c.r, c.b, "y el color tira a rojo, no a azul")
