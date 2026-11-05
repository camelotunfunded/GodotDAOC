// Copyright (c) 2023-2025 Cory Petkovsek and Contributors
// Copyright (c) 2021 J. Cuellar

shader_type sky;
render_mode use_debanding;

group_uniforms general;
uniform bool sky_visible = true;
uniform vec2 color_correction = vec2(0.0, 1.0);
uniform vec4 ground_color: source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float horizon_offset = 0.0;

group_uniforms atmosphere;
uniform float atm_darkness = 0.5;
uniform float atm_sun_intensity = 18.0;
uniform vec4 atm_day_tint: source_color = vec4(0.808, 0.91, 1.0, 1.0);
uniform vec4 atm_horizon_light_tint: source_color = vec4(0.98, 0.635, 0.463, 1.0);
uniform vec4 atm_night_tint: source_color = vec4 (0.041, 0.049, 0.061, 0.245);
uniform vec3 atm_level_params = vec3(1.0, 0.0, 0.0);
uniform float atm_thickness = 0.7;
uniform vec3 atm_beta_ray = vec3(0.00001, 0.00001, 0.00003);
uniform vec3 atm_beta_mie = vec3(0.00000003038); // Value computed by multiplying Mie, turbidity, and 0.000434.

group_uniforms sun_disk;
uniform vec4 sun_light_color: source_color = vec4(1.0);
uniform vec4 sun_disk_color: source_color = vec4(0.996, 0.541, 0.14, 1.0);
uniform float sun_disk_intensity = 2.0;
uniform float sun_disk_size = 0.015;

group_uniforms sun_mie;
uniform vec4 atm_sun_mie_tint: source_color = vec4(1.0);
uniform float atm_sun_mie_intensity = 1.0;
uniform vec3 atm_sun_partial_mie_phase = vec3(0.36, 1.64, 1.6);

group_uniforms moon;
uniform vec4 moon_color: source_color = vec4(1.0);
uniform sampler2D moon_texture: source_color, repeat_disable;
uniform vec3 moon_texture_alignment = vec3(7.0, 1.4, 4.8);
uniform bool moon_texture_flip_u;
uniform bool moon_texture_flip_v;
uniform float moon_size = 0.07;

group_uniforms moon_mie;
uniform vec4 atm_moon_mie_tint: source_color = vec4(0.137, 0.184, 0.292, 1.0);
uniform float atm_moon_mie_intensity = 0.17152;
uniform vec3 atm_moon_partial_mie_phase = vec3(0.36, 1.64, 1.6);

group_uniforms star_map;
uniform vec4 starmap_color: source_color = vec4(0.71, 0.71, 0.71, 0.855);
uniform sampler2D starmap_texture: source_color;
uniform bool starmap_flip_u = false;
uniform bool starmap_flip_v = false;
uniform vec3 starmap_alignment = vec3(2.68288, -0.25891, 0.40101);
uniform float star_rotation_offset = 9.38899;
uniform float star_rotation = 0.0; // For simulating Earth rotation.
uniform float star_tilt = 0.0; // For tilting the sky according to observer latitude in radians. (90° - latitude)

group_uniforms star_field;
uniform vec4 star_field_color: source_color = vec4(1.0);
uniform sampler2D star_field_texture: source_color;
uniform float star_scintillation = 0.75;
uniform float star_scintillation_speed = 0.01;
uniform sampler2D noise_tex: source_color;

/* Sky alignment values for a star map that is in galactic coordinates. Works for most star maps.
X: 2.6555
Y: -0.23935
Z: 0.4505

These alignment values are consistent with a sky view from the North Pole (latitude zero)
at midnight. The positions of Polaris, Vega, Rigel, and Alpha Centauri confirmed
through various sources and calculations.
*/

group_uniforms clouds;
uniform vec4 clouds_night_color: source_color = vec4(0.09, 0.094, 0.129, 1.0);

group_uniforms daoc_legacy_clouds;
uniform bool daoc_legacy_clouds_enabled = false;
uniform sampler2D daoc_cloud_top_texture: source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D daoc_cloud_bottom_texture: source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D daoc_cloud_top_texture2: source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D daoc_cloud_bottom_texture2: source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 daoc_cloud_tiles = vec4(5.0, 4.0, 4.0, 3.0);
uniform vec4 daoc_cloud_speeds = vec4(0.003, 0.005, 0.005, 0.009);
uniform vec2 daoc_cloud_motion = vec2(0.0);
uniform float daoc_cloud_coverage = 0.28;
uniform float daoc_cloud_storminess = 0.0;
uniform float daoc_cloud_intensity = 1.0;
// Shape of each of the four layers (x = top, y = bottom, z = top2, w = bottom2).
// altitude: 1.0 = a high ceiling, almost flat overhead and slow near the horizon;
//           0.0 = a low ceiling, strong perspective, fast drift.
// softness: 0.0 = compact puffs with crisp edges; 1.0 = a diffuse, misty veil.
uniform vec4 daoc_cloud_altitude = vec4(0.85, 0.30, 0.65, 0.15);
uniform vec4 daoc_cloud_softness = vec4(0.55, 0.30, 0.75, 0.40);
// 0 keeps the flat legacy look; 1 shades the sun-facing edges and darkens the
// thick undersides by reading the layers again a little toward the sun.
uniform float daoc_cloud_shading = 0.7;
// Sunlight bleeding through the thin parts when looking toward the sun.
uniform float daoc_cloud_silver_lining = 0.6;
// How much of the sky colour behind them the clouds pick up (haze, distance).
uniform float daoc_cloud_sky_tint = 0.3;

