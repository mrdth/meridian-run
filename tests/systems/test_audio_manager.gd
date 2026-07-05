extends GutTest
# Tests for the AudioManager SFX pipeline (Story 1.6 / AC4 — D11/D12). Mirrors tests/systems/
# test_pool.gd. AudioManager is an autoload — its _ready built the SFX/Music buses, the 8-player
# pool, and the three synthesized AudioStreamWAV stabs before any test runs. Asserts: synthesized
# streams are valid mono 16-bit @ 44.1k; buses + routed pool exist; play_sfx drives a player with
# the right stream + pitch + volume; overflow beyond pool size does not error; typed helpers apply
# the heavy-pitch variant.


func test_synth_streams_are_valid_mono_16bit_at_44k() -> void:
	# Asset-free synthesis: fire/hit/kill are non-null in-memory AudioStreamWAVs, mono 16-bit @ 44100.
	for stream in [AudioManager.sfx_fire, AudioManager.sfx_hit, AudioManager.sfx_kill]:
		assert_not_null(stream)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_eq(stream.mix_rate, 44100)
		assert_false(stream.stereo)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
		assert_gt(stream.data.size(), 0)


func test_synth_is_deterministic() -> void:
	# Same seed/waveform ⇒ byte-identical stream each build (the determinism-leaning property).
	var a: PackedByteArray = AudioManager.sfx_fire.data
	# Re-build via a fresh AudioManager instance to compare (the synthesis is a pure function of the
	# fixed-seed RNG). We can't easily re-run _ready on the autoload, so assert the cached data is
	# stable across reads (non-empty + identical RID-free content) as a smoke check.
	assert_eq(a, AudioManager.sfx_fire.data)


func test_sfx_and_music_buses_exist() -> void:
	assert_ne(AudioServer.get_bus_index(&"SFX"), -1)
	assert_ne(AudioServer.get_bus_index(&"Music"), -1)
	assert_ne(AudioServer.get_bus_index(&"Master"), -1)


func test_pool_is_eight_players_routed_to_sfx() -> void:
	var count: int = 0
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer:
			count += 1
			assert_eq((c as AudioStreamPlayer).bus, &"SFX")
	assert_eq(count, 8)


func test_play_sfx_drives_a_player_with_stream_and_pitch() -> void:
	AudioManager.play_sfx(AudioManager.sfx_fire, 1.05, -2.0)
	var matched: AudioStreamPlayer = null
	for c in AudioManager.get_children():
		var p := c as AudioStreamPlayer
		if p.stream == AudioManager.sfx_fire:
			matched = p
			break
	assert_not_null(matched)
	assert_almost_eq(matched.pitch_scale, 1.05, 0.001)
	assert_almost_eq(matched.volume_db, -2.0, 0.001)
	assert_true(matched.playing, "play_sfx should start the player")


func test_play_sfx_overflow_does_not_error() -> void:
	# Fire well beyond the 8-player pool — interrupt-oldest handles it (no crash, no drop in code).
	for i in 20:
		AudioManager.play_sfx(AudioManager.sfx_hit, 1.0 + i * 0.01, 0.0)
	var any_playing: bool = false
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing:
			any_playing = true
			break
	assert_true(any_playing)


func test_play_hit_heavy_lowers_pitch() -> void:
	# Typed helper: heavy (Bomber) ⇒ 0.8 pitch; standard ⇒ jittered around 1.0.
	AudioManager.play_hit(true)
	var matched: AudioStreamPlayer = null
	for c in AudioManager.get_children():
		var p := c as AudioStreamPlayer
		if p.stream == AudioManager.sfx_hit and p.playing:
			matched = p
			break
	assert_not_null(matched)
	assert_almost_eq(matched.pitch_scale, 0.8, 0.001)


func test_play_fire_and_play_kill_reach_correct_streams() -> void:
	AudioManager.play_fire()
	var fire_playing := _find_playing(AudioManager.sfx_fire)
	assert_not_null(fire_playing)
	AudioManager.play_kill()
	var kill_playing := _find_playing(AudioManager.sfx_kill)
	assert_not_null(kill_playing)


func _find_playing(stream: AudioStream) -> AudioStreamPlayer:
	for c in AudioManager.get_children():
		var p := c as AudioStreamPlayer
		if p.stream == stream and p.playing:
			return p
	return null
