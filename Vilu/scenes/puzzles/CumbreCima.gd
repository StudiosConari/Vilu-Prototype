extends Node3D

## Beat 7 — Cumbre multinivel cooperativa:
##  0) Puente con GUANACO (Benjamín montado en la placa lo fija) para cruzar a MidLedge.
##  1) CORRIENTE ascendente: Emilia planea (mantiene Espacio) y sube a Platform_1.
##     Al llegar arma la CUERDA (Rope1); Benjamín pulsa E en la base y sube.
##  2) PLATAFORMA MÓVIL: Benjamín MONTADO (guanaco) se para sobre ella y lo lleva
##     a Platform_2.
##  3) CORRIENTE 2: Emilia sube a la plataforma FINAL y arma la CUERDA (Rope2);
##     Benjamín sube con E. Cuando LOS DOS están en la cima → Beat 7.

const GUARDIAN_SCR := preload("res://scenes/actors/GuardianOjosSalado.gd")

signal reached_summit

@export var advance_to_beat := 7

var _solved := false
var _bridge_latched := false
var _bridge_state := -1
var _on_final := 0

@onready var _mount_plate: Area3D = get_node_or_null("MountPlate")
@onready var _bridge_mesh: Node3D = get_node_or_null("Bridge/Mesh")
@onready var _bridge_shape: CollisionShape3D = get_node_or_null("Bridge/Shape")
@onready var _p1_trigger: Area3D = get_node_or_null("Platform1Trigger")
@onready var _rope1: Area3D = get_node_or_null("Rope1")
@onready var _final_trigger: Area3D = get_node_or_null("FinalTrigger")
@onready var _rope2: Area3D = get_node_or_null("Rope2")
@onready var _updraft2: Node = get_node_or_null("Updraft2")


func _ready() -> void:
	_set_bridge(false)
	if _p1_trigger:
		_p1_trigger.body_entered.connect(_on_platform1_reached)
	if _final_trigger:
		_final_trigger.body_entered.connect(_on_final_enter)
		_final_trigger.body_exited.connect(_on_final_exit)
	# La corriente del final YA NO la abre el `ArrowSwitch`. Ese nodo del greybox
	# quedó sin malla —su guion busca un hijo "Mesh" que no existe—, así que era
	# un blanco invisible, y encima su caja caía 0.8 m por encima de un bloque
	# visible que hace otra cosa: imposible de adivinar jugando. Ahora la abren
	# los dos personajes al pisar juntos la última pasarela; ver _vigilar_corriente_final.
	_pasarela_final = find_child(PASARELA_FINAL, true, false) as Node3D
	if _pasarela_final == null:
		push_warning("Cumbre: no encuentro la pasarela final %s" % PASARELA_FINAL)
	_armar_pasarelas_mortales()
	_arrancar_recorridos()
	_armar_interruptores()
	_vestir_corrientes()
	# Al reaparecer tras una caída, la plataforma vuelve al principio: si se
	# quedara a mitad de camino no habría forma de volver a subirse.
	var juego := get_tree().get_first_node_in_group("game")
	if juego != null and juego.has_signal("jugador_reaparecio"):
		juego.jugador_reaparecio.connect(reiniciar_plataforma_principal)
	_hint("Cumbre: cruzá el puente con el guanaco. Benjamín le dispara al bloque para soltar la plataforma y se sube; los interruptores de embestida la hacen doblar. Al final, LOS DOS sobre la última pasarela abren la corriente: Emilia sube (Espacio) y le tira la cuerda a Benjamín (E).")
	_spawn_guardian()


## Las dos pasarelas que no se pueden pisar: tocarlas devuelve al checkpoint.
##
## Van por RUTA y no por nombre suelto. En la escena hay DOS nodos llamados
## `camino_de_ladrillos_de_piedra3`: el de acá y el de `FinalTrigger`, que es la
## plataforma del Guardián. Buscándolos por nombre, `find_child` recorría el
## árbol entero y devolvía el primero —el del Guardián, que está antes—, así que
## la trampa quedaba puesta en la plataforma final: pisarla para hablar con él te
## echaba de vuelta al principio, y la pasarela mortal de verdad no hacía nada.
##
## No se les quita la colisión: hay que poder pisarlas para que la trampa se
## note, igual que en la del oro.
const PASARELAS_MORTALES := ["Plataforma/camino_de_ladrillos_de_piedra3",
	"Plataforma/camino_de_ladrillos_de_piedra4"]

## Marcador al que se vuelve al pisar una pasarela mortal: la bifurcación de los
## dos caminos. Si no está en la escena se cae al `PlayerSpawn` del principio.
const CHECKPOINT := "CheckpointBifurcacion"

var _pasarelas: Array = []
var _reiniciando := false


