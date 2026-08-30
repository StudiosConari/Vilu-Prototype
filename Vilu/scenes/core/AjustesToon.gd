extends Resource
class_name AjustesToon

## Todos los mandos del sombreado toon, en un archivo que se edita en el
## inspector.
##
## Antes estos números estaban repartidos en tres sitios y ninguno se podía
## tocar sin editar código: los valores por defecto de toon_objeto.gdshader
## (que ToonSkin nunca sobreescribía, así que mandaban ellos), dos constantes
## del propio ToonSkin.gd para el contorno de casco, y los parámetros del nodo
## ContornoToon dentro de Game.tscn. Ahora salen todos de aquí.
##
## PARA AJUSTARLO: abrí `res://scenes/core/toon.tres` en el inspector y movés
## las barras. Los cambios se ven al volver a entrar a la zona; si el juego ya
## está corriendo, se ven EN EL ACTO editando desde el árbol Remoto (nodo Game,
## propiedad Ajustes Toon), porque cada cambio avisa a los materiales.
##
## Los defaults de aquí abajo SON el preajuste. Tienen que estar acá y no sólo
## en toon.tres porque Godot, al guardar un recurso, omite toda propiedad que
## valga lo mismo que el default del script: un preajuste escrito sólo en el
## .tres se borra solo la primera vez que se toca cualquier otra cosa.
##
## VALORES ORIGINALES, por si querés volver al aspecto de antes:
##   saturacion 1.25 · pasos_luz 3 · dureza_corte 0.02 · piso_sombra 0.35
##   tinte_sombra (0.55, 0.60, 0.85) · rim_fuerza 0.30 · rim_ancho 0.6
##   contorno_grosor 0.018 · pantalla_opacidad 0.85
##   pantalla_umbral_profundidad 0.4 · pantalla_umbral_normal 0.6

@export_group("Color")
## Cuánto se aviva el color base. 1.0 = el color tal cual viene de la textura;
## por encima de eso se satura, y es lo que hace que los tonos canten.
@export_range(0.5, 2.5, 0.01) var saturacion := 1.0:
	set(v):
		saturacion = v
		emit_changed()

@export_group("Luz escalonada")
## Cuántos escalones tiene la rampa de luz. Pocos = contraste de cómic duro;
## muchos = degradado casi suave.
@export_range(1, 6, 1) var pasos_luz := 4:
	set(v):
		pasos_luz = v
		emit_changed()

## Qué tan seco es el salto entre un escalón y el siguiente. Subirlo difumina
## el borde entre bandas.
@export_range(0.001, 0.3, 0.001) var dureza_corte := 0.05:
	set(v):
		dureza_corte = v
		emit_changed()

## Cuánta luz le queda a la cara en sombra. 0 = negro; subirlo aclara las
## sombras y baja el contraste general.
@export_range(0.0, 0.8, 0.01) var piso_sombra := 0.48:
	set(v):
		piso_sombra = v
		emit_changed()

## Ancho del degradado en el BORDE de la sombra proyectada. Va aparte de
## `dureza_corte` a propósito: el filtro de sombras entrega una penumbra de
## varios metros y un corte estrecho la colapsa contra la retícula del mapa de
## sombras, que es lo que se ve como recorte escalonado al pie de los macizos.
## Subirlo ablanda SOLO el borde de sombra, sin tocar las bandas de luz.
@export_range(0.01, 0.5, 0.01) var sombra_suavidad := 0.30:
	set(v):
		sombra_suavidad = v
		emit_changed()

## Color con el que se rellena la sombra en vez de ir a negro. Cuanto más lejos
## del blanco, más tiñe.
@export var tinte_sombra := Color(0.74, 0.77, 0.90):
	set(v):
		tinte_sombra = v
		emit_changed()

@export_group("Luz de borde")
## Brillo en el canto del objeto, para despegarlo del fondo. En 0 se apaga.
@export_range(0.0, 2.0, 0.01) var rim_fuerza := 0.16:
	set(v):
		rim_fuerza = v
		emit_changed()

## Qué franja del canto se ilumina.
@export_range(0.0, 1.0, 0.01) var rim_ancho := 0.55:
	set(v):
		rim_ancho = v
		emit_changed()

@export var rim_color := Color(1.0, 0.97, 0.85):
	set(v):
		rim_color = v
		emit_changed()

## Fuerza del rim EN EL TERRENO, aparte de la de los objetos.
##
## En un prop el rim sirve: despega su silueta del fondo. En una llanura no hay
## silueta que despegar, y como el término es aditivo y casi blanco, lo único
## que hace es lavar el suelo hacia el blanco justo donde se lo mira a rasante.
## Peor aún: depende del ángulo de visión, así que el lavado se DESPLAZA al
## caminar, y como la arena ya tiene el canal rojo al tope, ese brillo de más
## solo puede subir verde y azul y el salto se lee como una mancha de bordes
## duros. Por eso arranca en 0.
@export_range(0.0, 2.0, 0.01) var rim_terreno := 0.0:
	set(v):
		rim_terreno = v
		emit_changed()

