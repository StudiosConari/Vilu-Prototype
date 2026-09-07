extends GutTest

## Que al accionar un cubo o un obelisco del Isluga se cambie al modelo de
## energía verde, y que el cambio sea un fundido y no un parpadeo.

const MUDA := preload("res://scenes/core/MudaDeAsset.gd")
const CUBO_VERDE := preload("res://models/prop_mediano/cubo_de_piedra_oscuro_verde.glb")
const OBELISCO_VERDE := preload("res://models/focal/obelisko_oscuro_verde.glb")
const INTERRUPTOR := preload("res://scenes/actors/InterruptorGolpeable.gd")


## Un prop con malla y cuerpo, como el que deja el importador de glTF.
func _prop() -> Node3D:
	var n := Node3D.new()
	var cuerpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3.ONE
	cs.shape = caja
	cuerpo.add_child(cs)
	n.add_child(cuerpo)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	n.add_child(mi)
	add_child_autofree(n)
	return n


func _cuerpos(n: Node) -> int:
	var c := 0
	if n is CollisionObject3D:
		c += 1
	for h in n.get_children():
		c += _cuerpos(h)
	return c


func test_monta_el_modelo_nuevo_encima() -> void:
	var p := _prop()
	var nuevo := MUDA.mudar(p, CUBO_VERDE, 0.2)
	assert_not_null(nuevo, "el relevo se montó")
	assert_eq(nuevo.get_parent(), p, "cuelga del viejo, así hereda sitio y escala")


func test_hereda_sitio_giro_y_escala() -> void:
	# Los props del Isluga vienen con escalas raras y algún eje volteado; copiar
	# el transform a mano es justo donde eso se rompe. Colgándolo del viejo con
	# transform en cero, hereda todo.
	var p := _prop()
	p.scale = Vector3(1.11, 0.63, 1.11)
	p.rotation.y = 1.2
	var nuevo := MUDA.mudar(p, CUBO_VERDE, 0.2)
	assert_eq(nuevo.transform, Transform3D.IDENTITY, "sin transform propio")
	assert_almost_eq(nuevo.global_transform.origin, p.global_transform.origin, Vector3.ONE * 0.001,
		"y acaba exactamente donde el viejo")


func test_el_relevo_no_trae_colision() -> void:
	# La colisión sigue siendo la del viejo: es la que ya está en las capas
	# correctas y a la que apunta el interruptor. Dos cuerpos en el mismo sitio
	# se estorban entre ellos.
	var p := _prop()
	var antes := _cuerpos(p)
	var nuevo := MUDA.mudar(p, CUBO_VERDE, 0.2)
	assert_eq(_cuerpos(nuevo), 0, "el relevo es sólo fachada")
	assert_eq(_cuerpos(p) - _cuerpos(nuevo), antes, "y el viejo conserva la suya")


func test_el_cambio_es_inmediato() -> void:
	# El modelo cambia en el mismo cuadro. Se probó a cruzar las transparencias
	# durante segundo y medio y se veía mal: dos mallas semitransparentes
	# superpuestas se transparentan también entre ellas, así que durante todo el
	# cruce se le veía el interior a las dos y el prop parecía hueco.
	var p := _prop()
	var vieja: MeshInstance3D = null
	for h in p.get_children():
		if h is MeshInstance3D:
			vieja = h
	var nuevo := MUDA.mudar(p, CUBO_VERDE, 0.3)
	assert_false(vieja.visible, "el viejo se apaga ya, sin esperar nada")
	for h in nuevo.get_children():
		if h is GeometryInstance3D:
			assert_almost_eq((h as GeometryInstance3D).transparency, 0.0, 0.01,
				"y el nuevo entra opaco, no fundiéndose")


func test_el_destello_tapa_el_corte() -> void:
	var p := _prop()
	MUDA.mudar(p, CUBO_VERDE, 0.3)
	var luz: OmniLight3D = null
	for h in p.get_children():
		if h is OmniLight3D:
			luz = h
	assert_not_null(luz, "hay fogonazo en el momento del cambio")
	await wait_seconds(0.15)
	assert_gt(luz.light_energy, 0.0, "que sube en un suspiro")


func test_el_destello_se_va_solo() -> void:
	# Si se quedara encendido, cada prop accionado dejaría una luz verde fija
	# encima. La que queda es la del interruptor, azul, y es otra cosa.
	var p := _prop()
	MUDA.mudar(p, CUBO_VERDE, 0.3)
	await wait_seconds(0.8)
	for h in p.get_children():
		assert_false(h is OmniLight3D, "el fogonazo no deja luz puesta")


func test_el_destello_es_corto() -> void:
	for guion in [preload("res://scenes/actors/InterruptorGolpeable.gd"),
			preload("res://scenes/actors/Obelisco.gd"),
			preload("res://scenes/actors/HitCube.gd")]:
		var n: Node = guion.new()
		assert_lt(float(n.get("muda_segundos")), 0.6, "el destello dura poco")
		n.free()


func test_no_muda_dos_veces() -> void:
	# Golpear un interruptor que ya está usado no puede apilar modelos.
	var p := _prop()
	MUDA.mudar(p, CUBO_VERDE, 0.2)
	var segundo := MUDA.mudar(p, CUBO_VERDE, 0.2)
	assert_null(segundo, "la segunda llamada no monta nada")


func test_sin_modelo_no_pasa_nada() -> void:
	# Cualquier otro interruptor del juego no tiene versión verde: la muda tiene
	# que ser inofensiva ahí.
	var p := _prop()
	assert_null(MUDA.mudar(p, null, 0.2), "sin modelo no hay muda")


func test_el_interruptor_muda_al_accionarse() -> void:
	var p := _prop()
	p.set_script(INTERRUPTOR)
	p.set("modelo_activo", CUBO_VERDE)
	p.set("muda_segundos", 0.2)
	await wait_frames(2)
	p.call("_encender")
	assert_true(p.has_meta("mudado"), "accionarlo dispara el cambio de modelo")


func test_los_dos_modelos_verdes_existen() -> void:
	# Si alguien mueve o borra un .glb, esto avisa acá y no en el Isluga.
	assert_not_null(CUBO_VERDE, "el cubo verde está en el proyecto")
	assert_not_null(OBELISCO_VERDE, "y el obelisco verde también")


func test_la_mina_muda_sus_dos_obeliscos() -> void:
	# Los de la mina son `obelisko`, no `obelisko oscuro`, así que su gemela es
	# `obelisko verde` y no la oscura verde del Isluga.
	var texto := FileAccess.get_file_as_string("res://scenes/regions/Mina.tscn")
	assert_eq(texto.count('modelo_activo = ExtResource("92_obelverde")'), 2,
		"los dos obeliscos de la mina cambian al verde")
	assert_true(texto.contains("res://models/focal/obelisko_verde.glb"),
		"y apuntan al modelo verde, no al oscuro verde")


func test_el_isluga_tiene_los_ocho_props_conectados() -> void:
	# El guardián de la escena: la lógica puede estar perfecta y no verse nada si
	# nadie asignó `modelo_activo`. Son seis cubos-interruptor y dos obeliscos.
	var texto := FileAccess.get_file_as_string("res://scenes/puzzles/Isluga.tscn")
	assert_eq(texto.count('modelo_activo = ExtResource("90_cuboverde")'), 6,
		"los seis cubos cambian de modelo")
	assert_eq(texto.count('modelo_activo = ExtResource("91_obelverde")'), 2,
		"y los dos obeliscos del ascensor también")
