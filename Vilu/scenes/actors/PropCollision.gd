extends Node3D

## Genera colisión automáticamente para todos los mallados colgados de este nodo.
##
## USO: poné este script en un Node3D contenedor (ej. "Props") dentro de la
## región, y arrastrá ahí adentro los .glb/.fbx que quieras. Al arrancar la
## escena, cada MeshInstance3D recibe su cuerpo estático sin tocar nada más.
##
## MODOS:
##   TRIMESH       — calca la malla exacta. Preciso pero caro. Para túneles,
##                   arcos, escaleras, cualquier cosa con huecos por donde se
##                   pasa. SOLO sirve para geometría que no se mueve.
##   CONVEX        — envuelve la malla en su cáscara convexa. Barato. Ideal
##                   para rocas, cajones, troncos: cosas macizas.
##   MULTI_CONVEX  — descompone en varias piezas convexas. Punto medio para
##                   formas irregulares que con CONVEX quedarían "infladas".
##   NONE          — sin colisión, puramente decorativo (pastos, carteles).
##
## EXCEPCIONES POR NODO: si un mallado suelto necesita otro modo distinto al
## del contenedor, agregalo a uno de estos grupos en el editor:
##   "col_trimesh", "col_convex", "col_multi", "col_none"

enum Mode { TRIMESH, CONVEX, MULTI_CONVEX, NONE }

@export var mode: Mode = Mode.CONVEX

## Capa física del entorno. 1 = mundo sólido (es la que usan el resto de los
## CSG y contra la que choca la cámara).
@export_flags_3d_physics var collision_layer := 1

## Si un mallado ya tiene un cuerpo propio (venía con colisión del importador,
## o usaste el sufijo -col en Blender), no se le toca.
@export var skip_if_has_body := true

var _made := 0


func _ready() -> void:
	_walk(self)
	if _made > 0:
		print("[PropCollision] %s: colisión generada para %d mallado(s)."
			% [name, _made])


func _walk(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_apply(child)
		# Los .glb importados anidan el mallado dentro de nodos intermedios,
		# así que hay que bajar por todo el árbol.
		_walk(child)


func _apply(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	if skip_if_has_body and _has_body(mi):
		return

	match _mode_for(mi):
		Mode.NONE:
			return
		Mode.TRIMESH:
			mi.create_trimesh_collision()
		Mode.CONVEX:
			mi.create_convex_collision()
		Mode.MULTI_CONVEX:
			mi.create_multiple_convex_collisions()

	# create_*_collision deja el cuerpo en la capa por defecto: lo forzamos a
	# la del entorno para que la cámara y los raycasts de suelo lo vean.
	for child in mi.get_children():
		if child is StaticBody3D:
			child.collision_layer = collision_layer
			child.collision_mask = 0   # el entorno no necesita detectar a nadie
	_made += 1


func _mode_for(mi: MeshInstance3D) -> Mode:
	if mi.is_in_group("col_none"):
		return Mode.NONE
	if mi.is_in_group("col_trimesh"):
		return Mode.TRIMESH
	if mi.is_in_group("col_convex"):
		return Mode.CONVEX
	if mi.is_in_group("col_multi"):
		return Mode.MULTI_CONVEX
	return mode


func _has_body(mi: MeshInstance3D) -> bool:
	for child in mi.get_children():
		if child is StaticBody3D or child is CollisionObject3D:
			return true
	return false
