extends Node
## 全局音频管理（Autoload）。
## 现在没有音频文件时会静默跳过；以后把 ogg/wav 按名称放进 audio/sfx 或 audio/music 即可。

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const SFX_VOICES := 8
const EXTENSIONS := [".ogg", ".wav", ".mp3"]

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _music_player: AudioStreamPlayer
var _current_music := &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

func play_sfx(sound: StringName, volume_db := 0.0, pitch_variation := 0.05) -> void:
	var stream := _load_audio(SFX_DIR, sound)
	if stream == null:
		return

	var player := _next_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()

func play_music(track: StringName) -> void:
	if track == _current_music:
		return

	_current_music = track
	_music_player.stop()

	var stream := _load_audio(MUSIC_DIR, track)
	if stream == null:
		return

	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_current_music = &""
	_music_player.stop()

func _next_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player

	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	return _sfx_players[_sfx_cursor]

func _load_audio(dir: String, name: StringName) -> AudioStream:
	for ext in EXTENSIONS:
		var path: String = dir + String(name) + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null
