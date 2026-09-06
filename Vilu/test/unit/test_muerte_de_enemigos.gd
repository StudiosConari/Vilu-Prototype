extends GutTest

## La animación de caer.
##
## Lola y el Chupacabras la tienen declarada y el modelo la trae, y aun así no
## se veía nunca: como no hay clip de reposo, quieto se pausa el paso poniendo
## `speed_scale` en cero, y los bichos mueren casi siempre parados —pegándote de
## cerca—, así que la caída arrancaba congelada en su primer fotograma.

const LOLA := preload("res://scenes/enemies/Lola.tscn")
const CHUPA := preload("res://scenes/enemies/Chupacabras.tscn")


func _animador(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _animador(h)
		if x != null:
			return x
	return null


func _cae(escena: PackedScene, clip: String) -> void:
	var e: CharacterBody3D = escena.instantiate()
	add_child_autofree(e)
	await wait_frames(3)
	var ap := _animador(e)
	assert_not_null(ap, "el modelo trae su reproductor")
	if ap == null:
		return
	assert_true(ap.has_animation(clip), "y su clip de caer '%s'" % clip)

	# Quieto: es como se muere, y es cuando el paso está pausado.
	ap.speed_scale = 0.0
	e.call("_morir")
	await wait_frames(2)
	assert_eq(ap.assigned_animation, clip, "cae con su animación")
	assert_almost_eq(ap.speed_scale, 1.0, 0.01,
		"y a velocidad normal, no congelada en el primer fotograma")


func test_lola_cae_con_su_animacion() -> void:
	await _cae(LOLA, "Death_A")


func test_el_chupacabras_cae_con_la_suya() -> void:
	await _cae(CHUPA, "Death")
