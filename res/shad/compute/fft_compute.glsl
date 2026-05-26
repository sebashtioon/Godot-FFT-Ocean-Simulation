#[compute]
#version 460
/** 
 * A coalesced decimation-in-time Stockham FFT kernel. 
 * Source: http://wwwa.pikara.ne.jp/okojisan/otfft-en/stockham3.html
 */

#define PI           (3.141592653589793)
#define MAX_MAP_SIZE (1024U)
#define NUM_SPECTRA  (4U)

layout(local_size_x = MAX_MAP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, set = 1, binding = 0) restrict buffer ButterflyFactorBuffer {
	vec4 butterfly[]; // log2(map_size) x map_size
};

layout(std430, set = 1, binding = 1) restrict buffer FFTBuffer {
	// Layout: map_size x map_size x NUM_SPECTRA x 2 (ping-pong: input|output)
	vec2 data[];
};

shared vec2 row_shared[2 * MAX_MAP_SIZE]; // "Ping-pong" shared buffer for a single row

/** Returns (a0 + j*a1)(b0 + j*b1) */
vec2 mul_complex(in vec2 a, in vec2 b) {
	return vec2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x);
}

#define ROW_SHARED(col, pingpong) (row_shared[(pingpong)*MAX_MAP_SIZE + (col)])
#define BUTTERFLY(col, stage)     (butterfly[(stage)*map_size + (col)])
#define DATA_IN(id, layer)  (data[(layer)*map_size*map_size + (id.y)*map_size + (id.x)])
#define DATA_OUT(id, layer) (data[NUM_SPECTRA*map_size*map_size + (layer)*map_size*map_size + (id.y)*map_size + (id.x)])
void main() {
	const uint map_size = gl_NumWorkGroups.y * gl_WorkGroupSize.y;
	const uint num_stages = findMSB(map_size); // Equivalent: log2(map_size) (assuming map_size is a power of 2)
	const uvec2 id = uvec2(gl_GlobalInvocationID.xy); // col, row
	const uint col = id.x;
	const uint spectrum = gl_GlobalInvocationID.z; // The spectrum in the buffer to perform FFT on.
	const bool is_active = (col < map_size);

	ROW_SHARED(col, 0) = is_active ? DATA_IN(id, spectrum) : vec2(0.0);
	for (uint stage = 0U; stage < num_stages; ++stage) {
		barrier();
		uvec2 buf_idx = uvec2(stage & 1U, (stage + 1U) & 1U); // x=read index, y=write index
		if (is_active) {
			vec4 butterfly_data = BUTTERFLY(col, stage);
			uvec2 read_indices = uvec2(floatBitsToUint(butterfly_data.xy));
			vec2 twiddle_factor = butterfly_data.zw;

			vec2 upper = ROW_SHARED(read_indices[0], buf_idx[0]);
			vec2 lower = ROW_SHARED(read_indices[1], buf_idx[0]);
			ROW_SHARED(col, buf_idx[1]) = upper + mul_complex(lower, twiddle_factor);
		}
	}
	if (is_active) {
		DATA_OUT(id, spectrum) = ROW_SHARED(col, num_stages & 1U);
	}
}