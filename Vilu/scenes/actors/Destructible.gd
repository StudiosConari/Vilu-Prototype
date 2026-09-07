extends Node3D

## Prop que se rompe a golpes y deja pasar. Pensado para las barricadas de
## tablones, pero sirve para cualquier modelo importado que tape un camino.
##
## Se cuelga sobre el nodo raíz de la instancia del .glb. El importador deja
## dentro un MeshInstance3D y un StaticBody3D con nombre autogenerado, así que
## ambos se buscan por tipo, nunca por nombre.
##
## El melee del jugador lanza un Area3D con máscara 4 y llama `take_damage` al
## cuerpo que entra. El cuerpo importado viene en capa 1 (entorno) y hay que
## sumarle la 4 para que además sea golpeable, sin quitarle la 1 o el jugador lo
## atravesaría mientras sigue en pie.

const CAPA_ENTORNO  := 1
const CAPA_GOLPEABLE := 4

## Golpes que aguanta antes de romperse.
@export var golpes_necesarios := 3

## Habilidad que se concede al romperlo. Vacío = no concede nada.
@export var otorga := ""

## Texto del cartel al romperlo. Vacío = sin cartel.
@export var mensaje := ""

## Nodo que desaparece al romperse: el modelo del objeto que había encima.
## Se recoge al destruir el prop, no al tocarlo.
@export var recompensa: NodePath

## Nodo al que se avisa al romper esto, con que tenga un método `despertar()`.
## Lo usan los tablones que encierran a Lola: hasta que no caen, ella no se
## mueve del sitio. Mismo trato que el `despierta` del obelisco.
@export var despierta: NodePath

## Otros destructibles que se rompen JUNTO con éste.
##
## Una barricada puede estar hecha de varias piezas apiladas —la de la mina son
## dos tablones, uno sobre otro— y romperlas de a una no es un reto, es tener
## que golpear dos veces lo mismo: el jugador ya entendió qué hay que hacer con
## el primer golpe. Peor todavía si sólo cae el de abajo, porque el de arriba
## queda flotando en el aire.
##
## Vale poner la lista en las dos piezas: la guarda de `_roto` corta la ida y
## vuelta, así que se rompan por donde se rompan caen las dos.
@export var arrastra: Array[NodePath] = []

## Si ya se tenía la habilidad de una partida anterior, el prop arranca roto.
@export var recordar_si_ya_se_obtuvo := true

var _golpes := 0
var _roto   := false
var _cuerpo: StaticBody3D = null
var _malla: MeshInstance3D = null


func _ready() -> void:
	_cuerpo = _buscar(self, "StaticBody3D") as StaticBody3D
	_malla  = _buscar(self, "MeshInstance3D") as MeshInstance3D
	if _cuerpo == null:
		push_warning("Destructible en %s: el modelo no trae cuerpo de colisión" % name)
		return

	_cuerpo.add_to_group("hittable")
	_cuerpo.collision_layer = CAPA_ENTORNO | CAPA_GOLPEABLE
	# El cuerpo recibe el golpe, pero la cuenta y el estado viven aquí: se le
	# cuelga un reenviador mínimo en vez de duplicar la lógica.
	_cuerpo.set_script(preload("res://scenes/actors/DestructibleCuerpo.gd"))
	_cuerpo.set("dueno", self)

	if recordar_si_ya_se_obtuvo and otorga != "" and GameManager.has_ability(otorga):
		_desaparecer_recompensa()
		_romper(false)


func _buscar(n: Node, clase: String) -> Node:
	for c in n.get_children():
		if c.is_class(clase):
			return c
		var hondo := _buscar(c, clase)
		if hondo:
			return hondo
	return null


## Lo llama el reenviador del cuerpo.
func golpear(_dmg: float, _desde: Vector3) -> void:
	if _roto:
		return
	_golpes += 1
	if _golpes >= golpes_necesarios:
		_romper(true)
	else:
		_sacudir()