func _armar_pasarelas_mortales() -> void:
	for ruta in PASARELAS_MORTALES:
		var n := get_node_or_null(NodePath(ruta)) as Node3D
		if n == null:
			push_warning("Cumbre: no encuentro la pasarela '%s'" % ruta)
			continue
		_pasarelas.append(n)
	print("[cumbre] pasarelas mortales: %s"
		% ", ".join(PackedStringArray(_pasarelas.map(
			func(x: Node3D) -> String: return str(get_path_to(x))))))


## Se comprueba QUÉ PISA el jugador, no en qué caja está.
##
## Es lo mismo que hace TrampaDelOro, y por el mismo motivo: estas pasarelas
## están pegadas a otras plataformas legítimas, así que un área envolvente
## dispararía estando en la de al lado.
func _vigilar_pasarelas() -> void:
	if _reiniciando or _pasarelas.is_empty():
		return
	var p := _jugador_activo()
	if p == null:
		return
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return
	var desde: Vector3 = p.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 1.6)
	q.collision_mask = 1
	if p is CollisionObject3D:
		q.exclude = [(p as CollisionObject3D).get_rid()]
	var r := esp.intersect_ray(q)
	if r.is_empty():
		return
	for pas: Node3D in _pasarelas:
		if _es_parte_de(r["collider"], pas):
			_reiniciar_intento()
			return


func _reiniciar_intento() -> void:
	_reiniciando = true
	var juego := get_tree().get_first_node_in_group("game")
	# El checkpoint de la bifurcación si está puesto; si no, el principio.
	var marca := get_node_or_null(CHECKPOINT) as Node3D
	if marca != null:
		_hint("Esa pasarela no aguanta. Volvés a la bifurcación.")
	else:
		marca = get_node_or_null("PlayerSpawn") as Node3D
		_hint("Esa pasarela no aguanta. Volvés al principio.")
	if juego != null and juego.has_method("_colocar_en") and marca != null:
		juego.call("_colocar_en", marca.global_position)
		# `_colocar_en` ya deja ahí el punto seguro del juego, así que caerse
		# después tampoco devuelve al principio: las dos formas de fallar
		# cuestan lo mismo.
	reiniciar_plataforma_principal()
	get_tree().create_timer(1.0).timeout.connect(func() -> void: _reiniciando = false)


func _jugador_activo() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and "active" in p and p.active:
			return p
	return null


func _es_parte_de(nodo: Node, raiz: Node) -> bool:
	var n := nodo
	while n != null:
		if n == raiz:
			return true
		n = n.get_parent()
	return false


func _process(_delta: float) -> void:
	_vigilar_pasarelas()
	_vigilar_plataforma_principal()
	_vigilar_corriente_final()
	# Etapa 0: el puente se fija al pisarlo un personaje MONTADO (guanaco).
	if _bridge_latched:
		return
	if _mount_plate:
		for b in _mount_plate.get_overlapping_bodies():
			if b.is_in_group("player") and "mounted" in b and b.mounted:
				_bridge_latched = true
				_set_bridge(true)
				break


## Cuánto se hunde el puente bajo la lava mientras está desactivado, en metros.
const PUENTE_HUNDIDO := 14.0
## Lo que tarda en emerger.
const PUENTE_SUBIDA := 1.8

## Dónde está el puente cuando está arriba. Se anota en _ready, antes de
## hundirlo, así podés moverlo en el editor y sigue valiendo.
var _puente_arriba := Vector3.ZERO


## Sube o hunde el puente.
##
## Antes esto sólo conmutaba `visible` de un nodo llamado "Bridge/Mesh" y
## desactivaba una caja de colisión. Ese Mesh era del greybox y ya no existe —lo
## reemplazaste por el modelo `camino_de_ladrillos_de_piedra2`—, así que la
## búsqueda daba nulo, el puente se veía SIEMPRE y nunca se ocultaba.
##
## Ahora se mueve de verdad: aparece emergiendo de la lava al activarse el
## primer interruptor, que es el que pisa Benjamín montado en el guanaco.
func _set_bridge(up: bool) -> void:
	var s := 1 if up else 0
	if s == _bridge_state:
		return
	_bridge_state = s

	var puente := get_node_or_null("Bridge") as Node3D
	if puente != null:
		if _puente_arriba == Vector3.ZERO:
			_puente_arriba = puente.position
		var destino: Vector3 = _puente_arriba if up \
			else _puente_arriba - Vector3(0.0, PUENTE_HUNDIDO, 0.0)
		if up:
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(puente, "position", destino, PUENTE_SUBIDA)
		else:
			puente.position = destino   # al arrancar, hundido y sin animación

	# El modelo trae su propia colisión de malla; esta caja es la del greybox y
	# se sigue conmutando por si alguna escena todavía la usa.
	if _bridge_shape:
		_bridge_shape.set_deferred("disabled", not up)


