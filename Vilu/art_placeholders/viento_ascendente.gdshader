shader_type spatial;

// Corriente de aire que sube.
//
// Se dibuja SUMANDO luz en vez de tapar lo que hay detrás, y sin escribir
// profundidad: así se lee como aire y no como una plancha de vidrio o de agua,
// que era el problema del material de disparador que tenían antes.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Alto de la caja de esta corriente concreta. Se lo pone el código a cada malla,
// porque no todas miden igual y el desvanecido de las puntas tiene que caer
// donde toca en cada una.
instance uniform float altura = 7.0;

uniform vec3 color_abajo : source_color = vec3(0.55, 0.84, 1.0);
uniform vec3 color_arriba : source_color = vec3(0.93, 0.99, 1.0);
/// Qué tan rápido suben las ráfagas.
uniform float velocidad = 2.1;
/// Cuántas vetas hay a lo ancho.
uniform float vetas = 7.0;
uniform float intensidad = 1.25;
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
	float rec = t * 6.2831 - TIME * velocidad * vel - fase * 6.2831;
	float rafaga = pow(max(sin(rec) * 0.5 + 0.5, 0.0), 7.0);

	// Y no todas las columnas están encendidas al mismo tiempo.
	rafaga *= step(0.40, azar(celda + 5.0));

	// Un velo tenue de fondo, para que la corriente se siga leyendo en los
	// huecos entre ráfagas y no parpadee a oscuras.
	float velo = 0.09 + 0.05 * sin(TIME * 1.7 + fase * 6.2831);

	// Se apaga en las dos puntas: nace difusa abajo y se deshace arriba.
	float puntas = smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.60, 1.0, t));

	// La silueta brilla más que las caras vistas de frente, que es lo que hace
	// que parezca una columna de aire con volumen.
	float borde = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), grosor_borde);

	ALBEDO = mix(color_abajo, color_arriba, t);
	ALPHA = clamp((rafaga + velo) * puntas * (0.30 + 0.90 * borde) * intensidad, 0.0, 1.0);
}