group_uniforms daoc_celestial;
// Textured sun and moon sprites taken from the original DAoC client. The legacy
// client draws each of them as a camera-facing quad at sun_distance /
// moon_distance; every radius below is that quad's half-size divided by its
// distance, i.e. its angular half-size in radians, straight out of sky_*.dat.
uniform bool daoc_celestial_enabled = false;
uniform bool daoc_sun_sprites_visible = true;
uniform bool daoc_moon_sprites_visible = true;
uniform sampler2D daoc_sun_disk_texture: source_color, repeat_disable, filter_linear;
uniform sampler2D daoc_sun_flare_texture: source_color, repeat_disable, filter_linear;
uniform sampler2D daoc_sun_glow_texture: source_color, repeat_disable, filter_linear;
uniform sampler2D daoc_moon_disk_texture: source_color, repeat_disable, filter_linear;
uniform sampler2D daoc_moon_back_texture: source_color, repeat_disable, filter_linear;
// xyz = tint, w = the DAT alpha, kept as an explicit intensity because the
// source BMPs carry no alpha channel of their own.
uniform vec4 daoc_sun_disk_tint: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 daoc_sun_flare_tint: source_color = vec4(1.0, 0.63, 0.12, 0.5);
uniform vec4 daoc_sun_glow_tint: source_color = vec4(1.0, 0.63, 0.12, 1.0);
uniform vec4 daoc_moon_tint: source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform vec4 daoc_moon_back_tint: source_color = vec4(0.06, 0.2, 0.35, 1.0);
uniform vec3 daoc_sun_radii = vec3(0.015, 0.15, 0.15); // disk, flare, glow
uniform float daoc_moon_radius = 0.015;

group_uniforms cirrus_clouds;
uniform bool cirrus_visible = true;
uniform float cirrus_intensity = 2.0;
uniform float cirrus_coverage = 0.5;
uniform float cirrus_thickness = 10.0;
uniform float cirrus_absorption = 2.0;
uniform float cirrus_sky_tint_fade = 0.5;
uniform float cirrus_size = 1.0;
uniform vec2 cirrus_uv = vec2(0.16, 0.11);
uniform vec2 cirrus_position1 = vec2(0.0);
uniform vec2 cirrus_position2 = vec2(0.0);
uniform sampler2D cirrus_texture;

group_uniforms cumulus_clouds;
uniform bool cumulus_visible = true;
uniform float cumulus_intensity = 0.6;
uniform float cumulus_coverage = 0.55;
uniform float cumulus_thickness = 0.0243;
uniform float cumulus_absorption = 2.0;
uniform float cumulus_noise_freq = 2.7;
uniform float cumulus_sky_tint_fade = 0.0;
uniform float cumulus_size = 0.5;
uniform vec2 cumulus_position = vec2(0.0);
uniform sampler2D cumulus_texture;
uniform vec3 cumulus_partial_mie_phase = vec3(0.95756, 1.04244, 0.412);
uniform float cumulus_mie_intensity = 1.0;

group_uniforms overlays;
uniform bool show_azimuthal_grid = false;
uniform vec4 azimuthal_grid_color : source_color = vec4(.871, .722, .529, 1.);
uniform float azimuthal_grid_rotation_offset = 0.03;
uniform bool show_equatorial_grid = false;
uniform vec4 equatorial_grid_color : source_color = vec4(0., .75, 1., 1.);
uniform float equatorial_grid_rotation_offset = 0.03;

group_uniforms transform_matrices;
uniform mat3 moon_matrix; // Calculated externally via GDScript.

#include "Common.gdshaderinc"

// Provides a transformation matrix when passed a vec3.
mat3 create_rotation_matrix(vec3 r) {
	float c1 = cos(r.x), s1 = sin(r.x);
	float c2 = cos(r.y), s2 = sin(r.y);
	float c3 = cos(r.z), s3 = sin(r.z);

	mat3 rotX = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, c1, -s1),
		vec3(0.0, s1, c1)
	);

	mat3 rotY = mat3(
		vec3(c2, 0.0, s2),
		vec3(0.0, 1.0, 0.0),
		vec3(-s2, 0.0, c2)
	);

	mat3 rotZ = mat3(
		vec3(c3, -s3, 0.0),
		vec3(s3, c3, 0.0),
		vec3(0.0, 0.0, 1.0)
	);

	return rotZ * rotY * rotX; // Combine rotations in ZYX order
}

vec2 calc_equirect_uv(vec3 norm) {
	float flipu = starmap_flip_u ? -1.0 : 1.0;
	float flipv = starmap_flip_v ? -1.0 : 1.0;
	float u = flipu * ((atan(norm.y, norm.x) + PI) * INV_TAU); // 0 to 1 horizontally
	float v = -flipv * (acos(norm.z) * INV_PI); // 0 (north pole) to 1 (south pole)
	return vec2(u, v);
}

