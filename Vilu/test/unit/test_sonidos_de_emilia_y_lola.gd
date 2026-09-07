extends GutTest

## La cadena de Emilia suena distinta en cada golpe, y Lola grita al salir.
##
## Antes el combo eran dos sonidos GENERADOS —"punch" los dos primeros golpes,
## "kick" los dos últimos— con el tono subiendo un 10% por paso para disimular
## la repetición. Sonaba a tartamudeo: lo que hay que oír es que la cadena
## avanza y que el cuarto es un remate.
##
## Y a Lola la anunciaba el rugido genérico de jefe, el mismo del Chupacabras.
## Está encerrada detrás de los tablones y no se la ve hasta que caen, así que
## el sonido es lo único que dice quién sale.

const JUGADOR := preload("res://scenes/actors/PlayerController.gd")
const SFX := preload("res://scenes/Sfx.gd")
const LOLA := preload("res://scenes/enemies/Lola.tscn")
const MINA := preload("res://scenes/regions/Mina.tscn")


func test_hay_un_sonido_por_eslabon_de_la_cadena() -> void:
	assert_eq(JUGADOR.SONIDO_DEL_GOLPE.size(), 4,
		"puño, cruzado, patada y remate")


func test_ningun_golpe_repite_el_sonido_del_anterior() -> void:
	# Es el punto de todo esto: con uno solo repetido, el combo no se oye
	# avanzar.
	var vistos := {}
	for s: String in JUGADOR.SONIDO_DEL_GOLPE:
		assert_false(vistos.has(s), "%s suena una sola vez en la cadena" % s)
		vistos[s] = true


func test_la_cadena_cubre_todos_los_golpes_declarados() -> void:
	# `melee_damage` es la que decide cuántos eslabones tiene el combo. Si
	# alguien le añade un quinto, esto avisa antes de que suene un índice fuera
	# de rango en pleno combate.
	var p: CharacterBody3D = JUGADOR.new()
	assert_eq(JUGADOR.SONIDO_DEL_GOLPE.size(), p.melee_damage.size(),
		"un sonido por cada golpe del combo")
	p.free()


func test_los_cinco_sonidos_estan_declarados() -> void:
	for s: String in JUGADOR.SONIDO_DEL_GOLPE:
		assert_true(SFX.GRABADOS.has(s), "%s registrado en Sfx" % s)
	assert_true(SFX.GRABADOS.has("grito_lola"), "el grito de Lola registrado")


func test_los_archivos_estan_en_el_proyecto() -> void:
	# Sfx aguanta que falte un archivo —se queda con el tono generado— así que
	# la ausencia no rompe nada y por eso no se nota. Acá sí.
	for id: String in SFX.GRABADOS:
		assert_true(ResourceLoader.exists(SFX.GRABADOS[id]),
			"%s: existe %s" % [id, SFX.GRABADOS[id]])


func test_lola_grita_con_su_propia_voz() -> void:
	var l: CharacterBody3D = LOLA.instantiate()
	assert_eq(l.sonido_al_despertar, "grito_lola",
		"no el rugido genérico de jefe")
	assert_true(l.dormido, "sigue encerrada hasta que caigan los tablones")
	l.free()


func test_el_grito_no_sale_acelerado() -> void:
	# El rugido generado se diseñó grave (0,7). Un grito grabado a 0,7 se
	# convierte en otra cosa.
	var l: CharacterBody3D = LOLA.instantiate()
	assert_almost_eq(l.tono_al_despertar, 1.0, 0.001, "tal cual se grabó")
	l.free()


func test_los_tablones_de_lola_la_despiertan() -> void:
	# El grito no sirve de nada si los tablones no avisan. Los dos apuntan a
	# ella y se arrastran entre sí: caigan por donde caigan, Lola se entera.
	var mina: Node3D = MINA.instantiate()
	var lola := mina.find_child("Lola", true, false)
	assert_not_null(lola, "Lola está en la mina")
	var cuantos := 0
	for n in _tablones_que_despiertan(mina, lola):
		cuantos += 1
	assert_eq(cuantos, 2, "los dos tablones de su lado la despiertan")
	mina.free()


func _tablones_que_despiertan(raiz: Node, quien: Node) -> Array:
	var r := []
	for n in raiz.find_children("*", "", true, false):
		if not ("despierta" in n):
			continue
		var ruta: NodePath = n.get("despierta")
		if ruta.is_empty():
			continue
		if n.get_node_or_null(ruta) == quien:
			r.append(n)
	return r
