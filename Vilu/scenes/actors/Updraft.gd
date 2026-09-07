@tool
extends Area3D

## Corriente de aire vertical. Sube o baja, según se le diga.
##
## Es `@tool` para que tildar `hacia_abajo` se vea EN EL EDITOR. Sin eso, el
## script no corre ahí y la corriente seguía pintada de azul hasta arrancar el
## juego: había que ejecutar para comprobar si la habías marcado bien, que es
## justo lo que uno no quiere al acomodar un nivel.
##
## ASCENDENTE (por defecto): mientras esté ACTIVA y un personaje con ALAS
## (Emilia) esté dentro planeando (mantiene Espacio), sube. Es una AYUDA: hay
## que tener las alas y hay que querer usarla.
##
## DESCENDENTE (`hacia_abajo`): arrastra hacia abajo a quien entre, tenga alas o
## no y quiera o no. Es una TRAMPA, y por eso no pide nada ni admite planeo —una
## trampa de la que se puede salir planeando no es una trampa—.
##
## En los dos casos el empuje lo aplica PlayerController leyendo `in_updraft` /
## `in_downdraft`. Requiere collision_mask 2.

@export var active := true

## Que la zona que empuja se ajuste sola a la columna que se ve.
##
## Destildalo sólo si de verdad querés que el empuje no coincida con lo que se
## dibuja; en un plataformas eso es casi siempre un fallo, no una decisión.
@export var ajustar_disparador := true

## Hacia dónde tira. Tildado, arrastra hacia abajo en vez de elevar.
##
## Cambia también el aspecto: la malla se pinta con el material rojo, que además
## hace bajar las ráfagas. Sin eso una corriente que tira hacia abajo se vería
## idéntica a una que eleva, y el jugador se metería en ella creyendo que le
## conviene.
@export var hacia_abajo := false:
	set(v):
		hacia_abajo = v
		if is_inside_tree():
			_refresh_visual()

## El material de las descendentes. Se pone solo al tildar `hacia_abajo`.
const MATERIAL_ROJO := preload("res://art_placeholders/mat_viento_descendente.tres")

## La malla de la columna, buscada POR TIPO y no por nombre.
##
## Buscarla como "Mesh" parecía razonable y no lo era: duplicando corrientes en
## el editor, Godot renombra los hijos, y en esta escena hay dos con la malla
## llamada `Mesh2`. Ésas se quedaban sin pintar y sin ocultarse al desactivarse
## —fallaba en silencio, que es lo peor— porque el nodo simplemente no aparecía.
func _malla() -> MeshInstance3D:
	for h in get_children():
		if h is MeshInstance3D:
			return h as MeshInstance3D
	return null


func _ready() -> void:
	_refresh_visual()
	# En el editor sólo se pinta. Enganchar las señales ahí no sirve de nada —no
	# hay jugador— y deja el nodo tocado sin motivo.
	if Engine.is_editor_hint():
		return
	monitoring = true
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if active and body.is_in_group("player"):
		_marcar(body, true)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_marcar(body, false)


## Enciende o apaga la bandera que le toca a esta corriente.
##
## Se apagan LAS DOS al salir, no sólo la suya: una corriente puede cambiar de
## sentido en el editor mientras alguien está dentro, y quedaría la bandera
## vieja encendida para siempre.
func _marcar(body: Node3D, dentro: bool) -> void:
	if "in_updraft" in body:
		body.in_updraft = dentro and not hacia_abajo
	if "in_downdraft" in body:
		body.in_downdraft = dentro and hacia_abajo


func set_active(on: bool) -> void:
	active = on
	_refresh_visual()
	# Refrescar a quien ya esté dentro.
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			_marcar(b, active)


func _refresh_visual() -> void:
	var m := _malla()
	if m == null:
		# Sin malla es un empujón invisible: el jugador no puede aprender una
		# regla que no ve. Se avisa en vez de dejarlo pasar en silencio.
		push_warning("Updraft %s: no tiene malla; empuja sin verse" % name)
		return
	m.visible = active
	# El material sólo se fuerza en las descendentes. Las que suben se quedan con
	# el que tengan puesto en la escena, que puede no ser el de siempre.
	if hacia_abajo and m is GeometryInstance3D:
		(m as GeometryInstance3D).material_override = MATERIAL_ROJO
	_medir_la_altura(m)
	if ajustar_disparador:
		_ajustar_disparador(m)


## Hace que la zona que empuja sea EXACTAMENTE la columna que se ve.
##
## El área y la malla son dos hijos distintos del mismo nodo, así que mover o
## redimensionar uno sin el otro los separa, y en el editor eso pasa sin querer
## todo el tiempo. Medido en el Ojos del Salado: de dieciocho corrientes, once
## estaban descuadradas. Cinco tenían la zona de empuje casi tres veces más alta
## que la columna —te elevaba parado donde no se ve viento—; cuatro la tenían
## 2,17 m más abajo; una era dos metros más ancha, y otra al revés, con columna
## de sobra que no empujaba.
##
## Un viento que empuja donde no se ve es de las cosas más injustas que puede
## haber en un plataformas: el jugador no tiene forma de aprender la regla.
##
## Se ajusta en el script y no a mano en la escena porque a mano dura hasta la
## próxima vez que alguien mueva algo.
func _ajustar_disparador(m: MeshInstance3D) -> void:
	var forma := _forma()
	if forma == null or m.mesh == null:
		return
	# La caja de la malla, expresada en el espacio del área.
	var caja: AABB = m.transform * m.get_aabb()
	var bs := forma.shape as BoxShape3D
	# La forma puede venir COMPARTIDA entre varias corrientes —duplicar un nodo
	# en el editor comparte sus recursos—, y redimensionarla in situ cambiaría
	# también las otras. Se le da una propia a cada una.
	#
	# La marca va sobre la FORMA que se creó, no sobre el nodo: marcando el nodo,
	# cambiarle la forma después lo dejaba creyéndose dueño de una que no era
	# suya, y volvía a redimensionar la compartida. Lo cazó el test.
	if bs == null or bs != _forma_propia:
		bs = BoxShape3D.new() if bs == null else bs.duplicate()
		forma.shape = bs
		_forma_propia = bs
	bs.size = caja.size
	forma.transform = Transform3D(Basis.IDENTITY, caja.get_center())


## La caja que creó ESTA corriente. Sirve para no volver a duplicarla y, sobre
## todo, para no tocar una que sea de otra.
var _forma_propia: BoxShape3D = null


func _forma() -> CollisionShape3D:
	for h in get_children():
		if h is CollisionShape3D:
			return h as CollisionShape3D
	return null


## Le dice al shader cuánto mide ESTA columna.
##
## El shader desvanece las dos puntas usando ese número, así que si no coincide
## con la malla el desvanecido cae donde no toca: una columna de doce metros con
## `altura` en ocho se apaga a media altura y se ve CORTADA.
##
## Hoy TODAS coinciden —el valor está bien puesto a mano en la escena—, así que
## esto no arregla nada: es una red. Sale de la malla que hay, de modo que
## cambiarle el tamaño a una columna en el editor ya no puede descuadrarlo.
func _medir_la_altura(m: MeshInstance3D) -> void:
	var mi := m
	if mi == null or mi.mesh == null:
		return
	# SIN escalar: el shader mide con `VERTEX`, que es la posición en el espacio
	# del modelo. Multiplicando por la escala del nodo el número sale en metros
	# de mundo y no coincide con lo que el shader compara.
	var alto: float = mi.get_aabb().size.y
	if alto > 0.01:
		mi.set_instance_shader_parameter("altura", alto)
