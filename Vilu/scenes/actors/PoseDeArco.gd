extends SkeletonModifier3D

## Mantiene el arco tensado con el tren superior mientras las piernas caminan.
##
## EL PROBLEMA. Tensar es un clip de una sola pasada que se congela en la máxima
## extensión, y mientras dura no se elige clip de movimiento: Benjamín apuntaba
## bien, pero al caminar se deslizaba con los pies clavados. Y si en vez de eso
## se le deja caminar sin más, camina bien y suelta el arco: pierde la pose.
##
## LA SOLUCIÓN. Que corran las dos cosas: el AnimationPlayer reproduce el
## caminar entero —piernas, caderas, balanceo— y justo después se le reescribe la
## rotación de los huesos del pecho para arriba con la pose de apuntar. De
## cintura para abajo camina; de cintura para arriba sujeta la cuerda.
##
## POR QUÉ UN `SkeletonModifier3D` Y NO `_process`. El orden es lo único que
## importa acá: la pose de apuntar es FIJA, así que si se escribiera antes de que
## el AnimationPlayer aplique el caminar, el caminar la pisaría y no se vería
## nunca —no sería «un cuadro tarde», sería no funcionar—. Un modificador corre
## en el hueco que el motor reserva justo después de la animación, que es el
## único sitio donde esto es correcto.
##
## Sólo se escribe la ROTACIÓN. La posición de los huesos en un esqueleto de
## Mixamo viene del reposo salvo en la cadera, y tocarla estiraría al personaje.

## De qué hueso para arriba manda el arco.
##
## Arranca en `Spine1` y no en `Spine`: dejándole la primera vértebra al caminar,
## el torso sigue balanceándose con el paso y la mezcla no se ve como un muñeco
## partido en dos.
const TREN_SUPERIOR := [
	"mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
	"mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
	"mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
]

## Cuánto tarda en entrar y salir la pose, en segundos. Sin esto, empezar a
## tensar caminando da un tirón de brazos de un cuadro para otro.
const MEZCLA := 0.18

## Rotación de cada hueso del tren superior en la pose de apuntar, por índice.
var poses := {}

## Si la pose tiene que aplicarse ahora.
var activo := false

## Cuánto pesa la pose ahora mismo: 0 = camina normal, 1 = apunta del todo.
var _peso := 0.0


func _process(delta: float) -> void:
	var meta := 1.0 if (activo and not poses.is_empty()) else 0.0
	_peso = move_toward(_peso, meta, delta / MEZCLA)


## Guarda la pose que tenga el esqueleto AHORA como la de apuntar.
##
## Se llama con el clip de tensar congelado en su máxima extensión: lo que hay
## en el esqueleto en ese instante es exactamente lo que hay que conservar.
func capturar() -> void:
	var esq := get_skeleton()
	if esq == null:
		return
	poses.clear()
	for nombre: String in TREN_SUPERIOR:
		var idx := esq.find_bone(nombre)
		if idx >= 0:
			poses[idx] = esq.get_bone_pose_rotation(idx)


func _process_modification() -> void:
	if _peso <= 0.001 or poses.is_empty():
		return
	var esq := get_skeleton()
	if esq == null:
		return
	for idx: int in poses:
		if idx >= esq.get_bone_count():
			continue
		var apuntando: Quaternion = poses[idx]
		# Interpolado contra lo que puso el caminar, no impuesto: así la entrada
		# y la salida de la pose son un movimiento y no un salto.
		esq.set_bone_pose_rotation(idx,
			esq.get_bone_pose_rotation(idx).slerp(apuntando, _peso))
