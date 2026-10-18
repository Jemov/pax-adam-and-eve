// Called after the game's surface function; its terrain, regions and lighting remain active.
uniform sampler2D holocene_sea_ice : filter_linear, repeat_enable;
uniform float holocene_north_winter = 1.0;
uniform float holocene_base_temperature = 0.52;
uniform float holocene_base_biomass = 0.8;
uniform float holocene_enabled = 0.0;

Surface surface(vec3 n) {
	Surface s = adam_eve_native_surface(n);
	if (holocene_enabled < 0.5) { return s; }
	vec2 uv = sph_uv(n);
	vec3 natural_colour = samp_sph(map_albedo, uv).rgb;
	vec3 water_colour = mix(vec3(0.025, 0.12, 0.16), vec3(0.012, 0.045, 0.095), clamp(s.depth * 2.0, 0.0, 1.0));
	vec3 original_environment = mix(water_colour, natural_colour, s.land);
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	if (abs(dx.x) > 0.5) { dx.x = 0.0; }
	if (abs(dy.x) > 0.5) { dy.x = 0.0; }
	vec4 ice_masks = textureGrad(holocene_sea_ice, uv, dx, dy);
	float ice = max(mix(ice_masks.g, ice_masks.r, holocene_north_winter), mix(ice_masks.b, ice_masks.a, holocene_north_winter));
	original_environment = mix(original_environment, vec3(0.78, 0.86, 0.91), ice);
	// The native flat pass applies an exposure curve. Invert it for cartographic
	// albedo so vegetation retains its colour instead of washing out to white.
	#ifdef ADAM_EVE_FLAT
		original_environment = -log(max(vec3(0.001), vec3(1.0) - original_environment)) / 2.6;
	#endif
	// Player development and subsequent terraforming still use the game's own appearance.
	float changed_climate = max(abs(temperature - holocene_base_temperature), abs(biomass - holocene_base_biomass));
	float intact = (1.0 - smoothstep(0.04, 0.25, changed_climate)) * (1.0 - smoothstep(0.01, 0.5, radiation));
	float building = clamp(max(s.city_land, s.city_sea), 0.0, 1.0);
	s.col = mix(s.col, original_environment, intact * (1.0 - building));
	return s;
}