func _on_platform1_reached(body: Node3D) -> void:
	if body.is_in_group("player") and _rope1 and _rope1.has_method("arm"):
		_rope1.arm(true)


func _on_final_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _rope2 and _rope2.has_method("arm"):
		_rope2.arm(true)
	_on_final += 1
	if _on_final >= 2:
		_solve()


func _on_final_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_final = max(0, _on_final - 1)


func _solve() -> void:
	if _solved:
		return
	_solved = true
	# Llegar a la cima cierra las dos misiones del Ojos del Salado: subir y
	# activarlo. Aquí no hay dos hitos separados, el puzzle termina de una vez.
	Misiones.hecho("ojos_cima")
	Misiones.hecho("ojos_volcan")
	_hint("¡Cima de VILU alcanzada por los dos!")
	if GameManager.get_beat() < advance_to_beat:
		GameManager.set_beat(advance_to_beat)
	GameManager.conceder("ojos_salado")
	reached_summit.emit()


func is_solved() -> bool:
	return _solved


## Le cuelga la lógica del Guardián a la estatua puesta en la escena.
##
## Antes creaba una cápsula del greybox en (36, 13.2, -17), coordenadas del nivel
## viejo. Con el nivel rehecho —que va de y≈100 a y≈118— eso queda unos 105 m por
## debajo, en el vacío: el Guardián existía, con su diálogo y su mapa de los
## volcanes, pero era imposible llegar a él.
##
## Si algún día no hay estatua se vuelve a la cápsula, pero colocada junto al
## disparador final y no en las coordenadas viejas.
func _spawn_guardian() -> void:
	var estatua := find_child("guardian_del_ojos_del_salado*", true, false) as Node3D
	if estatua != null:
		estatua.set_script(GUARDIAN_SCR)
		estatua.call("_ready")   # el nodo ya está en el árbol: no se dispara sola
		print("[cumbre] Guardián montado en %s" % estatua.name)
		return

	push_warning("Cumbre: no hay estatua del Guardián; se usa la cápsula del greybox")
	var g := Node3D.new()
	g.set_script(GUARDIAN_SCR)
	add_child(g)
	var ref := _final_trigger as Node3D
	g.global_position = ref.global_position if ref != null else global_position


func _hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)


# ─── Plataformas con recorrido ────────────────────────────────────────────────
#
# CÓMO SE DEFINE UN RECORRIDO, sin tocar código:
#
#   Cada nodo lleva grabado de dónde SALE, en el metadato `pos_inicial`. Las
#   paradas ya fijadas van en `pos_tramo1`, `pos_tramo2`... y el punto donde
#   está el nodo AHORA MISMO es siempre el tramo que estás definiendo: lo
#   arrastrás en el editor a donde querés que termine y ya está.
#
#   Si nunca lo moviste, salida y llegada coinciden y se queda quieto, que es lo
#   correcto: todavía no hay recorrido que hacer.
#
#   Para encadenar OTRO tramo hay que fijar el anterior como `pos_tramoN` antes
#   de volver a mover el nodo; si no, el movimiento nuevo reescribe el viejo en
#   vez de sumarse. Pedímelo y lo anoto.
#
#   Para reubicar un recorrido ENTERO —en vez de estirarlo— hay que borrarle los
#   metadatos al nodo y volver a grabarlos, o seguirá saliendo del sitio viejo.

const INTERRUPTOR := preload("res://scenes/actors/InterruptorGolpeable.gd")
const BOTON_GUANACO := preload("res://scenes/actors/BotonDeGuanaco.gd")

## Contenedores cuyos hijos van y vienen en bucle.
const CONTENEDORES_EN_BUCLE := ["Bloques moviles", "plataformas moviles"]

## Segundos de un punto al siguiente para los bloques y baldosas en bucle, cuyos
## tramos miden todos parecido.
@export var duracion_recorrido := 3.0

## La plataforma principal va a VELOCIDAD constante, en metros por segundo, no
## en un tiempo fijo por tramo: sus tramos miden entre 6 y 18 m, así que con una
## duración fija el largo salía disparado a casi 6 m/s y no había forma de
## seguirle el paso.
@export var velocidad_plataforma := 2.5
@export var pausa_en_extremos := 0.4

## Segundos que espera la plataforma principal desde que Benjamín se sube.
const ESPERA_ANTES_DE_ARRANCAR := 1.0

