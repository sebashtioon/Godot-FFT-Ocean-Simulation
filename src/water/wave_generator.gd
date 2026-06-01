@tool
class_name WaveGenerator extends Node

const G := 9.81
const DEPTH := 20.0
const NUM_SPECTRA := 4
const BYTES_PER_VEC2 := 8

const MAX_CASCADES := 8
const MAX_WAVE_QUERIES := 256
const WAVE_QUERY_LOCAL_SIZE := 64

var map_size : int
var context : RenderingContext
var pipelines : Dictionary
var descriptors : Dictionary

var _gpu_num_cascades := 0

func init_gpu(num_cascades : int) -> void:
	# device/shader creation
	if not context: context = RenderingContext.create(RenderingServer.get_rendering_device())
	var spectrum_compute_shader := context.load_shader('./res/shad/compute/spectrum_compute.glsl')
	var fft_butterfly_shader := context.load_shader('./res/shad/compute/fft_butterfly.glsl')
	var spectrum_modulate_shader := context.load_shader('./res/shad/compute/spectrum_modulate.glsl')
	var fft_compute_shader := context.load_shader('./res/shad/compute/fft_compute.glsl')
	var transpose_shader := context.load_shader('./res/shad/compute/transpose.glsl')
	var fft_unpack_shader := context.load_shader('./res/shad/compute/fft_unpack.glsl')
	var wave_query_shader := context.load_shader('./res/shad/compute/wave_query.glsl')

	var dims := Vector2i(map_size, map_size)
	var num_fft_stages := int(log(map_size) / log(2))

	_gpu_num_cascades = num_cascades
	# Spectrum is written once per parameter change and then read every sim step; RGBA16F is plenty.
	descriptors[&'spectrum'] = context.create_texture(dims, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, RenderingDevice.TEXTURE_USAGE_STORAGE_BIT, num_cascades)
	descriptors[&'butterfly_factors'] = context.create_storage_buffer(num_fft_stages*map_size * 4 * 4)
	
	# Reuse a single FFT buffer across cascades (we update one cascade at a time).
	# Size: map_size^2 * NUM_SPECTRA * 2 (ping-pong) * sizeof(vec2)
	var fft_buffer_bytes := map_size * map_size * NUM_SPECTRA * 2 * BYTES_PER_VEC2
	descriptors[&'fft_buffer'] = context.create_storage_buffer(fft_buffer_bytes)
	descriptors[&'displacement_map'] = context.create_texture(dims, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT, num_cascades)
	descriptors[&'normal_map'] = context.create_texture(dims, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT, num_cascades)

	var spectrum_set := context.create_descriptor_set([descriptors[&'spectrum']], spectrum_compute_shader, 0)
	var spectrum_read_set := context.create_descriptor_set([descriptors[&'spectrum']], spectrum_modulate_shader, 0)
	var fft_butterfly_set := context.create_descriptor_set([descriptors[&'butterfly_factors']], fft_butterfly_shader, 1)
	var fft_compute_set := context.create_descriptor_set(
	[descriptors[&'butterfly_factors'], descriptors[&'fft_buffer']],
	fft_compute_shader,
	1)
	
	var transpose_set := context.create_descriptor_set([descriptors[&'fft_buffer']], transpose_shader, 0)
	var fft_buffer_write_set := context.create_descriptor_set([descriptors[&'fft_buffer']], spectrum_modulate_shader, 1)
	var fft_buffer_read_set := context.create_descriptor_set([descriptors[&'fft_buffer']], fft_unpack_shader, 1)
	var unpack_set := context.create_descriptor_set([descriptors[&'displacement_map'], descriptors[&'normal_map']], fft_unpack_shader, 0)

	# --- WAVE SAMPLING (BUOYANCY/PHYSICS) ---
	# map_scales layout matches the material parameter: vec4(uv_scale.xy, displacement_scale, normal_scale)
	descriptors[&'wave_query_map_scales'] = context.create_storage_buffer(MAX_CASCADES * 16)
	# Query buffers: vec4(x, z, 0, 0) -> vec4(height, normal.xyz)
	descriptors[&'wave_query_points'] = context.create_storage_buffer(MAX_WAVE_QUERIES * 16)
	descriptors[&'wave_query_results'] = context.create_storage_buffer(MAX_WAVE_QUERIES * 16)
	var wave_query_set0 := context.create_descriptor_set([descriptors[&'displacement_map'], descriptors[&'wave_query_map_scales']], wave_query_shader, 0)
	var wave_query_set1 := context.create_descriptor_set([descriptors[&'wave_query_points'], descriptors[&'wave_query_results']], wave_query_shader, 1)

	# compute pipeline
	pipelines[&'spectrum_compute'] = context.create_pipeline([map_size >> 4, map_size >> 4, 1], [spectrum_set], spectrum_compute_shader)
	pipelines[&'spectrum_modulate'] = context.create_pipeline([map_size >> 4, map_size >> 4, 1], [spectrum_read_set, fft_buffer_write_set], spectrum_modulate_shader)
	pipelines[&'fft_butterfly'] = context.create_pipeline([map_size >> 7, num_fft_stages, 1], [RID(), fft_butterfly_set], fft_butterfly_shader)
	pipelines[&'fft_compute'] = context.create_pipeline([1, map_size, NUM_SPECTRA], [RID(), fft_compute_set], fft_compute_shader)
	pipelines[&'transpose'] = context.create_pipeline([map_size >> 5, map_size >> 5, NUM_SPECTRA], [transpose_set], transpose_shader)
	pipelines[&'fft_unpack'] = context.create_pipeline([map_size >> 4, map_size >> 4, 1], [unpack_set, fft_buffer_read_set], fft_unpack_shader)
	var query_groups_x := maxi(1, ceili(float(MAX_WAVE_QUERIES) / float(WAVE_QUERY_LOCAL_SIZE)))
	pipelines[&'wave_query'] = context.create_pipeline([query_groups_x, 1, 1], [wave_query_set0, wave_query_set1], wave_query_shader)

	# We only need to generate butterfly factors once for each map_size
	var compute_list := context.compute_list_begin()
	pipelines[&'fft_butterfly'].call(context, compute_list)
	context.compute_list_end()