vec3 sample_moon_texture(vec3 dir) {
	dir = moon_matrix * dir * create_rotation_matrix(moon_texture_alignment);
	dir.x = -dir.x;
	dir.z = -dir.z;
	float flipu = moon_texture_flip_u ? 1.0 : -1.0;
	float flipv = moon_texture_flip_v ? 1.0 : -1.0;
	float u = 0.5 + flipu * atan(dir.z, dir.x) * INV_TAU; // Longitude
	float v = 0.5 + flipv * asin(dir.y) * INV_PI; // Latitude
	return texture(moon_texture, vec2(u, v)).rgb;
}

float calc_disk_mask(vec3 norm, vec3 coords, lowp float size) {
	float dist = length(norm - coords);
	return 1.0 - step(size, dist);
}

// Samples one DAoC sky sprite in the direction `dir`. `body_pos` is the unit
// direction of the sun or the moon and `radius` its angular half-size. The
// projection is gnomonic on purpose: the client billboards a FLAT quad, so a
// spherical cap would deform the disk as it approaches the horizon.
vec4 sample_daoc_sprite(sampler2D tex, vec3 dir, vec3 body_pos, float radius) {
	float depth = dot(dir, body_pos);
	if (radius <= 0.0 || depth <= 0.001) {
		return vec4(0.0);
	}
	// Any reference vector that is not parallel to body_pos; swapped at the
	// zenith so the basis never collapses when the body is straight overhead.
	vec3 up_ref = abs(body_pos.y) > 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up_ref, body_pos));
	vec3 up = cross(body_pos, right);
	vec2 offset = vec2(dot(dir, right), dot(dir, up)) / (depth * radius);
	if (abs(offset.x) > 1.0 || abs(offset.y) > 1.0) {
		return vec4(0.0);
	}
	return texture(tex, offset * vec2(0.5, -0.5) + vec2(0.5));
}

float map_range(float value, float from_min, float from_max, float to_min, float to_max) {
	return to_min + (value - from_min) * (to_max - to_min) / (from_max - from_min);
}

bool ray_sphere_intersect(float r, vec3 origin, vec3 dir, out float t, out vec3 nrm) {
	origin += vec3(0.0, 450.0, 0.0);
	float a = dot(dir, dir);
	float b = 2.0 * dot(origin, dir);
	float c = dot(origin, origin) - r * r;
	float d = b * b - 4.0 * a * c;
	float valid = step(0.0, d); // 1.0 if d >= 0.0, else 0.0
	d = sqrt(max(d, 0.0)); // Prevent sqrt of negative numbers
	a *= 2.0;
	float t1 = 0.5 * (-b + d);
	float t2 = 0.5 * (-b - d);
	float t_min = min(t1, t2); // Select the smallest intersection
	t = mix(t2, t1, step(t2, t1) * step(0.0, t1)); // Use t1 if t2 < t1 and t1 >= 0, else t2
	t = mix(0.0, t, step(0.0, t) * valid); // Invalidate if t < 0 or d < 0
	nrm = mix(vec3(0.0), origin + t * dir, step(0.0, t) * valid); // Set nrm only if valid
	return bool(step(0.0, t) * valid);
}

// For rendering the moon. This function courtesy of Kelvin van Hoorn.
// https://kelvinvanhoorn.com/2024/12/07/skybox-tutorial-godot/
float simple_sphere_intersect(vec3 ray_dir, vec3 sphere_pos, float radius) {
	vec3 oc = -sphere_pos;
	float b = dot(oc, ray_dir);
	float c = dot(oc, oc) - radius * radius;
	float h = b * b - c;
	float valid = step(0.0, h); // 1.0 if h >= 0.0, else 0.0
	h = sqrt(max(h, 0.0)); // Ensure sqrt is non-negative
	return mix(-1.0, -b - h, valid);
}

// Atmosphere
//------------------------------------------------------------------------------

vec3 calc_atmospheric_scatter(float sr, float sm, vec2 mu, vec3 mult) {
	vec3 beta_mie = atm_beta_mie;
	vec3 beta_ray = atm_beta_ray * atm_thickness;

	vec3 extc_factor = clamp_rgb_to_unit(exp(-(beta_ray * sr + beta_mie * sm)));

	float extc_ff = mix(clamp_to_unit(atm_thickness * 0.5), 1.0, mult.x);
	vec3 final_extc_factor = mix(1.0 - extc_factor, (1.0 - extc_factor) * extc_factor, extc_ff);
	float rayleigh_phase = calc_rayleigh_phase(mu.x);
	vec3 BRT = beta_ray * rayleigh_phase;
	vec3 BMT = beta_mie * calc_mie_phase(mu.x, atm_sun_partial_mie_phase);
	BMT *= atm_sun_mie_intensity * atm_sun_mie_tint.rgb;

	vec3 BRMT = (BRT + BMT) / (beta_ray + beta_mie);
	vec3 scatter = atm_sun_intensity * (BRMT * final_extc_factor) * atm_day_tint.rgb * mult.y;
	scatter = mix(scatter, scatter * (1.0 - extc_factor), atm_darkness);

	vec3 lcol =  mix(atm_day_tint.rgb, atm_horizon_light_tint.rgb, mult.x);
	vec3 nscatter = (1.0 - extc_factor) * atm_night_tint.rgb;
	nscatter += calc_mie_phase(mu.y, atm_moon_partial_mie_phase) *
		atm_moon_mie_tint.rgb * atm_moon_mie_intensity * 0.005;

	return (scatter * lcol) + nscatter;
}

