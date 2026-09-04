extends GutTest

## La quebrada del Alicanto: la cámara y la trampa del oro.

const RESCATE := preload("res://scenes/actors/AlicantoRescate.gd")
const TRAMPA := preload("res://scenes/actors/TrampaDelOro.gd")


## Un doble del nodo del juego que sólo anota adónde le mandan la cámara.
class JuegoFalso extends Node3D:
	var mirado: Node3D = null
	var distancia := 0.0
	var alto := 0.0
	var soltadas := 0

	func focus_camera_on(n: Node3D, _dur := 0.0, dist := 0.0, alt := 1.5) -> void:
		mirado = n
		distancia = dist
		alto = alt

	func clear_camera_focus() -> void:
		mirado = null
		soltadas += 1


func _juego() -> JuegoFalso:
	var j := JuegoFalso.new()
	j.add_to_group("game")
	add_child_autofree(j)
	return j


## La zona, sin construir la quebrada entera: sólo interesa la lógica.
func _zona() -> Node3D:
	var z := Node3D.new()
	z.set_script(RESCATE)
	z.geometria_fijada = true
	add_child_autofree(z)
	return z


func test_la_camara_se_va_al_alicanto() -> void:
	var j := _juego()
	var z := _zona()
	var ave := Node3D.new()
	ave.name = "alicanto"
	z.add_child(ave)
	z.set("_alicanto", ave)

	z.call("_mirar_al_alicanto")
	assert_eq(j.mirado, ave, "la cámara mira al ave")
	assert_eq(j.distancia, RESCATE.DISTANCIA_CAMARA)
	assert_eq(j.alto, RESCATE.ALTO_CAMARA)


func test_sin_ave_la_camara_vuelve_a_emilia() -> void:
	var j := _juego()
	var z := _zona()
	z.set("_alicanto", null)
	z.call("_mirar_al_alicanto")
	assert_eq(j.soltadas, 1, "no se queda mirando a un nodo que no existe")


func test_al_bajar_el_ave_la_camara_la_sigue() -> void:
	var j := _juego()
	var z := _zona()
	# Un hijo llamado "alicanto" evita instanciar el modelo: la zona lo adopta.
	var ave := Node3D.new()
	ave.name = "alicanto"
	ave.visible = false
	z.add_child(ave)

	z.call("_summon_alicanto")
	assert_eq(j.mirado, ave, "al aparecer, se lo enseña al jugador")
	assert_true(ave.visible, "y deja de estar escondido")


# ─── La trampa: el oro se va abajo con la losa ────────────────────────────────

func _losa(nombre: String, en: Vector3, tam := Vector3(8, 1, 8)) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.position = en
	var mi := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	mi.mesh = caja
	n.add_child(mi)
	return n


func _cristal(nombre: String, en: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.position = en
	return n


func test_el_oro_de_encima_cae_con_el_camino() -> void:
	var zona := Node3D.new()
	add_child_autofree(zona)
	var puente := _losa("puente_derrumbable_1", Vector3(0, 0, 0))
	var camino := _losa("camino_derrumbable_1", Vector3(20, 0, 0))
	zona.add_child(puente)
	zona.add_child(camino)
	var encima := _cristal("cristal_de_oro_1", Vector3(21, 1, 1))
	var lejos := _cristal("cristal_de_oro_2", Vector3(60, 1, 0))
	zona.add_child(encima)
	zona.add_child(lejos)

	var trampa := Node3D.new()
	trampa.set_script(TRAMPA)
	trampa.puente = puente
	trampa.camino = camino
	zona.add_child(trampa)

	assert_eq(encima.get_parent(), camino, "el oro de encima cuelga del camino")
	assert_eq(lejos.get_parent(), zona, "el de la quebrada se queda donde estaba")


func test_el_oro_adoptado_se_mueve_con_la_losa() -> void:
	var zona := Node3D.new()
	add_child_autofree(zona)
	var puente := _losa("puente_derrumbable_1", Vector3(0, 0, 0))
	var camino := _losa("camino_derrumbable_1", Vector3(20, 0, 0))
	zona.add_child(puente)
	zona.add_child(camino)
	var oro := _cristal("cristal_de_oro_1", Vector3(20, 1, 0))
	zona.add_child(oro)

	var trampa := Node3D.new()
	trampa.set_script(TRAMPA)
	trampa.puente = puente
	trampa.camino = camino
	zona.add_child(trampa)

	var antes := oro.global_position.y
	camino.global_position -= Vector3(0.0, TRAMPA.CAIDA, 0.0)
	assert_almost_eq(oro.global_position.y, antes - TRAMPA.CAIDA, 0.01,
		"el oro baja los mismos metros que la losa")
