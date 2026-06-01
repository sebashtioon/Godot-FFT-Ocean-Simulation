extends RigidBody3D
class_name BuoyantBody3D

@export var water_path : NodePath

# Local-space probe points (meters). Put them around/below the hull.
@export var float_points : Array[Vector3] = [
	Vector3(1.0, -0.5, 1.0),
	Vector3(-1.0, -0.5, 1.0),
	Vector3(1.0, -0.5, -1.0),
	Vector3(-1.0, -0.5, -1.0),
]

# Spring model: choose how deep (in meters) the object should sit at equilibrium.
@export_range(0.01, 10.0, 0.01) var equilibrium_depth := 0.75
@export_range(0.0, 5.0, 0.01) var buoyancy_multiplier := 1.0

# Damping/drag.
@export_range(0.0, 50.0, 0.01) var vertical_damping := 6.0
@export_range(0.0, 50.0, 0.01) var linear_drag := 1.25
@export_range(0.0, 50.0, 0.01) var angular_drag := 1.0

@export_range(0.0, 10.0, 0.01) var max_depth := 3.0

var _water : Node = null
var _gravity_mag := 9.81

func _ready() -> void:
	_gravity_mag = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.81))
	_water = get_node_or_null(water_path) if water_path != NodePath() else null
	if _water == null and get_tree() != null:
		_water = get_tree().get_first_node_in_group(&"water")

func _physics_process(_delta : float) -> void:
	if _water == null and get_tree() != null:
		_water = get_tree().get_first_node_in_group(&"water")
	if _water == null:
		return
	if float_points.is_empty():
		return
	if not _water.has_method(&"sample_surface"):
		return

	var probe_world : Array[Vector3] = []
	probe_world.resize(float_points.size())
	var query := PackedVector2Array()
	query.resize(float_points.size())
	for i in range(float_points.size()):
		var wp := global_transform * float_points[i]
		probe_world[i] = wp
		query[i] = Vector2(wp.x, wp.z)

	var surface : PackedVector4Array = _water.call(&"sample_surface", query)
	if surface.size() != float_points.size():
		return

	var point_count := float(float_points.size())
	var k_per_point := (mass * _gravity_mag) / (equilibrium_depth * point_count) * buoyancy_multiplier

	var total_force := Vector3.ZERO
	var total_torque := Vector3.ZERO
	var submerged_points := 0

	for i in range(float_points.size()):
		var wp := probe_world[i]
		var water_h := surface[i].x
		var depth := water_h - wp.y
		if depth <= 0.0:
			continue
		depth = min(depth, max_depth)
		submerged_points += 1

		var r := wp - global_transform.origin
		var vel_at_point := linear_velocity + angular_velocity.cross(r)

		var buoyancy := Vector3.UP * (depth * k_per_point)
		var damping := Vector3.UP * (-vel_at_point.y * vertical_damping)
		var drag := -vel_at_point * (linear_drag * depth)

		var f := buoyancy + damping + drag
		total_force += f
		total_torque += r.cross(f)

	# Apply as equivalent center force + torque (avoids ambiguity in apply_force position semantics).
	apply_force(total_force)
	if submerged_points > 0:
		var submerged_factor := float(submerged_points) / point_count
		apply_torque(total_torque - angular_velocity * (angular_drag * submerged_factor))
