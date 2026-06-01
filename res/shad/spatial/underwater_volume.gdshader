shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform float underwater_amount : hint_range(0.0, 1.0) = 0.0;
uniform float camera_depth = 0.0;
uniform vec4 shallow_color : source_color = vec4(0.08, 0.46, 0.55, 1.0);
uniform vec4 deep_color : source_color = vec4(0.01, 0.08, 0.13, 1.0);
uniform vec3 absorption = vec3(0.55, 0.18, 0.06);
uniform float density : hint_range(0.0, 0.25) = 0.035;
uniform float max_distance = 170.0;
uniform float shimmer_strength : hint_range(0.0, 0.05) = 0.002;
uniform vec3 sun_world_direction = vec3(0.0, -0.6, -0.8);
uniform vec3 camera_world_position = vec3(0.0);
uniform mat3 camera_world_basis = mat3(1.0);
uniform vec4 god_ray_color : source_color = vec4(0.38, 0.72, 0.62, 1.0);
uniform float god_ray_strength : hint_range(0.0, 1.0) = 0.14;
uniform float god_ray_scale : hint_range(0.01, 1.0) = 0.09;
uniform float god_ray_speed : hint_range(0.0, 2.0) = 0.18;
uniform float god_ray_sharpness : hint_range(0.0, 1.0) = 0.58;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 get_view_position(vec2 screen_uv, mat4 inv_projection_matrix) {
	float raw_depth = texture(depth_texture, screen_uv).x;
	if (raw_depth >= 1.0) {
		return vec3(0.0, 0.0, -max_distance);
	}

	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return view.xyz;
}

float god_ray_pattern(vec3 world_pos, vec3 light_dir) {
	vec3 downward_light = normalize(vec3(light_dir.x, min(light_dir.y, -0.25), light_dir.z));
	vec2 ray_uv = (world_pos.xz - downward_light.xz * world_pos.y) * god_ray_scale;
	ray_uv += downward_light.xz * TIME * god_ray_speed * 12.0;
	float bands = sin(ray_uv.x * 1.35 + ray_uv.y * 0.42);
	bands += 0.5 * sin(ray_uv.x * 2.6 - ray_uv.y * 0.7);
	bands = bands * 0.5 + 0.5;
	return smoothstep(god_ray_sharpness, 1.0, bands);
}

float god_rays(vec3 view_pos, float view_distance, float fog, float depth_factor) {
	vec3 light_dir = normalize(sun_world_direction);
	vec3 view_dir = normalize(camera_world_basis * normalize(view_pos));
	float looking_toward_sun = pow(max(dot(view_dir, -light_dir), 0.0), 0.75) * 0.65 + 0.35;

	float water_path = max(view_distance, mix(0.0, camera_depth + 32.0, underwater_amount));
	water_path = clamp(water_path, 0.0, max_distance);
	float bands = 0.0;
	for (int i = 0; i < 6; ++i) {
		float sample_fraction = (float(i) + 0.5) / 6.0;
		float sample_distance = max(2.0, water_path * sample_fraction);
		vec3 sample_world_pos = camera_world_position + view_dir * sample_distance;
		bands += god_ray_pattern(sample_world_pos, light_dir);
	}
	bands /= 6.0;

	float surface_rejection = smoothstep(2.0, 10.0, water_path);
	float distance_fade = surface_rejection * (1.0 - smoothstep(130.0, max_distance, water_path));
	float depth_fade = 1.0 - smoothstep(0.75, 1.0, depth_factor);
	float water_visibility = underwater_amount;
	
	return bands * looking_toward_sun * distance_fade * depth_fade * fog * water_visibility;
}

void fragment() {
	vec2 wave_offset = vec2(
		sin(SCREEN_UV.y * 38.0 + TIME * 0.8),
		cos(SCREEN_UV.x * 31.0 - TIME * 0.65)
	) * shimmer_strength * underwater_amount;

	vec2 uv = clamp(SCREEN_UV + wave_offset, vec2(0.001), vec2(0.999));
	vec3 scene_color = texture(screen_texture, uv).rgb;
	vec3 view_pos = get_view_position(SCREEN_UV, INV_PROJECTION_MATRIX);
	float view_distance = clamp(-view_pos.z, 0.0, max_distance);
	float depth_factor = clamp(camera_depth / 18.0, 0.0, 1.0);
	float fog = 1.0 - exp(-view_distance * density * mix(0.65, 1.45, depth_factor));

	vec3 transmitted = scene_color * exp(-absorption * view_distance * 0.025);
	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_factor);
	vec3 underwater_color = mix(transmitted, water_color, fog);
	underwater_color += god_rays(view_pos, view_distance, fog, depth_factor) * god_ray_strength * god_ray_color.rgb;
	ALBEDO = mix(scene_color, underwater_color, underwater_amount);
	ALPHA = underwater_amount;
}
