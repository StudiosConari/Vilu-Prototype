extends GutTest

## «Derrota al Chupacabras» señala la mina mientras estés fuera de ella.
##
## El bicho vive en el fondo de la mina y se marca solo al aparecer —ya está en
## el grupo `objetivo_chupacabras`—, pero eso sólo sirve estando dentro. Fuera,
## en el poblado, la misión no señalaba nada y había que acordarse del camino.

const GUIA := preload("res://scenes/core/GuiaDeObjetivos.gd")


func test_la_ultima_mision_lleva_a_la_mina() -> void:
	assert_eq(String(GUIA.DESTINOS.get("chupacabras", "")), "Mina",
		"sin el bicho a la vista, se señala la puerta de la mina")


func test_las_dos_misiones_de_la_mina_llevan_al_mismo_sitio() -> void:
	# «Vuelve a la mina» y «Derrota al Chupacabras» son seguidas y las dos
	# terminan en el mismo socavón.
	assert_eq(GUIA.DESTINOS.get("volver_mina"), GUIA.DESTINOS.get("chupacabras"),
		"la misma puerta para las dos")


func test_ya_hecho_le_quita_el_marcador() -> void:
	# A PRUEBA DE OLVIDOS. Salirse del grupo lo hace cada tipo por su cuenta y
	# basta que a uno se le olvide para que su marcador se quede colgado. Pasó
	# con un cubo ya golpeado.
	var g: Node = GUIA.new()
	add_child_autofree(g)
	var hecho := _cosa_hecha(true)
	var pendiente := _cosa_hecha(false)
	add_child_autofree(hecho)
	add_child_autofree(pendiente)
	assert_true(g.call("_ya_esta_hecho", hecho), "el que dice que ya fue, no se marca")
	assert_false(g.call("_ya_esta_hecho", pendiente), "el que falta, sí")


func test_lo_que_no_sabe_responder_no_estorba() -> void:
	var g: Node = GUIA.new()
	add_child_autofree(g)
	var mudo := Node3D.new()
	add_child_autofree(mudo)
	assert_false(g.call("_ya_esta_hecho", mudo),
		"sin método de estado se confía en el grupo, como siempre")


class CosaHecha extends Node3D:
	var listo := false
	func esta_usado() -> bool:
		return listo


func _cosa_hecha(listo: bool) -> Node3D:
	var c := CosaHecha.new()
	c.listo = listo
	return c
