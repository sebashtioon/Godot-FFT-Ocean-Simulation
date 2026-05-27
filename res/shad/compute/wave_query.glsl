#[compute]
#version 460



#define LOCAL_SIZE (64U)
#define MAX_CASCADES (8)


layout (local_size_x = LOCAL_SIZE, local_size_y = 1, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform readonly image2DArray displacement_map;

layout(std430, set = 0, binding = 1) restrict readonly buffer MapScales {
    vec4 map_scales[MAX_CASCADES];
};
layout(std430, set = 1, binding = 0) restrict readonly buffer QueryPoints {
    // as a vec4 x, z, 0, 0
    vec4 points[];
};
layout(std430, set = 1, binding = 1) restrict writeonly buffer Results {
    // as a vec4, with the height and normal.xyz

    vec4 results[];
};

layout(push_constant) uniform PushConstants{
    uint query_count;
    uint num_cascades;
    float water_y;
    float _pad0;
};

int wrap_int(int x, int m) {
    int r = x % m;
    return r < 0 ? r + m : r;
}

vec4 displacement_bilinear(vec2 uv, int layer, int size) {
    uv = fract(uv);
    vec2 texel = uv * float(size) - 0.5;
    ivec2 i0 = ivec2(floor(texel));
    vec2 f = fract(texel);

    ivec2 p00 = ivec2(wrap_int(i0.x + 0, size), wrap_int(i0.y + 0, size));
    ivec2 p10 = ivec2(wrap_int(i0.x + 1, size), wrap_int(i0.y + 0, size));
    ivec2 p01 = ivec2(wrap_int(i0.x + 0, size), wrap_int(i0.y + 1, size));
    ivec2 p11 = ivec2(wrap_int(i0.x + 1, size), wrap_int(i0.y + 1, size));

    vec4 c00 = imageLoad(displacement_map, ivec3(p00, layer));
    vec4 c10 = imageLoad(displacement_map, ivec3(p10, layer));
    vec4 c01 = imageLoad(displacement_map, ivec3(p01, layer));
    vec4 c11 = imageLoad(displacement_map, ivec3(p11, layer));

    vec4 cx0 = mix(c00, c10, f.x);
    vec4 cx1 = mix(c01, c11, f.x);
    return mix(cx0, cx1, f.y);

};

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx => query_count) { // check
        return;
    }

    ivec2 map_dims = imageSize(displacement_map).xy;
    int map_size = map_dims.x;
    float inv_map_size = 1.0 / float(map_size);
    int layer_count = imageSize(displacement_map).z;

    vec2 world_xz = points[idx].xy;

    float height = 0.0;
    float dhdx = 0.0;
    float dhdz = 0.0;


    uint cascades = min(num_cascades, uint(MAX_CASCADES));
    cascades = min(cascades, uint(layer_count));



    // need to iterate throgh cascades
    for (uint i = 0U; i < cascades; ++i) {
        dhdx += 
        dhdz += 
    }



    vec3 normal = normalize(vec3(-dhdx, 1.0, -dhdz)); // TODO later cant be bothered rn
    results[idx] = vec4(water_y + height, normal)
}


