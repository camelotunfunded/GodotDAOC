shader_type canvas_item;

uniform int realm_channel = 0;

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float primary = realm_channel == 0 ? colour.r : (realm_channel == 1 ? colour.g : colour.b);
	float other = realm_channel == 0 ? max(colour.g, colour.b) : (realm_channel == 1 ? max(colour.r, colour.b) : max(colour.r, colour.g));
	float realm_backdrop = smoothstep(0.035, 0.13, primary - other) * (1.0 - smoothstep(0.34, 0.58, primary));
	colour.a *= 1.0 - realm_backdrop;
	COLOR = colour;
}