## Qué interruptor abre cada tramo de la plataforma principal, DEL SEGUNDO EN
## ADELANTE. El primero no lleva llave acá: lo abre el bloque de flecha más que
## Benjamín se suba encima.
##
## Al llegar al final de un tramo la plataforma se queda esperando su llave; en
## cuanto se acciona, sale para el lado siguiente. Para sumar tramos se agrega
## la ruta del interruptor que toque y se fija la parada nueva en la escena.
const LLAVES_DE_TRAMO := ["Interruptores/boton de guanaco",
	"Interruptores/bloque_de_piedra_volcanico4",
	"Interruptores/boton de guanaco2",
	"Interruptores/boton de guanaco3"]

var _principal_armada := false
var _principal_andando := false
## Cuántos tramos completó ya la plataforma principal.
var _tramo_principal := 0
var _llaves_activadas := {}
var _tw_principal: Tween = null
## Está en el segundo de cortesía, todavía sin arrancar. Se lleva aparte de
## `_principal_andando` porque el guardarraíl de abajo tiene que dejar pasar la
## salida y bloquear en cambio los interruptores accionados en marcha.
var _esperando_salida := false
## Sube en cada reinicio. Sirve para que una espera o un tween disparados antes
## del reinicio no revivan el recorrido viejo cuando ya no toca.
var _generacion := 0
## La ruta de la plataforma principal se lee UNA vez, al arrancar. Releerla en
## marcha metería la posición intermedia como parada fantasma: mientras se mueve,
## el nodo no está en ninguno de sus puntos fijados.
var _ruta_principal: Array = []


func _arrancar_recorridos() -> void:
	var n := 0
	for cont in CONTENEDORES_EN_BUCLE:
		var c := get_node_or_null(cont)
		if c == null:
			continue
		for h in c.get_children():
			if h is Node3D and _recorrer_en_bucle(h):
				n += 1
	print("[cumbre] plataformas con recorrido en bucle: %d" % n)
	var plat := get_node_or_null("plataforma movil principal") as Node3D
	if plat != null:
		_ruta_principal = _ruta_de(plat)
		print("[cumbre] paradas de la plataforma principal: %d" % _ruta_principal.size())
		# Se la manda al ARRANQUE de su ruta ya mismo. En la escena queda donde
		# la dejaste al definir el último tramo —o sea, al final del recorrido—,
		# y si no se la mueve acá aparece allá arriba y no se la encuentra.
		if not _ruta_principal.is_empty():
			_hacer_montable(plat)
			plat.position = _ruta_principal[0]
		# Cada tramo del 2º en adelante necesita su llave. Si se suma una parada
		# sin sumar el interruptor que la abre, la plataforma se queda clavada
		# ahí y no hay forma de saber por qué mirando la escena.
		var sin_llave: int = max(0, _ruta_principal.size() - 2 - LLAVES_DE_TRAMO.size())
		if sin_llave > 0:
			push_warning("Cumbre: %d tramo(s) de la plataforma principal sin interruptor que los abra"
				% sin_llave)


## Recorre todos sus puntos y vuelve por donde vino, para siempre.
func _recorrer_en_bucle(n: Node3D) -> bool:
	var ruta := _ruta_de(n)
	if ruta.is_empty():
		return false
	_hacer_montable(n)
	var ini: Vector3 = ruta[0]
	n.position = ini

	var tw := create_tween().set_loops()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(1, ruta.size()):
		var p: Vector3 = ruta[i]
		tw.tween_property(n, "position", p, duracion_recorrido)
		tw.tween_interval(pausa_en_extremos)
	for i in range(ruta.size() - 2, -1, -1):
		var p: Vector3 = ruta[i]
		tw.tween_property(n, "position", p, duracion_recorrido)
		tw.tween_interval(pausa_en_extremos)
	return true


## Los puntos por los que pasa un nodo, en orden. Vacío si no hay recorrido.
func _ruta_de(n: Node3D) -> Array:
	if not n.has_meta("pos_inicial"):
		return []
	var r: Array = [n.get_meta("pos_inicial")]
	var i := 1
	while n.has_meta("pos_tramo%d" % i):
		r.append(n.get_meta("pos_tramo%d" % i))
		i += 1
	# Donde está el nodo ahora cuenta como un punto más, salvo que ya coincida
	# con el último fijado: eso significa que ese tramo está cerrado y todavía no
	# definiste el siguiente.
	var ultimo: Vector3 = r[r.size() - 1]
	if ultimo.distance_to(n.position) >= 0.05:
		r.append(n.position)
	return r if r.size() >= 2 else []


# ─── Interruptores ────────────────────────────────────────────────────────────

