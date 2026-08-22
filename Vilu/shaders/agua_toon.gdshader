// Agua TOON — plano de superficie para lagunas y bofedales.
//
// El agua de anime no simula nada: es color plano, una franja más clara donde
// toca la orilla, y unas líneas blancas que se mueven encima. Eso es todo lo
// que hace este shader.
//
// LA ESPUMA DE ORILLA usa la textura de profundidad para saber a qué distancia
// está el fondo. Si esa textura no trae datos utilizables, la espuma
// simplemente no aparece y el agua se sigue viendo bien — nunca rompe la
// imagen. (Es la misma precaución que en el shader de contorno.)
//
// USO: escena AguaToon.tscn, o este shader en cualquier MeshInstance3D plano.

shader_type spatial;
// depth_draw_never es CLAVE: si el agua escribiera su propia profundidad,
// después la leería a sí misma, el calado daría cero en todos lados y la
// superficie entera saldría cubierta de espuma.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

uniform sampler2D profundidad : hint_depth_texture, filter_linear;

group_uniforms Color;
uniform vec3 color_llano : source_color = vec3(0.35, 0.72, 0.85);
uniform vec3 color_hondo : source_color = vec3(0.10, 0.32, 0.58);
uniform vec3 color_espuma : source_color = vec3(0.95, 0.99, 1.0);
uniform float opacidad : hint_range(0.0, 1.0) = 0.82;
group_uniforms;

group_uniforms Profundidad;
// A cuántos metros de fondo el agua alcanza su color más hondo.
uniform float hondura : hint_range(0.5, 20.0) = 4.0;
// Ancho de la franja de espuma contra la orilla, en metros.
uniform float ancho_espuma : hint_range(0.0, 3.0) = 0.7;
// Escalones de color. 2 o 3 = look anime; subilo para degradado.
uniform int pasos_color : hint_range(1, 8) = 3;
group_uniforms;

group_uniforms Olas;
uniform float escala_olas : hint_range(0.05, 3.0) = 0.55;
uniform float velocidad : hint_range(0.0, 2.0) = 0.35;
// Cuánta superficie ocupan las líneas blancas.
uniform float densidad_lineas : hint_range(0.0, 1.0) = 0.22;
uniform float altura_ondulado : hint_range(0.0, 1.0) = 0.12;
group_uniforms;

varying vec3 v_mundo;


// Ruido de valor simple, suficiente para el patrón estilizado.
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


void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Ondulado suave de la lámina
	float o = sin(v_mundo.x * 0.35 + TIME * velocidad * 2.0)
			+ cos(v_mundo.z * 0.29 - TIME * velocidad * 1.6);
	VERTEX.y += o * altura_ondulado * 0.5;
}


void fragment() {
	// ─── Profundidad del fondo bajo el agua ───────────────────────────────
	float bruto = texture(profundidad, SCREEN_UV).x;
	float hay_fondo = step(0.000001, bruto);

	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, bruto);
	vec4 vista = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vista.xyz /= max(vista.w, 0.00001);
	float d_fondo = -vista.z;
	float d_agua = -(VIEW_MATRIX * vec4(v_mundo, 1.0)).z;
	// Metros de agua entre la superficie y el fondo
	float calado = max(d_fondo - d_agua, 0.0) * hay_fondo;

	// ─── Color por calado, escalonado ─────────────────────────────────────
	float t = clamp(calado / hondura, 0.0, 1.0);
	float pasos = float(pasos_color);
	t = floor(t * pasos) / max(pasos - 1.0, 1.0);
	vec3 col = mix(color_llano, color_hondo, clamp(t, 0.0, 1.0));

	// ─── Líneas de ola ────────────────────────────────────────────────────
	vec2 uv = v_mundo.xz * escala_olas;
	float n = ruido(uv + vec2(TIME * velocidad, TIME * velocidad * 0.6));
	n += 0.5 * ruido(uv * 2.3 - vec2(TIME * velocidad * 0.8, 0.0));
	float linea = step(1.0 - densidad_lineas, n * 0.66);
	col = mix(col, color_espuma, linea * 0.55);

	// ─── Espuma de orilla ─────────────────────────────────────────────────
	// Donde el fondo está muy cerca de la superficie, o sea el borde.
	float orilla = (1.0 - smoothstep(0.0, max(ancho_espuma, 0.001), calado)) * hay_fondo;
	col = mix(col, color_espuma, orilla);

	ALBEDO = col;
	ROUGHNESS = 0.25;
	SPECULAR = 0.4;
	// El borde se opaca para que no se vea el corte del plano contra la tierra
	ALPHA = clamp(opacidad + orilla * 0.5, 0.0, 1.0);
}
