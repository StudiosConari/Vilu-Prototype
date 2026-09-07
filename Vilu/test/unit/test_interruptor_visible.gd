extends GutTest

## Que al accionar un cubo-interruptor del Isluga se note.
##
## Se encendían en naranja dentro de un cráter que es naranja de lado a lado: el
## aviso se perdía en la lava. Ahora la luz es azul y más fuerte.
##
## Lo que NO se hace, y se probó: envolver el cubo en un halo para distinguirlo
## antes de golpearlo. Se veían seis globos celestes opacos flotando en mitad
## del cráter, tapando el nivel. El cubo se ve tal cual es hasta que lo accionás.

const INTERRUPTOR := preload("res://scenes/actors/InterruptorGolpeable.gd")


## Un cubo con su cuerpo de colisión, como lo deja el importador de glTF.
func _cubo() -> Node3D:
	var n := Node3D.new()
	var cuerpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3.ONE
	cs.shape = caja
	cuerpo.add_child(cs)
	n.add_child(cuerpo)
	n.set_script(INTERRUPTOR)
	add_child_autofree(n)
	await wait_frames(2)
	return n


func _luz(n: Node3D) -> OmniLight3D:
	for h in n.get_children():
		if h is OmniLight3D:
			return h
	return null


func test_antes_de_accionarlo_no_lleva_nada_encima() -> void:
	var n: Node3D = await _cubo()
	assert_null(_luz(n), "sin luz hasta que lo golpeás")
	for h in n.get_children():
		assert_false(h is MeshInstance3D, "y sin globos ni halos tapando el nivel")


func test_al_accionarlo_enciende() -> void:
	var n: Node3D = await _cubo()
	n.call("_encender")
	var l := _luz(n)
	assert_not_null(l, "accionado alumbra")
	await wait_seconds(0.6)            # la luz entra con interpolación
	assert_almost_eq(l.light_energy, float(n.get("brillo")), 0.1, "y al brillo pleno")


func test_el_aviso_es_azul_no_naranja() -> void:
	# El cráter es naranja entero: un aviso naranja sobre lava naranja no es un
	# aviso. Se comprueba que el azul le gane al rojo.
	var n: Node3D = await _cubo()
	var c: Color = n.get("color_activo")
	assert_gt(c.b, c.r, "tira a azul, no a naranja")


func test_alumbra_mas_que_antes() -> void:
	# Estaba en 2.2 de energía y 4.5 m de alcance, y no se veía de lejos.
	var n: Node3D = await _cubo()
	assert_gt(float(n.get("brillo")), 2.2, "más fuerte que antes")
	assert_gt(float(n.get("alcance")), 4.5, "y llega más lejos")


func test_no_enciende_dos_veces() -> void:
	var n: Node3D = await _cubo()
	n.call("_encender")
	n.call("_encender")
	var luces := 0
	for h in n.get_children():
		if h is OmniLight3D:
			luces += 1
	assert_eq(luces, 1, "una sola luz por interruptor")