func _update(compute_list : int, cascade_index : int, parameters : Array[WaveCascadeParameters]) -> void:
	var params := parameters[cascade_index]
	## --- WAVE SPECTRA UPDATE ---
	if params.should_generate_spectrum:
		var alpha := JONSWAP_alpha(params.wind_speed, params.fetch_length*1e3)
		var omega := JONSWAP_peak_angular_frequency(params.wind_speed, params.fetch_length*1e3)
		pipelines[&'spectrum_compute'].call(context, compute_list, RenderingContext.create_push_constant([params.spectrum_seed.x, params.spectrum_seed.y, params.tile_length.x, params.tile_length.y, alpha, omega, params.wind_speed, deg_to_rad(params.wind_direction), DEPTH, params.swell, params.detail, params.spread, cascade_index]))
		params.should_generate_spectrum = false
	pipelines[&'spectrum_modulate'].call(context, compute_list, RenderingContext.create_push_constant([params.tile_length.x, params.tile_length.y, DEPTH, params.time, cascade_index]))

	## --- WAVE SPECTRA INVERSE FOURIER TRANSFORM ---
	# Note: We need not do a second transpose after computing FFT on rows since rotating the wave by
	#       PI/2 doesn't affect it visually.
	pipelines[&'fft_compute'].call(context, compute_list)
	pipelines[&'transpose'].call(context, compute_list)
	context.compute_list_add_barrier(compute_list) # FIXME: Why is a barrier only needed here?!
	pipelines[&'fft_compute'].call(context, compute_list)

	## --- DISPLACEMENT/NORMAL MAP UPDATE ---
	pipelines[&'fft_unpack'].call(context, compute_list, RenderingContext.create_push_constant([cascade_index, params.whitecap, params.foam_grow_rate, params.foam_decay_rate]))

