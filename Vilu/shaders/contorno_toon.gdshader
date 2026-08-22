// Contorno negro estilo cómic — post-proceso de pantalla completa.
//
// Es lo que define el look de las referencias: línea oscura alrededor de cada
// forma. Hacerlo por material (casco invertido) obligaría a duplicar cada
// material del juego; hacerlo en pantalla lo aplica a TODO de una vez:
// terreno, casas, rocas, cactus y personajes.
//
// NO LEE LA TEXTURA DE PANTALLA, a propósito. Esa vía exige que el material
// esté en la pasada transparente y que el motor haya hecho la copia de
// pantalla; si no se cumple, se lee basura y se pinta sobre toda la imagen.
// En cambio acá sólo se dibuja LA LÍNEA, con alfa: donde no hay borde el alfa
// es 0 y la escena de abajo pasa intacta. Es imposible que tape nada.
//
// CÓMO DETECTA LOS BORDES
//   · Salto de PROFUNDIDAD -> silueta contra lo que hay detrás.
//   · Salto de NORMAL      -> aristas internas (el filo de una roca, la unión
//                             de dos caras de una casa).
// Hacen falta las dos: sólo profundidad pierde los pliegues internos, sólo
// normales pierde la silueta contra el cielo.
//
// USO: va en un QuadMesh hijo de la cámara. Ver ContornoToon.tscn.

shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D profundidad : hint_depth_texture, filter_nearest;
uniform sampler2D normales : hint_normal_roughness_texture, filter_nearest;

group_uniforms Linea;
uniform vec3 color_linea : source_color = vec3(0.08, 0.06, 0.10);
// Grosor en píxeles. Las referencias usan línea gruesa y pareja.
uniform float grosor : hint_range(0.5, 5.0) = 1.5;
uniform float opacidad : hint_range(0.0, 1.0) = 0.85;
group_uniforms;

group_uniforms Sensibilidad;
// Cuánto salto de profundidad hace falta para dibujar línea. Bajo = más líneas.
uniform float umbral_profundidad : hint_range(0.01, 5.0) = 0.4;
// Cuánto tienen que diferir dos normales. Bajo = marca hasta curvas suaves.
uniform float umbral_normal : hint_range(0.05, 1.5) = 0.6;
// A partir de esta distancia la línea se desvanece, para que el horizonte no
// se llene de trazos.
uniform float distancia_fin : hint_range(20.0, 500.0) = 200.0;
group_uniforms;


// Profundidad cruda del buffer. Con Z invertida (lo que usa Godot), el fondo
// SIN geometría vale 0. Sirve para saber si un píxel es cielo.
float bruto(vec2 uv) {
	return texture(profundidad, uv).x;
}


bool es_fondo(vec2 uv) {
	return bruto(uv) <= 0.000001;
}


// Profundidad lineal en metros desde la cámara.
float dist_lineal(vec2 uv, mat4 inv_proj) {
	float d = texture(profundidad, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	vec4 vista = inv_proj * vec4(ndc, 1.0);
	vista.xyz /= vista.w;
	return -vista.z;
}


vec3 normal_en(vec2 uv) {
	return texture(normales, uv).xyz * 2.0 - 1.0;
}


void vertex() {
	// El QuadMesh mide 2x2, así que VERTEX.xy ya va de -1 a 1: es exactamente
	// el rango del espacio de recorte.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


void fragment() {
	vec2 texel = grosor / VIEWPORT_SIZE;
	float d_centro = dist_lineal(SCREEN_UV, INV_PROJECTION_MATRIX);
	float borde = 0.0;

	vec2 offs[4] = vec2[4](
		vec2( texel.x, 0.0), vec2(-texel.x, 0.0),
		vec2(0.0,  texel.y), vec2(0.0, -texel.y)
	);

	// Las NORMALES se evalúan siempre y la profundidad refuerza cuando existe.
	//
	// La razón original de esta estructura era que la textura de profundidad
	// "no traía datos utilizables". Eso era cierto, pero la causa no estaba
	// acá: toon_objeto.gdshader escribía ALPHA, lo que mandaba TODOS los
	// objetos a la cola transparente, y los transparentes no escriben ni
	// profundidad ni normales. Arreglado eso, los dos buffers traen datos.
	//
	// La estructura se mantiene igual porque sigue siendo correcta: el fondo
	// sin geometría no se puede linealizar, así que hay que tratarlo aparte.
	vec3 n_centro = normal_en(SCREEN_UV);
	float dif_norm = 0.0;
	float dif_prof = 0.0;
	float silueta = 0.0;

	bool hay_prof = !es_fondo(SCREEN_UV);

	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i];
		dif_norm = max(dif_norm, distance(n_centro, normal_en(uv)));
		if (hay_prof) {
			if (es_fondo(uv)) {
				// Vecino sin geometría: recorte contra el cielo. Se marca
				// aparte porque linealizar el fondo divide por cero, y un NaN
				// hace que step() devuelva 0 — así se perdía la silueta.
				silueta = 1.0;
			} else {
				dif_prof = max(dif_prof,
					abs(d_centro - dist_lineal(uv, INV_PROJECTION_MATRIX)));
			}
		}
	}

	float borde_norm = step(umbral_normal, dif_norm);
	float borde_prof = 0.0;
	if (hay_prof) {
		// El umbral crece con la distancia: si fuera fijo, a 100 m cualquier
		// ladera vista de canto dispararía línea por su propia pendiente y el
		// horizonte sería una maraña.
		float umbral = umbral_profundidad * max(1.0, d_centro * 0.06);
		borde_prof = step(umbral, dif_prof);
	}

	borde = clamp(borde_norm + borde_prof + silueta, 0.0, 1.0);

	// Desvanecido en la lejanía, sólo si la profundidad es utilizable.
	if (hay_prof) {
		borde *= 1.0 - smoothstep(distancia_fin * 0.6, distancia_fin, d_centro);
	}

	ALBEDO = color_linea;
	ALPHA = borde * opacidad;
}
