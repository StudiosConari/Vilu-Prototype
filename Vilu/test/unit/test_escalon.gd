extends GutTest

## Que el personaje no se enganche en las juntas, y que si alguna vez queda
## metido dentro de la geometría pueda salir.
##
## HUBO una subida de escalón automática acá, y se quitó. Lo que hacía era
## levantar el cuerpo escribiendo su posición a mano al detectar un reborde bajo,
## y eso podía dejarlo DENTRO de un muro. Empotrado, `test_move` informaba las
## ocho direcciones libres —ignora el solape inicial— y `move_and_slide` no lo
## movía ni un centímetro, porque el desplazamiento entero se lo comía la
## despenetración: no había salida más que cerrar el juego.
##
## Medido contra la puerta de la iglesia, caminando hacia ella desde dieciséis
## sitios: sin la subida, 0 atascos; con ella, 4. Se probó a pedir la
## comprobación de solape y a subir con `move_and_collide` en vez de a mano, y
## siguió atascando en 3 y 4. Subir escalones solo es una comodidad; quedarse
## empotrado arruina la partida.
##
## No volver a intentarlo sin una sonda que mida los dieciséis acercamientos.

const PLAYER := preload("res://scenes/actors/Player.tscn")


func test_no_hay_subida_de_escalon() -> void:
	var texto := FileAccess.get_file_as_string("res://scenes/actors/PlayerController.gd")
	assert_false(texto.contains("_subir_escalon"),
		"la subida de escalón se quitó: empotraba al jugador en los muros")


func test_el_cuerpo_tiene_margen_y_resbala() -> void:
	# Las dos propiedades de `Player.tscn` que atacan la otra mitad del problema:
	# quedarse trabado en la junta donde se tocan dos objetos.
	#
	# `safe_margin` por defecto es 1 mm, y con eso la cápsula se engancha en
	# cualquier costura entre dos mallas. `wall_min_slide_angle` por defecto son
	# 15º: chocando de casi frente contra algo, el cuerpo se PARA en vez de
	# resbalar. Bajándolo, resbala y sigue.
	var p: CharacterBody3D = PLAYER.instantiate()
	add_child_autofree(p)
	assert_almost_eq(p.safe_margin, 0.04, 0.001, "margen holgado contra las costuras")
	assert_lt(p.wall_min_slide_angle, 0.15, "resbala contra lo que choca de frente")


## Un cajón estático. `medidas` es el tamaño total; `centro`, dónde va su centro.
func _bloque(medidas: Vector3, centro: Vector3) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = medidas
	forma.shape = caja
	cuerpo.add_child(forma)
	add_child_autofree(cuerpo)
	cuerpo.global_position = centro
	return cuerpo


func test_estar_dentro_de_algo_se_detecta() -> void:
	# La comprobación que faltaba y que hizo invisible el fallo de la iglesia:
	# `test_move` no cuenta el solape inicial, así que un cuerpo metido dentro de
	# la geometría puede parecer libre. Preguntando con el solape sí se ve.
	var p: CharacterBody3D = PLAYER.instantiate()
	add_child_autofree(p)
	_bloque(Vector3(6.0, 6.0, 6.0), Vector3.ZERO)
	p.global_position = Vector3.ZERO           # justo en el centro del bloque
	await wait_physics_frames(2)
	assert_true(bool(p.call("_estorbado", p.global_transform, Vector3.UP * 0.001)),
		"contando el solape, se ve que está metido dentro")
	assert_true(bool(p.call("_sin_salida")), "y por lo tanto, sin salida")


func test_apoyado_en_una_pared_no_cuenta_como_atasco() -> void:
	# Empujar contra un muro es normal y no puede disparar un rescate: devolver
	# a alguien un metro atrás cada vez que se apoya en una pared sería mucho
	# peor que el fallo que se está arreglando.
	var p: CharacterBody3D = PLAYER.instantiate()
	add_child_autofree(p)
	_bloque(Vector3(40.0, 1.0, 40.0), Vector3(0.0, -0.5, 0.0))   # suelo
	_bloque(Vector3(4.0, 4.0, 4.0), Vector3(3.0, 2.0, 0.0))      # muro delante
	p.global_position = Vector3(0.4, 0.05, 0.0)
	await wait_physics_frames(4)
	assert_false(bool(p.call("_sin_salida")), "de costado sí puede irse")
