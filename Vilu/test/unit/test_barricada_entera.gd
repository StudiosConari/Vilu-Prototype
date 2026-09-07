extends GutTest

## Las barricadas de la mina caen enteras de un golpe.
##
## Están hechas de dos tablones apilados. Rompiéndolos de a uno no hay reto:
## sólo hay que golpear dos veces lo mismo, cuando el jugador ya entendió qué
## había que hacer con el primer golpe. Y si sólo cae el de abajo, el de arriba
## queda flotando en el aire.

const DESTRUCTIBLE := preload("res://scenes/actors/Destructible.gd")


## Un tablón con su malla y su cuerpo, como lo deja el importador de glTF.
func _tablon(nombre: String) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	var cuerpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cuerpo.add_child(cs)
	n.add_child(cuerpo)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	n.add_child(mi)
	n.set_script(DESTRUCTIBLE)
	n.set("golpes_necesarios", 1)
	return n


## Los dos tablones de una barricada, apuntándose el uno al otro.
func _barricada() -> Array:
	var padre := Node3D.new()
	add_child_autofree(padre)
	var abajo := _tablon("Abajo")
	var arriba := _tablon("Arriba")
	padre.add_child(abajo)
	padre.add_child(arriba)
	abajo.set("arrastra", [NodePath("../Arriba")] as Array[NodePath])
	arriba.set("arrastra", [NodePath("../Abajo")] as Array[NodePath])
	return [abajo, arriba]


func test_golpear_el_de_abajo_tira_los_dos() -> void:
	var b := _barricada()
	b[0].call("golpear", 10.0, Vector3.ZERO)
	assert_true(bool(b[0].call("esta_roto")), "cae el que recibió el golpe")
	assert_true(bool(b[1].call("esta_roto")), "y el de arriba se viene con él")


func test_tambien_al_reves() -> void:
	# Se puede acertar al de arriba primero; la barricada es una sola cosa.
	var b := _barricada()
	b[1].call("golpear", 10.0, Vector3.ZERO)
	assert_true(bool(b[0].call("esta_roto")), "cae el de abajo también")


func test_apuntarse_mutuamente_no_cuelga_el_juego() -> void:
	# Los dos se listan el uno al otro. Sin la guarda de `_roto` esto sería una
	# recursión infinita y el juego se quedaría clavado en el golpe.
	var b := _barricada()
	b[0].call("golpear", 10.0, Vector3.ZERO)
	assert_true(bool(b[1].call("esta_roto")), "la ida y vuelta se corta sola")


func test_un_destructible_suelto_sigue_solo() -> void:
	# Casi todos los destructibles del juego no arrastran a nadie: esto no puede
	# haberles cambiado nada.
	var suelto := _tablon("Suelto")
	add_child_autofree(suelto)
	suelto.call("golpear", 10.0, Vector3.ZERO)
	assert_true(bool(suelto.call("esta_roto")), "se rompe como siempre")


func test_la_mina_tiene_sus_dos_barricadas_atadas() -> void:
	# El guardián de la escena: son dos parejas —la del primer obelisco y la que
	# encierra a Lola—, o sea cuatro declaraciones.
	var texto := FileAccess.get_file_as_string("res://scenes/regions/Mina.tscn")
	assert_eq(texto.count("\narrastra = [NodePath("), 4,
		"las dos parejas de tablones están atadas en los dos sentidos")
