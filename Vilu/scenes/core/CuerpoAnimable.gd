extends RefCounted

## Convierte el cuerpo estático de un .glb importado en uno ANIMABLE.
##
## POR QUÉ HACE FALTA. El importador de glTF cuelga un StaticBody3D, y un cuerpo
## estático que se mueve por código no arrastra a quien lleva encima: el jugador
## se queda flotando donde estaba y se cae. El nodo correcto para una plataforma
## es AnimatableBody3D con `sync_to_physics`, que calcula su propia velocidad a
## partir del movimiento y se la pasa al pasajero.
##
## Como no se le puede cambiar la clase a un nodo ya creado, se construye uno
## nuevo, se le pasan las formas de colisión y la malla, y se tira el viejo.
##
## Se usa sin instanciar:
##   const ANIMABLE := preload("res://scenes/core/CuerpoAnimable.gd")
##   var cuerpo := ANIMABLE.convertir(self)

const ENCAJAR := preload("res://scenes/core/EncajarModelo.gd")


## Devuelve el AnimatableBody3D, ya colgado de `raiz`, o null si el modelo no
## trae nada que mover.
static func convertir(raiz: Node3D, nombre := "Cuerpo") -> AnimatableBody3D:
	var mallas := ENCAJAR.mallas(raiz)
	var viejo := _buscar(raiz, "StaticBody3D") as StaticBody3D
	if viejo == null and mallas.is_empty():
		return null

	var nuevo := AnimatableBody3D.new()
	nuevo.name = nombre
	nuevo.sync_to_physics = true
	nuevo.collision_layer = viejo.collision_layer if viejo else 1
	nuevo.collision_mask = 0
	raiz.add_child(nuevo)

	if viejo:
		nuevo.transform = viejo.transform
		for h in viejo.get_children():
			viejo.remove_child(h)
			nuevo.add_child(h)
		viejo.queue_free()

	# La malla también viaja. Si se queda fuera, el bloque se ve quieto mientras
	# su colisión se mueve, que es peor que no moverlo.
	for m in mallas:
		if m.get_parent() == nuevo:
			continue
		var t := m.global_transform
		m.get_parent().remove_child(m)
		nuevo.add_child(m)
		m.global_transform = t
	return nuevo


static func _buscar(n: Node, clase: String) -> Node:
	for c in n.get_children():
		if c.is_class(clase):
			return c
		var hondo := _buscar(c, clase)
		if hondo:
			return hondo
	return null
