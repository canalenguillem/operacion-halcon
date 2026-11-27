// Fachada de edificio: textura de ventanas (o de muro cortina) en coordenadas del mundo
// —una ventana cada 3 m sea cual sea el tamaño del edificio—, teñida por el color de cada
// instancia del MultiMesh, y con las ventanas encendidas brillando de noche (`night`).
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
// Solo las ventanas encendidas; el resto, negro.
uniform sampler2D lit_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
// Metros que ocupa la textura (4 × 4 ventanas).
uniform float tile = 12.0;
uniform float roughness_value = 0.85;
uniform float metallic_value = 0.0;
// 0 de día, 1 de noche cerrada.
uniform float night = 0.0;
uniform float lit_energy = 1.4;
// Color de las piezas sueltas (sin color por instancia).
uniform vec4 tint : source_color = vec4(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(6.0));
	w /= (w.x + w.y + w.z);
	vec3 x = texture(tex, vec2(p.z, -p.y) / tile).rgb;
	vec3 y = texture(tex, p.xz / tile).rgb;
	vec3 z = texture(tex, vec2(p.x, -p.y) / tile).rgb;
	return x * w.x + y * w.y + z * w.z;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	ALBEDO = triplanar(albedo_tex, world_pos, world_normal) * srgb_to_linear(COLOR.rgb) * tint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	EMISSION = triplanar(lit_tex, world_pos, world_normal) * night * lit_energy;
}
