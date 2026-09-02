extends Node3D

## Botón que sólo cede a la EMBESTIDA del guanaco de Benjamín (tecla G).
##
## A propósito NO se mete al grupo "hittable" ni recibe `golpear`: una flecha no
## lo activa, y ésa es toda la diferencia con InterruptorGolpeable, que sí es
## para flechazos. Si algún día se quisiera uno que acepte las dos cosas, hay
## que ponerle los dos guiones, no aflojar éste.
##
## El guanaco no es un cuerpo físico —avanza desplazando su posición—, así que
## no hay colisión que escuchar. Se comprueba la cercanía mientras embiste, que
## es exactamente lo que él hace para dañar enemigos.

signal activado

## Radio de golpe alrededor del botón, en metros.
@export var radio := 2.6
## A quién avisar, y con qué método. Se puede dejar vacío y usar la señal.
@export var objetivo: NodePath
@export var metodo := ""
@export var mensaje := ""
@export var una_sola_vez := true
@export var color_activo := Color(1.0, 0.65, 0.2)

var _usado := false
var _luz: OmniLight3D = null


func _ready() -> void:
	add_to_group("boton_guanaco")


func _process(_delta: float) -> void:
	if _usado and una_sola_vez:
		return
	for g in get_tree().get_nodes_in_group("guanaco_companion"):
		if not (g is Node3D) or not g.has_method("esta_embistiendo"):
			continue
		if not g.call("esta_embistiendo"):
			continue
		if (g as Node3D).global_position.distance_to(global_position) <= radio:
			_accionar()
			return


func _accionar() -> void:
	if _usado and una_sola_vez:
		return
	_usado = true
	_encender()
	if mensaje != "":
		_aviso(mensaje)
	activado.emit()
	if metodo != "" and not objetivo.is_empty():
		var o := get_node_or_null(objetivo)
		if o != null and o.has_method(metodo):
			o.call(metodo)


func esta_usado() -> bool:
	return _usado


## Se le nota que ya fue: se le enciende una luz al lado.
##
## Antes esto le reemplazaba el material por un color plano emisivo, y eso
## BORRABA la textura del modelo: el botón se convertía en una mancha amarilla.
## Una luz avisa igual y no toca el modelo, que es lo mismo que hace el
## interruptor de flecha.
func _encender() -> void:
	if _luz != null:
		return
	_luz = OmniLight3D.new()
	_luz.light_color = color_activo
	_luz.omni_range = 4.5
	_luz.light_energy = 0.0
	add_child(_luz)
	# La escala del modelo se descuenta, o la luz se iría lejos en los que están
	# agrandados.
	var f := global_transform.basis.get_scale()
	_luz.position.y = 0.8 / maxf(f.y, 0.001)
	create_tween().tween_property(_luz, "light_energy", 2.2, 0.35)


func _primera_malla(n: Node) -> MeshInstance3D:
	for h in n.get_children():
		if h is MeshInstance3D:
			return h
		var hondo := _primera_malla(h)
		if hondo != null:
			return hondo
	return null


func _aviso(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_banner"):
		hud.show_banner(texto)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			# El HUD se vuelve a buscar acá dentro en vez de capturarlo: una lambda
			# que captura un nodo y sobrevive a que lo liberen da "Lambda capture at
			# index 0 was freed", aunque se compruebe is_instance_valid antes.
			var h := get_tree().get_first_node_in_group("hud")
			if h != null and h.has_method("clear_banner"):
				h.clear_banner())
