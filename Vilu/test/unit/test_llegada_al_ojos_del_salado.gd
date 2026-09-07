extends GutTest

## El viaje rápido al Ojos del Salado deja al jugador junto al Guardián.
##
## EL FALLO. La escena no tenía `TravelSpawn`, y sin él `Game` cae al
## `PlayerSpawn`: viajar desde el mapa te dejaba al PIE del volcán, con todo el
## puzle por delante otra vez, en vez de arriba con el Guardián. El Isluga sí lo
## tenía; a éste se le había olvidado.
##
## El sitio NO se eligió a ojo. Ya pasó una vez con un checkpoint que quedó en el
## aire y hacía caer sin fin: acá se tiró un rayo hacia abajo por toda la cumbre
## y se puso el marcador donde hay roca, no donde parecía.

const ESCENA := preload("res://scenes/puzzles/OjosDelSalado.tscn")

## Metros de caída que se toleran al aparecer. Más que esto ya no es "aparecer
## sobre el suelo", es "aparecer cayendo".
const CAIDA_MAXIMA := 4.0


func _cumbre() -> Node3D:
	var e: Node3D = ESCENA.instantiate()
	add_child_autofree(e)
	return e


func test_la_cumbre_tiene_donde_llegar() -> void:
	var e := _cumbre()
	assert_not_null(e.find_child("TravelSpawn", true, false),
		"sin esto el viaje rápido te deja al pie del volcán")


func test_se_llega_junto_al_guardian() -> void:
	# De poco sirve el marcador si cae al otro lado de la cumbre.
	var e := _cumbre()
	var t := e.find_child("TravelSpawn", true, false) as Node3D
	var g := e.find_child("guardian_del_ojos_del_salado*", true, false) as Node3D
	assert_not_null(g, "el Guardián está en la escena")
	var d: float = t.global_position.distance_to(g.global_position)
	assert_lt(d, 12.0, "se aparece a la vista del Guardián (%.1f m)" % d)


func test_hay_roca_debajo() -> void:
	# LO QUE DE VERDAD IMPORTA. Un marcador en el aire es una caída infinita, y
	# eso ya pasó una vez en el Isluga.
	var e := _cumbre()
	await wait_physics_frames(3)
	var t := e.find_child("TravelSpawn", true, false) as Node3D
	var esp: PhysicsDirectSpaceState3D = e.get_world_3d().direct_space_state
	var desde: Vector3 = t.global_position
	var p := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 30.0)
	var h: Dictionary = esp.intersect_ray(p)
	assert_false(h.is_empty(), "hay suelo bajo el punto de llegada")
	if not h.is_empty():
		var caida: float = desde.y - (h["position"] as Vector3).y
		assert_lt(caida, CAIDA_MAXIMA,
			"se aparece encima del suelo, no cayendo (%.2f m)" % caida)


func test_esta_arriba_y_no_al_pie_del_volcan() -> void:
	# El PlayerSpawn es el principio del puzle, abajo. Si el TravelSpawn
	# estuviera a esa altura, no habría arreglado nada.
	var e := _cumbre()
	var t := e.find_child("TravelSpawn", true, false) as Node3D
	var p := e.find_child("PlayerSpawn", true, false) as Node3D
	assert_gt(t.global_position.y, p.global_position.y + 10.0,
		"llega arriba, no al principio del ascenso")
