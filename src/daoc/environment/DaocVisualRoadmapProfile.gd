extends RefCounted
class_name DaocVisualRoadmapProfile

## Presets purement visuels de la roadmap. Ils ne touchent ni aux heightmaps,
## ni aux collisions, ni aux coordonnees, ni a l'autorite client/serveur.
enum Quality { LOW, HIGH, CAPTURE }


static func values(quality: int) -> Dictionary:
	match quality:
		Quality.LOW:
			return {
				"terrain_pbr_enabled": false,
				"terrain_macro_variation_enabled": true,
				"terrain_macro_variation_scale": 144.0,
				"terrain_macro_color_strength": 0.045,
				"terrain_macro_roughness_strength": 0.06,
				"sky_glow_enabled": true,
				"sky_glow_intensity": 0.35,
				"sky_glow_hdr_threshold": 1.8,
				"sky_ambient_from_sky_enabled": false,
				"sky_realtime_radiance_enabled": false,
				"sky_aerial_perspective_enabled": true,
				"sky_aerial_perspective_amount": 0.18,
				"sky_volumetric_fog_enabled": false,
				"sky_sun_energy_scale": 1.08,
				"sky_sun_warm_palette_enabled": true,
				"sky_sun_warmth_strength": 0.45,
				"sky_tonemap_agx_enabled": true,
				"sky_tonemap_exposure": 1.0,
				"sky_color_saturation": 1.08,
				"sky_color_contrast": 1.03,
				"ground_contact_ssao_enabled": true,
				"ground_contact_ssao_intensity": 1.25,
				"outward_rocks_enabled": false,
				"outward_flowers_enabled": false,
				"grass_remaster_enabled": true,
				"grass_remaster_spacing_inspector_raw": 130.0,
				"grass_remaster_density_inspector": 0.55,
				"grass_remaster_card_width_inspector_raw": 40.0,
				"grass_remaster_card_height_inspector_raw": 36.0,
				"foliage_wind_enabled": true,
				"foliage_canopy_strength_raw": 28.0,
				"foliage_leaf_flutter_strength_raw": 10.0,
				"water_visual_enabled": true,
				"water_modern_texture_enabled": true,
				"water_shore_enabled": true,
			}
		Quality.CAPTURE:
			var capture := values(Quality.HIGH)
			capture.merge({
				"terrain_pbr_map_size": 2048,
				"sky_realtime_radiance_enabled": true,
				"sky_glow_intensity": 0.55,
				"sky_ambient_sky_contribution": 0.52,
				"sky_ambient_energy_scale": 0.92,
				"sky_volumetric_fog_enabled": true,
				"sky_volumetric_fog_density": 0.00005,
				"sky_volumetric_fog_length_raw": 6500.0,
				"sky_sun_rays_energy": 2.00,
				"sky_sun_energy_scale": 1.48,
				"sky_tonemap_exposure": 1.03,
				"sky_shadow_max_distance_raw": 9000.0,
				"sky_color_saturation": 1.24,
				"sky_color_contrast": 1.14,
				"ground_contact_ssao_intensity": 2.15,
				"terrain_bilinear_enabled": true,
				"terrain_bilinear_factor": 4,
				"world_pbr_map_size": 1024,
				"grass_remaster_spacing_inspector_raw": 52.0,
				"grass_remaster_density_inspector": 1.4,
			}, true)
			return capture
		_:
			return {
				"terrain_pbr_enabled": true,
				"terrain_pbr_map_size": 1024,
				"terrain_pbr_normal_strength": 1.6,
				"terrain_pbr_ao_amount": 0.8,
				"terrain_virtual_relief_enabled": true,
				"terrain_virtual_relief_depth": 0.022,
				"terrain_virtual_relief_steps": 12,
				"terrain_dry_roughness_floor": 0.7,
				"terrain_ao_light_affect": 0.35,
				"terrain_dry_specular": 0.3,
				"terrain_macro_variation_enabled": true,
				"terrain_macro_variation_scale": 128.0,
				"terrain_macro_color_strength": 0.07,
				"terrain_macro_roughness_strength": 0.10,
				"sky_glow_enabled": true,
				"sky_glow_intensity": 0.50,
				"sky_glow_hdr_threshold": 1.65,
				"sky_ambient_from_sky_enabled": true,
				"sky_ambient_sky_contribution": 0.50,
				"sky_ambient_energy_scale": 1.0,
				"sky_realtime_radiance_enabled": true,
				"sky_aerial_perspective_enabled": true,
				"sky_aerial_perspective_amount": 0.18,
				"sky_volumetric_fog_enabled": true,
				"sky_volumetric_fog_density": 0.000012,
				"sky_volumetric_fog_length_raw": 5500.0,
				"sky_sun_rays_energy": 1.10,
				"sky_sun_arc_extra_tilt_degrees": 20.0,
				"sky_shadow_softness_degrees": 0.0,
				"sky_shadow_max_distance_raw": 8000.0,
				"sky_sun_energy_scale": 1.70,
				"sky_sun_warm_palette_enabled": true,
				"sky_sun_warmth_strength": 0.62,
				"sky_tonemap_agx_enabled": true,
				"sky_tonemap_exposure": 1.10,
				"sky_color_saturation": 1.22,
				"sky_color_contrast": 1.14,
				"sky_cloud_shading": 0.78,
				"sky_cloud_silver_lining": 0.68,
				"sky_cloud_drift_enabled": true,
				"ground_contact_ssao_enabled": true,
				"ground_contact_ssao_radius": 1.6,
				"ground_contact_ssao_intensity": 1.85,
				"ground_contact_ssao_power": 1.35,
				"outward_rocks_enabled": true,
				"outward_flowers_enabled": true,
				"grass_remaster_enabled": true,
				"grass_remaster_spacing_inspector_raw": 60.0,
				"grass_remaster_density_inspector": 1.4,
				"grass_remaster_card_width_inspector_raw": 54.0,
				"grass_remaster_card_height_inspector_raw": 50.0,
				"foliage_wind_enabled": true,
				"foliage_canopy_strength_raw": 42.0,
				"foliage_leaf_flutter_strength_raw": 17.0,
				"water_visual_enabled": true,
				"water_modern_texture_enabled": true,
				"water_alpha": 0.58,
				"water_shore_enabled": true,
				"water_shore_strength": 0.82,
				"water_wave_strength_scale": 0.85,
				"water_refraction_scale": 0.80,
				"terrain_bilinear_enabled": true,
				"terrain_bilinear_factor": 2,
				"world_pbr_enabled": true,
				"world_pbr_map_size": 512,
				"world_pbr_normal_strength": 1.4,
				"world_pbr_ao_amount": 0.6,
			}


static func apply_to(target: Object, quality: int) -> Dictionary:
	var applied := {}
	var available := {}
	for info in target.get_property_list():
		available[str(info.get("name", ""))] = true
	for property_name in values(quality):
		if available.has(property_name):
			var value: Variant = values(quality)[property_name]
			target.set(property_name, value)
			applied[property_name] = value
	return applied