// Clouds
//------------------------------------------------------------------------------
const int CUMULUS_STEP = 10;

// One cloud layer lives on a flat ceiling at a height set by `altitude`. The
// old tangent plane (xz / y) exploded at the horizon into a checkerboard; the
// equirect that replaced it had no perspective at all, so every layer looked
// glued to the same dome. Adding a constant to the divisor keeps the plane's
// perspective while bounding it: the ceiling height is that constant. The
// factor (h + 1) keeps the texel density at the zenith identical whatever the
// height, so the DAT `tiles` values keep their meaning.
vec2 daoc_cloud_uv(vec3 dir, float altitude) {
	float h = mix(0.30, 2.0, clamp_to_unit(altitude));
	return dir.xz / (max(dir.y, 0.0) + h) * ((h + 1.0) * 0.16);
}

// A low ceiling passes overhead faster than a high one at the same wind:
// plain parallax, and the cheapest way to make the layers separate.
float daoc_cloud_parallax(float altitude) {
	return mix(1.7, 0.6, clamp_to_unit(altitude));
}

// Turns the raw PNG alpha into a cloud edge. Compact clouds cut a narrow band
// out of the alpha ramp (crisp puffs); diffuse ones keep almost the whole ramp
// (a veil). `gain` is the coverage: it pushes the ramp up before the cut.
float daoc_cloud_shape(float alpha, float softness, float gain) {
	float lo = mix(0.42, 0.04, softness);
	float hi = mix(0.62, 1.00, softness);
	return smoothstep(lo, hi, alpha * gain);
}

// Shaped, weighted alpha of the four layers at direction `dir`. Shared by the
// main sample and the toward-the-sun sample used for shading.
vec4 daoc_cloud_layers(vec3 dir, vec2 wind, float coverage_gain, out vec4 top, out vec4 bottom,
		out vec4 top2, out vec4 bottom2) {
	top = textureLod(daoc_cloud_top_texture, daoc_cloud_uv(dir, daoc_cloud_altitude.x) * daoc_cloud_tiles.x
		+ wind * daoc_cloud_speeds.x * daoc_cloud_parallax(daoc_cloud_altitude.x), 0.0);
	bottom = textureLod(daoc_cloud_bottom_texture, daoc_cloud_uv(dir, daoc_cloud_altitude.y) * daoc_cloud_tiles.y
		+ wind * daoc_cloud_speeds.y * daoc_cloud_parallax(daoc_cloud_altitude.y), 0.0);
	top2 = textureLod(daoc_cloud_top_texture2, daoc_cloud_uv(dir, daoc_cloud_altitude.z) * daoc_cloud_tiles.z
		+ wind * daoc_cloud_speeds.z * daoc_cloud_parallax(daoc_cloud_altitude.z), 0.0);
	bottom2 = textureLod(daoc_cloud_bottom_texture2, daoc_cloud_uv(dir, daoc_cloud_altitude.w) * daoc_cloud_tiles.w
		+ wind * daoc_cloud_speeds.w * daoc_cloud_parallax(daoc_cloud_altitude.w), 0.0);
	vec4 shaped = vec4(
		daoc_cloud_shape(top.a, daoc_cloud_softness.x, coverage_gain),
		daoc_cloud_shape(bottom.a, daoc_cloud_softness.y, coverage_gain),
		daoc_cloud_shape(top2.a, daoc_cloud_softness.z, coverage_gain),
		daoc_cloud_shape(bottom2.a, daoc_cloud_softness.w, coverage_gain));
	// The four DAT layers keep their historical weights; coverage also lifts
	// them so a storm can actually close the sky instead of stopping at 86 %.
	vec4 weights = mix(vec4(0.55, 0.42, 0.30, 0.23), vec4(0.92, 0.80, 0.62, 0.50),
		clamp_to_unit(daoc_cloud_coverage));
	return clamp(shaped * weights, vec4(0.0), vec4(1.0));
}

