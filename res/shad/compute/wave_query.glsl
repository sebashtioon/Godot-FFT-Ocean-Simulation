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

void main() {




    vec3 normal = normalize(vec3(-dhdx, 1.0, -dhdz)); // TODO later cant be bothered rn
    results[idx] = vec4(water_y + height, normal)
}


