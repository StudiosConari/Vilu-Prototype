extends GutTest

## Que el marcador de misión aparezca sobre lo que hay que hacer, y se vaya
## cuando ya está hecho.

const GUIA := preload("res://scenes/core/GuiaDeObjetivos.gd")
const MARCADOR := preload("res://scenes/actors/MarcadorDeObjetivo.gd")
const MISIONES := preload("res://scenes/core/Misiones.gd")


## Un Game de mentira: la guía sólo le pide el HUD y las puertas.
class GameFalso extends Node3D:
	var hud: Node = null
	var puerta: Node3D = null

	func puerta_hacia(_id: String) -> Node3D:
		return puerta


func _guia(mision: String) -> Node:
	var g := GameFalso.new()
	add_child_autofree(g)
	var guia := Node.new()
	guia.set_script(GUIA)
	g.add_child(guia)
	guia.set("_mision", mision)
	return guia


## Un objetivo cualquiera con una malla, para que tenga altura.
func _objetivo(grupo: String, alto := 2.0) -> Node3D:
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(1.0, alto, 1.0)
	m.mesh = caja
	m.position.y = alto * 0.5
	n.add_child(m)
	add_child_autofree(n)
	n.add_to_group(grupo)
	return n


func _marcador_de(n: Node3D) -> Node:
	for h in n.get_children():
		if h.get_script() == MARCADOR:
			return h
	return null


func test_le_pone_marcador_al_objetivo_de_la_mision() -> void:
	var o := _objetivo("objetivo_obeliscos")
	var g := _guia("obeliscos")
	g.call("_repasar")
	assert_not_null(_marcador_de(o), "el obelisco apagado lleva marcador")


func test_no_marca_lo_que_es_de_otra_mision() -> void:
	var o := _objetivo("objetivo_guanacos")
	var g := _guia("obeliscos")
	g.call("_repasar")
	assert_null(_marcador_de(o), "un guanaco no se marca durante los obeliscos")


func test_se_lo_quita_al_cumplirse() -> void:
	var o := _objetivo("objetivo_guanacos")
	var g := _guia("guanacos")
	g.call("_repasar")
	assert_not_null(_marcador_de(o), "primero lo lleva")
	# Curado: sale del grupo, igual que hace YastayEncounter.
	o.remove_from_group("objetivo_guanacos")
	g.call("_repasar")
	await wait_frames(2)          # queue_free tarda un cuadro
	assert_null(_marcador_de(o), "y al curarlo se le quita")


func test_las_misiones_de_ir_a_un_sitio_marcan_la_puerta() -> void:
	var puerta := Node3D.new()
	add_child_autofree(puerta)
	var g := _guia("mina")
	(g.get_parent() as Node).set("puerta", puerta)
	g.call("_repasar")
	assert_not_null(_marcador_de(puerta), "«busca la mina» marca la puerta de la mina")


func test_la_punta_se_pone_sobre_la_cabeza() -> void:
	# Un guanaco tumbado y una puerta de zona no miden lo mismo: si la altura
	# fuera fija, la misma punta quedaría dentro de la cabeza de uno y a tres
	# metros de la otra.
	var bajo := _objetivo("objetivo_x", 0.6)
	var alto := _objetivo("objetivo_x", 4.0)
	assert_almost_eq(MARCADOR.alto_de(bajo), 0.6, 0.05, "mide lo bajo")
	assert_almost_eq(MARCADOR.alto_de(alto), 4.0, 0.05, "y mide lo alto")


func test_medir_dos_veces_da_lo_mismo() -> void:
	# El marcador queda de HIJO de lo que marca, y su columna de luz mide catorce
	# metros. Sin excluirlo al medir, el objeto "crecía" al señalarlo: la mira de
	# la flecha de borde se iba al cielo y la flecha salía aunque el objetivo se
	# estuviera viendo.
	var o := _objetivo("objetivo_obeliscos", 2.0)
	var antes := MARCADOR.alto_de(o)
	var g := _guia("obeliscos")
	g.call("_repasar")
	assert_almost_eq(MARCADOR.alto_de(o), antes, 0.01,
		"con el marcador puesto sigue midiendo lo mismo")


func test_todas_las_misiones_saben_donde_estan() -> void:
	# El guardaespaldas de la cadena: al añadir una misión nueva hay que decir
	# dónde está su objetivo, o el jugador se queda con un texto y sin flecha.
	# Se busca en el código quién se mete a cada grupo `objetivo_<id>`.
	var etiquetados := _grupos_declarados_en_el_codigo()
	var huerfanas: Array[String] = []
	for m: Dictionary in MISIONES.CADENA:
		var id := String(m["id"])
		if GUIA.DESTINOS.has(id) or etiquetados.has(id):
			continue
		huerfanas.append(id)
	assert_eq(huerfanas, [] as Array[String],
		"estas misiones no tienen forma de señalar su objetivo")


## Los `<id>` de todos los `add_to_group("objetivo_<id>")` que hay en `scenes/`.
func _grupos_declarados_en_el_codigo() -> Dictionary:
	var r := {}
	var re := RegEx.create_from_string('add_to_group\\("objetivo_([a-z0-9_]+)"\\)')
	for ruta in _gd_de("res://scenes"):
		var f := FileAccess.open(ruta, FileAccess.READ)
		if f == null:
			continue
		for m in re.search_all(f.get_as_text()):
			r[m.get_string(1)] = true
	return r


func _gd_de(carpeta: String) -> Array[String]:
	var r: Array[String] = []
	var d := DirAccess.open(carpeta)
	if d == null:
		return r
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var ruta := carpeta.path_join(n)
		if d.current_is_dir():
			r.append_array(_gd_de(ruta))
		elif n.ends_with(".gd"):
			r.append(ruta)
		n = d.get_next()
	d.list_dir_end()
	return r
