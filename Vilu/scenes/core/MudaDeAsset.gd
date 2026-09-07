extends RefCounted

## Cambia un prop por otra versión suya, fundiendo uno en el otro.
##
## El caso: los cubos y los obeliscos del Isluga tienen una segunda versión con
## la energía verde, y al accionarlos hay que pasar de una a la otra sin que se
## vea un corte. Tintar el material no vale —lo que cambia es el dibujo de la
## textura, no un color— y cambiar la malla de golpe se ve como un parpadeo.
##
## CÓMO SE CAMBIA. El modelo se cambia DE GOLPE —el viejo se apaga y el nuevo
## aparece en el mismo cuadro— y el corte se tapa con un destello corto.
##
## Primero se probó cruzando las transparencias de los dos durante segundo y
## medio, y se veía mal: dos mallas semitransparentes superpuestas se
## transparentan también entre ellas, así que durante todo el cruce se le ve el
## interior a las dos y el prop parece hueco. Es un problema del cruce en sí, no
## de estos modelos; con geometría maciza no hay forma de que quede bien.
##
## El destello resuelve lo mismo por otra vía: el ojo no distingue el cuadro en
## que cambió la malla porque en ese instante hay un fogonazo, y lo que queda es
## la lectura de «se cargó de energía», que es justo lo que cuenta el cambio.
##
## Los dos modelos salieron del MISMO original de Tripo, sólo que retexturizado:
## miden lo mismo hasta la cuarta decimal, así que el relevo cae exactamente
## donde estaba el viejo. Lo que NO son es la misma malla —el decimado del
## pipeline no da el mismo vértice dos veces: 4.405 contra 4.362—, y por eso no
## se puede reaprovechar el modelo viejo cambiándole sólo la textura.
##
## Se usa sin instanciar:
##   const MUDA := preload("res://scenes/core/MudaDeAsset.gd")
##   MUDA.mudar(self, VERSION_VERDE, 0.35)

const TOON_SKIN := preload("res://scenes/core/ToonSkin.gd")

## El color del fogonazo y su fuerza. Verde, como la energía a la que cambia.
const DESTELLO := Color(0.55, 1.0, 0.60)
const FUERZA_DEL_DESTELLO := 9.0
const ALCANCE_DEL_DESTELLO := 6.0

## Qué parte del destello es subida. El resto es la bajada, más larga: subir
## rápido y bajar despacio es lo que se lee como fogonazo y no como parpadeo.
const SUBIDA := 0.25


## Cambia `viejo` por `nueva` en el acto, tapando el corte con un destello de
## `segundos`.
##
## Devuelve el nodo nuevo, o null si no había nada que montar.
static func mudar(viejo: Node3D, nueva: PackedScene, segundos := 0.35) -> Node3D:
	if viejo == null or nueva == null or not viejo.is_inside_tree():
		return null
	if viejo.has_meta("mudado"):
		return null                     # ya cambió: no se muda dos veces
	viejo.set_meta("mudado", true)

	var relevo := nueva.instantiate() as Node3D
	if relevo == null:
		return null
	viejo.add_child(relevo)
	# Hijo del viejo y con transform en cero: hereda su sitio, su giro y su
	# escala sin tener que copiarlos. Los props del Isluga vienen con escalas
	# raras —×1.11, ×0.63, alguno con el eje volteado— y copiar el transform a
	# mano es justo donde eso se rompe.
	relevo.transform = Transform3D.IDENTITY

	# El relevo es SÓLO fachada: la colisión sigue siendo la del viejo, que es
	# la que ya está en las capas correctas y a la que apunta el interruptor.
	# Dos cuerpos en el mismo sitio se estorban entre ellos.
	_quitar_colisiones(relevo)

	# El sombreado toon se aplica a la región entera al cargarla, así que un
	# nodo que aparece después se quedaría con su PBR de fábrica y se vería de
	# otro estilo, que es exactamente lo que el toon vino a arreglar.
	TOON_SKIN.new().aplicar(relevo)

	# El cambio, en este mismo cuadro. El viejo no se libera: dentro vive su
	# cuerpo de colisión y el guion que lo acciona.
	for m in _mallas(viejo, relevo):
		m.visible = false

	_destellar(viejo, segundos)
	return relevo


## El fogonazo que tapa el cambio.
##
## Se cuelga del prop, sube en un suspiro y baja despacio. Al terminar se libera:
## la luz que queda encendida en el sitio es cosa del interruptor, no de esto.
static func _destellar(donde: Node3D, segundos: float) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = DESTELLO
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	# En local: estos props vienen escalados, así que el alcance en metros hay
	# que dividirlo por su escala o un cubo a ×0.63 alumbraría metro y medio de
	# más que otro a ×1.11.
	var f := donde.global_transform.basis.get_scale()
	luz.omni_range = ALCANCE_DEL_DESTELLO / maxf(f.y, 0.001)
	donde.add_child(luz)
	luz.position.y = 0.8 / maxf(f.y, 0.001)

	var t := donde.create_tween().bind_node(donde)
	t.tween_property(luz, "light_energy", FUERZA_DEL_DESTELLO, segundos * SUBIDA)
	t.tween_property(luz, "light_energy", 0.0, segundos * (1.0 - SUBIDA))
	t.tween_callback(luz.queue_free)


## Las mallas de un árbol, saltándose la rama que se le indique.
static func _mallas(n: Node, saltar: Node = null) -> Array[GeometryInstance3D]:
	var r: Array[GeometryInstance3D] = []
	if n == saltar:
		return r
	if n is GeometryInstance3D and not (n is Light3D):
		r.append(n as GeometryInstance3D)
	for h in n.get_children():
		r.append_array(_mallas(h, saltar))
	return r


## Se saca del árbol EN EL ACTO y después se libera.
##
## `queue_free` a secas no basta: es diferido, así que durante un cuadro entero
## el cuerpo del relevo seguiría en el mundo, encajado dentro del cuerpo del
## viejo. Dos cuerpos superpuestos se empujan entre ellos y pueden escupir al
## jugador que esté encima —y estos props son plataformas que se pisan—.
static func _quitar_colisiones(n: Node) -> void:
	if n is CollisionObject3D:
		var padre := n.get_parent()
		if padre != null:
			padre.remove_child(n)
		n.queue_free()
		return
	for h in n.get_children().duplicate():
		_quitar_colisiones(h)