// Returns colour in rgb, opacity in a. `shade` receives a multiplier for the
// cloud colour: > 1 on the sun-facing rims, < 1 under thick cover.
vec4 render_daoc_legacy_clouds(vec3 pos, vec3 sun_pos, out float shade) {
	vec3 dir = normalize(pos);
	vec2 wind = daoc_cloud_motion;
	float coverage_gain = mix(0.55, 1.35, clamp_to_unit(daoc_cloud_coverage));
	vec4 top, bottom, top2, bottom2;
	vec4 layer_alpha = daoc_cloud_layers(dir, wind, coverage_gain, top, bottom, top2, bottom2);
	float opacity = 1.0 - ((1.0 - layer_alpha.x) * (1.0 - layer_alpha.y) *
		(1.0 - layer_alpha.z) * (1.0 - layer_alpha.w));
	float weight = max(dot(layer_alpha, vec4(1.0)), 0.0001);
	vec3 cloud_color = (top.rgb * layer_alpha.x + bottom.rgb * layer_alpha.y +
		top2.rgb * layer_alpha.z + bottom2.rgb * layer_alpha.w) / weight;

	shade = 1.0;
	if (daoc_cloud_shading > 0.0 && opacity > 0.002) {
		// Read the cover again slightly toward the sun. Thinner there means
		// this point is a lit rim; thicker means it sits in the shadow of its
		// own cloud. Purely 2D, but it gives the puffs a lit side and a base.
		vec3 toward = normalize(dir + sun_pos * 0.035);
		vec4 t1, t2, t3, t4;
		vec4 alpha_toward = daoc_cloud_layers(toward, wind, coverage_gain, t1, t2, t3, t4);
		float thick_here = dot(layer_alpha, vec4(1.0));
		float thick_toward = dot(alpha_toward, vec4(1.0));
		float rim = clamp((thick_here - thick_toward) * 2.5, -1.0, 1.0);
		// Sun below the horizon: the rims cannot be lit from above any more.
		float sun_up = clamp_to_unit(sun_pos.y * 4.0 + 0.2);
		shade = 1.0 + daoc_cloud_shading * (0.55 * rim * sun_up - 0.45 * opacity * opacity);
		shade = max(shade, 0.25);
	}
	return vec4(cloud_color, clamp_to_unit(opacity));
}

float sample_cirrus_noise(vec2 coords) {
	float a = textureLod(cirrus_texture, coords.xy * cirrus_uv + cirrus_position1, 0.0).r;
	float b = textureLod(cirrus_texture, coords.xy * cirrus_uv + cirrus_position2, 0.0).r;
	return ((a + b) * 0.5);
}

float sample_cumulus_noise(vec3 p) {
	vec3 pos = vec3(p * 0.01);
	pos.z *= 256.0;
	vec2 offset = vec2(0.317, 0.123);
	vec4 uv = vec4(0.0);
	uv.xy = pos.xy + offset * floor(pos.z);
	uv.zw = uv.xy + offset;
	float x1 = textureLod(cumulus_texture, uv.xy, 0.0).r;
	float x2 = textureLod(cumulus_texture, uv.zw, 0.0).r;
	return mix(x1, x2, fract(pos.z));
}

float calc_cumulus_fbm(vec3 p, float l) {
	float ret;
	ret = 0.51749673 * sample_cumulus_noise(p);
	p *= l;
	ret += 0.25584929 * sample_cumulus_noise(p);
	p *= l;
	ret += 0.12527603 * sample_cumulus_noise(p);
	p *= l;
	ret += 0.06255931 * sample_cumulus_noise(p);
	return ret;
}

float calc_cirrus_density(vec2 p) {
	float d = sample_cirrus_noise(p);
	float c = 1.0 - cirrus_coverage;
	d = d - c;
	return clamp_to_unit(d);
}

float calc_cumulus_density(vec3 p, vec3 offset, float t) {
	vec3 pos = p * 0.0212242 - offset;
	float dens = calc_cumulus_fbm(pos, cumulus_noise_freq);
	dens += dens;

	float cov = 1.0 - cumulus_coverage;
	cov = smoothstep(0.00, (cov * 3.5) + t, dens);
	dens *= cov;
	dens = map_range(dens, 1.0 - cov, 1.0, 0.0, 1.0);

	return clamp_to_unit(dens);
}

vec4 render_cirrus_clouds(vec3 pos) {
	pos.xy = pos.xz / pos.y;
	pos *= cirrus_size;
	float density = calc_cirrus_density(pos.xy);
	float sh = clamp_to_unit(exp(-cirrus_absorption * density));
	float a = clamp_to_unit(density * cirrus_thickness);
	return vec4(vec3(density*sh) * cirrus_intensity, a);
}

vec4 render_cumulus_clouds(vec3 ro, vec3 rd, float am, vec3 sun_pos, vec3 moon_pos) {
	vec4 ret = vec4(0.);
	vec3 wind = -vec3(cumulus_position.x, 0.0, cumulus_position.y);
	float a = 0.0;

	// n and tt doesnt need to be initialized since it would be set by ray_sphere_intersect
	vec3 n; float tt;
	if (ray_sphere_intersect(500., ro, rd, tt, n)) {
		float march_step = float(CUMULUS_STEP) * cumulus_thickness;
		vec3 dir_step = rd / rd.y * march_step;
		vec3 pos = n * cumulus_size;

		vec2 mu = vec2(dot(sun_pos, rd), dot(moon_pos, rd));
		vec3 mph = ((calc_mie_phase(mu.x, cumulus_partial_mie_phase) * atm_sun_mie_tint.rgb) +
			calc_mie_phase(mu.y, cumulus_partial_mie_phase) * am);

		vec4 t = vec4(1.0);
		t.rgb += (mph.rgb * cumulus_mie_intensity);

		for(int i = 0; i < CUMULUS_STEP; i++) {
			float h = float(i) * 0.1; // / float(kCLOUDS_STEP);
			float density = calc_cumulus_density(pos, wind, h);
			float sh = clamp_to_unit(exp(-cumulus_absorption * density * march_step));
			t *= sh;
			ret += (t * (exp(h) * 0.571428571) * density * march_step);
			a += (1.0 - sh) * (1.0 - a);
			pos += dir_step;
		}
		return vec4(ret.rgb * cumulus_intensity, a);
	}
	return vec4(ret.rgb * cumulus_intensity, a);
}

