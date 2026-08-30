extends StaticBody3D

## Reenviador mínimo. El melee del jugador y las flechas llaman `take_damage`
## sobre el cuerpo que entra en su área, pero el cuerpo lo crea el importador de
## glTF y no tiene script propio. Destructible.gd le cuelga este en tiempo de
## ejecución para que el golpe llegue al nodo que lleva la cuenta.
##
## Firma igual a la de Enemy.gd y HitCube.gd: take_damage(dmg, desde, fuerza, quemar).

var dueno: Node = null


func take_damage(dmg := 0.0, desde := Vector3.ZERO, _fuerza := 0.0, _quemar := false) -> void:
	if dueno and dueno.has_method("golpear"):
		dueno.golpear(dmg, desde)
