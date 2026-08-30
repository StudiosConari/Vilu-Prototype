// Sombreado TOON para objetos comunes: casas, props, rocas, personajes.
//
// Complementa a toon_terrain.gdshader. Usa exactamente la misma rampa de luz
// escalonada, para que un cactus y el suelo bajo sus pies reciban la luz igual
// y la escena se lea como una sola ilustración.
//
// Soporta textura (los FBX de flora y roca la traen) o color plano (las cajas
// de CSG de las casas y las cápsulas de los personajes).
//
// Se aplica con scenes/core/ToonSkin.gd, que recorre el árbol y convierte los
// StandardMaterial3D conservando su color y su textura.
//
// ESTA VERSIÓN ES OPACA Y NO DEBE ESCRIBIR ALPHA NUNCA.
//
// En Godot 4 basta con que el código mencione ALPHA para que el material pase
// a la cola transparente: es una decisión de compilación, no depende de que el
// valor sea 1.0. Y un objeto transparente se ordena POR OBJETO en vez de por
// píxel, y no escribe al buffer de profundidad ni al de normales.
//
// Cuando esta versión sí escribía ALPHA, el resultado era que las paredes no
// se tapaban entre sí —todo el mundo se veía en rayos X— y el contorno de
// post-proceso leía dos buffers vacíos, así que dibujaba líneas donde no
// correspondía. Para lo que de verdad es translúcido está la variante
// toon_objeto_translucido.gdshader, y ToonSkin elige entre las dos.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

group_uniforms Color;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D textura_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool usar_textura = false;
// Sube la saturación del color base para acercarlo a la viveza del cómic.
uniform float saturacion : hint_range(0.5, 2.5) = 1.25;
group_uniforms;

group_uniforms Luz_Toon;
uniform int pasos_luz : hint_range(1, 6) = 3;
uniform float dureza_corte : hint_range(0.001, 0.3) = 0.02;
// Ancho del degradado en el BORDE de la sombra proyectada, aparte del de las
// bandas de luz. Antes salia de dureza_corte x4, o sea que afinar el corte del
// cel shading afilaba tambien el borde de sombra, y ahi es donde se nota: el
// filtro de sombras entrega una penumbra de varios metros y un corte estrecho
// la colapsa contra la reticula del mapa, en escalones.
uniform float sombra_suavidad : hint_range(0.01, 0.5) = 0.08;
uniform float piso_sombra : hint_range(0.0, 0.8) = 0.35;
uniform vec3 tinte_sombra : source_color = vec3(0.55, 0.60, 0.85);
group_uniforms;

group_uniforms Contorno_Luz;
uniform float rim_fuerza : hint_range(0.0, 2.0) = 0.30;
uniform float rim_ancho : hint_range(0.0, 1.0) = 0.6;
uniform vec3 rim_color : source_color = vec3(1.0, 0.97, 0.85);
group_uniforms;


vec3 saturar(vec3 c, float k) {
	float gris = dot(c, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(gris), c, k), vec3(0.0), vec3(1.0));
}


void fragment() {
	vec4 c = albedo;
	if (usar_textura) {
		c *= texture(textura_albedo, UV);
	}
	ALBEDO = saturar(c.rgb, saturacion);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Sin ALPHA a propósito. Ver la nota de la cabecera.
}


void light() {
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(LIGHT);

	// Media lambert: comprime el rango para que la cara oscura no se apague
	float nl = dot(N, L) * 0.5 + 0.5;

	// Escalonado: el corazón del cel shading
	float pasos = float(pasos_luz);
	float escalado = clamp(nl, 0.0, 1.0) * pasos;
	float base = floor(escalado);
	float resto = escalado - base;
	float aa = max(fwidth(escalado) * 0.5, dureza_corte);
	float banda = (base + smoothstep(0.5 - aa, 0.5 + aa, resto)) / pasos;

	// La sombra proyectada también se corta duro, no degrada
	float sombra = smoothstep(0.5 - sombra_suavidad, 0.5 + sombra_suavidad, ATTENUATION);
	banda *= mix(piso_sombra, 1.0, sombra);

	// Nunca a negro: la sombra se rellena con un tinte frío
	float iluminacion = mix(piso_sombra, 1.0, banda);
	vec3 tinte = mix(tinte_sombra, vec3(1.0), banda);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * tinte * iluminacion;

	// Luz de borde: despega la silueta del fondo
	float rim = 1.0 - clamp(dot(N, normalize(VIEW)), 0.0, 1.0);
	rim = smoothstep(1.0 - rim_ancho, 1.0, rim) * rim_fuerza;
	DIFFUSE_LIGHT += rim_color * rim * clamp(dot(N, L), 0.0, 1.0);
}
