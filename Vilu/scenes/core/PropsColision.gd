extends Node3D

## Da colisión a los props puestos a mano que cuelguen de este nodo.
##
## CÓMO SE USA
##   1. En World.tscn, agregá un Node3D hijo y ponele este script.
##   2. Arrastrá adentro los .fbx que quieras (rocas, cactus, lo que sea) y
##      acomodalos a ojo en la vista 3D.
##   3. Listo. Al correr el juego cada malla recibe su cuerpo estático.
##
## POR QUÉ EN EJECUCIÓN Y NO CON @tool
##   Un @tool que genera nodos hijos los deja guardados en la escena, y a la
##   siguiente recarga los genera ENCIMA de los que ya estaban: es lo mismo
##   que duplicó la fiesta de La Tirana y la llevó de 702 bytes a 440 KB.
##   Generando en _ready() el .tscn guarda sólo tus props y no hay nada que
##   se pueda duplicar. La colisión no se ve en el editor de todos modos.
##
## FORMA POR PROP — se elige metiendo el nodo en un grupo:
##   col_none      no le pone colisión (pasto, flores, cosas decorativas)
##   col_trimesh   malla exacta; para lo hueco o cóncavo, como el círculo de
##                 rocas, que con envolvente convexa quedaría tapado
##   (sin grupo)   envolvente convexa: barata y suficiente para una piedra

## Apagalo para dejar todo atravesable de una (útil para probar recorridos).
@export var activo: bool = true

## Usa malla exacta para TODO lo que cuelgue de este nodo, sin tener que meter
## cada malla en el grupo col_trimesh.
##
## Para un contenedor de piedras sueltas no sirve —serían miles de caras para
## nada—, pero para un EDIFICIO es lo que hace falta: la envolvente convexa de
## una iglesia le tapa la puerta y no se puede entrar.
@export var trimesh_por_defecto: bool = false


func _ready() -> void:
	if not activo:
		return
	var n := _vestir(self)
	if n > 0:
		print("[props] %s: %d colisiones generadas" % [name, n])


func _vestir(nodo: Node) -> int:
	var total := 0
	for hijo in nodo.get_children():
		total += _vestir(hijo)

	if not (nodo is MeshInstance3D):
		return total
	var mi := nodo as MeshInstance3D
	if mi.mesh == null or nodo.is_in_group("col_none"):
		return total

	# Guarda contra mallas mal exportadas: una de 1 cm produciría una forma
	# degenerada que el motor físico no sabe manejar.
	var tam: Vector3 = mi.mesh.get_aabb().size
	if tam.x < 0.02 and tam.y < 0.02 and tam.z < 0.02:
		push_warning("PropsColision: %s tiene malla degenerada (%s), se omite"
			% [mi.name, str(tam)])
		return total

	var forma: Shape3D
	if trimesh_por_defecto or nodo.is_in_group("col_trimesh"):
		forma = mi.mesh.create_trimesh_shape()
	else:
		forma = mi.mesh.create_convex_shape(true, true)
	if forma == null:
		push_warning("PropsColision: no se pudo generar forma para %s" % mi.name)
		return total

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Colision"
	# collision_mask 0: es decorado, no necesita detectar a nadie, sólo que
	# lo detecten a él. Sin esto cada roca consulta al mundo cada cuadro.
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	mi.add_child(cuerpo)

	var cs := CollisionShape3D.new()
	cs.shape = forma
	cuerpo.add_child(cs)
	return total + 1