func _armar_interruptores() -> void:
	# De FLECHA. El de la izquierda suelta la plataforma principal.
	_montar(INTERRUPTOR, "Interruptores/bloque_de_piedra_volcanico2",
		"_al_activar_plataforma", "Le diste al bloque: la plataforma ya responde.")
	_agrandar("Interruptores/bloque_de_piedra_volcanico2")
	# De FLECHA. El de la derecha hace caer la plataforma vertical del paso.
	_montar(INTERRUPTOR, "Interruptores/bloque_de_piedra_volcanico3",
		"_al_activar_caida", "Le diste al bloque: algo cedió más adelante.")
	_agrandar("Interruptores/bloque_de_piedra_volcanico3")
	# DE EMBESTIDA. Éstos no aceptan flechazos: hay que darles con el guanaco (G).
	_montar(BOTON_GUANACO, "Interruptores/boton de guanaco",
		"_al_abrir_tramo", "El botón cede al golpe del guanaco.")
	_montar(BOTON_GUANACO, "Interruptores/boton de guanaco2",
		"_al_abrir_tramo", "El botón cede al golpe del guanaco.")
	_montar(BOTON_GUANACO, "Interruptores/boton de guanaco3",
		"_al_abrir_tramo", "El botón cede al golpe del guanaco.")
	# De FLECHA. Voltea la baldosa sobre la que la plataforma principal queda
	# apoyada al terminar el 2º tramo, y con eso mismo le abre el 3º.
	_montar(INTERRUPTOR, "Interruptores/bloque_de_piedra_volcanico4",
		"_al_activar_paso", "Le diste al bloque: el paso se despeja.")
	_agrandar("Interruptores/bloque_de_piedra_volcanico4")

	# Los que todavía no tienen trabajo asignado quedan como decorado, y se avisa
	# para que no parezca que se activan y no hacen nada.
	var sin_uso: Array = []
	var caja := get_node_or_null("Interruptores")
	if caja != null:
		for h in caja.get_children():
			if h.get_script() == null:
				sin_uso.append(h.name)
	if not sin_uso.is_empty():
		print("[cumbre] interruptores sin funcion asignada: %s"
			% ", ".join(PackedStringArray(sin_uso)))


## Le cuelga un guion de interruptor a un modelo ya colocado en la escena.
##
## `_ready` se llama a mano a propósito: el nodo ya está dentro del árbol, así
## que `set_script` no vuelve a dispararla, y es ahí donde el interruptor prepara
## el cuerpo del modelo para recibir el golpe.
func _montar(guion: GDScript, ruta: String, metodo: String, mensaje: String) -> void:
	var n := get_node_or_null(ruta) as Node3D
	if n == null:
		push_warning("Cumbre: no encuentro el interruptor %s" % ruta)
		return
	n.set_script(guion)
	n.set("objetivo", n.get_path_to(self))
	n.set("metodo", metodo)
	n.set("mensaje", mensaje)
	n.set("una_sola_vez", true)
	# Sólo si el guion trae `_ready` propia: no todos los interruptores necesitan
	# preparación, y llamarla a ciegas revienta en los que no la definen.
	var s := n.get_script() as Script
	if s != null and s.has_script_method("_ready"):
		n.call("_ready")
	# Y hay que encender el proceso a mano: `set_script` sobre un nodo que YA está
	# en el árbol no lo activa, así que `_process` no corría y el botón de
	# embestida no se enteraba nunca de que el guanaco lo golpeaba.
	if s != null and s.has_script_method("_process"):
		n.set_process(true)


## Interruptor de flecha 1: la plataforma principal pasa a responder, pero NO
## arranca sola. Espera a que Benjamín se suba, y recién un segundo después sale.
func _al_activar_plataforma() -> void:
	_principal_armada = true
	_hint("La plataforma quedó suelta. Subite y aguantá un momento.")


## Interruptor de flecha 2: la plataforma vertical del paso se viene abajo.
func _al_activar_caida() -> void:
	_derribar("plataformas de paso/baldosa_de_piedra3", "¡La plataforma cede!")


## Interruptor de flecha 3: voltea la baldosa donde la plataforma principal
## queda apoyada al final del 2º tramo, y le abre el 3º.
##
## Las dos cosas van juntas a propósito: mientras esa baldosa siga ahí, la
## plataforma la tiene justo encima y no tiene por dónde seguir.
func _al_activar_paso() -> void:
	_derribar("plataformas de paso/baldosa_de_piedra4", "El paso quedó libre.")
	_al_abrir_tramo()


## Tira una baldosa abajo y la hace desaparecer, con su colisión incluida: se
## mueve el nodo entero, no sólo se oculta la malla.
func _derribar(ruta: String, aviso: String) -> void:
	var p := get_node_or_null(ruta) as Node3D
	if p == null:
		push_warning("Cumbre: no encuentro la baldosa a derribar (%s)" % ruta)
		return
	_hint(aviso)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "position", p.position - Vector3(0.0, 40.0, 0.0), 1.4)
	tw.parallel().tween_property(p, "rotation:z", p.rotation.z + 1.2, 1.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(p):
			p.visible = false)


