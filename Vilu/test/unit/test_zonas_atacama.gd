extends "res://addons/gut/test.gd"

## A qué zona pertenece cada sitio de Atacama.
##
## Regresión de un fallo real: la escena del encuentro con el Yastay arrancaba
## sola estando en el bar del poblado, a media región de distancia. Las zonas de
## Atacama SE PISAN —los centros del Poblado y del Yastay están a 38,7 m con
## radios de 36 y 34, y Poblado y Alicanto igual—, y la activación por cercanía
## metía al jugador en todas las que lo contuvieran a la vez.
##
## `test_zones_do_not_overlap` no lo veía porque compara el CATÁLOGO (los "pos"
## de ZONAS), y las zonas de este mapa están puestas a mano en el .tscn: sus
## posiciones de verdad son las del nodo, no las del catálogo.
##
## Lo que tiene que valer no es que no se pisen —se pisan, y está bien: son
## vecinas— sino que cada punto pertenezca a UNA sola, la más metida.

const GAME := preload("res://scenes/core/Game.tscn")
const ATACAMA := "res://scenes/core/WorldAtacama.tscn"

## Dónde está la barra dentro del poblado. El mismo sitio que usa PobladoHub
## para sentar a la gente del bar.
const BARRA := Vector3(10.0, 0.0, -4.0)


func after_all() -> void:
	GameManager.reset_progress()


## El mundo de Atacama, montado por el juego y no suelto.
##
## Suelto también se puede, pero Terrain3D busca la cámara activa y sin ella
## corta su _physics_process con un error; el juego trae la suya. De paso esto
## recorre el arranque en el otro mundo, que es como se llega al bar desde el
## selector del título.
func _mundo(ruta := ATACAMA) -> Node3D:
	GameManager.reset_progress()
	GameManager.debug_start_world = ruta
	GameManager.debug_start_zone = "Poblado"
	var g: Node = GAME.instantiate()
	add_child_autofree(g)
	await wait_physics_frames(6)
	# Montar el mundo dispara un aviso de obsolescencia del propio motor
	# (instance_reset_physics_interpolation). No es nuestro y no dice nada de las
	# zonas, pero GUT lo cuenta como fallo: se da por visto para que estos tests
	# hablen sólo de lo suyo. Los errores que aparezcan DESPUÉS sí fallan.
	for e in get_errors():
		e.handled = true
	return g.world


func test_el_bar_es_del_poblado_y_no_del_yastay() -> void:
	var w := await _mundo()
	var pob: Node3D = w.get_node("Poblado")
	var yas: Node3D = w.get_node("Yastay")
	var bar: Vector3 = pob.position + BARRA

	# El nodo "Yastay" está al pie del puente, no en la arena: con el radio del
	# catálogo medido desde ahí, el bar caía dentro. Ahora la zona declara su
	# centro y su radio, y con eso la quebrada ni se acerca al poblado.
	var d_nodo: float = Vector2(bar.x - yas.position.x, bar.z - yas.position.z).length()
	assert_lt(d_nodo, 34.0,
		"el bar sigue estando a menos de 34 m del NODO del Yastay: si dejara de"
		+ " estarlo, este test ya no probaría el fallo que lo motivó")

	assert_eq(w.zona_en(bar), "Poblado",
		"desde el bar se está en el Poblado, no en la quebrada del Yastay")


func test_cada_zona_se_queda_con_su_centro() -> void:
	var w := await _mundo()
	for z in w.ZONAS:
		var id: String = z["id"]
		if not w.has_zone(id):
			continue   # zona del otro mundo
		# El del nodo NO sirve como centro: el del Yastay está al pie del puente,
		# fuera de su propia quebrada. Vale el que declare la zona, si lo declara.
		var n: Node3D = w.get_node(NodePath(id))
		var centro: Vector3 = n.position
		var propio: Variant = n.get("centro_de_zona")
		if propio is Vector3 and propio != Vector3.ZERO:
			centro = propio
		assert_eq(w.zona_en(centro), id,
			"el centro de %s pertenece a %s" % [id, id])


## Entre zonas —en el camino— no se está en ninguna, que es lo que apaga los
## guiones de las dos.
func test_lejos_de_todo_no_hay_zona() -> void:
	var w := await _mundo()
	assert_eq(w.zona_en(Vector3(600.0, 0.0, 600.0)), "",
		"a 600 m de todo no se está en ninguna zona")


# ─── Qué le toca a cada mundo ────────────────────────────────────────────────

const TARAPACA := "res://scenes/core/World.tscn"


func _todos(n: Node) -> Array:
	var r: Array = [n]
	for h in n.get_children():
		r.append_array(_todos(h))
	return r


func _tiene_boca_de_mina(w: Node) -> bool:
	for x in _todos(w):
		if x.get("target_region") == "Mina":
			return true
	return false


## La Mina es de Tarapacá. Atacama no tiene ni el modelo de la entrada ni el
## nodo "Mina", y aun así el guion del mundo le armaba el cerro de greybox de la
## boca —con su cartel flotante y su "[E] Entrar a la Mina"— en pleno desierto,
## al lado de la quebrada del Yastay. El bulto era CSG, así que no aparecía
## buscando mallas de caja.
func test_atacama_no_tiene_boca_de_mina() -> void:
	var w := await _mundo(ATACAMA)
	# De una sola vez: una aserción por nodo son miles y ahogan el informe.
	var greybox: PackedStringArray = []
	for x in _todos(w):
		if x is CSGBox3D:
			greybox.append(x.name)
	assert_eq(", ".join(greybox), "",
		"Atacama no debería tener geometría de greybox")
	assert_false(_tiene_boca_de_mina(w),
		"Atacama no tiene Mina, así que tampoco su entrada")


func test_tarapaca_conserva_su_entrada_a_la_mina() -> void:
	var w := await _mundo(TARAPACA)
	assert_true(_tiene_boca_de_mina(w),
		"en Tarapacá se sigue pudiendo entrar a la Mina")


## El encuentro con el Yastay tiene que empezar CRUZANDO el puente, no antes.
##
## La zona se activa por cercanía a un centro, y el nodo "Yastay" está plantado
## al oeste, al pie del puente: medir desde él con los 34 m del catálogo hacía
## que el guion arrancara a media región. Ahora la quebrada declara el centro de
## su anillo de monolitos y un radio que corta a mitad del puente.
func test_el_encuentro_empieza_cruzando_el_puente() -> void:
	var w := await _mundo()
	var yas: Node3D = w.get_node("Yastay")

	assert_ne(yas.centro_de_zona, Vector3.ZERO,
		"la quebrada declara dónde está su centro de verdad")
	assert_gt(Vector2(yas.centro_de_zona.x - yas.position.x,
			yas.centro_de_zona.z - yas.position.z).length(), 10.0,
		"ese centro NO es el del nodo: por eso hizo falta declararlo")

	# Los dos tramos del puente de entrada, de fuera hacia dentro.
	var fuera: Node3D = yas.get_node_or_null("puente_alicanto3")
	var dentro: Node3D = yas.get_node_or_null("puente_alicanto4")
	assert_not_null(fuera, "el puente de entrada conserva su tramo de fuera")
	assert_not_null(dentro, "…y el de dentro")
	if fuera == null or dentro == null:
		return

	assert_eq(w.zona_en(fuera.global_position), "",
		"al pie del puente todavía no se está en la quebrada")
	assert_eq(w.zona_en(dentro.global_position), "Yastay",
		"cruzando el puente ya sí")
