extends StaticBody3D

## Cubo que se activa tras recibir 'hits_needed' golpes (melee de Emilia o flechas
## de Benjamín). La ALTURA del cubo debería reflejar los golpes (1 = bajo … 4 =
## alto). Grupo "hittable" + capa 4 para que lo alcancen melee y flechas.
##
## Dos modos:
##  · latch (por defecto): al alcanzar hits_needed queda activado y los golpes
##    extra se ignoran. Sirve para cubos que disparan un mecanismo (ascensores).
##  · reset_on_overhit: hay que golpearlo EXACTAMENTE hits_needed veces. Si te
##    pasás (un golpe de más), se reinicia a cero y hay que empezar de nuevo. Así
##    el jugador debe acertar la cantidad justa en cada cubo.

const MUDA := preload("res://scenes/core/MudaDeAsset.gd")

signal activated      # pasó a estado "satisfecho" (justo hits_needed)
signal deactivated    # estaba satisfecho y se reinició (solo en reset_on_overhit)

const INTERACT_SCR := preload("res://scenes/actors/Interactable.gd")

## Cómo se acciona.
##
##  · GOLPE: melee o flechas, `hits_needed` veces. El de siempre.
##  · INTERACTUAR: acercarse y pulsar [E]. Se acciona de una y `hits_needed`
##    deja de contar.
##
## El modo sólo cambia CÓMO se enciende: sigue emitiendo `activated` igual, así
## que lo que esté enganchado a la señal —el ascensor del compañero— no se entera
## de nada.
enum Activacion { GOLPE, INTERACTUAR }
@export var activacion: Activacion = Activacion.GOLPE

## Texto del cartel del HUD al acercarse. Sólo en modo INTERACTUAR.
@export var prompt := "[E] Activar"

## Radio de la zona de interacción, en metros. Sólo en modo INTERACTUAR.
@export var alcance := 2.5

## Color al que se enciende al accionarse. Sólo en modo INTERACTUAR.
@export var color_activo := Color(0.55, 0.85, 1.0)

## Versión del modelo a la que se cambia al activarlo.
##
## El obelisco que llevan encima estos cubos tiene una gemela con la energía
## verde. Vacío = no se cambia de modelo y sólo se enciende la luz.
@export var modelo_activo: PackedScene

## Qué nodo se cambia. Vacío = este mismo. Acá se apunta al obelisko que cuelga
## del cubo: lo que muda es el obelisco, no la baldosa que se pisa.
@export var nodo_a_mudar: NodePath

## Cuánto dura el destello que tapa el cambio, en segundos. El modelo cambia
## de golpe; esto sólo es el fogonazo que hace que no se vea el corte.
@export var muda_segundos := 0.35

@export var hits_needed := 1
@export var reset_on_overhit := false

var _hits := 0
var _satisfied := false
var _mat: StandardMaterial3D
var _luz: OmniLight3D = null

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	if _mesh:
		_mesh.material_override = _mat
	_refresh_color()
	if activacion == Activacion.INTERACTUAR:
		_montar_zona()
		return
	add_to_group("hittable")
	collision_layer = 4
	collision_mask = 0


## Zona de interacción, para el modo [E].
##
## No entra al grupo "hittable" ni toma la capa 4: si lo hiciera seguiría siendo
## un blanco válido para el melee y las flechas, y se podría accionar de las dos
## formas. La idea del modo es que sólo valga una.
func _montar_zona() -> void:
	collision_layer = 0
	var zona := Area3D.new()
	zona.collision_layer = 0
	zona.collision_mask = 2          # capa de los jugadores
	zona.set_script(INTERACT_SCR)
	zona.prompt = prompt
	add_child(zona)

	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = alcance
	cs.shape = esfera
	zona.add_child(cs)

	zona.interacted.connect(_al_interactuar)


func _al_interactuar(jugador: Node) -> void:
	if _satisfied:
		return
	_hits = maxi(hits_needed, 1)     # de una: el número de golpes no cuenta acá
	_apply_state()
	# Retirar la zona: sin esto el cartel del HUD se queda puesto al lado de algo
	# que ya no hace nada.
	if jugador and jugador.has_method("clear_interactable"):
		for h in get_children():
			if h is Area3D:
				jugador.clear_interactable(h)
	for h in get_children():
		if h is Area3D:
			h.queue_free()


# Firma compatible con lo que llaman melee/flecha: take_damage(dmg, from, force, burn).
func take_damage(_dmg := 0.0, _from := Vector3.ZERO, _force := 0.0, _burn := false) -> void:
	if activacion == Activacion.INTERACTUAR:
		return   # este se acciona con [E]; los golpes no cuentan
	if _satisfied and not reset_on_overhit:
		return   # latch: ya activado, ignora golpes extra
	_hits += 1
	if reset_on_overhit and _hits > hits_needed:
		_hits = 0   # te pasaste -> reinicia
	_apply_state()


func _apply_state() -> void:
	var was := _satisfied
	if reset_on_overhit:
		_satisfied = (_hits == hits_needed)
	else:
		_satisfied = (_hits >= hits_needed)
	_refresh_color()
	if _satisfied and not was:
		if activacion == Activacion.INTERACTUAR:
			_encender()
		activated.emit()
	elif was and not _satisfied:
		deactivated.emit()


## Confirmación visual para el modo [E].
##
## El de GOLPE se tiñe de verde con `_refresh_color`, pero eso necesita una malla
## propia y aquí el cuerpo sólo lleva colgado un modelo importado, cuyos
## materiales no se tocan. Una luz encima resuelve lo mismo sin ensuciar el
## modelo, y de paso se ve desde el otro lado del puzzle: el jugador que acciona
## el obelisco necesita saber que le abrió el ascensor a su compañero, que está
## lejos.
func _encender() -> void:
	if _luz != null:
		return
	_luz = OmniLight3D.new()
	_luz.light_color = color_activo
	_luz.omni_range = 6.0
	_luz.light_energy = 0.0
	add_child(_luz)
	_luz.position.y = 1.4
	create_tween().tween_property(_luz, "light_energy", 2.6, 0.4)
	var quien: Node3D = self
	if not nodo_a_mudar.is_empty():
		quien = get_node_or_null(nodo_a_mudar) as Node3D
	MUDA.mudar(quien, modelo_activo, muda_segundos)


func _refresh_color() -> void:
	if _mat == null:
		return
	if _satisfied:
		_mat.albedo_color = Color(0.2, 0.9, 0.3)
		_mat.emission_enabled = true
		_mat.emission = Color(0.1, 0.55, 0.15)
	else:
		_mat.emission_enabled = false
		var t := float(_hits) / float(maxi(1, hits_needed))
		_mat.albedo_color = Color(0.85, 0.25, 0.25).lerp(Color(0.9, 0.85, 0.2), t)


func is_done() -> bool:
	return _satisfied


func is_satisfied() -> bool:
	return _satisfied
