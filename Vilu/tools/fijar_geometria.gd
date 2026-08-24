@tool
extends EditorScript

## Convierte la geometría GENERADA POR CÓDIGO en nodos de escena editables.
##
## EL PROBLEMA QUE RESUELVE
##   Las zonas construyen su decorado en _build_*(): crean los nodos y los
##   agregan al árbol, pero SIN `owner`. Godot los dibuja, y sin embargo no
##   aparecen en el panel de Escena, no se pueden seleccionar ni arrastrar, y
##   no se guardan en el .tscn. Son invisibles para el editor.
##
##   Asignarles `owner` los vuelve parte de la escena: aparecen en el árbol,
##   se seleccionan, se mueven con el gizmo y se guardan al hacer Ctrl+S.
##
## CÓMO USARLO — EL ORDEN IMPORTA, NO LO CAMBIES
##   1. Abrí la escena de la ZONA que querés editar, sola. Por ejemplo
##      scenes/regions/Region1_Tarapaca.tscn (no World.tscn).
##   2. Abrí este archivo en el editor de Script y ejecutalo (Ctrl+Shift+X).
##   3. En el nodo que tiene el script de la zona, tildá `Geometria Fijada`.
##   4. RECIÉN AHORA Ctrl+S.
##
## POR QUÉ EL FLAG VA ANTES DE GUARDAR
##   Guardar con el decorado adentro pero el flag todavía en false deja la
##   escena en el peor estado posible: al reabrirla, Godot carga los nodos
##   guardados Y ADEMÁS el script vuelve a construir todo encima. Eso ya pasó
##   con La Tirana y la llevó de 702 bytes a 440 KB, con dos fiestas
##   superpuestas. Tildando primero, el guardado deja nodos y flag juntos y no
##   hay ninguna ventana en la que se pueda duplicar.
##
##   El flag NO se puede tildar antes del paso 2: con él en true el script no
##   construye nada, y entonces no habría geometría que adoptar.
##
## A PARTIR DE AHÍ el decorado es tuyo: movés, borrás y agregás a mano, y el
## script deja de generarlo.
##
## SI ALGO SALE MAL: la escena limpia está en git. `git checkout --
## scenes/regions/Region1_Tarapaca.tscn` la devuelve a 702 bytes.
##
## OJO: es de ida. Una vez fijado, cambiar los números del script ya no hace
## nada (justamente por eso). Si te arrepentís, borrás los nodos del árbol y
## destildás `Geometria Fijada`.


func _run() -> void:
	var raiz := get_scene()
	if raiz == null:
		push_error("Abrí primero la escena de la zona que querés editar.")
		return

	var antes := _contar_con_owner(raiz)
	var n := _adoptar(raiz, raiz)
	var despues := _contar_con_owner(raiz)

	print("[fijar] nodos adoptados: %d   (antes en la escena: %d, ahora: %d)"
		% [n, antes, despues])
	if n == 0:
		print("[fijar] no había geometría generada suelta. ¿Es la escena correcta?")
		return
	print("[fijar] AHORA, EN ESTE ORDEN:")
	print("[fijar]   1. Tildá `Geometria Fijada` en el nodo de la zona.")
	print("[fijar]   2. Recién después Ctrl+S.")
	print("[fijar] Si guardás con el flag todavía en false, al reabrir se cargan")
	print("[fijar] los nodos Y el script los construye otra vez encima.")


## Le da `owner` a todo lo que cuelga del árbol y no lo tenga. El orden importa:
## un hijo sólo puede tener owner si su padre ya está en la escena.
func _adoptar(n: Node, raiz: Node) -> int:
	var total := 0
	for hijo in n.get_children():
		if hijo.owner == null and hijo != raiz:
			hijo.owner = raiz
			total += 1
		total += _adoptar(hijo, raiz)
	return total


func _contar_con_owner(n: Node) -> int:
	var total := 0
	for hijo in n.get_children():
		if hijo.owner != null:
			total += 1
		total += _contar_con_owner(hijo)
	return total