// Main
//------------------------------------------------------------------------------

vec3 render_sky(vec3 world_pos, vec3 clouds_pos, vec3 sun_pos, vec3 moon_pos, float p_time) {
	vec3 col = vec3(0.0);

	vec4 angle_mult;
	angle_mult.x = clamp_to_unit(1.0 - sun_pos.y);
	angle_mult.y = clamp_to_unit(sun_pos.y + 0.45);
	angle_mult.z = clamp_to_unit(-sun_pos.y + 0.30);
	angle_mult.w = clamp_to_unit(-sun_pos.y + 0.60);

	// Atmosphere
	vec2 mu = vec2(dot(sun_pos, world_pos), dot(moon_pos, world_pos));
	float sr, sm;
	calc_simple_optical_depth(world_pos.y + atm_level_params.z - horizon_offset, sr, sm, atm_level_params.xy);

	world_pos.y -= horizon_offset;
	float horizonBlend = clamp_to_unit((world_pos.y - 0.03) * 3.0);
	float horizonBlendCumulus = clamp_to_unit((world_pos.y + 0.01) * 50.0);

	vec3 scatter = calc_atmospheric_scatter(sr, sm, mu.xy, angle_mult.xyz);
	col.rgb += scatter.rgb;

	// Sun
	vec3 sun_disk = calc_disk_mask(world_pos, sun_pos, sun_disk_size) * sun_disk_color.rgb * scatter.rgb;
	sun_disk *= sun_disk_intensity;
	// The DAoC sundisk.bmp sprite replaces the procedural disk rather than
	// stacking on top of it: two suns would otherwise share one direction.
	bool daoc_sun_sprites = daoc_celestial_enabled && daoc_sun_sprites_visible;
	sun_disk = daoc_sun_sprites ? vec3(0.0) : sun_disk;

	// Moon
	float moon_intersect = simple_sphere_intersect(world_pos, moon_pos, moon_size);
	float moon_mask = moon_intersect > (-1. + sqrt(moon_size)) ? 1.0 : 0.0;
	vec3 moon_normal = normalize(world_pos * moon_intersect - moon_pos);

	float moon_ndotl = clamp(dot(moon_normal, sun_pos), 0.0, 1.0);
	vec3 moon_tex = sample_moon_texture(moon_normal);
	vec3 moon_output = moon_mask * moon_ndotl * exp2(1.0) * moon_tex * moon_color.rgb;
	float moonMask = (1.0 - moon_mask);
	// The legacy moon is a flat sprite, not a lit sphere. Drop the Sky3D sphere
	// entirely; moonback.tga is what hides the star map behind the disk.
	bool daoc_moon_sprites = daoc_celestial_enabled && daoc_moon_sprites_visible;
	moon_output = daoc_moon_sprites ? vec3(0.0) : moon_output;
	moonMask = daoc_moon_sprites ? 1.0 : moonMask;

	// Deep space

	// Tilt the sky along the X-axis.
	mat3 tilt = create_rotation_matrix(vec3(star_tilt, 0.0, 0.0));

	// Rotation around Y-axis. For simulating Earth's rotation.
	mat3 rotation = create_rotation_matrix(vec3(0.0, star_rotation + star_rotation_offset, 0.0));

	// Initial XYZ rotation for alignment.
	mat3 alignment_xyz = create_rotation_matrix(starmap_alignment);

	// Combine everything together to get the desired alignment.
	vec3 final_alignment = normalize(alignment_xyz * rotation * tilt * world_pos);

	// Now generate UV coordinates for the texture.
	vec2 deep_space_uv = calc_equirect_uv(normalize(final_alignment));

	// Star map
	vec3 deep_space_background = textureLod(starmap_texture, deep_space_uv, 0.0).rgb;
	deep_space_background *= starmap_color.rgb;
	deep_space_background = adjust_contrast(deep_space_background, starmap_color.a);
	vec3 deep_space = deep_space_background.rgb * moonMask + moon_output;

	// Star Field
	float star_scint = textureLod(noise_tex, deep_space_uv + (p_time * star_scintillation_speed), 0.0).r;
	star_scint = mix(1.0, star_scint * 1.5, star_scintillation);

	vec3 star_field = textureLod(star_field_texture, deep_space_uv, 0.0).rgb * star_field_color.rgb;
	star_field = clamp_rgb_to_unit(mix(star_field.rgb, star_field.rgb * star_scint, star_scintillation));
	star_field = clamp_rgb_to_unit(star_field.rgb);
	//deep_space.rgb -= clamp_to_unit(star_field.r * 10.0);
	deep_space.rgb += star_field.rgb * moonMask;
	deep_space.rgb *= angle_mult.z;
	col.rgb += sun_disk.rgb + deep_space.rgb * horizonBlend;

	// DAoC celestial sprites
	if (daoc_moon_sprites) {
		// moonback first: an opaque backing disk, exactly as in the client.
		vec4 moon_back = sample_daoc_sprite(daoc_moon_back_texture, world_pos, moon_pos, daoc_moon_radius);
		col.rgb = mix(col.rgb, daoc_moon_back_tint.rgb * moon_back.rgb,
			moon_back.a * daoc_moon_back_tint.a * horizonBlend);
		vec4 moon_disk = sample_daoc_sprite(daoc_moon_disk_texture, world_pos, moon_pos, daoc_moon_radius);
		col.rgb = mix(col.rgb, daoc_moon_tint.rgb * moon_disk.rgb,
			moon_disk.a * daoc_moon_tint.a * horizonBlend);
	}
	if (daoc_sun_sprites) {
		// The three sun layers are ADDITIVE: sunglow.bmp and sunflare.bmp are
		// opaque BMPs whose black background must not paint a black square, and
		// the DAT alpha is their intensity.
		float sun_visible = horizonBlend;
		col.rgb += sample_daoc_sprite(daoc_sun_glow_texture, world_pos, sun_pos, daoc_sun_radii.z).rgb
			* daoc_sun_glow_tint.rgb * daoc_sun_glow_tint.a * sun_visible;
		col.rgb += sample_daoc_sprite(daoc_sun_flare_texture, world_pos, sun_pos, daoc_sun_radii.y).rgb
			* daoc_sun_flare_tint.rgb * daoc_sun_flare_tint.a * sun_visible;
		col.rgb += sample_daoc_sprite(daoc_sun_disk_texture, world_pos, sun_pos, daoc_sun_radii.x).rgb
			* daoc_sun_disk_tint.rgb * daoc_sun_disk_tint.a * sun_visible;
	}

	// Clouds
	if (daoc_legacy_clouds_enabled) {
		float storm = clamp_to_unit(daoc_cloud_storminess);
		// A weather front does not only add clouds: the sky between them
		// loses its blue. Without this the storm shots stayed a summer blue.
		float sky_grey = dot(col.rgb, vec3(0.299, 0.587, 0.114));
		col.rgb = mix(col.rgb, vec3(sky_grey) * vec3(0.78, 0.82, 0.88), storm * 0.75);

		float shade;
		vec4 legacy_clouds = render_daoc_legacy_clouds(clouds_pos, sun_pos, shade);
		vec3 cloud_tint = sun_light_color.rgb;
		cloud_tint = mix(cloud_tint, clouds_night_color.rgb, angle_mult.w);
		cloud_tint = mix(cloud_tint, vec3(0.42, 0.44, 0.48), storm);
		legacy_clouds.rgb *= cloud_tint * daoc_cloud_intensity * shade;

		// Sun bleeding through the thin edges when looking toward it.
		float toward_sun = pow(clamp_to_unit(dot(normalize(clouds_pos), sun_pos)), 6.0);
		float thin = legacy_clouds.a * (1.0 - legacy_clouds.a) * 4.0;
		legacy_clouds.rgb += sun_light_color.rgb * toward_sun * thin
			* daoc_cloud_silver_lining * (1.0 - storm * 0.7) * clamp_to_unit(sun_pos.y * 3.0 + 0.3);

		// Distant clouds take the colour of the air in front of them: the
		// atmosphere already computed in `scatter`, more so near the horizon
		// and for diffuse layers.
		float mean_softness = dot(daoc_cloud_softness, vec4(0.25));
		float haze = daoc_cloud_sky_tint * (0.4 + 0.6 * mean_softness);
		float horizon_haze = pow(1.0 - clamp_to_unit(clouds_pos.y), 3.0);
		legacy_clouds.rgb = mix(legacy_clouds.rgb, scatter, clamp_to_unit(haze * 0.5 + horizon_haze * 0.6));
		legacy_clouds.rgb += scatter * 0.10;

		legacy_clouds.a = mix(0.0, legacy_clouds.a, horizonBlend);
		col.rgb = mix(col.rgb, legacy_clouds.rgb, legacy_clouds.a);
	} else {
		if (cirrus_visible) {
			vec4 cirrus_clouds = render_cirrus_clouds(clouds_pos);
			cirrus_clouds.a = clamp_to_unit(cirrus_clouds.a);
			vec3 cloud_tint = sun_light_color.rgb;
			cloud_tint = mix(cloud_tint, clouds_night_color.rgb, angle_mult.w);
			cirrus_clouds.rgb *= cloud_tint * cirrus_intensity;
			cirrus_clouds.a = mix(0.0, cirrus_clouds.a, horizonBlend);
			col.rgb = mix(col.rgb, cirrus_clouds.rgb + mix(vec3(0.0), scatter, cirrus_sky_tint_fade), cirrus_clouds.a);
		}

		if (cumulus_visible) {
			vec4 cumulus_clouds = render_cumulus_clouds(vec3(0.0), clouds_pos, angle_mult.z, sun_pos, moon_pos);
			cumulus_clouds.a = clamp_to_unit(cumulus_clouds.a);
			vec3 cloud_tint = sun_light_color.rgb;
			cloud_tint = mix(cloud_tint, clouds_night_color.rgb, angle_mult.w);
			cumulus_clouds.rgb *= cloud_tint * cumulus_intensity;
			cumulus_clouds.a = mix(0.0, cumulus_clouds.a, horizonBlend);
			col.rgb = mix(col.rgb, cumulus_clouds.rgb + mix(vec3(0.0), scatter, cumulus_sky_tint_fade), cumulus_clouds.a);
		}
	}

	col.rgb = mix(col.rgb, ground_color.rgb * scatter, clamp_to_unit((-world_pos.y - atm_level_params.z) * 100.0));
	col.rgb = apply_photo_tonemap(col.rgb, color_correction.y, color_correction.x);
	return col;
}

