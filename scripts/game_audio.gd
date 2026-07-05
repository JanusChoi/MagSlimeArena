extends Node
## Global BGM + hook SFX; Autoload persists across title / arena / menu.

const _BGM_PATH := "res://assets/audio/bgm.ogg"
const _HOOK_SFX := preload("res://assets/audio/electricity_link.ogg")

@export var bgm_volume_db: float = -2.0
@export var hook_sfx_volume_db: float = -10.0

var _bgm: AudioStreamPlayer
var _hook: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hook = _make_player(hook_sfx_volume_db)
	add_child(_hook)
	_hook.stream = _HOOK_SFX
	call_deferred("ensure_bgm_playing")


func ensure_bgm_playing() -> void:
	if _bgm == null:
		_bgm = _make_player(bgm_volume_db)
		add_child(_bgm)
	if _bgm.stream == null:
		var stream: AudioStream = load(_BGM_PATH)
		if stream == null:
			push_warning("GameAudio: BGM load failed: %s" % _BGM_PATH)
			return
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm.stream = stream
	if not _bgm.playing:
		_bgm.play()


func play_hook_sfx() -> void:
	if _hook.stream == null:
		return
	_hook.stop()
	_hook.play()


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	player.bus = &"Master"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	return player
