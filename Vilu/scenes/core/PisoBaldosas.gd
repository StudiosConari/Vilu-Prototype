@tool
extends Node3D

## Pisos empedrados con los modelos de baldosa, para plazas y caminos.
##
## Es @tool porque las zonas que lo usan también lo son: sin esto, al
## previsualizarlas en el editor sus pisos no se construirían.
##
## POR QUÉ MULTIMESH: una plaza de 44x44 con losas de 2 m son ~500 piezas, y
## los caminos suman varios cientos más. Como instancias sueltas serían miles
## de nodos; como MultiMesh es UN nodo por tipo de baldosa. Los pisos no
## necesitan colisión propia (el terreno de Terrain3D ya la da), así que
## MultiMesh alcanza y sobra.
##
## La escala de los FBX es desconocida (suelen venir en centímetros), así que
## cada baldosa se mide y se normaliza al tamaño de losa pedido.

const GRIS := "res://models/props/baldosas/baldosa_piedra.fbx"
const TIERRA := "res://models/props/baldosas/baldosa_tierra_piedras.fbx"
## baldosa_tierra.fbx no está: viene mal exportada (1852 vértices metidos en
## 1 cm y grosor cero), o sea que no es una losa sino un plano degenerado.

## Modelos entre los que se sortea cada losa. Ahora sólo gris.
## Para volver al damero de dos tonos: [GRIS, TIERRA].
##
## Es `var` y no `const` para que cada zona pueda pedir su propia paleta antes
## de construir el piso, por ejemplo:  piso.baldosas = [PisoBaldosas.TIERRA]
var baldosas: Array = [GRIS]

## Tamaño al que se lleva cada losa, en metros.
const LADO := 2.0
## Solape mínimo entre losas vecinas. Los modelos no son cuadrados perfectos
## (uno mide 0.98 x 1.0), así que sin este margen quedan juntas abiertas por
## las que se ve el terreno.
const SOLAPE := 1.02
## Alto final de cada losa, en metros.
##
## Enterrarlas no servía: la caja envolvente del modelo incluye sus guijarros
## en relieve, así que alinear el tope de esa caja al suelo dejaba la cara
## plana por debajo y sólo asomaban las piedritas.
## La solución correcta es dejarlas FINAS y darles colisión propia, para que el
## jugador camine sobre ellas en vez de sobre el terreno. Con 12 cm el relieve
## se sigue leyendo y el escalón contra las construcciones es imperceptible.
const GROSOR := 0.12

var _rng := RandomNumberGenerator.new()
var _cache := {}          # ruta -> {"mesh": Mesh, "escala": float}
var _lotes := {}          # ruta -> Array[Transform3D]
var _areas: Array = []    # zonas pendientes de recibir superficie de colisión

## Altura medida de la cara superior del empedrado tras construir(). Expuesta
## para poder verificarla desde afuera.
var tope_medido := 0.0


func _init() -> void:
	_rng.seed = 20260821


## Rectángulo empedrado centrado en `centro` (usa X y Z).
func plaza(centro: Vector3, ancho: float, largo: float) -> void:
	var nx := int(ceil(ancho / LADO))
	var nz := int(ceil(largo / LADO))
	var x0 := centro.x - ancho * 0.5 + LADO * 0.5
	var z0 := centro.z - largo * 0.5 + LADO * 0.5
	for ix in nx:
		for iz in nz:
			_poner(Vector3(x0 + float(ix) * LADO, centro.y, z0 + float(iz) * LADO))
	_areas.append({"centro": centro, "ancho": ancho, "largo": largo, "yaw": 0.0})


## Franja empedrada entre dos puntos.
func camino(a: Vector3, b: Vector3, ancho: float) -> void:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var largo := d.length()
	if largo < LADO:
		return
	var dir := d.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var pasos := int(ceil(largo / LADO))
	var anchos := int(ceil(ancho / LADO))
	for i in pasos:
		var t := (float(i) + 0.5) * LADO
		for j in anchos:
			var off := (float(j) - float(anchos - 1) * 0.5) * LADO
			var p := Vector2(a.x, a.z) + dir * t + perp * off
			_poner(Vector3(p.x, a.y, p.y))

	var medio := Vector2(a.x, a.z) + dir * (largo * 0.5)
	_areas.append({
		"centro": Vector3(medio.x, a.y, medio.y),
		"ancho": float(anchos) * LADO,
		"largo": largo,
		"yaw": atan2(dir.x, dir.y),
	})