vec4 create_axis_angle_quat(vec3 axis, float angle) {
	float s = sin(angle * 0.5);
	return vec4(axis * s, cos(angle * 0.5));
}

vec3 rotate_vector_by_quat(vec3 v, vec4 q) {
	vec3 t = 2.0 * cross(q.xyz, v);
	return v + q.w * t + cross(q.xyz, t);
}

vec3 align_and_rotate_vector(vec3 dir, vec3 target, float rotation_angle) {
	vec3 z_axis = vec3(0.0, 0.0, 1.0); // Original grid alignment

	// First, align Z-axis with target (Polaris)
	target = normalize(target);
	vec3 axis = cross(z_axis, target);
	float angle = acos(dot(z_axis, target));
	float valid = step(0.0001, length(axis)); // 1.0 if length(axis) >= 0.0001
	axis = normalize(axis);
	vec4 align_quat = create_axis_angle_quat(axis, angle);
	dir = mix(dir, rotate_vector_by_quat(dir, align_quat), valid);
	vec4 rot_quat = create_axis_angle_quat(vec3(0.0, 0.0, 1.0), rotation_angle);
	dir = mix(dir, rotate_vector_by_quat(dir, rot_quat), valid);
	return dir;
}

void render_grid(vec3 dir, vec3 pole_dir, float rotation_angle, vec4 line_color, float grid_spacing, float line_thickness, inout vec3 color) {
	float spacing = max(grid_spacing, 0.001);
	float thickness = max(line_thickness, 0.0001);

	// Rotate dir with sidereal motion and align with pole_dir
	dir = align_and_rotate_vector(dir, pole_dir, rotation_angle);

	// Latitude / Circles / Theta Spherical coordinates
	float theta = acos(dir.z);
	float theta_deriv = fwidth(theta);
	float circle_thickness = max(thickness, theta_deriv);
	float circle = mod(theta, spacing);
	float circle_line = 1.0 - smoothstep(0.0, circle_thickness * 1.5, abs(circle - circle_thickness * 0.5));
	circle_line *= clamp_to_unit(thickness / circle_thickness);

	// Add poles
	float pole_thickness = circle_thickness;
	float north_pole = 1.0 - smoothstep(0.0, pole_thickness, theta);
	float south_pole = 1.0 - smoothstep(0.0, pole_thickness, abs(theta - PI));
	circle_line = max(circle_line, max(north_pole, south_pole));

	// Darken Lat at poles
	float circle_adjust = sin(theta);
	circle_line *= clamp(circle_adjust, 0.2, 1.0);

	// Longitude / Radial lines / Phi Spherical coordinates
	float phi = atan(dir.y, dir.x);
	float phi_deriv = fwidth(phi);
	float radial_thickness = max(thickness, phi_deriv);
	float radial = mod(phi + PI, spacing); // PI w/ less precision to remove moire
	float radial_line = 1.0 - smoothstep(0.0, radial_thickness * 1.5, abs(radial - radial_thickness));
	radial_line *= clamp_to_unit(thickness / radial_thickness);

	float grid = max(radial_line, circle_line);
	color += line_color.rgb * line_color.a * grid;
}

