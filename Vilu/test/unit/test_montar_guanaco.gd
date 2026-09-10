extends GutTest

## Ir montado en el guanaco: la pose se mantiene y el jinete va sobre el lomo.

const ANIMADOR := preload("res://scenes/actors/AnimadorPersonaje.gd")
const JUGADOR := preload("res://scenes/actors/PlayerController.gd")


## Un AnimationPlayer con los clips que le importan a esta prueba.
func _reproductor() -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	for n in [ANIMADOR.REPOSO, ANIMADOR.CAMINAR, ANIMADOR.CORRER,
			ANIMADOR.MONTADO, ANIMADOR.SALTO_QUIETO, ANIMADOR.SALTO_MOVIENDO]:
		var a := Animation.new()
		a.length = 0.5
		lib.add_animation(n, a)
	ap.add_animation_library("", lib)
	return ap


## El animador, sin cargar el modelo: sólo interesa qué clip elige.
func _animador() -> Node3D:
	var n := Node3D.new()
	n.set_script(ANIMADOR)
	add_child_autofree(n)
	var ap := _reproductor()
	n.add_child(ap)
	n.set("_anim", ap)
	var cuerpo := CharacterBody3D.new()
	add_child_autofree(cuerpo)
	n.set("_jugador", cuerpo)
	return n


func test_al_montar_se_queda_en_la_pose() -> void:
	var a := _animador()
	a.call("montado", true)
	var ap: AnimationPlayer = a.get("_anim")
	assert_eq(ap.assigned_animation, ANIMADOR.MONTADO)
	assert_true(a.get("_montado"))


func test_saltar_montado_no_cambia_la_pose() -> void:
	var a := _animador()
	a.call("montado", true)
	a.call("saltar", false, 0.7)
	var ap: AnimationPlayer = a.get("_anim")
	assert_eq(ap.assigned_animation, ANIMADOR.MONTADO,
		"el que salta es el guanaco; el jinete sigue sentado")


func test_si_algo_pisa_la_pose_vuelve_sola() -> void:
	var a := _animador()
	a.call("montado", true)
	var ap: AnimationPlayer = a.get("_anim")
	# Algo lanza un clip por su cuenta —así se quedaba DE PIE sobre el lomo—.
	ap.play(ANIMADOR.REPOSO)
	a.call("_process", 0.016)
	assert_eq(ap.assigned_animation, ANIMADOR.MONTADO, "se recupera sola")


func test_al_desmontar_vuelve_a_moverse() -> void:
	var a := _animador()
	a.call("montado", true)
	a.call("montado", false)
	assert_false(a.get("_montado"))
	a.call("_process", 0.016)
	var ap: AnimationPlayer = a.get("_anim")
	assert_eq(ap.assigned_animation, ANIMADOR.REPOSO,
		"y no se queda congelado en la pose de jinete")


func test_el_jinete_va_a_la_altura_del_lomo() -> void:
	var p: CharacterBody3D = JUGADOR.new()
	# El respaldo, para cuando no hay malla ni esqueleto de dónde medir. Con el
	# modelo actual el lomo está a 1,03 m y la cadera sentada a 0,74 sobre el
	# origen: la diferencia ronda 0,3-0,4. El 0,64 de antes era del guanaco viejo.
	assert_between(p.alto_de_montura, 0.25, 0.6,
		"lomo menos cadera sentada, en metros")
	p.free()


## El lomo se MIDE del modelo. Sin malla —así se monta acá— se estima, y la
## estimación tiene que caer donde cae el modelo real, que es a poco más de la
## mitad de la altura del animal.
func test_el_lomo_se_mide_del_guanaco() -> void:
	var g := Node3D.new()
	g.set_script(preload("res://scenes/actors/GuanacoCompanion.gd"))
	add_child_autofree(g)
	g.set("_ready_done", true)
	var lomo: float = g.call("altura_del_lomo")
	assert_between(lomo, 1.4, 1.8, "con el guanaco de 2,94 m el lomo ronda 1,55 m")