## Cierra los lotes, crea los MultiMesh y les pone la superficie de colisión.
## Llamar UNA vez al final.
func construir() -> int:
	var total := 0
	# Altura REAL a la que queda la cara superior del empedrado. Se mide de las
	# transformaciones ya construidas en vez de calcularla: así la colisión
	# coincide siempre con lo que se ve, sin depender de que mi aritmética de
	# escalas sea correcta.
	var tope := -INF
	for ruta in _lotes.keys():
		var lista: Array = _lotes[ruta]
		if lista.is_empty():
			continue
		var datos = _modelo(ruta)
		if datos == null:
			continue

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = datos["mesh"]
		mm.instance_count = lista.size()
		var caja_malla: AABB = mm.mesh.get_aabb()
		for i in lista.size():
			var trans: Transform3D = lista[i]
			mm.set_instance_transform(i, trans)
			var mundo: AABB = trans * caja_malla
			tope = maxf(tope, mundo.position.y + mundo.size.y)

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Piso_" + ruta.get_file().get_basename()
		mmi.multimesh = mm
		add_child(mmi)
		total += lista.size()
	_lotes.clear()

	tope_medido = tope if tope > -INF else 0.0
	if total > 0 and tope > -INF:
		for a in _areas:
			_suelo_solido(a["centro"], float(a["ancho"]), float(a["largo"]),
				float(a["yaw"]), tope)
	_areas.clear()
	return total


# ─── Interno ────────────────────────────────────────────────────────────────

## Superficie sólida para caminar sobre el empedrado.
##
## Un MultiMesh no tiene colisión, y darle un cuerpo a cada losa serían cientos
## de cuerpos físicos: justo lo que se evita usando MultiMesh. En cambio se
## pone UN cuerpo por área, con su cara superior al nivel del empedrado.
func _suelo_solido(centro: Vector3, ancho: float, largo: float, yaw: float,
		tope: float) -> void:
	const ESPESOR := 0.6
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	add_child(cuerpo)
	# `tope` es la altura medida de la cara superior del empedrado.
	cuerpo.position = Vector3(centro.x, tope - ESPESOR * 0.5, centro.z)
	cuerpo.rotation.y = yaw

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ancho, ESPESOR, largo)
	forma.shape = caja
	cuerpo.add_child(forma)

func _poner(pos: Vector3) -> void:
	if baldosas.is_empty():
		return
	var ruta: String = baldosas[_rng.randi_range(0, baldosas.size() - 1)]
	var datos = _modelo(ruta)
	if datos == null:
		return
	var esc: Vector3 = datos["escala"]
	var base_off: float = float(datos["base"])

	# Giro en múltiplos de 90°: variedad sin romper el calce. Como la escala se
	# aplica ANTES del giro (en espacio local), la losa ya mide LADO x LADO y
	# sigue midiendo lo mismo tras rotar 90°.
	var giro := float(_rng.randi_range(0, 3)) * (PI * 0.5)
	var base := Basis(Vector3.UP, giro) * Basis.IDENTITY.scaled(esc)
	# Apoyada sobre el suelo: su base en pos.y, su cara superior en pos.y+GROSOR
	var t := Transform3D(base, pos + Vector3(0.0, base_off, 0.0))

	if not _lotes.has(ruta):
		_lotes[ruta] = []
	_lotes[ruta].append(t)


## Carga la baldosa una vez: saca su malla y calcula el factor de escala que
## la lleva a LADO metros de lado.
func _modelo(ruta: String):
	if _cache.has(ruta):
		return _cache[ruta]
	if not ResourceLoader.exists(ruta):
		push_warning("PisoBaldosas: falta %s (¿lo importó Godot?)" % ruta)
		_cache[ruta] = null
		return null

	var esc: PackedScene = load(ruta)
	var inst: Node3D = esc.instantiate()
	add_child(inst)

	var malla: Mesh = null
	var caja := AABB()
	var primero := true
	for m in _mallas(inst):
		if malla == null:
			malla = m.mesh
		var a: AABB = m.get_aabb()
		var tt: Transform3D = inst.global_transform.affine_inverse() * m.global_transform
		a = tt * a
		if primero:
			caja = a
			primero = false
		else:
			caja = caja.merge(a)

	inst.queue_free()

	if malla == null:
		_cache[ruta] = null
		return null

	# La medida fiable es la de la MALLA, no la del nodo: get_aabb() del nodo
	# depende del estado del árbol de escena y puede leerse antes de tiempo.
	var tam: Vector3 = malla.get_aabb().size

	# Guarda contra modelos mal exportados: sin esto, una malla de 1 cm produce
	# un factor de escala de cientos y aparece como un muro gigante.
	if tam.x < 0.02 or tam.z < 0.02:
		push_warning("PisoBaldosas: %s tiene malla degenerada (%s), se omite"
			% [ruta.get_file(), str(tam)])
		_cache[ruta] = null
		return null

	# Escala POR EJE para que la losa llene su celda exacta. Con escala uniforme
	# un modelo de 0.98 x 1.0 dejaba 4 cm de hueco en X contra su vecina.
	var sx: float = LADO * SOLAPE / tam.x
	var sz: float = LADO * SOLAPE / tam.z
	# El alto se lleva a GROSOR para TODAS las losas: así sus caras superiores
	# quedan al mismo nivel aunque los modelos tengan distinto espesor original
	# (uno mide 0.22 y el otro 0.24).
	var sy: float = GROSOR / maxf(tam.y, 0.0001)

	# Desplazamiento para que la BASE quede en el origen (el pivote del modelo
	# no siempre está ahí).
	var base_off: float = -malla.get_aabb().position.y * sy

	_cache[ruta] = {"mesh": malla, "escala": Vector3(sx, sy, sz), "base": base_off}
	return _cache[ruta]


func _mallas(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mallas(c))
	return out
