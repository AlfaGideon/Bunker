extends RefCounted
## The bunker's plasma panel.
##
## One viewport, three channels: the idle logo splash, the anime reel and the
## advertising block. Everything the panel shows is drawn inside a SubViewport
## whose texture is put on the glass, so the panel keeps working no matter which
## scene it stands in — the camp behind the fire or the hall wall.

const LOGO := "res://assets/branding/logo.png"
const AD := "res://assets/tv/ad_slot.jpg"
const REEL := ["res://assets/tv/anime_episode_01.jpg", "res://assets/tv/anime_episode_02.jpg"]
const SIZE := Vector2i(768, 432)

const CHANNELS := ["splash", "anime", "ads"]
const BADGES := ["ЗАСТАВКА", "АНИМЕ", "РЕКЛАМА"]
const TITLES := [
	"БУНКЕР • ПОСЛЕДНИЙ ШЛЮЗ • ЗАСТАВКА",
	"АНИМЕШЕЧКА • «ОГНИ МЁРТВОГО ГОРОДА» • СЕРИЯ 1",
	"РЕКЛАМНЫЙ БЛОК • МЕСТО СВОБОДНО",
]
# Professions that know how to run the panel. Any of them may start a screening.
const CINEMA := ["Киномеханик", "Билетёр", "Киновед"]

const SCANLINE_SHADER := """shader_type canvas_item;
uniform float time = 0.0;
uniform float lines = 0.055;
uniform float vignette = 0.42;
void fragment() {
	float stripe = 0.5 + 0.5 * sin(UV.y * 640.0);
	float vig = smoothstep(0.78, 0.30, distance(UV, vec2(0.5)));
	float flicker = 0.96 + 0.04 * sin(time * 31.0);
	float alpha = stripe * lines * flicker + (1.0 - vig) * vignette;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(alpha, 0.0, 0.85));
}
"""

var viewport: SubViewport
var stage: Control
var still: TextureRect
var shade: ColorRect
var title: Label
var badge: Label
var channel := 0
var clock := 0.0
var reel_index := 0
var reel_clock := 0.0
var reduced_motion := false
var material: StandardMaterial3D

var _shade_material: ShaderMaterial
var _textures := {}


static func is_cinema_profession(profession: String) -> bool:
	return profession in CINEMA


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## Builds the viewport under `parent` (a node in the scene tree) and returns it.
func mount(parent: Node) -> SubViewport:
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)

	stage = Control.new()
	stage.size = Vector2(SIZE)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(stage)

	var backdrop := ColorRect.new()
	backdrop.color = Color("04080a")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(backdrop)

	still = TextureRect.new()
	still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(still)

	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SCANLINE_SHADER
	_shade_material.shader = shader
	shade.material = _shade_material
	stage.add_child(shade)

	var bar := ColorRect.new()
	bar.color = Color(0.02, 0.05, 0.06, 0.72)
	bar.position = Vector2(0, SIZE.y - 46)
	bar.size = Vector2(SIZE.x, 46)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bar)

	title = Label.new()
	title.position = Vector2(18, SIZE.y - 42)
	title.size = Vector2(SIZE.x - 36, 38)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("dfe7df"))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text = TITLES[0]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(title)

	badge = Label.new()
	badge.position = Vector2(16, 14)
	badge.size = Vector2(300, 34)
	badge.add_theme_font_size_override("font_size", 17)
	badge.add_theme_color_override("font_color", Color("ff8a5c"))
	badge.text = "● " + BADGES[0]
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(badge)

	_apply_channel()
	return viewport


## The material that replaces the glass of the exported panel.
func screen_material() -> StandardMaterial3D:
	if material == null and viewport != null:
		material = StandardMaterial3D.new()
		material.albedo_texture = viewport.get_texture()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_repeat = false
	return material


## Swaps the glass of a spawned `blender_plasma_tv` for the live viewport.
func attach(panel: Node3D) -> bool:
	var swapped := false
	for node in panel.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.material_override != null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			if source is StandardMaterial3D and str(source.resource_name).begins_with("tv-screen"):
				mesh.set_surface_override_material(surface, screen_material())
				swapped = true
	return swapped


func set_channel(index: int) -> void:
	channel = posmod(index, CHANNELS.size())
	reel_clock = 0.0
	_apply_channel()


func next() -> int:
	set_channel(channel + 1)
	return channel


func has_content() -> bool:
	return channel != 0


func channel_name() -> String:
	return BADGES[channel]


func caption() -> String:
	if channel == 0:
		return "ТЕЛЕВИЗОР · ЗАСТАВКА ЛОГОТИПА · нажми — включить кино"
	if channel == 1:
		return "ТЕЛЕВИЗОР · АНИМЕ «ОГНИ МЁРТВОГО ГОРОДА»\nнажми — рекламный блок"
	return "ТЕЛЕВИЗОР · РЕКЛАМА · место под будущие ролики\nнажми — вернуть заставку"


func _apply_channel() -> void:
	if still == null:
		return
	match CHANNELS[channel]:
		"anime":
			still.texture = _texture(REEL[reel_index])
			still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			still.pivot_offset = Vector2(SIZE) * 0.5
			still.scale = Vector2.ONE
		"ads":
			still.texture = _texture(AD)
			still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			still.pivot_offset = Vector2(SIZE) * 0.5
			still.scale = Vector2.ONE
		_:
			# No content: the game's own logo fills the panel, letterboxed.
			still.texture = _texture(LOGO)
			still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			still.pivot_offset = Vector2(SIZE) * 0.5
			still.scale = Vector2.ONE
	title.text = TITLES[channel]
	badge.text = "● " + BADGES[channel]
	badge.add_theme_color_override("font_color",
		Color("7ff0a8") if channel == 0 else Color("ff8a5c") if channel == 1 else Color("ffd06a"))
	if viewport != null:
		# The splash does not move, so the panel only re-renders when the reel runs.
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if channel != 0 else SubViewport.UPDATE_ONCE


func tick(delta: float) -> void:
	clock += delta
	if _shade_material != null:
		_shade_material.set_shader_parameter("time", clock)
	if channel == 1 and still != null:
		reel_clock += delta
		if reel_clock >= 3.8:
			reel_clock -= 3.8
			reel_index = (reel_index + 1) % REEL.size()
			still.texture = _texture(REEL[reel_index])
		if not reduced_motion:
			# Slow push-in, like a real broadcast cutting between two shots.
			var zoom := 1.0 + 0.05 * clampf(reel_clock / 3.8, 0.0, 1.0)
			still.scale = Vector2(zoom, zoom)
	if badge != null and channel != 0:
		badge.modulate.a = 0.45 if reduced_motion else 0.55 + 0.45 * (0.5 + 0.5 * sin(clock * 3.4))
