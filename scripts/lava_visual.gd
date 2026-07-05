extends Control
## 屏幕底部岩浆带：顶边 = 液面 = 死亡线；优先使用裁剪后的 lava-flow 帧动画。

const _FLOW_FRAME_COUNT := 120
const _FLOW_FRAME_DIR := "res://assets/lava/flow_frames/frame_%04d.png"

@export var base_intensity: float = 0.55
@export var scroll_intensity: float = 1.35
@export var base_playback_speed: float = 0.75
@export var scroll_playback_speed: float = 1.25
@export var surface_line_height: float = 4.0
@export var use_shader_fallback: bool = false

@onready var _video: AnimatedSprite2D = $LavaVideo
@onready var _fill: ColorRect = $LavaFill
@onready var _surface_line: ColorRect = $SurfaceLine

static var _cached_flow_frames: SpriteFrames

var _heat_time: float = 0.0
var _intensity: float = 1.0
var _shader_mat: ShaderMaterial
var _anim_fps: float = 12.0
var _has_video: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_setup_shader()
	_setup_video()
	_intensity = base_intensity
	_apply_shader_uniforms()
	_set_playback_speed(base_playback_speed)
	resized.connect(_layout_children)
	call_deferred("_layout_children")


func _process(delta: float) -> void:
	if _has_video and _video:
		return
	_heat_time += delta
	_apply_shader_uniforms()


func set_scroll_active(active: bool) -> void:
	_intensity = scroll_intensity if active else base_intensity
	_set_playback_speed(scroll_playback_speed if active else base_playback_speed)
	if _surface_line:
		_surface_line.visible = true
		_surface_line.modulate.a = 0.85 if active else 0.45


func get_surface_fraction() -> float:
	return anchor_top


func _setup_shader() -> void:
	if _fill == null:
		return
	_shader_mat = _fill.material as ShaderMaterial
	if _shader_mat == null:
		var shader := load("res://shaders/lava_surface.gdshader") as Shader
		if shader:
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = shader
			_fill.material = _shader_mat
	_fill.visible = use_shader_fallback


func _setup_video() -> void:
	if _video == null:
		return
	var frames := _get_flow_frames()
	if frames == null or frames.get_frame_count("flow") == 0:
		_has_video = false
		if _fill:
			_fill.visible = true
		return
	_has_video = true
	_video.sprite_frames = frames
	_video.play("flow")
	_anim_fps = frames.get_animation_speed("flow")
	if _fill:
		_fill.visible = use_shader_fallback


func _set_playback_speed(speed: float) -> void:
	if _has_video and _video and _video.sprite_frames:
		_video.sprite_frames.set_animation_speed("flow", _anim_fps * speed)
		if not _video.is_playing():
			_video.play("flow")
		return
	_apply_shader_uniforms()


func _layout_children() -> void:
	if _fill:
		_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _surface_line:
		_surface_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_surface_line.offset_top = 0.0
		_surface_line.offset_bottom = surface_line_height
	if not _has_video or _video == null:
		return
	var tex := _video.sprite_frames.get_frame_texture("flow", 0) if _video.sprite_frames else null
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	# 帧已裁成 1080x480；顶边 = 液面，拉伸铺满整个 HUD 岩浆区
	_video.scale = Vector2(size.x / tex_size.x, size.y / tex_size.y)
	_video.position = Vector2.ZERO
	_video.offset = Vector2.ZERO
	_video.centered = false


func _get_flow_frames() -> SpriteFrames:
	if _cached_flow_frames != null:
		return _cached_flow_frames
	var frames := SpriteFrames.new()
	frames.add_animation(&"flow")
	frames.set_animation_speed(&"flow", 12.0)
	frames.set_animation_loop(&"flow", true)
	for i in range(1, _FLOW_FRAME_COUNT + 1):
		var texture: Texture2D = load(_FLOW_FRAME_DIR % i)
		if texture:
			frames.add_frame(&"flow", texture)
	if frames.get_frame_count("flow") == 0:
		return null
	_cached_flow_frames = frames
	return frames


func _apply_shader_uniforms() -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("heat_time", _heat_time)
		_shader_mat.set_shader_parameter("intensity", _intensity)
