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

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float get_view_distance(vec2 screen_uv, mat4 inv_projection_matrix) {
	float raw_depth = texture(depth_texture, screen_uv).x;
	if (raw_depth >= 1.0) {
		return max_distance;
	}

	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return clamp(-view.z, 0.0, max_distance);
}

void fragment() {
	vec2 wave_offset = vec2(
		sin(SCREEN_UV.y * 38.0 + TIME * 0.8),
		cos(SCREEN_UV.x * 31.0 - TIME * 0.65)
	) * shimmer_strength * underwater_amount;

	vec2 uv = clamp(SCREEN_UV + wave_offset, vec2(0.001), vec2(0.999));
	vec3 scene_color = texture(screen_texture, uv).rgb;
	float view_distance = get_view_distance(SCREEN_UV, INV_PROJECTION_MATRIX);
	float depth_factor = clamp(camera_depth / 18.0, 0.0, 1.0);
	float fog = 1.0 - exp(-view_distance * density * mix(0.65, 1.45, depth_factor));

	vec3 transmitted = scene_color * exp(-absorption * view_distance * 0.025);
	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_factor);
	ALBEDO = mix(scene_color, mix(transmitted, water_color, fog), underwater_amount);
	ALPHA = underwater_amount;
}
