extends GutTest

## Que no se reaparezca en el aire.
##
## El `CheckpointBifurcacion` del Ojos del Salado está a 110 m de altura con el
## suelo 23 m por debajo. Reaparecías ahí, caías a la lava, la lava te devolvía
## al mismo punto y vuelta a empezar: una caída infinita sin salida.
##
## Se comprueba en Game y no moviendo el marcador porque es una clase de fallo
## que se repite —un punto de reaparición mal puesto— y estos niveles se siguen
## editando a mano.

const JUEGO := preload("res://scenes/core/Game.gd")


func test_el_margen_es_una_caida_que_se_aguanta() -> void:
	assert_lte(JUEGO.SUELO_BAJO_EL_PUNTO_SEGURO, 6.0,
		"más que esto no es un sitio donde reaparecer, es uno desde donde caerse")
	assert_gte(JUEGO.SUELO_BAJO_EL_PUNTO_SEGURO, 2.0,
		"pero un escaloncito no puede invalidar un punto bueno")


func test_el_checkpoint_del_ojos_del_salado_pisa_suelo() -> void:
	# Este marcador dio una caída infinita: reaparecías ahí y no había dónde
	# apoyarse. Se movió a mano a suelo firme, sobre `plataforma_cubica_23`, que
	# NO es la plataforma móvil —ésa es "plataforma movil principal"—, así que el
	# suelo no se le va de debajo al reiniciarse el intento.
	#
	# OJO CON CÓMO SE MIDE. Con un script suelto (`-s`) daba 23 m de vacío, y era
	# mentira: ahí los autoloads no se resuelven, `CumbreCima.gd` no compila y el
	# nivel nunca construye sus plataformas. Hay que cargarlo como acá.
	var esc := load("res://scenes/puzzles/OjosDelSalado.tscn") as PackedScene
	var raiz := esc.instantiate()
	add_child_autofree(raiz)
	await wait_physics_frames(5)
	var marca := raiz.find_child("CheckpointBifurcacion", true, false) as Node3D
	assert_not_null(marca, "el checkpoint sigue existiendo")
	var esp: PhysicsDirectSpaceState3D = marca.get_world_3d().direct_space_state
	var p: Vector3 = marca.global_position
	var q := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP, p + Vector3.DOWN * JUEGO.SUELO_BAJO_EL_PUNTO_SEGURO)
	q.collision_mask = 1
	assert_false(esp.intersect_ray(q).is_empty(),
		"el checkpoint apoya en suelo firme")


func test_un_punto_con_suelo_se_respeta() -> void:
	# La red no puede estropear los puntos buenos, que son casi todos.
	# Fuera del árbol: su `_ready` carga el mundo entero. `_con_suelo_debajo`
	# saca el espacio físico del personaje, que sí está en el árbol.
	var g: Node3D = JUEGO.new()
	autofree(g)
	var suelo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(20.0, 1.0, 20.0)
	cs.shape = caja
	suelo.add_child(cs)
	add_child_autofree(suelo)
	suelo.global_position = Vector3(0.0, -0.5, 0.0)
	# Un personaje de mentira: `_con_suelo_debajo` sólo lo usa para el espacio
	# físico y para saber si está en el árbol.
	var quien := CharacterBody3D.new()
	add_child_autofree(quien)
	g.set("party", [quien])
	g.set("active_index", 0)
	await wait_physics_frames(3)
	var bueno := Vector3(0.0, 0.2, 0.0)
	assert_almost_eq(Vector3(g.call("_con_suelo_debajo", bueno)), bueno, Vector3.ONE * 0.01,
		"un punto con suelo debajo se deja tal cual")
