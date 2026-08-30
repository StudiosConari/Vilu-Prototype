extends RefCounted

## Ajusta un modelo importado a una altura concreta y lo apoya en el suelo.
##
## Los .glb del pipeline vienen a su tamaño real, pero ni todos miden lo mismo
## ni todos traen el origen en los pies. Confiar en el archivo obliga a buscar a
## mano la escala y el desplazamiento de cada uno, y a rehacerlo cada vez que se
## reprocesa el asset. Midiendo la caja envolvente sale solo.
##
## Se usa sin instanciar:
##   const ENCAJAR := preload("res://scenes/core/EncajarModelo.gd")
##   ENCAJAR.encajar(mi_modelo, 2.4)


## Escala `raiz` para que mida `altura` metros de alto, centrada en el eje
## vertical de su padre y con la base en y=0. Con altura <= 0 sólo la centra.
static func encajar(raiz: Node3D, altura: float) -> void:
	var caja := envolvente(raiz)
	if caja.size.y <= 0.001:
		return
	var k := 1.0
	if altura > 0.0:
		k = altura / caja.size.y
		raiz.scale = Vector3.ONE * k
	var c := caja.get_center()
	raiz.position = Vector3(-c.x * k, -caja.position.y * k, -c.z * k)


## Caja envolvente de todas las mallas del árbol, en el espacio de `n`.
static func envolvente(n: Node3D) -> AABB:
	var caja := AABB()
	var primero := true
	for m in mallas(n):
		var local: AABB = n.global_transform.affine_inverse() * m.global_transform * m.get_aabb() \
			if n.is_inside_tree() and m.is_inside_tree() else m.transform * m.get_aabb()
		if primero:
			caja = local
			primero = false
		else:
			caja = caja.merge(local)
	return caja


static func mallas(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(mallas(c))
	return out