## Con el guanaco delante, el jinete se sienta a la altura del lomo menos su
## cadera, y no a un número fijo.
func test_sentado_se_calcula_del_lomo_y_la_cadera() -> void:
	var p: CharacterBody3D = JUGADOR.new()
	# Sin guanaco: el respaldo.
	assert_almost_eq(p.call("_alto_para_sentarse"), p.alto_de_montura, 0.001)
	p.free()


func test_el_jinete_va_en_mitad_del_lomo() -> void:
	var p: CharacterBody3D = JUGADOR.new()
	assert_between(p.avance_de_montura, 0.0, 0.6,
		"cuánto se adelanta el guanaco para que no se lo monte en el cuello")
	p.free()


## Las piernas se cierran sobre la pose del clip: el jinete venía con las
## rodillas a 80 cm una de otra, abiertas para un caballo, y sobre el guanaco
## quedaban colgando lejos del lomo.
func _con_modelo() -> Array:
	var cuerpo := CharacterBody3D.new()
	add_child_autofree(cuerpo)
	var a := Node3D.new()
	a.set_script(ANIMADOR)
	cuerpo.add_child(a)
	a.call("montar", cuerpo, load("res://models/personaje/benjamin.glb"), 2.2)
	var esq: Skeleton3D = a.call("_buscar_esqueleto", a)
	return [a, esq]


func _rodillas(esq: Skeleton3D) -> float:
	var i := esq.find_bone("mixamorig_LeftLeg")
	var d := esq.find_bone("mixamorig_RightLeg")
	return esq.get_bone_global_pose(i).origin.distance_to(esq.get_bone_global_pose(d).origin)


func test_montado_cierra_las_piernas() -> void:
	var par := _con_modelo()
	var a: Node3D = par[0]
	var esq: Skeleton3D = par[1]
	assert_not_null(esq, "el modelo trae esqueleto")
	a.set("cierre_de_piernas", 0.0)
	a.call("montado", true)
	var abiertas := _rodillas(esq)
	a.set("cierre_de_piernas", 12.0)
	a.call("montado", false)
	a.call("montado", true)
	var cerradas := _rodillas(esq)
	# En el espacio del esqueleto, sin la escala del personaje (×2,2): 7 cm acá
	# son 16 en el mundo.
	assert_lt(cerradas, abiertas - 0.05,
		"con 12° las rodillas se juntan (%.2f -> %.2f)" % [abiertas, cerradas])
	# Y se mantiene cuadro a cuadro sin acumularse.
	a.call("_process", 0.016)
	a.call("_process", 0.016)
	assert_almost_eq(_rodillas(esq), cerradas, 0.005, "no se sigue cerrando sola")


## Hablar desmonta: el guanaco se queda invocado al lado y, al cerrar el globo,
## Benjamín vuelve a subirse solo.
class GuanacoFalso extends Node3D:
	var montado := false

	func set_mounted(v: bool) -> void:
		montado = v


func _benjamin_en_el_arbol() -> CharacterBody3D:
	var p: CharacterBody3D = load("res://scenes/actors/Player.tscn").instantiate()
	p.is_archer = true
	add_child_autofree(p)
	return p


func test_al_hablar_se_baja_y_al_terminar_vuelve_a_subir() -> void:
	var p := _benjamin_en_el_arbol()
	var g := GuanacoFalso.new()
	g.add_to_group("guanaco_companion")
	add_child_autofree(g)
	p.mounted = true
	g.montado = true

	p.call("_bajarse_para_hablar")
	assert_false(p.mounted, "habla de pie")
	assert_false(g.montado, "y el guanaco deja de llevarlo")
	assert_true(is_instance_valid(g) and g.is_inside_tree(), "pero no se va: espera al lado")

	p.call("_volver_a_subirse")
	assert_true(p.mounted, "al terminar vuelve a montarlo")
	assert_true(g.montado)


func test_si_no_iba_montado_hablar_no_lo_sube() -> void:
	var p := _benjamin_en_el_arbol()
	var g := GuanacoFalso.new()
	g.add_to_group("guanaco_companion")
	add_child_autofree(g)
	p.call("_bajarse_para_hablar")
	p.call("_volver_a_subirse")
	assert_false(p.mounted, "iba a pie y sigue a pie")

