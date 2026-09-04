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
	assert_between(p.alto_de_montura, 0.4, 0.9,
		"la altura del lomo del guanaco, en metros desde los pies")
	p.free()


func test_el_jinete_va_en_mitad_del_lomo() -> void:
	var p: CharacterBody3D = JUGADOR.new()
	assert_between(p.avance_de_montura, 0.0, 0.6,
		"cuánto se adelanta el guanaco para que no se lo monte en el cuello")
	p.free()