void sky() {
	float current_time = TIME;
	vec3 col = vec3(0.0); // Set up the initial sky color which will be added to later to produce the final result.
	vec3 world_pos = EYEDIR; // Original shader set this up in the vertex() function. For sky shaders the overall equivalent is EYEDIR.
	vec3 clouds_pos = EYEDIR; // The same is used for cloud rendering.
	vec3 sun_pos = LIGHT0_DIRECTION; // Redefined from now-deprecated _sun_direction.
	vec3 moon_pos = LIGHT1_DIRECTION; // Redefined from now-deprecated _moon_direction.

	if (sky_visible) {
		col = render_sky(world_pos, clouds_pos, sun_pos, moon_pos, current_time);
	}

	// Draw overlay grids
	{
		float grid_thickness = 0.0002;
		float grid_spacing = 0.261799; // 15 degrees
		vec3 zenith_dir = vec3(0.0, 1.0, 0.0); // Y-axis aligned azimuthal
		vec3 north_celestial_pole = create_rotation_matrix(vec3(star_tilt, 0.0, 0.0)) * zenith_dir;
		float rotation_angle = star_rotation + star_rotation_offset;
		if (show_azimuthal_grid) {
			render_grid(EYEDIR, zenith_dir, azimuthal_grid_rotation_offset, azimuthal_grid_color, grid_spacing, grid_thickness, col);
		}
		if (show_equatorial_grid) {
			render_grid(EYEDIR, north_celestial_pole, rotation_angle + equatorial_grid_rotation_offset, equatorial_grid_color, grid_spacing, grid_thickness, col);
		}
	}

	COLOR = col.rgb;
}
