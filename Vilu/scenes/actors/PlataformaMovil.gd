extends Node3D

## Plataforma que va y viene sola entre su sitio y otro punto.
##
## Se cuelga sobre el nodo raíz de la instancia del .glb, igual que Destructible
## o Antorcha. No hay que preparar nada más: encuentra la malla y el cuerpo que
## dejó el importador y los convierte en algo que sí arrastra al que va encima.
##
## El destino se da con un NODO, no con números: se apunta a la plataforma a la
## que tiene que llegar y el recorrido sale solo. Así, si movés cualquiera de
## las dos en el editor, no hay que recalcular nada a mano.

const ENCAJAR := preload("res://scenes/core/EncajarModelo.gd")
## Convertir el cuerpo importado en uno animable es común a todas las
## plataformas, así que vive aparte.
const ANIMABLE := preload("res://scenes/core/CuerpoAnimable.gd")

## Qué parte del camino hasta el destino recorre.
##
## VERTICAL sólo sube y baja: es el ascensor, y no se desplaza aunque el bloque
## de destino esté a un lado. HORIZONTAL sólo se desplaza, manteniendo su altura.
## LIBRE va al destino tal cual, en diagonal.
enum Modo { VERTICAL, HORIZONTAL, LIBRE }

@export var modo: Modo = Modo.VERTICAL

## Adónde tiene que llegar. Admite dos cosas distintas:
##
##  · Otra PLATAFORMA: se para enfrente, a `separacion` de su borde.
##  · Un Marker3D vacío: va hasta él y su centro acaba ahí. Es lo que sirve
##    cuando el sitio de destino no tiene ningún bloque al que apuntar — se
##    añade un Marker3D como hermano y se arrastra a ojo en el editor.
##
## Vacío en VERTICAL = busca sola el bloque más cercano que esté por encima. En
## los otros modos hace falta indicarlo: "el de al lado" es ambiguo.
@export var destino: NodePath

## Radio en el que busca ese vecino, en metros. Sólo para el modo VERTICAL.
@export var radio_de_busqueda := 14.0

## Hueco que queda entre los dos bloques al llegar, en metros.
##
## El viaje no termina ENCIMA del destino sino ENFRENTE: la plataforma se para
## a un paso, y el que va montado cruza. En 0 quedan pegadas. Sólo cuenta en los
## modos HORIZONTAL y LIBRE; el ascensor sube hasta el nivel del otro y ahí no
## hay nada que separar.
@export_range(0.0, 6.0, 0.05) var separacion := 0.6

## Recorrido a mano, cuando no se quiere apuntar a otro nodo. En metros y en
## EJES DEL MUNDO, no del bloque.
##
## Esto último importa: estos props vienen girados, y si el desplazamiento se
## interpretara en los ejes del nodo, un (-8, 0, 0) que uno escribe pensando
## "ocho metros a la izquierda" saldría torcido esos mismos grados. Se convierte
## igual que el recorrido hacia un destino, así que el resultado no depende de
## cómo esté rotado el bloque.
@export var recorrido_suelto := Vector3(0.0, 2.5, 0.0)

@export_group("Ritmo")
## Segundos que tarda el viaje. Otro tanto para volver.
@export_range(0.5, 30.0, 0.1) var duracion := 3.0

## Segundos parado en cada extremo.
##
## No es adorno: sin pausa hay que subirse en el instante exacto en que la
## plataforma pasa por el sitio bueno. Con una espera a cada lado el salto deja
## de ser cuestión de reflejos.
@export_range(0.0, 10.0, 0.1) var espera := 1.0

## Desfase inicial del ciclo, en segundos. Para que varias plataformas seguidas
## no se muevan todas a la vez.
@export var desfase := 0.0

@export_group("Ruta alterna")
## Segundo recorrido, al que se cambia llamando a `cambiar_ruta()`.
##
## Se mide desde el EXTREMO del primero: la plataforma se queda donde terminaba
## el trayecto viejo y desde ahí recorre éste. En metros y en ejes del mundo,
## igual que `recorrido_suelto`.
##
## Sirve para que algo del nivel —un interruptor, una palanca, un cubo que se
## golpea— redirija la plataforma sin que haya que duplicar el nodo.
@export var recorrido_alterno := Vector3.ZERO

var _cuerpo: AnimatableBody3D = null
var _base := Vector3.ZERO
var _lejos := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	_cuerpo = ANIMABLE.convertir(self, "Plataforma")
	if _cuerpo == null:
		push_warning("PlataformaMovil en %s: el modelo no trae ni malla ni colisión" % name)
		set_physics_process(false)
		return
	_base = _cuerpo.position
	_lejos = _base + _recorrido()
	_t = desfase
	# Explícito: si el guion se cuelga en caliente Godot no engancha solo la
	# llamada de física.
	set_physics_process(true)


## Cuánto tiene que desplazarse, en el espacio local de este nodo.
func _recorrido() -> Vector3:
	var meta := _nodo_destino()
	if meta == null:
		return _a_local(recorrido_suelto)

	var d := meta.global_position - global_position
	match modo:
		Modo.VERTICAL:
			# Se compara la altura de la CARA DE ARRIBA, no la del origen: dos
			# bloques de distinto grosor con el mismo origen no se pisan a la
			# misma altura.
			var alto: float = _techo_de(meta) - _techo_de(self)
			d = Vector3(0.0, alto, 0.0)
		Modo.HORIZONTAL:
			d.y = 0.0
			d = _hasta_quedar_enfrente(d, meta)
		Modo.LIBRE:
			d = _hasta_quedar_enfrente(d, meta)
	if d.length() < 0.05:
		return _a_local(recorrido_suelto)
	return _a_local(d)


