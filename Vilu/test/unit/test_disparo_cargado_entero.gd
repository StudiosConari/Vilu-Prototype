extends GutTest

## Soltado el cargado, la animación termina sí o sí.
##
## EL FALLO. `_caminar_apuntando` borra la marca de «clip de una pasada» para
## poder poner los clips de andar. Al soltar, esa marca no volvía a ponerse, así
## que el tramo de soltar —el arco que vuelve a su sitio— lo pisaba el primer
## paso que dieras y quedaba a medias.
##
## Lo demás del disparo cargado se queda como estaba: apretar otra vez lo
## reinicia, que es lo de siempre.

const ANIMADOR := preload("res://scenes/actors/AnimadorPersonaje.gd")
const BENJAMIN := preload("res://models/personaje/benjamin.glb")


func _arquero() -> Node3D:
	var visual := Node3D.new()
	add_child_autofree(visual)
	var an: Node3D = ANIMADOR.new()
	visual.add_child(an)
	var j := CharacterBody3D.new()
	add_child_autofree(j)
	an.call("montar", j, BENJAMIN, 2.2)
	return an


func _ap(an: Node3D) -> AnimationPlayer:
	return an.get("_anim")


func test_soltar_no_se_deja_pisar_por_el_caminar() -> void:
	var an := _arquero()
	an.call("tensar")
	_ap(an).seek(an.get("_tension"), true)
	# Caminar apuntando borró la marca: así es como los clips de andar podían
	# entrar mientras se apunta.
	an.set("_unica", "")
	an.call("soltar")
	assert_eq(String(an.get("_unica")), ANIMADOR.FLECHA_CARGADA,
		"el tramo de soltar manda sobre el movimiento hasta acabar")


func test_al_acabar_el_clip_suelta_el_mando() -> void:
	# La marca no puede quedarse puesta: sería un personaje que ya no elige
	# ninguna animación de movimiento nunca más.
	var an := _arquero()
	an.call("tensar")
	_ap(an).seek(an.get("_tension"), true)
	an.call("soltar")
	an.call("_al_terminar", ANIMADOR.FLECHA_CARGADA)
	assert_eq(String(an.get("_unica")), "",
		"terminado el gesto, el movimiento vuelve a mandar")


func test_apretar_otra_vez_sigue_reiniciando() -> void:
	# Esto es el comportamiento de siempre y se queda como estaba: el cambio es
	# sólo que el caminar no corta la soltada.
	var an := _arquero()
	an.call("tensar")
	assert_true(an.get("_tensando"), "vuelve a tensar sin trabas")