## Destino común de TODAS las llaves de tramo.
##
## En vez de un método por interruptor —que se repetía uno por tramo— se mira
## cuáles de los de LLAVES_DE_TRAMO quedaron usados y se apuntan todos. Sumar un
## tramo nuevo es entonces agregar su ruta a esa lista y montarlo apuntando acá.
##
## Da igual cuándo se golpee: la llave queda guardada, y la plataforma cambia de
## dirección al llegar a la esquina que le toca, no antes.
func _al_abrir_tramo() -> void:
	for ruta in LLAVES_DE_TRAMO:
		var n := get_node_or_null(ruta)
		if n != null and n.has_method("esta_usado") and n.call("esta_usado"):
			_llaves_activadas[ruta] = true
	_hint("Algo se destrabó: la plataforma cambia de dirección.")
	_seguir_ruta_principal()


# ─── Plataforma principal ─────────────────────────────────────────────────────

## Vigila a Benjamín sobre la plataforma principal.
##
## Se mira quién la PISA, no un área: la plataforma está pegada a otras y una
## caja envolvente dispararía desde la de al lado.
func _vigilar_plataforma_principal() -> void:
	if not _principal_armada or _principal_andando or _esperando_salida \
			or _tramo_principal > 0:
		return
	var plat := get_node_or_null("plataforma movil principal") as Node3D
	if plat == null:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node3D) or p.get("is_archer") != true:
			continue   # sólo Benjamín
		var esp := get_world_3d().direct_space_state
		if esp == null:
			return
		var desde: Vector3 = (p as Node3D).global_position + Vector3.UP * 0.3
		var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 1.6)
		q.collision_mask = 1
		if p is CollisionObject3D:
			q.exclude = [(p as CollisionObject3D).get_rid()]
		var r := esp.intersect_ray(q)
		if not r.is_empty() and _es_parte_de(r["collider"], plat):
			_hint("Sujetate.")
			get_tree().create_timer(ESPERA_ANTES_DE_ARRANCAR).timeout.connect(
				_salir_tras_la_espera.bind(_generacion))
			_esperando_salida = true
			return


## Sale hacia el punto siguiente del recorrido, si hay uno y si su llave ya está.
##
## Se la llama en dos momentos: al terminar un tramo (por si la llave del que
## viene ya estaba puesta) y al accionar un interruptor (por si la plataforma
## estaba esperándolo). Sea cual sea el orden, sale una sola vez.
func _seguir_ruta_principal() -> void:
	# Si ya está en camino no se le pide otro tramo. Sin esto, accionar un
	# interruptor con la plataforma EN MARCHA arrancaba un segundo movimiento
	# encima del primero: los dos tiraban del mismo nodo y salía en diagonal
	# hacia un punto que no tocaba, saltándose una parada.
	if _principal_andando:
		return
	var plat := get_node_or_null("plataforma movil principal") as Node3D
	if plat == null:
		return
	if _ruta_principal.is_empty():
		push_warning("Cumbre: la plataforma principal no tiene recorrido; movela en el editor")
		return
	if _tramo_principal + 1 >= _ruta_principal.size():
		return   # ya llegó al último punto definido

	if _tramo_principal >= 1:
		var i := _tramo_principal - 1
		var llave: String = LLAVES_DE_TRAMO[i] if i < LLAVES_DE_TRAMO.size() else ""
		if llave != "" and not _llaves_activadas.has(llave):
			return   # esperando su interruptor

	_esperando_salida = false
	_principal_andando = true
	var destino: Vector3 = _ruta_principal[_tramo_principal + 1]
	# A velocidad constante: cada tramo tarda lo que mide. Con una duración fija
	# el tramo de 18 m iba a casi 6 m/s y no había forma de ir encima.
	var largo: float = plat.position.distance_to(destino)
	var dura: float = maxf(largo / maxf(velocidad_plataforma, 0.1), 0.2)

	var gen := _generacion
	_tw_principal = create_tween()
	_tw_principal.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tw_principal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw_principal.tween_property(plat, "position", destino, dura)
	_tw_principal.tween_callback(func() -> void:
		if gen != _generacion:
			return   # hubo un reinicio mientras iba en camino
		_tramo_principal += 1
		_principal_andando = false
		_seguir_ruta_principal())