## Recorta el viaje para quedar ENFRENTE del destino, no encima.
##
## Se descuenta el medio ancho de cada bloque en la dirección del viaje, medido
## sobre sus cajas envolventes, más la separación pedida. Hacerlo con las cajas
## y no con un número a mano es lo que permite mezclar bloques de distinto
## tamaño sin recalcular nada: cambiá un modelo por otro más ancho y el punto de
## parada se corrige solo.
func _hasta_quedar_enfrente(d: Vector3, meta: Node3D) -> Vector3:
	var largo := d.length()
	if largo < 0.05:
		return d
	# Un destino SIN MALLA -un Marker3D- no es una plataforma delante de la que
	# pararse: es un punto al que ir. Se viaja entero y el centro acaba ahí.
	# Sirve para mandarla a un sitio donde no hay ningún bloque al que apuntar.
	if ENCAJAR.envolvente(meta).size.length() < 0.001:
		return d
	var dir := d / largo
	var freno: float = _medio_ancho(self, dir) + _medio_ancho(meta, dir) + separacion
	# Nunca al revés: si los bloques ya se tocan, se queda donde está.
	return dir * maxf(largo - freno, 0.0)


## Medio ancho del bloque en esa dirección, en METROS DE MUNDO.
##
## `envolvente` devuelve la caja en ejes del NODO y sin su escala aplicada, así
## que no se puede usar tal cual: `bloques_de_espuma_morada21` está puesto a
## 0.37 y su caja local mide 4.91, cuando en el mundo ocupa 1.82. Proyectando
## los ejes de la base —que sí llevan rotación y escala— sale el ancho real.
##
## Sólo cuentan X y Z: el viaje es horizontal y la altura no estorba.
func _medio_ancho(n: Node3D, dir: Vector3) -> float:
	var caja := ENCAJAR.envolvente(n)
	if caja.size.length() < 0.001:
		return 0.0
	var b := n.global_transform.basis
	var m := caja.size * 0.5
	return absf(dir.dot(b.x * m.x)) + absf(dir.dot(b.z * m.z))


## Pasa un desplazamiento de ejes del mundo a los del nodo.
##
## El cuerpo cuelga de esta raíz, así que su `position` va en el espacio de la
## raíz. Sumarle un vector de mundo sin convertir lo mandaría torcido tantos
## grados como esté girado el bloque.
func _a_local(mundo: Vector3) -> Vector3:
	return global_transform.basis.inverse() * mundo


func _nodo_destino() -> Node3D:
	if not destino.is_empty():
		return get_node_or_null(destino) as Node3D
	if modo != Modo.VERTICAL:
		return null
	# El vecino más cercano que esté por encima. Se mira entre los hermanos, que
	# es donde están los demás bloques del camino.
	var padre := get_parent()
	if padre == null:
		return null
	var mio := global_position
	var mejor: Node3D = null
	var mejor_d := radio_de_busqueda
	for h in padre.get_children():
		if h == self or not (h is Node3D):
			continue
		var otro := h as Node3D
		if otro.global_position.y - mio.y < 0.5:
			continue                      # no está por encima: no sirve de meta
		var plano := Vector2(otro.global_position.x - mio.x, otro.global_position.z - mio.z)
		if plano.length() < mejor_d:
			mejor_d = plano.length()
			mejor = otro
	return mejor


## Altura de la cara superior de un modelo, en el mundo.
func _techo_de(n: Node3D) -> float:
	var caja := ENCAJAR.envolvente(n)
	if caja.size.y <= 0.001:
		return n.global_position.y
	return n.global_position.y + caja.end.y


## Cambia al segundo recorrido. El extremo del viejo pasa a ser el arranque.
##
## Reengancha el ciclo desde cero para que salga andando desde donde está, en
## vez de dar un salto al punto que le tocaría del ciclo viejo.
func cambiar_ruta() -> void:
	if _cuerpo == null or recorrido_alterno == Vector3.ZERO:
		return
	if _ruta_cambiada:
		return
	_ruta_cambiada = true
	_base = _lejos
	_lejos = _base + _a_local(recorrido_alterno)
	_cuerpo.position = _base
	_t = 0.0


## Para que no se pueda encadenar el cambio dos veces con dos golpes.
var _ruta_cambiada := false


func _physics_process(delta: float) -> void:
	_t += delta
	var ciclo := duracion * 2.0 + espera * 2.0
	var f: float = fmod(_t, ciclo)
	var k := 0.0
	if f < duracion:
		k = smoothstep(0.0, 1.0, f / duracion)          # yendo
	elif f < duracion + espera:
		k = 1.0                                          # esperando al otro lado
	elif f < duracion * 2.0 + espera:
		k = smoothstep(0.0, 1.0, 1.0 - (f - duracion - espera) / duracion)
	else:
		k = 0.0                                          # esperando en su sitio
	_cuerpo.position = _base.lerp(_lejos, k)