@export_group("Contorno del objeto")
## La silueta negra que rodea cada modelo, hecha por casco invertido.
@export var contorno_activo := true:
	set(v):
		contorno_activo = v
		emit_changed()

## Grosor en METROS DE MUNDO. ToonSkin lo divide por la escala del nodo, así
## que mide igual en un guijarro que en una iglesia.
@export_range(0.0, 0.06, 0.001) var contorno_grosor := 0.012:
	set(v):
		contorno_grosor = v
		emit_changed()

@export var contorno_color := Color(0.07, 0.05, 0.09):
	set(v):
		contorno_color = v
		emit_changed()

@export_group("Contorno de pantalla")
## El segundo contorno, el de post-proceso: dibuja también las aristas
## INTERNAS, no sólo la silueta. Es el que más carga el estilo.
@export var pantalla_color := Color(0.08, 0.06, 0.1):
	set(v):
		pantalla_color = v
		emit_changed()

## Ancho de la línea, en píxeles.
@export_range(0.5, 5.0, 0.1) var pantalla_grosor := 0.5:
	set(v):
		pantalla_grosor = v
		emit_changed()

## Cuánto se ve la línea. Bajarlo es la forma más directa de suavizar el estilo
## sin perder el trazo del todo.
@export_range(0.0, 1.0, 0.01) var pantalla_opacidad := 0.55:
	set(v):
		pantalla_opacidad = v
		emit_changed()

## A partir de qué salto de profundidad se dibuja línea. SUBIRLO dibuja MENOS.
@export_range(0.01, 5.0, 0.01) var pantalla_umbral_profundidad := 0.55:
	set(v):
		pantalla_umbral_profundidad = v
		emit_changed()

## Ídem para los quiebres de normal (los pliegues dentro de un mismo objeto).
## SUBIRLO dibuja MENOS.
@export_range(0.05, 1.5, 0.01) var pantalla_umbral_normal := 0.75:
	set(v):
		pantalla_umbral_normal = v
		emit_changed()

## Distancia a la que la línea se desvanece, para que el horizonte no se llene
## de trazos.
@export_range(20.0, 500.0, 1.0) var pantalla_distancia_fin := 200.0:
	set(v):
		pantalla_distancia_fin = v
		emit_changed()


## Vuelca los mandos de objeto sobre un material del shader toon.
func aplicar_a_material(m: ShaderMaterial) -> void:
	m.set_shader_parameter("saturacion", saturacion)
	m.set_shader_parameter("pasos_luz", pasos_luz)
	m.set_shader_parameter("dureza_corte", dureza_corte)
	m.set_shader_parameter("piso_sombra", piso_sombra)
	m.set_shader_parameter("sombra_suavidad", sombra_suavidad)
	m.set_shader_parameter("tinte_sombra", tinte_sombra)
	m.set_shader_parameter("rim_fuerza", rim_fuerza)
	m.set_shader_parameter("rim_ancho", rim_ancho)
	m.set_shader_parameter("rim_color", rim_color)


## Ídem para el contorno de post-proceso que cuelga de la cámara.
func aplicar_a_pantalla(m: ShaderMaterial) -> void:
	m.set_shader_parameter("color_linea", pantalla_color)
	m.set_shader_parameter("grosor", pantalla_grosor)
	m.set_shader_parameter("opacidad", pantalla_opacidad)
	m.set_shader_parameter("umbral_profundidad", pantalla_umbral_profundidad)
	m.set_shader_parameter("umbral_normal", pantalla_umbral_normal)
	m.set_shader_parameter("distancia_fin", pantalla_distancia_fin)


## Ídem para el material de Terrain3D.
##
## El shader del terreno tiene su PROPIA copia de los mandos de luz —es otro
## archivo, no puede compartir uniforms con el de objetos— y hasta ahora se
## quedaba con los valores de fábrica: el suelo seguía con el toon duro mientras
## las casas ya iban suaves, y por eso no se leían como una sola ilustración.
##
## Sólo se empujan los mandos COMPARTIDOS. La paleta del terreno (color_pampa,
## alturas de franja, pintura) es suya y se sigue editando en su material.
func aplicar_a_terreno(mat: Resource) -> void:
	if mat == null or not mat.has_method("set_shader_param"):
		return
	mat.set_shader_param("pasos_luz", pasos_luz)
	mat.set_shader_param("dureza_corte", dureza_corte)
	mat.set_shader_param("piso_sombra", piso_sombra)
	mat.set_shader_param("sombra_suavidad", sombra_suavidad)
	mat.set_shader_param("tinte_sombra", tinte_sombra)
	mat.set_shader_param("rim_fuerza", rim_terreno)
	mat.set_shader_param("rim_ancho", rim_ancho)
	mat.set_shader_param("rim_color", rim_color)