## Convierte un modelo quieto en una plataforma que se pueda ir montado.
##
## Los .glb entran con un StaticBody3D dentro. Un cuerpo estático movido por
## código sí desplaza su colisión, pero NO ARRASTRA a quien esté encima: el
## jugador se queda clavado donde estaba y se cae al vacío en cuanto la
## plataforma sale de abajo suyo.
##
## Así que al lado del cuerpo del modelo se le cuelga un AnimatableBody3D con la
## MISMA forma y `sync_to_physics`, que es el que sí empuja al pasajero, y se
## apaga la colisión original para que no queden dos superficies peleando.
##
## Todo esto pasa sólo en ejecución: la escena en disco no se toca, así que
## podés seguir moviendo los modelos en el editor sin arrastrar nada raro.
func _hacer_montable(n: Node3D) -> void:
	# Si el nodo YA es un cuerpo animable —la plataforma principal lo es— no hay
	# que colgarle otro: ése arrastra por sí solo. Pero sí hay que resolver un
	# choque entre dos superficies; ver _unificar_superficie.
	if n is AnimatableBody3D:
		_unificar_superficie(n as AnimatableBody3D)
		return
	if n.has_node("CuerpoMovil"):
		return
	var cuerpo := _primer_cuerpo(n)
	if cuerpo == null:
		return
	var forma: CollisionShape3D = null
	for h in cuerpo.get_children():
		if h is CollisionShape3D:
			forma = h
			break
	if forma == null:
		return

	var movil := AnimatableBody3D.new()
	movil.name = "CuerpoMovil"
	movil.sync_to_physics = true
	movil.collision_layer = cuerpo.collision_layer
	movil.collision_mask = cuerpo.collision_mask

	var copia := CollisionShape3D.new()
	copia.shape = forma.shape
	# La forma se reubica respecto del modelo, no del cuerpo viejo: el nuevo
	# cuerpo cuelga del modelo y no hereda la transformación del anterior.
	copia.transform = cuerpo.transform * forma.transform
	movil.add_child(copia)
	n.add_child(movil)

	forma.set_deferred("disabled", true)


func _primer_cuerpo(n: Node) -> StaticBody3D:
	for h in n.get_children():
		if h is StaticBody3D and not (h is AnimatableBody3D):
			return h
		var hondo := _primer_cuerpo(h)
		if hondo != null:
			return hondo
	return null


# ─── Corrientes de viento ─────────────────────────────────────────────────────

const MAT_VIENTO := preload("res://art_placeholders/mat_viento_ascendente.tres")


## Le cambia el aspecto a las corrientes ascendentes.
##
## Venían con `mat_trigger.tres`, el material genérico de los disparadores, y
## por eso parecían bloques de agua. Ese material NO se toca porque lo comparten
## otros disparadores de la escena: acá se les pone uno propio encima.
##
## Se buscan por GUION y no por el nodo que las agrupa: hay una, Updraft2, que
## cuelga de la raíz y no de "corrientes de viento", y buscando por sitio se
## quedaba fuera. Así entran todas, estén donde estén, y también las que sumes
## después.
func _vestir_corrientes() -> void:
	var n := 0
	for c in _corrientes(self):
		for m in _mallas_de(c):
			m.material_override = MAT_VIENTO
			# El alto va por malla: el shader lo necesita para desvanecer las
			# puntas donde toca, y no todas las cajas miden lo mismo.
			if m.mesh != null:
				m.set_instance_shader_parameter("altura", m.mesh.get_aabb().size.y)
			n += 1
	print("[cumbre] corrientes de viento vestidas: %d" % n)


