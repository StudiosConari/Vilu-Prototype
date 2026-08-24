extends Node

## Convierte los materiales de un árbol de nodos al sombreado toon.
##
## POR QUÉ HACE FALTA: el terreno ya usa su propio shader escalonado y todo
## lleva contorno negro por post-proceso, pero las casas, los props y los
## personajes seguían con iluminación PBR suave. Con luz degradada al lado de
## luz en escalones la escena se lee partida en dos estilos.
##
## Recorre el árbol y reemplaza cada StandardMaterial3D por un ShaderMaterial
## con toon_objeto.gdshader, CONSERVANDO su color y su textura. Los FBX de
## flora y roca traen textura; las cajas de CSG y las cápsulas, sólo color.
##
## Se usa como utilidad, sin instanciar:
##   ToonSkin.new().aplicar(nodo)

const SHADER := preload("res://shaders/toon_objeto.gdshader")
## Variante que escribe ALPHA. Sólo para lo realmente translúcido: en Godot 4
## mencionar ALPHA manda el material a la cola transparente, y ahí deja de
## escribir profundidad y de tapar a lo que tiene detrás.
const SHADER_TRANSLUCIDO := preload("res://shaders/toon_objeto_translucido.gdshader")

## Grosor del contorno de casco invertido, en metros de mundo.
const CONTORNO_GROSOR := 0.018
const CONTORNO_COLOR := Color(0.07, 0.05, 0.09)

## Cachea por material de origen: dos props del mismo modelo comparten el
## ShaderMaterial en vez de crear uno por instancia.
var _cache := {}
var _convertidos := 0


func aplicar(raiz: Node) -> int:
	_convertidos = 0
	_recorrer(raiz)
	return _convertidos


func _recorrer(n: Node) -> void:
	if n is MeshInstance3D:
		_vestir_mesh(n)
	elif n is MultiMeshInstance3D:
		_vestir_multimesh(n)
	elif n is CSGShape3D:
		_vestir_csg(n)
	for c in n.get_children():
		_recorrer(c)


## Escala de mundo del nodo, para compensar el contorno.
##
## `grow_amount` infla el casco invertido en espacio LOCAL, antes de aplicar la
## transformación, así que la escala del nodo lo multiplica. Una iglesia puesta
## a escala 21 se lleva un borde de 21 x 0.018 = 0.39 m: un manchón negro en vez
## de una línea. Midiendo la escala se puede dividir y dejar el grosor igual
## para todos, esté el modelo a escala 1 o a escala 30.
func _escala_de(n: Node3D) -> float:
	if not n.is_inside_tree():
		return 1.0
	var e: Vector3 = n.global_transform.basis.get_scale()
	return maxf(maxf(absf(e.x), absf(e.y)), absf(e.z))


func _vestir_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var esc := _escala_de(mi)
	for s in mi.mesh.get_surface_count():
		# El override tiene prioridad; si no hay, el material va en la malla.
		var origen: Material = mi.get_surface_override_material(s)
		if origen == null:
			origen = mi.mesh.surface_get_material(s)
		var nuevo := _convertir(origen, esc)
		if nuevo != null:
			mi.set_surface_override_material(s, nuevo)
			_convertidos += 1


func _vestir_multimesh(mmi: MultiMeshInstance3D) -> void:
	var origen: Material = mmi.material_override
	if origen == null and mmi.multimesh != null and mmi.multimesh.mesh != null:
		origen = mmi.multimesh.mesh.surface_get_material(0)
	var nuevo := _convertir(origen, _escala_de(mmi))
	if nuevo != null:
		mmi.material_override = nuevo
		_convertidos += 1


func _vestir_csg(c: CSGShape3D) -> void:
	if not ("material_override" in c):
		return
	var nuevo := _convertir(c.material_override, _escala_de(c))
	if nuevo != null:
		c.material_override = nuevo
		_convertidos += 1


## Crea (o reutiliza) el ShaderMaterial equivalente a un material estándar.
##
## `escala` es la escala de mundo del nodo que lo va a llevar, y entra en la
## clave de caché: dos objetos con el mismo material de origen pero a escalas
## distintas necesitan contornos distintos, o el más grande se lleva un borde
## proporcionalmente más gordo.
func _convertir(origen: Material, escala := 1.0) -> ShaderMaterial:
	# Ya convertido: no volver a envolverlo.
	if origen is ShaderMaterial:
		return null

	# La escala se redondea a dos decimales para agrupar: si no, cada variación
	# mínima crearía su propio material y la caché no serviría de nada.
	var cubo := snappedf(maxf(escala, 0.01), 0.01)
	var clave: String = "%s@%.2f" % [
		str(origen.get_instance_id()) if origen != null else "__plano__", cubo]
	if _cache.has(clave):
		return _cache[clave]

	var color := Color(1, 1, 1, 1)
	var textura: Texture2D = null
	var translucido := false
	if origen is StandardMaterial3D or origen is ORMMaterial3D:
		color = origen.albedo_color
		textura = origen.albedo_texture
		# Dos señales, porque un material puede traer cualquiera de las dos:
		# color con alpha < 1, o transparencia activada explícitamente.
		translucido = color.a < 1.0 \
			or origen.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED

	var m := ShaderMaterial.new()
	m.shader = SHADER_TRANSLUCIDO if translucido else SHADER

	m.set_shader_parameter("albedo", color)
	if textura != null:
		m.set_shader_parameter("textura_albedo", textura)
		m.set_shader_parameter("usar_textura", true)
	else:
		m.set_shader_parameter("usar_textura", false)

	m.next_pass = _contorno(cubo)

	_cache[clave] = m
	return m


## Contorno por CASCO INVERTIDO: se dibuja el objeto una segunda vez, inflado
## unos milímetros, con las caras frontales descartadas y en negro plano. Sólo
## sobresale por el borde, y eso da la silueta.
##
## Va aparte del contorno por post-proceso: aquel detecta bien las aristas
## internas pero depende de la textura de profundidad, que no siempre trae
## datos utilizables. El casco invertido no depende de ningún buffer, así que
## la silueta sale siempre.
## El grosor se DIVIDE por la escala del nodo, porque `grow_amount` trabaja en
## espacio local y la transformación lo multiplica después. Así CONTORNO_GROSOR
## significa siempre lo mismo —metros de mundo— sin importar a qué escala esté
## puesto el modelo.
var _contornos := {}   # escala -> StandardMaterial3D

func _contorno(escala: float) -> StandardMaterial3D:
	if _contornos.has(escala):
		return _contornos[escala]
	var c := StandardMaterial3D.new()
	c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	c.albedo_color = CONTORNO_COLOR
	c.cull_mode = BaseMaterial3D.CULL_FRONT      # sólo las caras de atrás
	c.grow = true
	c.grow_amount = CONTORNO_GROSOR / maxf(escala, 0.01)
	c.disable_receive_shadows = true
	c.no_depth_test = false
	_contornos[escala] = c
	return c
