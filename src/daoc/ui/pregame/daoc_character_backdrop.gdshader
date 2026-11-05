shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.29, 0.13, 0.10, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.07, 0.03, 0.03, 1.0);
uniform vec4 accent : source_color = vec4(0.69, 0.42, 0.22, 1.0);

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(color_top.rgb, color_bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	float radial = 1.0 - smoothstep(0.0, 0.72, distance(uv, vec2(0.47, 0.43)));
	float floor_glow = smoothstep(0.9, 0.42, abs(uv.y - 0.72));
	base += accent.rgb * radial * 0.16;
	base += accent.rgb * floor_glow * 0.035;
	float vignette = smoothstep(0.36, 0.82, distance(uv, vec2(0.5)));
	base *= 1.0 - vignette * 0.38;
	COLOR = vec4(base, 1.0);
}
