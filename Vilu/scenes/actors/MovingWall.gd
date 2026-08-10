extends AnimatableBody3D

## Muralla que oscila de izquierda a derecha (eje X) tapando un objetivo. En capa
## 1 (entorno) para que las flechas choquen contra ella. Hay que disparar cuando
## no está tapando el cubo.

@export var amplitude := 4.0
@export var speed := 1.8

var _t := 0.0
var _base := Vector3.ZERO


func _ready() -> void:
	_base = position


func _physics_process(delta: float) -> void:
	_t += delta
	position.x = _base.x + sin(_t * speed) * amplitude
