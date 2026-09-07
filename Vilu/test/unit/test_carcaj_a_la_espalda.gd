extends GutTest

## El carcaj cruza la espalda con la BOCA arriba, junto al hombro derecho.
##
## EL FALLO. Salía justo al revés: el fondo asomando por el hombro y la boca
## apuntando a la cadera, o sea las flechas cabeza abajo. El código orientaba el
## +Z de la pieza hacia arriba dando por hecho que ése era el lado abierto, y en
## este modelo la boca está en el -Z.
##
## Se comprueba contra la GEOMETRÍA, no contra el número de grados: cuál de los
## dos extremos es la boca lo dice la malla, y hacia dónde acaba mirando se mide
## sobre el personaje montado. Así el test sigue valiendo si mañana cambia el
## modelo o la forma de colgarlo.

const ARMA := preload("res://scenes/actors/ArmaDeBenjamin.gd")
const ANIMADOR := preload("res://scenes/actors/AnimadorPersonaje.gd")
const BENJAMIN := preload("res://models/personaje/benjamin.glb")


var _visual: Node3D = null


## Benjamín de pie mirando a -Z, con el arma puesta. Devuelve el carcaj.
func _carcaj() -> Node3D:
	_visual = Node3D.new()
	add_child_autofree(_visual)
	var an: Node3D = ANIMADOR.new()
	_visual.add_child(an)
	var j := CharacterBody3D.new()
	add_child_autofree(j)
	an.call("montar", j, BENJAMIN, 2.2)
	var esqs := an.find_children("*", "Skeleton3D", true, false)
	assert_gt(esqs.size(), 0, "el modelo trae esqueleto")
	var arma: Node3D = ARMA.new()
	_visual.add_child(arma)
	arma.call("montar", esqs[0], _visual, an.get("_anim"))
	return arma.get("_carcaj")


## Hacia dónde mira la BOCA del carcaj, en el mundo.
##
## La boca es el extremo de la malla que está ABIERTO. En este modelo es el del
## -Z: se marcaron los dos extremos con una bola de color y se miró de espaldas.
func _hacia_donde_mira_la_boca(car: Node3D) -> Vector3:
	return (-car.global_transform.basis.z).normalized()


func test_el_eje_largo_del_carcaj_es_su_z() -> void:
	# De esto depende todo lo demás: si el eje largo fuera otro, orientar el Z no
	# querría decir nada.
	var m := (load("res://models/personaje/benjamin_arma.glb") as PackedScene).instantiate()
	var c := m.get_node_or_null("carcaj") as MeshInstance3D
	assert_not_null(c, "el .glb trae la pieza")
	var t: Vector3 = c.mesh.get_aabb().size
	assert_gt(t.z, t.x, "el Z es más largo que el X")
	assert_gt(t.z, t.y, "y que el Y")
	m.free()


func test_la_boca_apunta_hacia_arriba() -> void:
	# Lo primero que se ve mal: las flechas cabeza abajo.
	var car := _carcaj()
	assert_not_null(car, "el carcaj se cuelga")
	var arriba: float = _hacia_donde_mira_la_boca(car).dot(Vector3.UP)
	assert_gt(arriba, 0.5, "la boca mira claramente hacia arriba (%.2f)" % arriba)


func test_la_boca_asoma_por_el_hombro_derecho() -> void:
	# El derecho es el que tira de la cuerda, y por tanto el que saca flechas.
	# Benjamín mira a -Z, así que su derecha es +X.
	var car := _carcaj()
	var derecha: float = _hacia_donde_mira_la_boca(car).dot(Vector3.RIGHT)
	assert_gt(derecha, 0.2, "la boca cae del lado derecho (%.2f)" % derecha)


func test_el_fondo_queda_junto_a_la_cadera_izquierda() -> void:
	# Dicho al revés, que es como se veía el fallo: el culo del carcaj no puede
	# ser lo que asoma por encima del hombro.
	var car := _carcaj()
	var fondo: Vector3 = car.global_transform.basis.z.normalized()
	assert_lt(fondo.dot(Vector3.UP), -0.5, "el fondo baja")
	assert_lt(fondo.dot(Vector3.RIGHT), -0.2, "y se va hacia su izquierda")


func test_va_en_diagonal_y_no_derecho() -> void:
	# Una diagonal, no un tubo vertical a la espalda ni una bandolera plana.
	var car := _carcaj()
	var b := _hacia_donde_mira_la_boca(car)
	var inclinacion := rad_to_deg(acos(clampf(b.dot(Vector3.UP), -1.0, 1.0)))
	assert_between(inclinacion, 15.0, 55.0,
		"se ladea lo justo para cruzar la espalda (%.0f°)" % inclinacion)


func test_queda_a_la_espalda_y_no_delante() -> void:
	var car := _carcaj()
	# El cuerpo mira a -Z: detrás es +Z.
	assert_gt(car.global_position.z, _visual.global_position.z,
		"cuelga por detrás del cuerpo")
