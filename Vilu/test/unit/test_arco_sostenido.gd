extends GutTest

## Benjamín camina con el arco sostenido usando SUS animaciones.
##
## Antes esto lo apañaba un modificador de esqueleto: sonaba el caminar de
## siempre y se le reescribía encima la rotación de los huesos del pecho para
## arriba. Funcionaba a medias y se notaba —una pose congelada pegada sobre otra
## animación—. Ahora hay cuatro clips hechos, uno por dirección, con el brazo
## atrás y las piernas andando. El modificador se queda de respaldo.
##
## Son CUATRO y no uno porque apuntando el personaje encara a donde apunta y no
## a donde va: se camina de lado y de espaldas todo el rato.

const ANIMADOR := preload("res://scenes/actors/AnimadorPersonaje.gd")
const BENJAMIN := preload("res://models/personaje/benjamin.glb")
const SOSTENIDO := preload("res://models/personaje/benjamin_arco_sostenido.glb")


func test_el_glb_trae_las_cuatro_direcciones() -> void:
	var e := SOSTENIDO.instantiate()
	var ap: AnimationPlayer = e.find_children("*", "AnimationPlayer", true, false)[0]
	for n: String in ANIMADOR.CLIPS_DE_ARCO:
		assert_true(ap.has_animation(n), "el .glb trae %s" % n)
	e.free()


func test_las_pistas_apuntan_al_mismo_rig_que_benjamin() -> void:
	# De esto depende que los clips se puedan injertar tal cual. Si el rig
	# cambiara, los clips no se verían — y esto lo dice antes que el juego.
	var suyas := _rutas(BENJAMIN, "caminar")
	var nuevas := _rutas(SOSTENIDO, "mantener_adelante")
	assert_gt(nuevas.size(), 0, "el clip nuevo tiene pistas")
	for r: String in nuevas:
		assert_true(suyas.has(r), "%s existe también en el rig de Benjamín" % r)


func _rutas(escena: PackedScene, clip: String) -> Array:
	var e := escena.instantiate()
	var ap: AnimationPlayer = e.find_children("*", "AnimationPlayer", true, false)[0]
	var a := ap.get_animation(clip)
	var r := []
	for i in a.get_track_count():
		r.append(String(a.track_get_path(i)))
	e.free()
	return r


# ─── la elección de dirección ─────────────────────────────────────────────────

## Un animador montado sobre el modelo de Benjamín, dentro de un Visual que se
## puede girar como lo gira el juego al apuntar.
func _montado(giro_del_visual: float) -> Node3D:
	var visual := Node3D.new()
	visual.rotation.y = giro_del_visual
	add_child_autofree(visual)
	var an: Node3D = ANIMADOR.new()
	visual.add_child(an)
	an.call("montar", _jugador(), BENJAMIN, 2.2)
	return an


func _jugador() -> CharacterBody3D:
	var j := CharacterBody3D.new()
	add_child_autofree(j)
	return j


func _clip_yendo(an: Node3D, velocidad: Vector3) -> String:
	(an.get("_jugador") as CharacterBody3D).velocity = velocidad
	return an.call("_clip_de_arco_sostenido")


func test_los_clips_quedan_en_la_libreria_de_benjamin() -> void:
	# El injerto: si no llegan a su AnimationPlayer, no hay nada que reproducir.
	var an := _montado(0.0)
	var ap: AnimationPlayer = an.get("_anim")
	for n: String in ANIMADOR.CLIPS_DE_ARCO:
		assert_true(ap.has_animation(n), "%s injertado en Benjamín" % n)


func test_los_clips_injertados_se_repiten() -> void:
	# Sin bucle, dar tres pasos deja al personaje clavado al terminar el clip.
	var an := _montado(0.0)
	var ap: AnimationPlayer = an.get("_anim")
	for n: String in ANIMADOR.CLIPS_DE_ARCO:
		assert_eq(ap.get_animation(n).loop_mode, Animation.LOOP_LINEAR,
			"%s se repite" % n)


func test_mirando_al_frente_cada_rumbo_elige_su_clip() -> void:
	# Con el visual sin girar, el personaje mira a -Z y su derecha es +X.
	var an := _montado(0.0)
	assert_eq(_clip_yendo(an, Vector3(0, 0, -4)), ANIMADOR.MANTENER_ADELANTE,
		"hacia donde mira: adelante")
	assert_eq(_clip_yendo(an, Vector3(0, 0, 4)), ANIMADOR.MANTENER_ATRAS,
		"de espaldas: atrás")
	assert_eq(_clip_yendo(an, Vector3(4, 0, 0)), ANIMADOR.MANTENER_DERECHA,
		"a su derecha")
	assert_eq(_clip_yendo(an, Vector3(-4, 0, 0)), ANIMADOR.MANTENER_IZQUIERDA,
		"a su izquierda")


func test_la_direccion_es_relativa_a_donde_mira() -> void:
	# ESTE es el punto de tener cuatro clips. Girado media vuelta, moverse hacia
	# -Z del mundo es andar DE ESPALDAS, no de frente.
	var an := _montado(PI)
	assert_eq(_clip_yendo(an, Vector3(0, 0, -4)), ANIMADOR.MANTENER_ATRAS,
		"mirando al revés, ir hacia -Z es caminar de espaldas")
	assert_eq(_clip_yendo(an, Vector3(0, 0, 4)), ANIMADOR.MANTENER_ADELANTE,
		"y hacia +Z es ir de frente")


func test_girado_un_cuarto_el_costado_pasa_a_ser_el_frente() -> void:
	var an := _montado(PI * 0.5)
	assert_eq(_clip_yendo(an, Vector3(-4, 0, 0)), ANIMADOR.MANTENER_ADELANTE,
		"mirando a -X, ir a -X es ir de frente")


func test_quieto_no_pide_ningun_clip() -> void:
	var an := _montado(0.0)
	assert_eq(_clip_yendo(an, Vector3.ZERO), "",
		"parado manda el clip de apuntar entero")


func test_caer_no_cuenta_como_caminar() -> void:
	# Sólo el plano. Si no, caer apuntando pediría un clip de andar.
	var an := _montado(0.0)
	assert_eq(_clip_yendo(an, Vector3(0, -9, 0)), "",
		"caer no es un rumbo")


func test_al_caminar_apuntando_manda_el_clip_y_no_el_modificador() -> void:
	# El modificador reescribe el tren superior. Encima de un clip que YA trae
	# el arco sostenido, eso sería pisar la animación buena con una pose
	# congelada.
	var an := _montado(0.0)
	(an.get("_jugador") as CharacterBody3D).velocity = Vector3(0, 0, -4)
	an.call("tensar")
	an.call("_caminar_apuntando")
	var ap: AnimationPlayer = an.get("_anim")
	assert_eq(String(ap.assigned_animation), ANIMADOR.MANTENER_ADELANTE,
		"suena el clip propio")
	var m = an.get("_pose_de_arco")
	if m != null:
		assert_false(m.activo, "el modificador se aparta")
