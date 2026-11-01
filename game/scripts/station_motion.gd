extends Node
# Procedural life for the Blender stations. The models themselves are static,
# so every moving part is exported as its own glTF node (knob-0..2, needle,
# cursor, steam) and animated here. Offsets are in the units used by
# tools/blender/props_tech.py: the model root is scaled by BunkerArt.spawn, so
# they shrink and grow with the prop.

const DIAL := "radio-glass"
const SCREEN := "terminal-screen"
const STEAM := "steam-puff"

const NEEDLE_SPAN := 0.17       # half-width of the lit dial window, metres
const CURSOR_TOP := 0.095       # offset from the cursor's home to the first line
const CURSOR_WALK := 0.19       # how far the cursor walks down before wrapping
const CURSOR_LINES := 3
const CURSOR_LINE_TIME := 0.6
const STEAM_BASE := 1.225       # the steam node's height in the exported model
const STEAM_RISE := 0.11
const STEAM_CYCLE := 3.6

var kind := ""
var prop: Node3D
var clock := 0.0
var knobs: Array[Node3D] = []
var needle: Node3D
var cursor: Node3D
var steam: Node3D
var dial: StandardMaterial3D
var screen: StandardMaterial3D
var puff: StandardMaterial3D
var dial_base := 1.0
var screen_base := 1.0
var puff_alpha := 0.34
var spin := 0.0
var spin_applied := 0.0
var spin_target := 0.0
var tuning := 0.0
var tune_position := 0.35
var cursor_home := Vector3.ZERO
var cursor_up := Vector3.UP
var cursor_bound := false


static func attach(wrapper: Node3D, motion_kind: String) -> Node:
	var motion: Node = load("res://game/scripts/station_motion.gd").new()
	motion.kind = motion_kind
	motion.prop = wrapper
	# Desync instances so a hall full of stations does not pulse in lockstep.
	motion.clock = randf() * 12.0
	motion.set_meta("motion", motion_kind)
	wrapper.add_child(motion)
	motion.bind()
	return motion


func bind() -> void:
	set_process(true)
	if prop == null or prop.get_child_count() == 0:
		return
	var model: Node3D = prop.get_child(0) as Node3D
	if model == null:
		return
	for child in model.get_children():
		var node := child as Node3D
		if node == null:
			continue
		var name := String(node.name)
		if name.begins_with("knob-"):
			knobs.append(node)
		elif name == "needle":
			needle = node
		elif name == "cursor":
			cursor = node
		elif name == "steam":
			steam = node
	match kind:
		"radio":
			dial = _paint(model, DIAL, Color("ffb347"), 0.9)
			if dial != null:
				dial_base = dial.emission_energy_multiplier
		"terminal":
			screen = _paint(model, SCREEN, Color("4ff0ee"), 0.6)
			if screen != null:
				screen_base = screen.emission_energy_multiplier
		"steam":
			puff = _paint(model, STEAM, Color.BLACK, 0.0)
			if puff != null:
				puff_alpha = puff.albedo_color.a


# The stations are drawn at gameplay distance, so the pulse is deliberately
# small: it should read as "powered" without becoming a lighthouse.
func _process(delta: float) -> void:
	clock += delta
	match kind:
		"radio":
			_radio(delta)
		"terminal":
			_terminal()
		"steam":
			_steam()


func _radio(delta: float) -> void:
	if not knobs.is_empty():
		spin = lerpf(spin, spin_target, 1.0 - exp(-5.0 * delta))
		var step: float = spin - spin_applied
		if absf(step) > 0.0005:
			for knob in knobs:
				# A knob is a cylinder turned to face the front panel, so its
				# own Z axis is the axle: this spins the disc where it stands.
				knob.rotate_object_local(Vector3(0, 0, 1), step)
			spin_applied = spin
	if needle != null:
		var target: float = -NEEDLE_SPAN + tune_position * NEEDLE_SPAN * 2.0
		needle.position.x = lerpf(needle.position.x, target, 1.0 - exp(-4.0 * delta))
	if dial != null:
		tuning = maxf(0.0, tuning - delta * 2.6)
		var pulse: float = 0.88 + 0.12 * sin(clock * 2.1)
		dial.emission_energy_multiplier = dial_base * (pulse + tuning * 0.55)


func _terminal() -> void:
	if cursor != null:
		if not cursor_bound:
			# The CRT is tilted back, so "up the screen" is the cursor's own Y axis.
			cursor_home = cursor.position
			cursor_up = cursor.basis.y.normalized()
			cursor_bound = true
		var walk: float = CURSOR_LINE_TIME * CURSOR_LINES
		var cycle: float = walk + 0.9
		var t: float = fmod(clock, cycle)
		var line: int = mini(int(t / CURSOR_LINE_TIME), CURSOR_LINES)
		var offset: float = CURSOR_TOP - float(line) * (CURSOR_WALK / CURSOR_LINES)
		cursor.position = cursor_home + cursor_up * offset
		# Solid while typing, blinking in the pause before the screen wraps.
		cursor.visible = t < walk or fmod(t, 0.22) < 0.13
	if screen != null:
		var flicker: float = 0.94 + 0.06 * sin(clock * 9.0)
		if fmod(clock, 4.3) < 0.06:
			flicker *= 0.55
		screen.emission_energy_multiplier = screen_base * flicker


func _steam() -> void:
	if steam == null:
		return
	var t: float = fmod(clock, STEAM_CYCLE) / STEAM_CYCLE
	steam.position.y = STEAM_BASE + STEAM_RISE * t
	steam.rotation.y = 0.22 * sin(clock * 0.8)
	steam.scale = Vector3.ONE * (1.0 + 0.4 * t)
	if puff != null:
		var color: Color = puff.albedo_color
		color.a = puff_alpha * clampf(1.0 - t, 0.0, 1.0)
		puff.albedo_color = color


# A knob turn and a needle jump, played when the record changes.
func tune(index: int) -> void:
	spin_target += 1.3 + 0.35 * float(index % 3)
	tuning = 1.0
	tune_position = clampf(0.18 + 0.22 * float(index % 4), 0.0, 1.0)


func _paint(root: Node, prefix: String, tint: Color, energy: float) -> StandardMaterial3D:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var target: MeshInstance3D = mesh
		if target.mesh == null or target.material_override != null:
			continue
		for index in target.mesh.get_surface_count():
			var source: Material = target.get_active_material(index)
			if not (source is StandardMaterial3D) or not str(source.resource_name).begins_with(prefix):
				continue
			var lit: StandardMaterial3D = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			if energy > 0.0:
				lit.emission_enabled = true
				lit.emission = tint
				lit.emission_energy_multiplier = energy
			target.set_surface_override_material(index, lit)
			return lit
	return null
