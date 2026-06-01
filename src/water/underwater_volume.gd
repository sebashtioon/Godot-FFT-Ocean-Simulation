extends MeshInstance3D
class_name UnderwaterVolume

const UNDERWATER_SHADER := preload("res://res/shad/spatial/underwater_volume.gdshader")

@export var water_path : NodePath
@export_range(0.0, 2.0, 0.01) var transition_margin := 0.35
@export_color_no_alpha var shallow_color := Color(0.08, 0.46, 0.55)
@export_color_no_alpha var deep_color := Color(0.01, 0.08, 0.13)
@export var absorption := Vector3(0.55, 0.18, 0.06)
@export_range(0.0, 0.25, 0.001) var density := 0.035
@export_range(10.0, 500.0, 1.0) var max_distance := 170.0
@export_range(0.0, 0.05, 0.001) var shimmer_strength := 0.008

var _water : Node
var _material := ShaderMaterial.new()
var _surface_height := 0.0

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	_material.shader = UNDERWATER_SHADER
	material_override = _material
	visible = false
	_find_water()
	_update_material_static_params()

func _process(_delta : float) -> void:
	if _water == null:
		_find_water()
	if _water == null:
		visible = false
		return

	_update_surface_height()
	var depth := _surface_height - global_position.y
	var amount := smoothstep(-transition_margin, transition_margin, depth)
	visible = amount > 0.001
	_material.set_shader_parameter(&"underwater_amount", amount)
	_material.set_shader_parameter(&"camera_depth", maxf(depth, 0.0))

func _find_water() -> void:
	_water = get_node_or_null(water_path) if water_path != NodePath() else null
	if _water == null and get_tree() != null:
		_water = get_tree().get_first_node_in_group(&"water")
	if _water != null and _water is Node3D:
		_surface_height = (_water as Node3D).global_position.y

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
