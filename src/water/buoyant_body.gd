extends RigidBody3D
class_name BuoyantBody3D

@export var water_path : NodePath
@export var marker_parent_path : Node3D

@export var float_point_markers : Array[Marker3D]

@export var gravity : float = 9.81
@export_range(0.01, 10.0, 0.01) var equilibrium_depth := 0.75
@export_range(0.0, 20.0, 0.01) var buoyancy_multiplier := 1.0

@export_range(0.0, 50.0, 0.01) var vertical_damping := 6.0
@export_range(0.0, 50.0, 0.01) var linear_drag := 1.25
@export_range(0.0, 50.0, 0.01) var angular_drag := 1.0

@export_range(0.0, 10.0, 0.01) var max_depth := 3.0

var _water : Node = null

func _ready() -> void:
	for marker in marker_parent_path.get_children(): # get all da markers
		float_point_markers.append(marker)
	_water = get_node_or_null(water_path) if water_path != NodePath() else null
	if _water == null and get_tree() != null:
		_water = get_tree().get_first_node_in_group(&"water")

func _physics_process(_delta : float) -> void:
	if _water == null and get_tree() != null:
		_water = get_tree().get_first_node_in_group(&"water")
	if _water == null:
		return
	if float_point_markers.is_empty():
		return
	if not (_water.has_method(&"sample_surface_for") or _water.has_method(&"sample_surface")):
		return

	var probe_world : Array[Vector3] = []
	probe_world.resize(float_point_markers.size())
	var query := PackedVector2Array()
	query.resize(float_point_markers.size())
	for i in range(float_point_markers.size()):
		var wp := global_transform * float_point_markers[i].position
		probe_world[i] = wp
		query[i] = Vector2(wp.x, wp.z)

	var surface : PackedVector4Array
	if _water.has_method(&"sample_surface_for"):
		surface = _water.call(&"sample_surface_for", get_instance_id(), query)
	else:
		surface = _water.call(&"sample_surface", query)
	if surface.size() != float_point_markers.size():
		return

	var point_count := float(float_point_markers.size())
	var k_per_point := (mass * gravity) / (equilibrium_depth * point_count) * buoyancy_multiplier

	var total_force := Vector3.ZERO
	var total_torque := Vector3.ZERO
	var submerged_points := 0

	for i in range(float_point_markers.size()):
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

	apply_force(total_force)
	if submerged_points > 0:
		var submerged_factor := float(submerged_points) / point_count
		apply_torque(total_torque - angular_velocity * (angular_drag * submerged_factor))