## Tira abajo el resto de la barricada.
##
## Va ANTES de los efectos y con `_roto` ya puesto: así, si dos piezas se
## apuntan la una a la otra, la vuelta se corta sola en la guarda de `_romper` y
## no hay recursión infinita.
##
## Los escombros y el cartel salen sólo en la pieza que recibió el golpe. Dos
## carteles iguales seguidos se leen como un error, y el sonido de romper por
## duplicado suena a eco.
func _arrastrar_a_los_demas(_con_efecto: bool) -> void:
	for ruta in arrastra:
		var n := get_node_or_null(ruta)
		if n == null or n == self:
			continue
		if n.has_method("romper_sin_efecto"):
			n.call("romper_sin_efecto")


## La rompe en silencio: sin escombros, sin cartel y sin conceder nada.
##
## Es la puerta por la que una pieza de la barricada tira de las demás.
func romper_sin_efecto() -> void:
	_romper(false)


## true una vez roto. Lo consulta lo que exija romperlo antes de dejarse usar:
## el obelisco de la mina, que estaba detrás de una barricada de tablones y se
## podía encender igual desde el otro lado.
func esta_roto() -> bool:
	return _roto


func _sacudir() -> void:
	if _malla == null:
		return
	# Un achatamiento corto: se lee como impacto y no toca el material, así que
	# no hay riesgo de perder la textura importada.
	var base := _malla.scale
	var t := create_tween()
	t.tween_property(_malla, "scale", base * Vector3(1.06, 0.94, 1.06), 0.05)
	t.tween_property(_malla, "scale", base, 0.12)


func _romper(con_efecto: bool) -> void:
	if _roto:
		return
	_roto = true
	_arrastrar_a_los_demas(con_efecto)
	if con_efecto:
		_escombros()
		if otorga != "" and not GameManager.has_ability(otorga):
			GameManager.unlock(otorga)
		if mensaje != "":
			_cartel(mensaje)
		_desaparecer_recompensa()
		_despertar_a_lo_de_detras()
	if _cuerpo:
		_cuerpo.queue_free()
	if _malla:
		_malla.queue_free()


## Sólo se llama al romperlo de verdad. Si el prop arranca roto por una partida
## anterior, lo de detrás se queda quieto: no hubo golpe que lo despertara.
func _despertar_a_lo_de_detras() -> void:
	if despierta.is_empty():
		return
	var n := get_node_or_null(despierta)
	if n == null:
		push_warning("Destructible en %s: no encuentro '%s' para despertar" % [name, despierta])
		return
	if n.has_method("despertar"):
		n.call("despertar")


func _desaparecer_recompensa() -> void:
	if recompensa.is_empty():
		return
	var n := get_node_or_null(recompensa)
	if n == null:
		return
	if not _roto or n is not Node3D:
		n.queue_free()
		return
	# Sube y se apaga: da a entender que el objeto se recogió, en vez de
	# esfumarse de golpe y parecer un fallo.
	var n3 := n as Node3D
	var t := create_tween().set_parallel(true)
	t.tween_property(n3, "position", n3.position + Vector3(0.0, 0.6, 0.0), 0.45)
	t.tween_property(n3, "scale", n3.scale * 0.05, 0.45)
	t.chain().tween_callback(n3.queue_free)


func _escombros() -> void:
	var aabb := _malla.get_aabb() if _malla else AABB(Vector3.ZERO, Vector3.ONE)
	var tam := aabb.size * _malla.scale if _malla else Vector3.ONE
	var color := Color(0.28, 0.18, 0.11)
	for i in 7:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var lado := maxf(tam.length() * 0.06, 0.05)
		bm.size = Vector3(lado, lado * randf_range(0.6, 1.6), lado)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		mi.set_surface_override_material(0, m)
		get_parent().add_child(mi)
		mi.global_position = global_position + Vector3(
			randf_range(-tam.x, tam.x) * 0.3,
			tam.y * randf_range(0.2, 0.8),
			randf_range(-tam.z, tam.z) * 0.3)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		# Sin RigidBody: siete cuerpos físicos por barricada no aportan nada y sí
		# cuestan. Un tween de caída basta para leer el golpe.
		var destino := mi.global_position + Vector3(
			randf_range(-1.0, 1.0), -tam.y * 0.5, randf_range(-1.0, 1.0))
		var t := create_tween().set_parallel(true)
		t.tween_property(mi, "global_position", destino, 0.55)
		t.tween_property(mi, "rotation", mi.rotation + Vector3(randf(), randf(), randf()) * 3.0, 0.55)
		t.chain().tween_callback(mi.queue_free)


func _cartel(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(texto)
