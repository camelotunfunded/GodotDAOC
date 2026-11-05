shader_type spatial;
render_mode cull_disabled, blend_mix, depth_prepass_alpha;

uniform sampler2D cliff_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 cliff_tint : source_color = vec3(0.68, 0.70, 0.66);
uniform vec3 local_haze_tint : source_color = vec3(0.62, 0.70, 0.74);


void fragment() {
	vec3 rock = texture(cliff_texture, UV).rgb;
	// Exposed zone skirts carry a lower vertex alpha than the permanent
	// backdrop. This creates a local veil on the abrupt cut only: the top
	// dissolves into the real sky/fog while ocean and neighbouring relief keep
	// their normal contrast.
	float haze = 1.0 - COLOR.a;
	ALBEDO = mix(rock * cliff_tint, local_haze_tint, haze * 0.78);
	ALPHA = COLOR.a;
	ROUGHNESS = 0.96;
	SPECULAR = 0.04;
	// The camera can see a closure skirt from either side. Flip the normal on
	// back faces so the cliff follows day/night lighting instead of turning
	// black on one side or glowing through the night as an unshaded material.
	NORMAL = normalize(FRONT_FACING ? NORMAL : -NORMAL);
}
