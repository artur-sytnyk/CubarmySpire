extends Node

const MUSIC: Dictionary = {
	"start_menu": { "path": "res://assets/sounds/music/start_menu.ogg", "volume_db": 0.0 },
	"menu":       { "path": "res://assets/sounds/music/menu.mp3",       "volume_db": 0.0 },
	"run_end":    { "path": "res://assets/sounds/music/run_end.mp3",    "volume_db": 0.0 },
}

const BATTLE_TRACKS: Array[Dictionary] = [
	{ "path": "res://assets/sounds/music/battle_1.mp3", "volume_db": 0.0 },
	{ "path": "res://assets/sounds/music/battle_2.mp3", "volume_db": 0.0 },
	{ "path": "res://assets/sounds/music/battle_3.mp3", "volume_db": 0.0 },
	{ "path": "res://assets/sounds/music/battle_4.mp3", "volume_db": 0.0 },
	{ "path": "res://assets/sounds/music/battle_5.mp3", "volume_db": 0.0 },
]

const SOUNDS: Dictionary = {
	"transition":   { "path": "res://assets/sounds/ui/transition.ogg",   "volume_db": -8.0, "pitch_randomized": false  },
	"button_click": { "path": "res://assets/sounds/ui/button_click.ogg", "volume_db": -12.0, "pitch_randomized": false },
	"purchase":     { "path": "res://assets/sounds/ui/purchase.ogg",     "volume_db": -6.0, "pitch_randomized": true  },
	"equip":        { "path": "res://assets/sounds/ui/equip.wav",        "volume_db": -6.0, "pitch_randomized": false },
	"unequip":      { "path": "res://assets/sounds/ui/unequip.wav",      "volume_db": -6.0, "pitch_randomized": false },
	"pu_hover":     { "path": "res://assets/sounds/ui/pu_hover.ogg",     "volume_db": 0.0, "pitch_randomized": false },
	"pu_select":    { "path": "res://assets/sounds/ui/pu_select.ogg",    "volume_db": 0.0, "pitch_randomized": false },
	"stage_win":    { "path": "res://assets/sounds/ui/victory.mp3",      "volume_db": 0.0, "pitch_randomized": false },
	"run_abandon":  { "path": "res://assets/sounds/ui/fail.mp3",         "volume_db": 0.0, "pitch_randomized": false },
}


const SOUND_VARIANTS: Dictionary = {
	"unit_spawn": {
		"volume_db": 0.0,
		"pitch_randomized": true,
		"tracks": [
			{ "path": "res://assets/sounds/sfx/unit_spawn_1.mp3", "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/unit_spawn_2.mp3", "volume_db": 0.0 },
		]
	},
	"unit_hit": {
		"volume_db": 0.0,
		"pitch_randomized": true,
		"tracks": [
			{ "path": "res://assets/sounds/sfx/unit_hit_1.ogg", "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/unit_hit_2.ogg", "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/unit_hit_3.ogg", "volume_db": 0.0 },
		]
	},
	"unit_death": {
		"volume_db": 0.0,
		"pitch_randomized": true,
		"tracks": [
			{ "path": "res://assets/sounds/sfx/unit_death_1.ogg", "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/unit_death_2.ogg", "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/unit_death_3.ogg", "volume_db": 0.0 },
		]
	},
	"sword_swing": {
		"volume_db": 0.0,
		"pitch_randomized": true,
		"tracks": [
			{ "path": "res://assets/sounds/sfx/melee_1.wav",  "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/melee_2.ogg",  "volume_db":  0.0 },
			{ "path": "res://assets/sounds/sfx/melee_3.ogg",  "volume_db": 0.0 },
		]
	},
	"melee_flurry": {
		"volume_db": 0.0,
		"pitch_randomized": true,
		"tracks": [
			{ "path": "res://assets/sounds/sfx/melee_flurry_1.ogg",  "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/melee_flurry_2.ogg",  "volume_db": 0.0 },
			{ "path": "res://assets/sounds/sfx/melee_flurry_3.ogg",  "volume_db": 0.0 },
		]
	},
	"bow_shoot": {
		"volume_db": 0.0,
		"pitch_randomized": true,
		"tracks": [
			{ "path": "res://assets/sounds/sfx/bow_1.wav",  "volume_db":  0.0 },
			{ "path": "res://assets/sounds/sfx/bow_2.ogg",  "volume_db": 0.0 },
		]
	},
}


var _music_player: AudioStreamPlayer
var _stream_cache: Dictionary = {}
var _is_transitioning: bool = false
var _current_mode: String = ""
var _last_battle_track: String = ""



func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.bus = GameData.BUS_MUSIC
	_build_cache()
	get_tree().node_added.connect(_on_node_added)
	_connect_existing_buttons(get_tree().root)


