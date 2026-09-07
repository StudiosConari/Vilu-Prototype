extends GutTest

## La pose que se guarda es la del arco TENSADO DEL TODO.
##
## EL FALLO. `_caminar_apuntando()` copiaba la pose de donde estuviera el clip en
## ese instante. Quien echa a andar en el mismo momento en que empieza a tensar
## tiene el clip a medio recorrer —el brazo todavía subiendo— y ésa era la pose
## que quedaba guardada. Peor: en cuanto se empieza a caminar, `_vigilar_tension`
## deja de avanzar el clip, así que nunca llegaba a la extensión buena. Benjamín
## caminaba el resto del rato con el arco a medio levantar.
##
## Ahora el clip se fuerza a su fotograma de máxima extensión y se aplica al
## esqueleto ANTES de leerlo.

const ANIMADOR := preload("res://scenes/actors/AnimadorPersonaje.gd")

## Dónde queda el arco tensado del todo, en segundos del clip.
const TENSION := 1.0

## La rotación del brazo en esa extensión. Es la que tiene que sobrevivir.
const TENSADO := Vector3(0.0, 0.0, -1.2)

var _brazo := 0


## Un muñeco mínimo: esqueleto de Mixamo, AnimationPlayer con los clips que
## toca, y el animador colgando de la misma raíz.
func _muneco() -> Node3D:
	var raiz := Node3D.new()
	var esq := Skeleton3D.new()
	esq.name = "Skeleton3D"
	for nombre: String in ["mixamorig_Hips", "mixamorig_Spine"] + ANIMADOR.POSE_DE_ARCO.TREN_SUPERIOR:
		esq.add_bone(nombre)
	raiz.add_child(esq)
	_brazo = esq.find_bone("mixamorig_RightArm")

	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	lib.add_animation("flecha_cargada", _clip_de_tensar(esq))
	# Los de andar: el animador elige uno en cuanto detecta movimiento.
	for n: String in ["reposo", "caminar", "correr"]:
		lib.add_animation(n, _clip_de_andar(esq))
	ap.add_animation_library("", lib)
	raiz.add_child(ap)

	var an: Node3D = ANIMADOR.new()
	raiz.add_child(an)
	add_child_autofree(raiz)
	an.set("_anim", ap)
	an.set("_jugador", _jugador_que_camina())
	an.set("_tension", TENSION)
	return an


## Lo asienta en el suelo y lo deja andando.
func _asentar(an: Node3D) -> void:
	var j: CharacterBody3D = an.get("_jugador")
	for i in 6:
		j.velocity = Vector3(3.0, -4.0, 0.0)
		j.move_and_slide()
		await wait_physics_frames(1)
	j.velocity = Vector3(3.0, 0.0, 0.0)
	assert_true(j.is_on_floor(), "el muñeco pisa suelo antes de empezar")


## El clip de tensar: el brazo sube de reposo a la extensión máxima en 1 s y se
## queda ahí. Es el punto: en t=0 la pose NO sirve.
func _clip_de_tensar(esq: Skeleton3D) -> Animation:
	var a := Animation.new()
	a.length = 1.4
	var p := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(p, NodePath("Skeleton3D:mixamorig_RightArm"))
	a.rotation_track_insert_key(p, 0.0, Quaternion.IDENTITY)
	a.rotation_track_insert_key(p, TENSION, Quaternion.from_euler(TENSADO))
	a.rotation_track_insert_key(p, 1.4, Quaternion.from_euler(TENSADO))
	return a


func _clip_de_andar(esq: Skeleton3D) -> Animation:
	var a := Animation.new()
	a.length = 0.8
	a.loop_mode = Animation.LOOP_LINEAR
	var p := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(p, NodePath("Skeleton3D:mixamorig_Hips"))
	a.rotation_track_insert_key(p, 0.0, Quaternion.IDENTITY)
	a.rotation_track_insert_key(p, 0.4, Quaternion(Vector3.RIGHT, 0.4))
	return a


## Un jugador andando POR EL SUELO, con suelo de verdad debajo.
##
## Lo de pisar suelo importa y no se puede fingir: `is_on_floor()` es del motor
## y no se deja sobrescribir, y el animador no elige clip de movimiento en el
## aire —ahí manda el salto—. Así que se le pone una losa y se le deja caer
## encima.
func _jugador_que_camina() -> CharacterBody3D:
	var suelo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(20.0, 1.0, 20.0)
	cs.shape = caja
	suelo.add_child(cs)
	suelo.position = Vector3(0.0, -1.0, 0.0)
	add_child_autofree(suelo)

	var j := CharacterBody3D.new()
	var jc := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	jc.shape = cap
	j.add_child(jc)
	j.position = Vector3(0.0, 0.4, 0.0)
	add_child_autofree(j)
	return j


func test_guarda_el_arco_tensado_aunque_el_clip_este_a_medias() -> void:
	# ESTE es el fallo. Se empieza a tensar y se echa a andar en el acto: el
	# clip está en 0, con el brazo todavía en reposo.
	var an := _muneco()
	await _asentar(an)
	an.call("tensar")
	an.get("_anim").seek(0.0, true)
	an.call("_caminar_apuntando")
	var pose: Dictionary = an.get("_pose_de_arco").poses
	assert_false(pose.is_empty(), "guardó algo")
	var guardada: Quaternion = pose[_brazo]
	assert_almost_eq(guardada.angle_to(Quaternion.from_euler(TENSADO)), 0.0, 0.05,
		"la pose guardada es la del arco tensado, no la del brazo a medio subir")


func test_no_guarda_el_brazo_en_reposo() -> void:
	# El mismo caso, dicho al revés: si guardara lo que había, sería la
	# identidad — el brazo colgando— y eso es exactamente lo que se veía.
	var an := _muneco()
	await _asentar(an)
	an.call("tensar")
	an.get("_anim").seek(0.0, true)
	an.call("_caminar_apuntando")
	var guardada: Quaternion = an.get("_pose_de_arco").poses[_brazo]
	assert_gt(guardada.angle_to(Quaternion.IDENTITY), 0.5,
		"no es el brazo colgando")


func test_al_andar_apuntando_suena_el_clip_de_andar() -> void:
	# La otra mitad: las piernas tienen que caminar. Si siguiera sonando el clip
	# de tensar, Benjamín se deslizaría con los pies clavados.
	var an := _muneco()
	await _asentar(an)
	an.call("tensar")
	an.call("_caminar_apuntando")
	var ap: AnimationPlayer = an.get("_anim")
	assert_ne(String(ap.assigned_animation), "flecha_cargada",
		"manda un clip de movimiento")
	assert_true(an.get("_pose_de_arco").activo,
		"y el arco lo sujeta el modificador")


func test_al_frenar_vuelve_el_clip_de_tensar() -> void:
	var an := _muneco()
	await _asentar(an)
	an.call("tensar")
	an.call("_caminar_apuntando")
	an.call("_apuntar_quieto")
	var ap: AnimationPlayer = an.get("_anim")
	assert_eq(String(ap.assigned_animation), "flecha_cargada",
		"parado vuelve a mandar el clip entero")
	assert_false(an.get("_pose_de_arco").activo,
		"y el modificador se aparta")
