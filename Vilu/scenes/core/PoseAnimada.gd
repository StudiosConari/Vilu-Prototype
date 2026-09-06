extends RefCounted

## Cambia el modelo quieto de un NPC por su versión con esqueleto, y le pone una
## animación.
##
## Los modelos que están puestos a mano en las escenas vienen del pipeline y NO
## tienen huesos: son cuerpos rígidos. La versión animada es otro `.glb` —el
## mismo cuerpo, ya rigueado en Mixamo— que vive al lado con el sufijo `_anim`.
## Animar a uno de ellos es, entonces, sustituir lo que se ve conservando dónde
## está, hacia dónde mira y cuánto mide.
##
## El modelo viejo NO se borra, se oculta: si algún día falta el animado o hay
## que volver atrás, está donde estaba.
##
## Se usa sin instanciar:
##   const POSE := preload("res://scenes/core/PoseAnimada.gd")
##   POSE.poner(nodo, "sentad", true)

const SUFIJO := "_anim"
const CARPETA := "res://models/personaje/%s.glb"
## Nombre del nodo que se le cuelga, para no ponerle dos.
const NOMBRE := "Animado"


## Le pone a `nodo` su modelo animado y reproduce la primera animación cuyo
## nombre EMPIECE por `clip`. Devuelve si pudo.
##
## Se busca por prefijo porque los clips traen el nombre del fichero: pedir
## "derrotad" acierta con "derrotado", "derrotado_de_costado" y "derrotada_de_
## espalda" sin tener que saber cuál tiene cada personaje.
static func poner(nodo: Node3D, clip: String, en_bucle: bool) -> bool:
	if nodo == null or nodo.has_node(NOMBRE):
		return false
	var escena := _escena_animada(nodo.name)
	if escena == null:
		return false

	var modelo := escena.instantiate() as Node3D
	if modelo == null:
		return false
	modelo.name = NOMBRE
	nodo.add_child(modelo)

	# NO se le ajusta el tamaño. Los dos modelos salen de la misma malla y miden
	# lo mismo, así que colgando el animado del nodo que ya está colocado hereda
	# su escala y coinciden solos.
	#
	# Intenté igualarlos midiendo la caja de las mallas y salió mal dos veces: en
	# una malla CON ESQUELETO esa caja no refleja lo que se ve, y el factor
	# calculado dejó a los cazadores midiendo primero 367 y después 4 metros.

	var ap := _buscar_anim(modelo)
	var elegido := ""
	if ap != null:
		for n in ap.get_animation_list():
			if String(n).begins_with(clip):
				elegido = n
				break
	if elegido == "":
		# Sin la animación pedida no vale la pena el cambio: se deshace para no
		# dejar dos cuerpos superpuestos.
		modelo.queue_free()
		return false

	if en_bucle:
		var a := ap.get_animation(elegido)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	ap.play(elegido)

	# Recién ahora se apaga el modelo viejo: si algo hubiera fallado arriba, el
	# NPC se queda como estaba en vez de desaparecer.
	for m: MeshInstance3D in _mallas(nodo):
		if not _es_parte_de(m, modelo):
			m.visible = false
	return true


## Le cambia el clip a alguien que YA tiene su modelo animado puesto.
##
## `poner` se planta si el nodo ya lo tiene, y con razón: dos cuerpos encima uno
## de otro. Pero un NPC puede cambiar de pose durante la partida —la herida cae
## derrotada y se incorpora al curarla—, y para eso alcanza con pedirle otro
## clip al que ya está. Devuelve si pudo.
static func reproducir(nodo: Node3D, clip: String, en_bucle: bool) -> bool:
	if nodo == null:
		return false
	var modelo := nodo.get_node_or_null(NOMBRE) as Node3D
	if modelo == null:
		return false
	var ap := _buscar_anim(modelo)
	if ap == null:
		return false
	for n in ap.get_animation_list():
		if not String(n).begins_with(clip):
			continue
		var a := ap.get_animation(n)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR if en_bucle else Animation.LOOP_NONE
		ap.play(n)
		return true
	return false


## Le quita el modelo animado y le devuelve el suyo, de pie y quieto.
##
## Es el "reposo" de los personajes del pipeline: son cuerpos rígidos y su pose
## de fábrica es estar de pie. Cuando el `_anim` no trae un clip de reposo —los
## cazadores tienen dos, caer y sentarse— dejarlo en cualquiera de los dos es
## peor: la persona herida se quedaba SENTADA EN EL AIRE después de curarla,
## porque el clip de sentarse está hecho para una silla que ahí no hay.
##
## Devuelve si había algo que quitar.
static func quitar(nodo: Node3D) -> bool:
	if nodo == null:
		return false
	var modelo := nodo.get_node_or_null(NOMBRE) as Node3D
	if modelo == null:
		return false
	nodo.remove_child(modelo)
	modelo.queue_free()
	# `poner` sólo los OCULTÓ, no los borró: por esto justamente.
	for m: MeshInstance3D in _mallas(nodo):
		m.visible = true
	return true


## El `.glb` animado que le corresponde a un nodo, por su nombre.
##
## Los nodos de la escena llevan un número al final —`cazador_joven2`— y el
## modelo no, así que se le quitan los dígitos finales.
static func _escena_animada(nombre_nodo: String) -> PackedScene:
	var base := nombre_nodo
	while base.length() > 0 and base[base.length() - 1] >= "0" and base[base.length() - 1] <= "9":
		base = base.substr(0, base.length() - 1)
	var ruta := CARPETA % (base + SUFIJO)
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as PackedScene


## Alto en metros de lo que se ve ahora colgando del nodo.
static func _alto_visible(nodo: Node3D) -> float:
	var lo := 1e9
	var hi := -1e9
	for m: MeshInstance3D in _mallas(nodo):
		if not m.visible:
			continue
		var ab: AABB = m.get_aabb()
		var t: Transform3D = m.global_transform
		for i in 8:
			var p: Vector3 = t * ab.get_endpoint(i)
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	return maxf(hi - lo, 0.0)


static func _mallas(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		if h is MeshInstance3D:
			r.append(h)
		r.append_array(_mallas(h))
	return r


static func _buscar_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for h in n.get_children():
		var x := _buscar_anim(h)
		if x != null:
			return x
	return null


static func _es_parte_de(nodo: Node, raiz: Node) -> bool:
	var n := nodo
	while n != null:
		if n == raiz:
			return true
		n = n.get_parent()
	return false