func _build_cache() -> void:
	for key: String in SOUNDS:
		var entry: Dictionary = SOUNDS[key]
		_stream_cache[key] = load(entry["path"])
	
	for key: String in SOUND_VARIANTS:
		var entry: Dictionary = SOUND_VARIANTS[key]
		var randomizer: AudioStreamRandomizer = AudioStreamRandomizer.new()
		randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		for i: int in entry["tracks"].size():
			var track: Dictionary = entry["tracks"][i]
			randomizer.add_stream(i, load(track["path"]))
		_stream_cache[key] = randomizer



func _on_node_added(node: Node) -> void:
	_connect_existing_buttons(node)


func _connect_existing_buttons(node: Node) -> void:
	if node is BaseButton and\
	(not node.has_meta("click_sound_ignore") and not node.has_meta("sound_connected")):
		node.set_meta("sound_connected", true)
		node.pressed.connect(func(): play_ui("button_click"))
	for child: Node in node.get_children():
		_connect_existing_buttons(child)


# API

func play_sfx(key: String) -> void:
	_play_one_shot(key, GameData.BUS_SFX)


func play_ui(key: String) -> void:
	_play_one_shot(key, GameData.BUS_UI)


func _play_one_shot(key: String, bus: String) -> void:
	if not _stream_cache.has(key):
		push_warning("SoundManager: unknown key: " + key)
		return
	var entry: Dictionary = SOUNDS.get(key, SOUND_VARIANTS.get(key, {}))
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = _stream_cache[key]
	player.bus = bus
	player.volume_db = entry.get("volume_db", 0.0)
	if entry.get("pitch_randomized", false):
		player.pitch_scale = randf_range(0.8, 1.2)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


# Background Music

func play_music(key: String, fade: bool = true) -> void:
	if key == "battle":
		if _current_mode == "battle" and _music_player.playing:
			unduck_music()
			return
		_start_battle_playlist(fade)
		return
	if not MUSIC.has(key):
		push_warning("SoundManager: unknown music key: " + key)
		return
	var entry: Dictionary = MUSIC[key]
	if _music_player.stream != null and _music_player.playing:
		if _music_player.stream.resource_path == entry["path"]:
			return
	_current_mode = key
	if _music_player.finished.is_connected(_on_battle_track_finished):
		_music_player.finished.disconnect(_on_battle_track_finished)
	if fade:
		_fade_out(func(): _start_music(entry["path"], entry.get("volume_db", 0.0)))
	else:
		_start_music(entry["path"], entry.get("volume_db", 0.0))


func stop_music(fade: bool = true) -> void:
	_current_mode = ""
	if _music_player.finished.is_connected(_on_battle_track_finished):
		_music_player.finished.disconnect(_on_battle_track_finished)
	if not _music_player.playing:
		return
	if fade:
		_fade_out()
	else:
		_music_player.stop()
		_music_player.volume_db = 0.0


func _start_battle_playlist(fade: bool) -> void:
	_current_mode = "battle"
	var track: Dictionary = _pick_battle_track()
	if not _music_player.finished.is_connected(_on_battle_track_finished):
		_music_player.finished.connect(_on_battle_track_finished)
	if _music_player.stream != null and _music_player.playing and fade:
		_fade_out(func(): _start_music(track["path"], track.get("volume_db", 0.0)))
	else:
		_start_music(track["path"], track.get("volume_db", 0.0))


func _on_battle_track_finished() -> void:
	if _current_mode != "battle":
		return
	await get_tree().create_timer(GameData.BATTLE_SILENCE_DURATION).timeout
	if _current_mode != "battle":
		return
	var track: Dictionary = _pick_battle_track()
	_start_music(track["path"], track.get("volume_db", 0.0))


func _pick_battle_track() -> Dictionary:
	var available: Array = BATTLE_TRACKS.filter(
			func(t: Dictionary): return t["path"] != _last_battle_track
	)
	var pick: Dictionary = available[randi() % available.size()]
	_last_battle_track = pick["path"]
	return pick


func _fade_out(on_complete: Callable = Callable()) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, GameData.MUSIC_FADE_OUT_DURATION)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
			_music_player.stop()
			_music_player.volume_db = 0.0
			_is_transitioning = false
			if on_complete.is_valid():
				on_complete.call()
	)


func _start_music(path: String, volume_db: float = 0.0) -> void:
	_music_player.stream = load(path)
	_music_player.volume_db = -80.0
	_music_player.play()
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", volume_db, GameData.MUSIC_FADE_IN_DURATION)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func duck_music(target_db: float = -18.0) -> void:
	if not _music_player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", target_db, GameData.MUSIC_FADE_OUT_DURATION)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func unduck_music() -> void:
	if not _music_player.playing:
		return
	var target_db: float = 0.0
	# recover the correct target volume for the current track
	if _current_mode == "battle":
		var track: Dictionary = BATTLE_TRACKS.filter(
				func(t: Dictionary): return t["path"] == _last_battle_track
		).front()
		target_db = track.get("volume_db", 0.0) if track else 0.0
	else:
		target_db = MUSIC.get(_current_mode, {}).get("volume_db", 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(_music_player, "volume_db", target_db, GameData.MUSIC_FADE_IN_DURATION)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
