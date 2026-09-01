// Niebla TOON — manto de nubes para tapar el vacío bajo un mapa flotante.
//
// Misma idea que la lava y el agua: nada de volumétrico ni de partículas, un
// plano con ruido y CORTE DURO. Un banco de niebla de verdad se resolvería con
// FogVolume, pero eso pide sombreado volumétrico encendido y no pega con el
// resto del juego, que es de bandas planas.
//
// Lo que lo hace leerse como nubes y no como una lámina:
//   · dos capas de ruido arrastrándose a distinta velocidad,
//   · el alfa CUANTIZADO en escalones, que da el borde recortado del dibujo,
//   · un desvanecido radial en el borde del plano, para que no termine en una
//     línea recta que delate que es un cuadrado.
//
// USO: escena NieblaToon.tscn, o este shader en cualquier MeshInstance3D plano.

shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled, unshaded, shadows_disabled;

group_uniforms Color;
uniform vec3 color_alto : source_color = vec3(0.92, 0.94, 1.00);
uniform vec3 color_hondo : source_color = vec3(0.55, 0.60, 0.78);
// Brillo propio. Con glow en el Environment las crestas se encienden un poco.
uniform float emision : hint_range(0.0, 3.0) = 0.35;
group_uniforms;

group_uniforms Nubes;
// Cuánto del plano queda cubierto. En 1 es un manto cerrado.
uniform float cobertura : hint_range(0.0, 1.0) = 0.62;
// Escalones de alfa. 1 = silueta recortada de una sola pieza; 4 = más suave.
uniform int escalones : hint_range(1, 8) = 3;
uniform float escala : hint_range(0.005, 0.5) = 0.035;
uniform float velocidad : hint_range(0.0, 0.5) = 0.015;
// Opacidad máxima. Por debajo de 1 se intuye lo que hay detrás.
uniform float opacidad : hint_range(0.0, 1.0) = 0.95;
// Cuánto CALA el manto: 0 = deck cerrado, 1 = jirones con huecos abiertos.
//
// Por defecto va casi cerrado, y no es capricho. Este manto está para tapar el
// vacío bajo el mapa; si el alfa sigue al ruido, los valles del ruido quedan a
// cero y se ve el fondo por los agujeros, que es justo lo que se venía a
// evitar. Las bandas viven en el COLOR, que da el aspecto dibujado sin abrir
// ventanas. Subilo si querés nubes sueltas en vez de un piso de nubes.
uniform float calados : hint_range(0.0, 1.0) = 0.15;
group_uniforms;

group_uniforms Borde;
// Dónde empieza a desvanecerse hacia el borde del plano, en fracción del radio.
uniform float desvanecido_desde : hint_range(0.0, 1.0) = 0.62;
group_uniforms;

group_uniforms Superficie;
uniform float ondulacion : hint_range(0.0, 8.0) = 1.5;
group_uniforms;

varying vec3 v_mundo;
varying vec2 v_uv;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}


float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * ruido(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}


void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
	// Un vaivén muy lento: de lejos no se nota como movimiento, pero quita la
	// sensación de calcomanía pegada.
	VERTEX.y += sin(v_mundo.x * 0.03 + TIME * 0.25) * cos(v_mundo.z * 0.027 - TIME * 0.2) * ondulacion;
}


void fragment() {
	vec2 uv = v_mundo.xz * escala;
	float a = fbm(uv + vec2(TIME * velocidad, TIME * velocidad * 0.4));
	float b = fbm(uv * 1.7 - vec2(TIME * velocidad * 0.5, TIME * velocidad * 0.8));
	float m = mix(a, b, 0.5);

	// Cuantizar: es lo que convierte el degradado del ruido en nube dibujada.
	float bruto = clamp((m - (1.0 - cobertura)) * 2.6, 0.0, 1.0);
	float pasos = float(escalones);
	float cuantizado = ceil(bruto * pasos) / pasos;

	// Desvanecido radial: el plano deja de existir antes de llegar a su borde.
	float r = length(v_uv - vec2(0.5)) * 2.0;
	float borde = 1.0 - smoothstep(desvanecido_desde, 1.0, r);

	// El tono acompaña al espesor: las crestas claras, los huecos azulados.
	vec3 col = mix(color_hondo, color_alto, cuantizado);

	ALBEDO = col;
	EMISSION = col * emision * cuantizado;
	ALPHA = mix(1.0, cuantizado, calados) * borde * opacidad;
}
