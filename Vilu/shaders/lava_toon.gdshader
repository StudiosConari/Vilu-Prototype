// Lava TOON — plano de superficie para el fondo de los cráteres.
//
// Misma idea que el agua: nada de simulación. Costra oscura, grietas
// incandescentes que se mueven lento, y bordes más calientes. La clave del
// aspecto anime está en que las grietas tienen CORTE DURO, no degradado.
//
// USO: escena LavaToon.tscn, o este shader en cualquier MeshInstance3D plano.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_disabled, unshaded;

group_uniforms Color;
uniform vec3 color_costra : source_color = vec3(0.15, 0.07, 0.07);
uniform vec3 color_lava : source_color = vec3(0.95, 0.32, 0.06);
uniform vec3 color_brasa : source_color = vec3(1.0, 0.85, 0.30);
// Cuánto brilla la lava. Con glow activo en el Environment, esto la hace lucir.
uniform float emision : hint_range(0.0, 8.0) = 2.6;
group_uniforms;

group_uniforms Grietas;
// Qué proporción de la superficie es lava viva y no costra.
uniform float cantidad : hint_range(0.0, 1.0) = 0.42;
// 0 = corte perfectamente duro (más anime), 1 = degradado.
uniform float suavidad : hint_range(0.0, 0.5) = 0.06;
uniform float escala : hint_range(0.02, 1.0) = 0.13;
uniform float velocidad : hint_range(0.0, 1.0) = 0.06;
group_uniforms;

group_uniforms Superficie;
uniform float altura_burbujeo : hint_range(0.0, 1.0) = 0.10;
group_uniforms;

varying vec3 v_mundo;


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


// Varias octavas: da la forma irregular de las placas de costra.
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}


void vertex() {
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float b = sin(v_mundo.x * 0.5 + TIME * 0.7) * cos(v_mundo.z * 0.43 - TIME * 0.5);
	VERTEX.y += b * altura_burbujeo * 0.5;
}


void fragment() {
	vec2 uv = v_mundo.xz * escala;
	// Dos capas que se arrastran en sentidos distintos: da sensación de flujo
	float a = fbm(uv + vec2(TIME * velocidad, TIME * velocidad * 0.35));
	float b = fbm(uv * 1.9 - vec2(TIME * velocidad * 0.6, TIME * velocidad));
	float m = mix(a, b, 0.45);

	// Corte duro entre costra y lava
	float umbral = 1.0 - cantidad;
	float grieta = smoothstep(umbral - suavidad, umbral + suavidad, m);

	// El centro de la grieta va más caliente que su borde
	float centro = smoothstep(umbral + 0.08, umbral + 0.22, m);

	vec3 col = mix(color_costra, color_lava, grieta);
	col = mix(col, color_brasa, centro * 0.75);

	ALBEDO = col;
	// Sólo emite donde hay lava viva; la costra queda apagada.
	EMISSION = col * emision * max(grieta, centro);
	ALPHA = 1.0;
}
