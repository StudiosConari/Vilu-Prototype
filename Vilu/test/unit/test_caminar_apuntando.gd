extends GutTest

## Benjamín camina con el arco tensado.
##
## Antes, tensar congelaba el clip en la máxima extensión y mientras durase no se
## elegía clip de movimiento: apuntaba bien, pero al andar se deslizaba con los
## pies clavados. Ahora las piernas caminan y el arco lo sujeta el tren superior,
## reescribiendo la rotación de los huesos del pecho para arriba.

const POSE_DE_ARCO := preload("res://scenes/actors/PoseDeArco.gd")


## Un esqueleto con los huesos de Mixamo que le interesan a la pose.
func _esqueleto() -> Skeleton3D:
	var esq := Skeleton3D.new()
	add_child_autofree(esq)
	# La cadena entera, para que los padres existan antes que los hijos.
	for nombre: String in ["mixamorig_Hips", "mixamorig_Spine"] + POSE_DE_ARCO.TREN_SUPERIOR:
		esq.add_bone(nombre)
	return esq


func _modificador(esq: Skeleton3D) -> SkeletonModifier3D:
	var m: SkeletonModifier3D = POSE_DE_ARCO.new()
	esq.add_child(m)
	return m


func test_captura_la_pose_de_todo_el_tren_superior() -> void:
	var esq := _esqueleto()
	var m := _modificador(esq)
	m.call("capturar")
	assert_eq(m.poses.size(), POSE_DE_ARCO.TREN_SUPERIOR.size(),
		"guarda los huesos del pecho para arriba")


func test_la_pose_manda_sobre_la_caminata() -> void:
	var esq := _esqueleto()
	var m := _modificador(esq)
	var brazo := esq.find_bone("mixamorig_RightArm")
	# Se apunta: ésa es la pose que hay que conservar.
	var apuntando := Quaternion(Vector3.UP, 1.0)
	esq.set_bone_pose_rotation(brazo, apuntando)
	m.call("capturar")
	m.activo = true
	m._peso = 1.0
	# Y ahora el clip de caminar mueve el brazo a otro lado.
	esq.set_bone_pose_rotation(brazo, Quaternion.IDENTITY)
	m.call("_process_modification")
	assert_almost_eq(esq.get_bone_pose_rotation(brazo).angle_to(apuntando), 0.0, 0.01,
		"el brazo vuelve a la pose de apuntar")


func test_las_piernas_no_se_tocan() -> void:
	# De cintura para abajo manda el caminar entero: es lo que hace que ande en
	# vez de deslizarse.
	var esq := _esqueleto()
	var m := _modificador(esq)
	m.call("capturar")
	m.activo = true
	m._peso = 1.0
	var cadera := esq.find_bone("mixamorig_Hips")
	var paso := Quaternion(Vector3.RIGHT, 0.5)
	esq.set_bone_pose_rotation(cadera, paso)
	m.call("_process_modification")
	assert_almost_eq(esq.get_bone_pose_rotation(cadera).angle_to(paso), 0.0, 0.001,
		"la cadera sigue siendo la del paso")


func test_apagado_no_toca_nada() -> void:
	var esq := _esqueleto()
	var m := _modificador(esq)
	var brazo := esq.find_bone("mixamorig_RightArm")
	esq.set_bone_pose_rotation(brazo, Quaternion(Vector3.UP, 1.0))
	m.call("capturar")
	m.activo = false
	m._peso = 0.0
	var caminando := Quaternion(Vector3.RIGHT, 0.3)
	esq.set_bone_pose_rotation(brazo, caminando)
	m.call("_process_modification")
	assert_almost_eq(esq.get_bone_pose_rotation(brazo).angle_to(caminando), 0.0, 0.001,
		"sin apuntar, el brazo es el del caminar")


func test_entra_y_sale_con_mezcla() -> void:
	# Sin mezcla, empezar a tensar caminando da un tirón de brazos de un cuadro
	# para otro.
	var esq := _esqueleto()
	var m := _modificador(esq)
	m.call("capturar")
	m.activo = true
	m._peso = 0.0
	m.call("_process", 0.05)
	assert_gt(m._peso, 0.0, "entra progresivamente")
	assert_lt(m._peso, 1.0, "y no de golpe")


func test_el_tren_superior_arranca_en_la_segunda_vertebra() -> void:
	# Dejándole la primera al caminar, el torso sigue balanceándose con el paso
	# y la mezcla no se ve como un muñeco partido en dos.
	assert_false(POSE_DE_ARCO.TREN_SUPERIOR.has("mixamorig_Spine"),
		"la primera vértebra la mueve el paso")
	assert_true(POSE_DE_ARCO.TREN_SUPERIOR.has("mixamorig_Spine1"),
		"y de la segunda para arriba manda el arco")
	for lado: String in ["Left", "Right"]:
		assert_true(POSE_DE_ARCO.TREN_SUPERIOR.has("mixamorig_%sHand" % lado),
			"las dos manos sujetan el arco")


func test_el_motor_llama_al_modificador() -> void:
	# EL FALLO QUE NINGÚN TEST VEÍA. Godot 4.7 invoca cada cuadro
	# `_process_modification_with_delta(delta)`, no `_process_modification()`.
	# Implementando sólo la segunda, el modificador no corría NUNCA: sin error,
	# sin aviso, simplemente no pasaba nada. En pantalla, Benjamín bajaba el arco
	# al empezar a andar.
	#
	# Los demás tests pasaban porque llamaban al método A MANO. Éste comprueba lo
	# único que importa: que la pose llegue al esqueleto sin que nadie empuje.
	var esq := _esqueleto()
	var m := _modificador(esq)
	m.set_meta("llamadas", 0)
	# Se cuenta cuántas veces entra por sí solo, sin que nadie la llame.
	var antes: int = m.get_meta("llamadas")
	await wait_frames(6)
	assert_gt(int(m.get_meta("llamadas")), antes,
		"el motor entra en el modificador cada cuadro")