func _mallas_de(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		if h is MeshInstance3D:
			r.append(h)
		r.append_array(_mallas_de(h))
	return r


## Todas las corrientes de la escena, reconocidas por su guion.
func _corrientes(n: Node) -> Array:
	var r: Array = []
	for h in n.get_children():
		var g := h.get_script() as Script
		if g != null and g.resource_path.get_file() == "Updraft.gd":
			r.append(h)
		r.append_array(_corrientes(h))
	return r


## Arranca tras el segundo de cortesía, salvo que entremedias hubiera un
## reinicio: en ese caso la espera es de un intento que ya no existe.
func _salir_tras_la_espera(gen: int) -> void:
	if gen != _generacion:
		return
	_seguir_ruta_principal()


## Devuelve la plataforma al principio de su recorrido.
##
## Hace falta porque si te caés a mitad de camino la plataforma se quedaba donde
## estuviera y no había manera de volver a subirse: el intento siguiente
## empezaba sin plataforma.
##
## Los interruptores ya accionados NO se olvidan: lo que se rehace es el viaje,
## no el puzzle. Volvés a subirte y recorre de nuevo los tramos ya abiertos.
func reiniciar_plataforma_principal() -> void:
	_generacion += 1
	if _tw_principal != null and _tw_principal.is_valid():
		_tw_principal.kill()
	_tw_principal = null
	_tramo_principal = 0
	_principal_andando = false
	_esperando_salida = false
	var plat := get_node_or_null("plataforma movil principal") as Node3D
	if plat != null and not _ruta_principal.is_empty():
		plat.position = _ruta_principal[0]


## Cuánto se agranda el blanco de los bloques de flecha, por lado y en metros.
const MARGEN_DE_GOLPE := 0.35


## El bloque mide 0.94 m y hay que acertarle de lejos esquivando la muralla, que
## lo tapa un 30% del ciclo. La colisión justa del modelo lo hacía cuestión de
## insistir; esto agranda sólo el blanco, no el modelo.
func _agrandar(ruta: String) -> void:
	var n := get_node_or_null(ruta)
	if n != null and n.has_method("agrandar_blanco"):
		n.call("agrandar_blanco", MARGEN_DE_GOLPE)


## Deja UNA sola superficie donde pisar en una plataforma animable.
##
## El modelo .glb trae su propia colisión estática, y queda unos centímetros por
## ENCIMA de la caja de la plataforma. El jugador se apoya entonces en la del
## modelo —que es estática y no arrastra a nadie— mientras la superficie
## animable le pasa por debajo sin tocarlo. Medido: el modelo llega a y=110.154
## y la plataforma a 110.100, cinco centímetros y medio de diferencia, y por eso
## la plataforma avanzaba 3.26 m mientras el pasajero sólo 1.67 m.
##
## Se apaga la del modelo y se sube la de la plataforma hasta donde estaba
## aquélla, así la altura al caminar no cambia ni un centímetro.
func _unificar_superficie(plat: AnimatableBody3D) -> void:
	var cuerpo := _primer_cuerpo(plat)
	if cuerpo == null:
		return                      # el modelo no traía colisión: nada que hacer
	var del_modelo := _forma_de(cuerpo)
	var de_la_plataforma: CollisionShape3D = null
	for h in plat.get_children():
		if h is CollisionShape3D:
			de_la_plataforma = h
			break
	if del_modelo == null or de_la_plataforma == null:
		return

	var arriba := _tope_de(del_modelo)
	var abajo := _tope_de(de_la_plataforma)
	if arriba > abajo:
		de_la_plataforma.global_position.y += (arriba - abajo)
	del_modelo.set_deferred("disabled", true)
	print("[cumbre] superficie unificada: la caja sube %.3f m y se apaga la del modelo"
		% maxf(arriba - abajo, 0.0))


func _forma_de(n: Node) -> CollisionShape3D:
	for h in n.get_children():
		if h is CollisionShape3D:
			return h
	return null


## Altura del punto más alto de una forma de colisión, en coordenadas del mundo.
func _tope_de(cs: CollisionShape3D) -> float:
	if cs.shape == null:
		return -INF
	var ab: AABB = cs.shape.get_debug_mesh().get_aabb()
	var g := cs.global_transform
	return g.origin.y + ab.end.y * g.basis.get_scale().y


# ─── Corriente del final ──────────────────────────────────────────────────────

## La pasarela donde tienen que juntarse los dos para abrir la corriente.
const PASARELA_FINAL := "camino_de_ladrillos_de_piedra5"

var _pasarela_final: Node3D = null
var _corriente_abierta := false


## Abre la corriente del final cuando LOS DOS personajes pisan la última
## pasarela.
##
## Se mira qué pisa cada uno, no un área envolvente: esa pasarela está pegada a
## otras y una caja dispararía desde la de al lado. Es el mismo criterio que usan
## las pasarelas mortales y la plataforma del recorrido.
##
## Cuentan los DOS del party, no sólo el que controlás: el que va con la IA
## también pisa, que es justamente lo que hace de esto algo cooperativo.
func _vigilar_corriente_final() -> void:
	if _corriente_abierta or _pasarela_final == null:
		return
	var encima := 0
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and _es_parte_de(_que_pisa(p as Node3D), _pasarela_final):
			encima += 1
	if encima < 2:
		return
	_abrir_corriente_final()


func _abrir_corriente_final() -> void:
	if _corriente_abierta:
		return
	_corriente_abierta = true
	if _updraft2 != null and _updraft2.has_method("set_active"):
		_updraft2.set_active(true)
	_hint("Los dos en la pasarela: se abrió la corriente. Emilia sube (Espacio).")


## Sobre qué cuerpo está parado alguien: rayo corto desde los tobillos.
func _que_pisa(p: Node3D) -> Node:
	var esp := get_world_3d().direct_space_state
	if esp == null:
		return null
	var desde: Vector3 = p.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 1.6)
	q.collision_mask = 1
	if p is CollisionObject3D:
		q.exclude = [(p as CollisionObject3D).get_rid()]
	var r := esp.intersect_ray(q)
	return r.get("collider") if not r.is_empty() else null
