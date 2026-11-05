shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never;

uniform vec3 fog_color : source_color = vec3(0.40, 0.59, 0.68);


void fragment() {
	// A very slow procedural variation avoids a perfectly flat translucent
	// wall. Vertex alpha supplies the real vertical/horizontal feathering.
	float wisp = 0.96 + 0.04 * sin(UV.x * 4.0 + UV.y * 3.0 + TIME * 0.025);
	ALBEDO = fog_color;
	EMISSION = fog_color * 0.18;
	ALPHA = COLOR.a * wisp;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = normalize(FRONT_FACING ? NORMAL : -NORMAL);
}
