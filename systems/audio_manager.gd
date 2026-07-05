extends Node
# Basic synthwave SFX pipeline (Story 1.6 / D11/D12 — AC4). Replaces the 1.1 stub. Owns:
#  • buses (Master + SFX + Music) created via AudioServer at _ready (asset-free — no .tres bus
#    layout to hand-author; AudioServer is the project-default path for runtime buses),
#  • a fixed pool of AudioStreamPlayer nodes routed to the SFX bus (reused — never instantiate +
#    queue_free per SFX; NFR4),
#  • three synthesized AudioStreamWAV stabs (fire/hit/kill) built in code from 16-bit PCM — a real
#    "synthwave punch" with ZERO asset files (an AI can't cleanly author binary .wav).
# Full synthwave music + the full SFX set are Story 8.5; this is the v0.1 pipeline + basic stabs.
#
# AudioManager is a thin autoload SERVICE (not gameplay logic) — calling it from projectiles /
# fire_system is fine (D8 boundary). Typed helpers (play_fire/play_hit/play_kill) own the stream
# choice + variation, keeping emit sites one-liners.

const _POOL_SIZE: int = 8
const _MIX_RATE: int = 44100
const _AMP: float = 0.5  # 0..1 of full 16-bit scale — leaves headroom so layered SFX don't clip
const BUS_SFX: StringName = &"SFX"
const BUS_MUSIC: StringName = &"Music"
const BUS_MASTER: StringName = &"Master"

var _players: Array[AudioStreamPlayer] = []
# Seeded RNG for pitch jitter (NFR10 — project default is a seeded RNG over global randf; audio
# jitter is non-gameplay, so a fixed local seed keeps the variation reproducible).
var _pitch_rng := RandomNumberGenerator.new()

# Synthesized streams (built in _ready, cached; emit sites reach them via the typed helpers).
var sfx_fire: AudioStreamWAV
var sfx_hit: AudioStreamWAV
var sfx_kill: AudioStreamWAV


func _ready() -> void:
	_pitch_rng.seed = 0xA110
	_ensure_buses()
	_build_pool()
	_synthesize_streams()


# --- public API ---

func play_sfx(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	# Find a free player (or interrupt the longest-playing one), set stream + pitch + volume, play.
	# Pooled ⇒ no per-SFX instantiate/queue_free (NFR4).
	if stream == null:
		return
	var p: AudioStreamPlayer = _grab_player()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_fire() -> void:
	# ±5% pitch so the ~6 Hz autofire breathes (FR48/NFR12 punch).
	play_sfx(sfx_fire, _pitch_rng.randf_range(0.95, 1.05))


func play_hit(heavy: bool = false) -> void:
	# Heavy (Bomber, 2 dmg) ⇒ lower pitch for a weightier thud; standard ⇒ light pitch jitter.
	if heavy:
		play_sfx(sfx_hit, 0.8)
	else:
		play_sfx(sfx_hit, _pitch_rng.randf_range(0.95, 1.05))


func play_kill() -> void:
	play_sfx(sfx_kill, _pitch_rng.randf_range(0.95, 1.05))


func play_music(_stream: AudioStream) -> void:
	pass  # E1: no music. Full synthwave score is Story 8.5.


func stop_music() -> void:
	pass  # E1: no music.


# --- setup ---

func _ensure_buses() -> void:
	# Master always exists at index 0. Add SFX + Music (forward-compat) routed to Master if absent.
	# Asset-free runtime bus creation via AudioServer (the project's default path for runtime buses).
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, BUS_SFX)
		AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, BUS_MASTER)
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, BUS_MUSIC)
		AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, BUS_MASTER)


func _build_pool() -> void:
	for i: int in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)


func _grab_player() -> AudioStreamPlayer:
	# Free (non-playing) player wins; otherwise interrupt the one playing LONGEST (oldest playback
	# position) so a fire/hit never audibly vanishes mid-burst. _players is non-empty (built in _ready).
	var free_player: AudioStreamPlayer = _players[0]
	var found_free := false
	var oldest: AudioStreamPlayer = _players[0]
	var oldest_pos := -1.0
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			free_player = p
			found_free = true
			break
		if p.get_playback_position() > oldest_pos:
			oldest_pos = p.get_playback_position()
			oldest = p
	return free_player if found_free else oldest


func _synthesize_streams() -> void:
	# Short PCM stabs: a sine-frequency sweep + optional white noise, shaped by an exponential decay
	# envelope. Each is a one-shot mono 16-bit @ 44.1 kHz. fire = snappy high zap; hit = low thud
	# (+noise); kill = noisy descending explosion-ish. Deterministic (fixed-seed noise RNG).
	sfx_fire = _make_stream(_synth(0.07, 820.0, 360.0, 0.15, 42.0, 0x4A11))
	sfx_hit = _make_stream(_synth(0.13, 220.0, 90.0, 0.5, 20.0, 0x8A11))
	sfx_kill = _make_stream(_synth(0.28, 170.0, 40.0, 0.7, 11.0, 0xCA11))


func _make_stream(samples: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = samples
	return wav


func _synth(duration_s: float, f0: float, f1: float, noise_amount: float, decay: float, noise_seed: int) -> PackedByteArray:
	# Linear frequency sweep f0→f1 over duration_s, sine wave, mixed with white noise (lerp amount),
	# shaped by exp(-decay * t). Phase is integrated trapezoidally so a sweep stays in tune. The
	# noise RNG is seeded ⇒ the stream is byte-identical run to run (deterministic synthesis).
	var n: int = maxi(int(duration_s * _MIX_RATE), 1)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var phase: float = 0.0
	var prev_freq: float = f0
	var dt: float = 1.0 / _MIX_RATE
	for i: int in n:
		var t: float = float(i) * dt
		var progress: float = float(i) / float(n)
		var freq: float = lerpf(f0, f1, progress)
		phase += (prev_freq + freq) * 0.5 * dt  # trapezoidal phase integration
		prev_freq = freq
		var s: float = sin(TAU * phase)
		if noise_amount > 0.0:
			s = lerpf(s, rng.randf_range(-1.0, 1.0), noise_amount)
		var env: float = exp(-decay * t)
		var sample_i: int = clampi(int(s * env * _AMP * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample_i)  # little-endian s16
	return bytes
