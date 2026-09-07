shader_type spatial;

// Corriente de aire que sube.
//
// SE DIBUJA CON ALFA PREMULTIPLICADO, no sumando luz a secas.
//
// Sumando (`blend_add`) el resultado es `color + fondo`, y eso tiene un agujero:
// sobre un fondo claro no hay nada que sumar. En el cráter del Ojos del Salado
// las corrientes se veían contra la lava y las sombras y desaparecían justo
// donde cruzaban las rocas y plataformas de color crema, así que se leían
// cortadas por la mitad.
//
// Premultiplicado el resultado es `color + fondo * (1 - ALPHA)`: la corriente
// atenúa un poco lo que tiene detrás ANTES de sumarle su brillo. Sobre oscuro
// sigue siendo un resplandor —que es como tiene que leerse el aire— y sobre
// claro se recorta, porque ahí sí tapa algo. Con `opacidad` a 0 se comporta
// exactamente como antes, por si alguna vez hace falta volver.
//
// Sin escribir profundidad: así no se tapan entre ellas ni se ven como una
// plancha de vidrio, que era el problema del material que tenían antes.
render_mode blend_premul_alpha, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Alto de la caja de esta corriente concreta. Se lo pone el código a cada malla,
// porque no todas miden igual y el desvanecido de las puntas tiene que caer
// donde toca en cada una.
instance uniform float altura = 7.0;

// Azules, no casi-blancos. Con los de antes —el de arriba estaba en 0,93/0,99/1—
// la corriente sumaba un color que ya era el del fondo claro, así que sobre las
// rocas crema del cráter no contrastaba con nada. Éstos se ven en los dos.
uniform vec3 color_abajo : source_color = vec3(0.34, 0.68, 0.97);
uniform vec3 color_arriba : source_color = vec3(0.72, 0.92, 1.0);
/// Qué tan rápido suben las ráfagas.
uniform float velocidad = 2.1;
/// Hacia dónde corren las ráfagas: 1 sube, -1 baja.
///
/// Una corriente que arrastra hacia abajo con las vetas subiendo dice lo
/// contrario de lo que hace, y el jugador se mete confiado.
uniform float sentido : hint_range(-1.0, 1.0) = 1.0;
/// Cuántas vetas hay a lo ancho.
uniform float vetas = 7.0;
uniform float intensidad = 1.25;
/// Cuánto atenúa el fondo antes de sumar su brillo. 0 = suma pura, como antes
/// —invisible sobre claro—; 1 = tapa del todo en el corazón de una ráfaga.
uniform float opacidad : hint_range(0.0, 1.0) = 0.95;
/// El cuerpo de la columna entre ráfaga y ráfaga.
///
/// Es LO QUE DECIDE si la corriente se ve sobre un fondo claro o brillante. Las
/// ráfagas son dispersas: la mayor parte de la columna está a opacidad muy baja,
/// y donde la opacidad es baja gana el fondo. Sobre la roca oscura un azul tenue
/// se lee igual; sobre la lava naranja no se lee nada. Subiendo el velo la
/// columna tiene cuerpo en todas partes y las ráfagas van encima.
uniform float velo_base : hint_range(0.0, 0.6) = 0.20;
/// Cuánto resalta la silueta frente a las caras vistas de frente.
uniform float grosor_borde = 1.7;

varying vec3 pos_local;


float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void vertex() {
	pos_local = VERTEX;
}


void fragment() {
	float h = max(altura, 0.001);
	float t = clamp(pos_local.y / h + 0.5, 0.0, 1.0);   // 0 abajo, 1 arriba

	// Cada columna del plano XZ lleva su propia fase y su propia velocidad. Si
	// subieran todas a la vez se vería una persiana bajando, no aire.
	vec2 celda = floor(vec2(pos_local.x, pos_local.z) * vetas);
	float fase = azar(celda);
	float vel = 0.55 + 0.9 * azar(celda + 31.7);

	// Ráfaga: una banda estrecha que recorre la columna de abajo hacia arriba.
	float rec = t * 6.2831 - TIME * velocidad * vel * sentido - fase * 6.2831;
	float rafaga = pow(max(sin(rec) * 0.5 + 0.5, 0.0), 7.0);

	// Y no todas las columnas están encendidas al mismo tiempo.
	rafaga *= step(0.40, azar(celda + 5.0));

	// Un velo tenue de fondo, para que la corriente se siga leyendo en los
	// huecos entre ráfagas y no parpadee a oscuras.
	float velo = velo_base + 0.05 * sin(TIME * 1.7 + fase * 6.2831);

	// Se apaga en las dos puntas: nace difusa abajo y se deshace arriba.
	// La ascendente nace difusa abajo y se deshace arriba; la descendente al
	// revés, así que se mira la columna del derecho o del revés según el sentido.
	float tp = sentido >= 0.0 ? t : 1.0 - t;
	float puntas = smoothstep(0.0, 0.16, tp) * (1.0 - smoothstep(0.60, 1.0, tp));

	// La silueta brilla más que las caras vistas de frente, que es lo que hace
	// que parezca una columna de aire con volumen.
	float borde = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), grosor_borde);

	// La fuerza de la corriente en este punto: 0 donde no hay nada, 1 en el
	// corazón de una ráfaga.
	float fuerza = clamp((rafaga + velo) * puntas * (0.30 + 0.90 * borde) * intensidad, 0.0, 1.0);

	// Premultiplicado: el color va YA multiplicado por su fuerza, y `ALPHA` dice
	// cuánto se atenúa el fondo antes de sumarlo. Si el color no se
	// premultiplicara, las zonas tenues saldrían a todo brillo.
	ALBEDO = mix(color_abajo, color_arriba, t) * fuerza;
	ALPHA = fuerza * opacidad;
}
