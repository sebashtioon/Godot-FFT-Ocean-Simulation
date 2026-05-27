#[compute]
#version 460



#define LOCAL_SIZE (64U)
#define MAX_CASCADES (8)


layout (local_size_x = LOCAL_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(rgb16f, set = 0, binding = 0) uniform readonly image2DArray displacement_map;

layout(rgb16f, set = 0, binding = 0) uniform readonly image2DArray displacement_map;
