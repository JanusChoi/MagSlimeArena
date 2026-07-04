extends ColorRect
## Screen-fixed lava overlay with animated shader surface.

@export var base_intensity: float = 1.0
@export var scroll_intensity: float = 1.65

var _heat_time: float = 0.0
var _intensity: float = 1.0
var _shader_mat: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_mat = material as ShaderMaterial
	if _shader_mat == null:
		var shader := load("res://shaders/lava_surface.gdshader") as Shader
		if shader:
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = shader
			material = _shader_mat
	_intensity = base_intensity
	_apply_uniforms()


func _process(delta: float) -> void:
	_heat_time += delta
	_apply_uniforms()


func set_scroll_active(active: bool) -> void:
	_intensity = scroll_intensity if active else base_intensity


func _apply_uniforms() -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("heat_time", _heat_time)
		_shader_mat.set_shader_parameter("intensity", _intensity)
