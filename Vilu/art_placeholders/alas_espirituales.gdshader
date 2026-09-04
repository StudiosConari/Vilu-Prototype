shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ---------- Texturas que vienen dentro del .glb ----------
uniform sampler2D tex_color  : source_color, filter_linear_mipmap;
uniform sampler2D tex_normal : hint_normal,  filter_linear_mipmap;
uniform sampler2D tex_rough  : hint_default_white, filter_linear_mipmap;

// ---------- Color espiritual ----------
uniform vec4  tinte : source_color = vec4(0.30, 0.95, 0.85, 1.0);
uniform float tinte_mezcla : hint_range(0.0, 1.0) = 0.40;
uniform float saturacion   : hint_range(0.0, 2.0) = 1.30;

// ---------- Aura de borde (fresnel) ----------
uniform float rim_potencia : hint_range(0.5, 8.0)  = 1.4;
uniform float brillo_base  : hint_range(0.0, 4.0)  = 0.55;
uniform float brillo_borde : hint_range(0.0, 12.0) = 4.6;

// ---------- Translucidez ----------
uniform float alpha_centro : hint_range(0.0, 1.0) = 0.55;
uniform float alpha_borde  : hint_range(0.0, 1.0) = 1.0;

// ---------- Destellos ----------
uniform float destellos_escala    = 34.0;
uniform float destellos_fuerza    : hint_range(0.0, 12.0) = 5.0;
uniform float destellos_umbral    : hint_range(0.0, 1.0)  = 0.66;
uniform float destellos_velocidad = 0.6;

// ---------- Viento magico (bandas que recorren el ala) ----------
uniform float viento_escala   = 5.5;
uniform float viento_fuerza   : hint_range(0.0, 3.0) = 0.9;
uniform float viento_velocidad = 0.35;

// ---------- APARICION / DISOLUCION en degradado ----------
// 1.45 = alas completas   |   -0.35 = totalmente disueltas
// Sube de -0.35 a 1.45 para que APAREZCAN (base -> puntas)
// Baja de 1.45 a -0.35 para que SE DISUELVAN (puntas -> base)
uniform float disolucion : hint_range(-0.35, 1.45) = 1.45;
uniform float disolucion_suavidad : hint_range(0.02, 0.40) = 0.16;
uniform float borde_brillo : hint_range(0.0, 40.0) = 16.0;
uniform float semi_envergadura = 0.489;   // media envergadura del modelo, en metros

// ---------- Control desde codigo ----------
uniform float impulso : hint_range(0.0, 1.0) = 0.0;   // pico en el golpe de alas

varying float grad_ala;   // 0 en la base, 1 en la punta

float hash13(vec3 p){
    p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float ruido3(vec3 x){
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash13(i + vec3(0,0,0)), hash13(i + vec3(1,0,0)), f.x),
                   mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
                   mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex(){
    // gradiente base->punta calculado desde la posicion local del vertice
    grad_ala = clamp(abs(VERTEX.x) / semi_envergadura, 0.0, 1.0);
}

void fragment(){
    vec4 base = texture(tex_color, UV);

    vec3 col = mix(base.rgb, tinte.rgb, tinte_mezcla);
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(luma), col, saturacion);

    NORMAL_MAP = texture(tex_normal, UV).rgb;
    ROUGHNESS  = texture(tex_rough, UV).g;
    METALLIC   = 0.0;

    float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_potencia);

    // destellos
    float n = ruido3(vec3(UV * destellos_escala, TIME * destellos_velocidad));
    float chispa = smoothstep(destellos_umbral, destellos_umbral + 0.14, n) * destellos_fuerza;

    // viento: bandas de energia recorriendo el ala
    float vn = ruido3(vec3(UV * viento_escala, TIME * viento_velocidad));
    float viento = smoothstep(0.46, 0.62, vn) * viento_fuerza;

    // ---- disolucion en degradado con frente encendido ----
    float ruido_dis = ruido3(vec3(UV * 14.0, 0.0));
    float campo = grad_ala * 0.72 + ruido_dis * 0.50;
    float d = disolucion - campo;
    float visible = clamp(d / disolucion_suavidad, 0.0, 1.0);
    float frente  = 1.0 - clamp(abs(d) / disolucion_suavidad, 0.0, 1.0);

    float glow = mix(brillo_base, brillo_borde, fres) + chispa + viento
               + frente * borde_brillo + impulso * 5.0;

    ALBEDO   = col;
    EMISSION = col * glow;
    ALPHA    = mix(alpha_centro, alpha_borde, fres) * visible * base.a;
}
