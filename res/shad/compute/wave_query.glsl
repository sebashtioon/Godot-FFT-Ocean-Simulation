#[compute]
#version 460



#define LOCAL_SIZE (64U)
#define MAX_CASCADES (8)


layout (local_size_x = LOCAL