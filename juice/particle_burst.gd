class_name ParticleBurst
extends GPUParticles2D
# Pooled one-shot particle burst (Story 1.6 / AC3). Root = GPUParticles2D (works in the
# Compatibility renderer). Pool contract (AR6/D7): re-init via activate() ONLY — _ready() runs
# once per node and never re-fires for a re-acquired pooled node, so all per-spawn config lives in
# activate(). Self-releases via a Timer(lifetime + margin) → Pool.release(self); NEVER queue_free()
# (GPUParticles2D has no reliable `finished` signal across Godot 4.x).
#
# Asset-free (on-pattern): the codebase is all vector/Polygon2D art with zero sprite textures, so
# the particle texture is a soft white radial-gradient ImageTexture baked ONCE (static cache) and
# tinted per-spawn via `modulate`. Each instance owns its OWN ParticleProcessMaterial (created in
# _ready, never shared) so per-spawn velocity/scale writes don't clobber sibling bursts; additive
# blend (CanvasItemMaterial) carries the neon glow read.

# Extra lifetime before self-release — GPUParticles2D emits over `lifetime`; the margin guarantees
# the last particles have faded before the node returns to the pool.
const _RELEASE_MARGIN_S: float = 0.15
const _TEXTURE_SIZE: int = 32

# Shared, lazily-baked soft-white radial gradient (read-only texture; tinting is via modulate).
static var _shared_texture: ImageTexture

@onready var _mat: ParticleProcessMaterial = _ensure_material()
var _release_timer: Timer


func _ready() -> void:
	# ONE-TIME setup (pool contract). Instance-local materials so simultaneous bursts don't share.
	_ensure_material()
	_ensure_additive_blend()
	texture = _bake_texture()  # shared ImageTexture (one bake for the whole game)
	one_shot = true
	emitting = false
	# Self-release Timer — the robust release trigger for one-shot particles.
	_release_timer = Timer.new()
	_release_timer.one_shot = true
	_release_timer.timeout.connect(_on_release)
	add_child(_release_timer)


func activate(effect: StringName, at: Vector2, color: Color, profile: Dictionary) -> void:
	# Pool re-init entry (AR6) — the ONLY re-init path. Idempotently resolve the material (the fire
	# system calls activate AFTER add_child, so @onready has fired — but lazy resolution keeps
	# direct-activate tests safe, mirroring enemy_projectile._resolve_visual).
	_ensure_material()
	global_position = at
	modulate = color  # tint the white texture/material — per-event faction hue
	# Stop emission before mutating `amount`/`lifetime` to avoid Godot's "changed while processing"
	# warning on a reused instance, then re-arm.
	emitting = false
	amount = int(profile.get(&"amount", 8))
	lifetime = float(profile.get(&"lifetime", 0.35))
	_mat.direction = profile.get(&"direction", Vector3(0.0, -1.0, 0.0))
	_mat.spread = rad_to_deg(float(profile.get(&"spread_rad", PI)))
	var speed: float = float(profile.get(&"speed", 200.0))
	_mat.initial_velocity_min = speed * 0.4
	_mat.initial_velocity_max = speed
	var sz: float = float(profile.get(&"scale", 0.7))
	_mat.scale_min = sz * 0.5
	_mat.scale_max = sz
	_mat.gravity = profile.get(&"gravity", Vector3.ZERO)
	emitting = true
	visible = true
	# Arm the self-release. Synchronous Pool.release is safe — this fires from a Timer, NOT inside
	# a physics callback. Never queue_free().
	_release_timer.stop()
	_release_timer.wait_time = lifetime + _RELEASE_MARGIN_S
	_release_timer.start()


func _on_release() -> void:
	Pool.release(self)


func _ensure_material() -> ParticleProcessMaterial:
	# Instance-local material (created here, never shared across pooled instances). Re-resolution is
	# idempotent — returns the existing one if already set.
	var m: ParticleProcessMaterial = process_material as ParticleProcessMaterial
	if m == null:
		m = ParticleProcessMaterial.new()
		process_material = m
	return m


func _ensure_additive_blend() -> void:
	# Additive blend lives on a CanvasItemMaterial (GPUParticles2D inherits CanvasItem.material),
	# NOT on ParticleProcessMaterial (which has no blend_mode — it controls simulation only).
	if not (material is CanvasItemMaterial):
		var cim := CanvasItemMaterial.new()
		cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = cim


static func _bake_texture() -> ImageTexture:
	# Bake a 32×32 soft-white radial gradient ONCE; shared across every burst. Tinting is per-spawn
	# via modulate, so the texture stays pure white. (Built lazily; safe under --headless.)
	if _shared_texture != null:
		return _shared_texture
	var img := Image.create(_TEXTURE_SIZE, _TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var half: float = _TEXTURE_SIZE * 0.5
	var max_r: float = half
	for y: int in _TEXTURE_SIZE:
		for x: int in _TEXTURE_SIZE:
			var dx: float = (x + 0.5) - half
			var dy: float = (y + 0.5) - half
			var d: float = sqrt(dx * dx + dy * dy) / max_r
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a  # softer falloff for a glowy core
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_shared_texture = ImageTexture.create_from_image(img)
	return _shared_texture
