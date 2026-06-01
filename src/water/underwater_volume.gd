extends MeshInstance3D
class_name UnderwaterVolume

const UNDERWATER_SHADER := preload("res://res/shad/spatial/underwater_volume.gdshader")

@export var water_path : NodePath
@export var sun_path : NodePath
@export_range(0.0, 2.0, 0.01) var transition_margin := 0.35
@export_color_no_alpha var shallow_color := Color(0.08, 0.46, 0.55)
@export_color_no_alpha var deep_color := Color(0.01, 0.08, 0.13)
@export var absorption := Vector3(0.55, 0.18, 0.06)
@export_range(0.0, 0.25, 0.001) var density := 0.035
@export_range(10.0, 500.0, 1.0) var max_distance := 170.0
@export_range(0.0, 0.05, 0.001) var shimmer_strength := 0.002
@export_color_no_alpha var god_ray_color := Color(0.38, 0.72, 0.62)
@export_range(0.0, 1.0, 0.01) var god_ray_strength := 0.14
@export_range(0.01, 1.0, 0.01) var god_ray_scale := 0.09
@export_range(0.0, 2.0, 0.01) var god_ray_speed := 0.18
@export_range(0.0, 1.0, 0.01) var god_ray_sharpness := 0.58

var _water : Node
var _sun : Node3D
var _material := ShaderMaterial.new()
var _surface_height := 0.0

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	sorting_offset = 4096.0
	_material.shader = UNDERWATER_SHADER
	_material.render_priority = 127
	material_override = _material
	visible = false
	_find_water()
	_find_sun()
	_update_material_static_params()

func _process(_delta : float) -> void:
	if _water == null:
		_find_water()
	if _water == null:
		visible = false
		return

	_update_material_static_params()
	_update_surface_height()
	var depth := _surface_height - global_position.y
	var amount := smoothstep(-transition_margin, transition_margin, depth)
	visible = amount > 0.001
	_material.set_shader_parameter(&"underwater_amount", amount)
	_material.set_shader_parameter(&"camera_depth", maxf(depth, 0.0))
	_material.set_shader_parameter(&"camera_world_position", global_position)
	_material.set_shader_parameter(&"camera_world_basis", global_transform.basis)
	_update_sun_direction()
	_update_water_material(amount)

func _find_water() -> void:
	_water = get_node_or_null(water_path) if water_path != NodePath() else null
	if _water == null and get_tree() != null:
		_water = get_tree().get_first_node_in_group(&"water")
	if _water != null and _water is Node3D:
		_surface_height = (_water as Node3D).global_position.y

func _find_sun() -> void:
	_sun = get_node_or_null(sun_path) if sun_path != NodePath() else null
	if _sun != null:
		return

	var root := get_tree().current_scene if get_tree() != null else null
	if root == null:
		return
	_sun = _find_first_directional_light(root)

func _find_first_directional_light(node : Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node
	for child in node.get_children():
		var light := _find_first_directional_light(child)
		if light != null:
			return light
	return null

func _update_surface_height() -> void:
	if not (_water is Node3D):
		return

	_surface_height = (_water as Node3D).global_position.y
	if not _water.has_method(&"sample_surface_for"):
		return

	var query := PackedVector2Array([Vector2(global_position.x, global_position.z)])
	var surface : PackedVector4Array = _water.call(&"sample_surface_for", get_instance_id(), query)
	if not surface.is_empty():
		_surface_height = surface[0].x

func _update_material_static_params() -> void:
	_material.set_shader_parameter(&"shallow_color", shallow_color)
	_material.set_shader_parameter(&"deep_color", deep_color)
	_material.set_shader_parameter(&"absorption", absorption)
	_material.set_shader_parameter(&"density", density)
	_material.set_shader_parameter(&"max_distance", max_distance)
	_material.set_shader_parameter(&"shimmer_strength", shimmer_strength)
	_material.set_shader_parameter(&"god_ray_color", god_ray_color)
	_material.set_shader_parameter(&"god_ray_strength", god_ray_strength)
	_material.set_shader_parameter(&"god_ray_scale", god_ray_scale)
	_material.set_shader_parameter(&"god_ray_speed", god_ray_speed)
	_material.set_shader_parameter(&"god_ray_sharpness", god_ray_sharpness)

func _update_sun_direction() -> void:
	if _sun == null:
		_find_sun()
	if _sun == null:
		return

	var light_world_direction := -_sun.global_transform.basis.z.normalized()
	_material.set_shader_parameter(&"sun_world_direction", light_world_direction.normalized())

func _update_water_material(underwater_amount : float) -> void:
	if not (_water is MeshInstance3D):
		return

	var water_mesh := _water as MeshInstance3D
	var material := water_mesh.material_override
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(&"camera_underwater_amount", underwater_amount)
