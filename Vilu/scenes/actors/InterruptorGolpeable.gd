extends Node3D

## Prop que al recibir un golpe acciona algo del nivel.
##
## Se cuelga sobre el nodo raíz de la instancia del .glb. El importador de glTF
## deja dentro un StaticBody3D con nombre autogenerado, así que se busca por
## tipo, nunca por nombre.
##
## CÓMO LLEGA EL GOLPE. El melee del jugador lanza un Area3D con máscara 4 y
## llama `take_damage` al cuerpo que entra; las flechas hacen lo mismo. El cuerpo
## importado viene en la capa 1 (entorno) y hay que SUMARLE la 4 para que además
## sea golpeable, sin quitarle la 1 o el jugador lo atravesaría. El reenviador
## que lleva el golpe hasta acá es el mismo que usa Destructible.
##
## Es deliberadamente genérico: no sabe nada de plataformas. Llama a un método
## por nombre sobre el nodo que se le indique, así que sirve igual para redirigir
## una plataforma, abrir una puerta o despertar a algo.

const CAPA_ENTORNO   := 1
const CAPA_GOLPEABLE := 4
const REENVIADOR := preload("res://scenes/actors/DestructibleCuerpo.gd")
const MUDA := preload("res://scenes/core/MudaDeAsset.gd")

## Nodo al que avisa.
@export var objetivo: NodePath

## Método que le llama. Tiene que existir en el objetivo o no pasa nada.
@export var metodo := "cambiar_ruta"

## Golpes que aguanta antes de accionarse.
@export var golpes_necesarios := 1

## Una vez accionado deja de responder. En false se puede volver a golpear.
@export var una_sola_vez := true

## Cartel del HUD al accionarse. Vacío = sin cartel.
@export var mensaje := ""

## Color al que se enciende cuando ya está accionado, para que se vea de lejos
## que ese interruptor ya está usado.
##
## Antes de accionarlo el cubo se ve tal cual es, sin nada encima. Se probó a
## envolverlo en un halo para que se distinguiera de lejos y quedó peor: seis
## globos celestes opacos flotando en mitad del cráter, tapando el nivel.
@export var color_activo := Color(0.45, 0.85, 1.0)

## Fuerza de la luz al accionarlo.
@export var brillo := 3.4

## Hasta dónde llega esa luz, en metros.
@export var alcance := 7.0

## Versión del modelo a la que se cambia al accionarlo.
##
## Los cubos del Isluga tienen una gemela con la energía verde. Vacío = no se
## cambia de modelo y sólo se enciende la luz, que es lo que hace cualquier otro
## interruptor del juego.
@export var modelo_activo: PackedScene

## Cuánto dura el destello que tapa el cambio, en segundos. El modelo cambia
## de golpe; esto sólo es el fogonazo que hace que no se vea el corte.
@export var muda_segundos := 0.35

var _golpes := 0
var _usado := false
var _cuerpo: StaticBody3D = null
var _luz: OmniLight3D = null


func _ready() -> void:
	_cuerpo = _buscar(self, "StaticBody3D") as StaticBody3D
	if _cuerpo == null:
		push_warning("InterruptorGolpeable en %s: el modelo no trae cuerpo de colisión" % name)
		return
	_cuerpo.add_to_group("hittable")
	_cuerpo.collision_layer = CAPA_ENTORNO | CAPA_GOLPEABLE
	# El cuerpo recibe el golpe, pero la cuenta y el estado viven acá: se le
	# cuelga un reenviador mínimo en vez de duplicar la lógica.
	_cuerpo.set_script(REENVIADOR)
	_cuerpo.set("dueno", self)


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
	if _usado and una_sola_vez:
		return
	_golpes += 1
	if _golpes < golpes_necesarios:
		_sacudir()
		return
	_golpes = 0
	_usado = true
	_accionar()


func _accionar() -> void:
	Sfx.play_at("hit", global_position, -2.0, 0.7)
	_encender()
	if mensaje != "":
		_cartel(mensaje)
	if objetivo.is_empty():
		return
	var n := get_node_or_null(objetivo)
	if n == null:
		push_warning("InterruptorGolpeable en %s: no encuentro '%s'" % [name, objetivo])
		return
	if n.has_method(metodo):
		n.call(metodo)
	else:
		push_warning("InterruptorGolpeable en %s: %s no tiene '%s'" % [name, n.name, metodo])


## true una vez accionado. Lo consulta lo que dependa de VARIOS interruptores:
## así no tiene que llevar una cuenta de avisos, que se descuadra si uno avisa
## dos veces.
func esta_usado() -> bool:
	return _usado


## Achatamiento corto: se lee como impacto y no toca el material, así que no hay
## riesgo de perder la textura importada.
func _sacudir() -> void:
	var base := scale
	var t := create_tween()
	t.tween_property(self, "scale", base * Vector3(1.08, 0.92, 1.08), 0.05)
	t.tween_property(self, "scale", base, 0.14)


## Ya accionado: enciende una luz azul, para que se vea de lejos que ese
## interruptor ya está usado.
##
## El azul es a propósito: el cráter del Isluga es naranja de lado a lado, y el
## naranja que tenía antes se perdía dentro de la lava. En esa paleta el azul es
## el color más lejano que hay, y por eso se nota.
func _encender() -> void:
	if _luz != null:
		return
	var f := global_transform.basis.get_scale()
	_luz = OmniLight3D.new()
	_luz.light_color = color_activo
	_luz.omni_range = alcance / maxf(f.y, 0.001)
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	add_child(_luz)
	_luz.position.y = 0.8 / maxf(f.y, 0.001)
	create_tween().bind_node(self).tween_property(_luz, "light_energy", brillo, 0.35)
	MUDA.mudar(self, modelo_activo, muda_segundos)


func _cartel(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner(texto)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			# El HUD se vuelve a buscar acá dentro en vez de capturarlo: una lambda que
			# captura un nodo y sobrevive a que lo liberen da "Lambda capture at index 0
			# was freed", aunque se compruebe is_instance_valid antes de usarlo.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())


## Agranda el blanco sin agrandar el modelo.
##
## El bloque mide 0.94 m y hay que acertarle de lejos, esquivando una muralla
## que lo tapa parte del tiempo: con la colisión justa del modelo cuesta
## demasiado. Se le añade una caja invisible alrededor, sólo en la capa de lo
## golpeable, así que no estorba al caminar ni cambia nada más.
func agrandar_blanco(margen: float) -> void:
	if _cuerpo == null or margen <= 0.0:
		return
	if _cuerpo.has_node("MargenDeGolpe"):
		return
	var lado := 0.0
	for h in _cuerpo.get_children():
		if h is CollisionShape3D and (h as CollisionShape3D).shape != null:
			var ab := (h as CollisionShape3D).shape.get_debug_mesh().get_aabb()
			lado = maxf(lado, maxf(ab.size.x, maxf(ab.size.y, ab.size.z)))
	if lado <= 0.0:
		return
	var caja := CollisionShape3D.new()
	caja.name = "MargenDeGolpe"
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * (lado + margen * 2.0)
	caja.shape = forma
	_cuerpo.add_child(caja)