func update(delta : float, parameters : Array[WaveCascadeParameters]) -> void:
	assert(parameters.size() != 0)
	if not context:
		init_gpu(maxi(2, len(parameters)))
	
	# Advance simulation time for all cascades
	for i in range(parameters.size()):
		parameters[i].time += delta
	
	var compute_list := context.compute_list_begin()
	
	# Update ALL cascades TODO implement something idk
	for cascade_index in range(parameters.size()):
		var params := parameters[cascade_index]
		# foam
		params.foam_grow_rate = delta * params.foam_amount * 7.5
		params.foam_decay_rate = delta * maxf(0.5, 10.0 - params.foam_amount) * 1.1
		_update(compute_list, cascade_index, parameters)
	
	context.compute_list_end()

func query_surface(world_xz : PackedVector2Array, map_scales : PackedVector4Array, water_y : float, num_cascades : int) -> PackedVector4Array:
	# Returns vec4(height, normal.xyz) per query point.
	if world_xz.is_empty():
		return PackedVector4Array()
	if not context:
		init_gpu(maxi(2, num_cascades))
	if not pipelines.has(&'wave_query'):
		push_error('WaveGenerator: wave_query pipeline not initialized (init_gpu not called?)')
		return PackedVector4Array()

	var query_count := mini(world_xz.size(), MAX_WAVE_QUERIES)
	if query_count != world_xz.size():
		push_warning('WaveGenerator: query_surface truncated to %d points (MAX_WAVE_QUERIES=%d).' % [query_count, MAX_WAVE_QUERIES])

	# Upload map scales (always upload all MAX_CASCADES entries).
	var scale_floats := PackedFloat32Array()
	scale_floats.resize(MAX_CASCADES * 4)
	for i in range(MAX_CASCADES):
		var v := map_scales[i] if i < map_scales.size() else Vector4.ZERO
		var base := i * 4
		scale_floats[base + 0] = v.x
		scale_floats[base + 1] = v.y
		scale_floats[base + 2] = v.z
		scale_floats[base + 3] = v.w
	var scale_bytes := scale_floats.to_byte_array()
	context.device.buffer_update(descriptors[&'wave_query_map_scales'].rid, 0, scale_bytes.size(), scale_bytes)

	# Upload query points.
	var point_floats := PackedFloat32Array()
	point_floats.resize(query_count * 4)
	for i in range(query_count):
		var p := world_xz[i]
		var base := i * 4
		point_floats[base + 0] = p.x
		point_floats[base + 1] = p.y
		point_floats[base + 2] = 0.0
		point_floats[base + 3] = 0.0
	var point_bytes := point_floats.to_byte_array()
	context.device.buffer_update(descriptors[&'wave_query_points'].rid, 0, point_bytes.size(), point_bytes)

	# Dispatch compute.
	var push := RenderingContext.create_push_constant([query_count, num_cascades, water_y, 0.0])
	var compute_list := context.compute_list_begin()
	pipelines[&'wave_query'].call(context, compute_list, push)
	context.compute_list_end()

	# Blocking readback. simple, but it will stall :(  
	# The main RenderingDevice is submitted by the engine; submit/sync are only valid on local devices
	# force_sync() makes sure the render thread processes the RD commands before the CPU readback
	RenderingServer.force_sync()

	var raw : PackedByteArray = context.device.buffer_get_data(descriptors[&'wave_query_results'].rid)
	var results := PackedVector4Array()
	results.resize(query_count)
	for i in range(query_count):
		var o := i * 16
		results[i] = Vector4(raw.decode_float(o + 0), raw.decode_float(o + 4), raw.decode_float(o + 8), raw.decode_float(o + 12))
	return results

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if context: context.free()

# Source: https://wikiwaves.org/Ocean-Wave_Spectra#JONSWAP_Spectrum
static func JONSWAP_alpha(wind_speed:=20.0, fetch_length:=550e3) -> float:
	return 0.076 * pow(wind_speed**2 / (fetch_length*G), 0.22)

# Source: https://wikiwaves.org/Ocean-Wave_Spectra#JONSWAP_Spectrum
static func JONSWAP_peak_angular_frequency(wind_speed:=20.0, fetch_length:=550e3) -> float:
	return 22.0 * pow(G*G / (wind_speed*fetch_length), 1.0/3.0)



# i am graphics porgrammer
