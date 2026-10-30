extends RefCounted
## Vector identity art for the character cards.
##
## Every emblem is drawn from Godot primitives, so the cards work in the APK
## without extra textures: a profession picks a palette, a tagline and an icon
## that is used on the card back and as a watermark on its parameter tiles.

const GROUP_STYLE := {
	"medical": {"icon": "cross", "accent": "7fe3c0", "deep": "0b2628", "tag": "МЕДИЦИНА И УХОД"},
	"science": {"icon": "flask", "accent": "8ecbff", "deep": "0d2334", "tag": "НАУКА И АНАЛИЗ"},
	"engineering": {"icon": "gear", "accent": "f0b45f", "deep": "241c13", "tag": "МЕХАНИКА И СВЕТ"},
	"electrical": {"icon": "bolt", "accent": "f5d06f", "deep": "251f12", "tag": "ЭНЕРГИЯ И СИГНАЛ"},
	"construction": {"icon": "hammer", "accent": "e0b07a", "deep": "261a13", "tag": "МАСТЕРСКАЯ И РЕМЕСЛО"},
	"food": {"icon": "pot", "accent": "ffb38a", "deep": "291812", "tag": "ПИЩА И ТЕПЛО"},
	"nature": {"icon": "leaf", "accent": "b6e07f", "deep": "172815", "tag": "ЖИЗНЬ И ЗЕМЛЯ"},
	"rescue": {"icon": "flame", "accent": "ff8a6a", "deep": "2b1411", "tag": "ОГОНЬ И СПАСЕНИЕ"},
	"mind": {"icon": "book", "accent": "d1b3ff", "deep": "20182e", "tag": "ЗНАНИЕ И ПАМЯТЬ"},
	"logistics": {"icon": "crate", "accent": "ffd98a", "deep": "292212", "tag": "ПУТИ И ЗАПАСЫ"}
}

const GROUPS := {
	"medical": ["Врач", "Фельдшер", "Медсестра", "Фармацевт", "Ветеринар", "Инструктор первой помощи", "Микробиолог"],
	"science": ["Химик", "Биолог", "Геолог", "Метеоролог", "Эколог", "Картограф"],
	"engineering": ["Инженер-механик", "Сантехник", "Сварщик", "Слесарь",
		"Техник вентиляции", "Инженер водоочистки"],
	"electrical": ["Электрик", "Энергетик", "Связист", "Радиотехник", "Программист"],
	"construction": ["Строитель", "Плотник", "Швея"],
	"food": ["Повар", "Пекарь", "Технолог пищевого производства"],
	"nature": ["Агроном", "Оператор теплицы", "Зоотехник"],
	"rescue": ["Пожарный", "Спасатель"],
	"mind": ["Психолог", "Учитель", "Переводчик", "Архивист"],
	"logistics": ["Логист", "Водитель"]
}

# A specific pictogram for the professions whose work is easy to recognise.
const ICONS := {
	"Врач": "cross", "Фельдшер": "cross", "Медсестра": "cross", "Инструктор первой помощи": "cross",
	"Фармацевт": "flask", "Химик": "flask", "Биолог": "cell", "Микробиолог": "cell",
	"Ветеринар": "paw", "Зоотехник": "paw",
	"Строитель": "hammer", "Плотник": "saw", "Сварщик": "spark",
	"Сантехник": "drop", "Инженер водоочистки": "drop",
	"Связист": "radio", "Радиотехник": "radio", "Программист": "chip",
	"Психолог": "eye", "Учитель": "book", "Архивист": "book", "Переводчик": "speech",
	"Пожарный": "flame", "Спасатель": "shield",
	"Геолог": "compass", "Картограф": "compass", "Метеоролог": "cloud",
	"Повар": "pot", "Пекарь": "bread", "Технолог пищевого производства": "pot",
	"Логист": "crate", "Водитель": "truck",
	"Швея": "needle", "Агроном": "leaf", "Эколог": "leaf", "Оператор теплицы": "leaf",
	"Электрик": "bolt", "Энергетик": "bolt", "Техник вентиляции": "fan", "Слесарь": "wrench"
}

# Each profession gets its own printed motto; the palette still comes from
# its group so the art system stays compact.
const TAGS := {
	"Врач": "МЕДИЦИНА И УХОД", "Фельдшер": "ПЕРВАЯ ПОМОЩЬ", "Медсестра": "ЗАБОТА И УХОД",
	"Инструктор первой помощи": "ПЕРВАЯ ПОМОЩЬ", "Фармацевт": "ЛЕКАРСТВА И ДОЗЫ",
	"Ветеринар": "ЖИВОТНЫЕ И ЗАБОТА", "Микробиолог": "МИКРОМИР И РИСК",
	"Химик": "ВЕЩЕСТВА И РЕАКЦИИ", "Биолог": "ЖИЗНЬ И СРЕДА", "Геолог": "ПОРОДЫ И ГЛУБИНА",
	"Метеоролог": "ПОГОДА И ПРОГНОЗ", "Эколог": "СРЕДА И БАЛАНС", "Картограф": "КАРТЫ И МАРШРУТЫ",
	"Агроном": "ЗЕМЛЯ И УРОЖАЙ", "Оператор теплицы": "ТЕПЛИЦА И ВСХОДЫ", "Зоотехник": "ЖИВОТНЫЕ И УХОД",
	"Повар": "КУХНЯ БУНКЕРА", "Пекарь": "ХЛЕБ И ПЕЧЬ", "Технолог пищевого производства": "ЗАПАСЫ И КАЧЕСТВО",
	"Пожарный": "ОГОНЬ И ЗАЩИТА", "Спасатель": "ПОИСК И СПАСЕНИЕ",
	"Психолог": "РАЗУМ И СТРЕСС", "Учитель": "ЗНАНИЕ И ДЕТИ", "Переводчик": "ЯЗЫКИ И СВЯЗЬ",
	"Архивист": "ПАМЯТЬ И ДОКУМЕНТЫ", "Программист": "КОД И СИСТЕМЫ",
	"Логист": "ПУТИ И ЗАПАСЫ", "Водитель": "ДОРОГА И МАШИНА", "Швея": "ТКАНЬ И ТЕПЛО",
	"Электрик": "ЭНЕРГИЯ И СЕТИ", "Энергетик": "ЭНЕРГИЯ И СЕТИ", "Связист": "СИГНАЛ И СВЯЗЬ",
	"Радиотехник": "СИГНАЛ И СВЯЗЬ", "Сварщик": "МЕТАЛЛ И ИСКРА", "Плотник": "ДЕРЕВО И ФОРМА",
	"Строитель": "КАМЕНЬ И ОПОРА", "Техник вентиляции": "ВОЗДУХ И ПОТОК", "Слесарь": "МЕТАЛЛ И МЕХАНИЗМЫ",
	"Сантехник": "ВОДА И ТРУБЫ", "Инженер водоочистки": "ЧИСТАЯ ВОДА", "Инженер-механик": "МАШИНЫ И УЗЛЫ"
}

const PARAMETER_ICONS := {
	"profession": "gear", "biology": "person", "health": "cross",
	"quality": "spark", "skill": "star", "baggage": "case", "fact": "note"
}

const DEFAULT_STYLE := {"icon": "gear", "accent": "d9b06e", "deep": "14272c", "tag": "РЕМЕСЛО И ОПЫТ"}


static func group_of(profession: String) -> String:
	for group in GROUPS:
		if profession in GROUPS[group]:
			return group
	return "engineering"


static func style(profession: String) -> Dictionary:
	var group := group_of(profession)
	var base: Dictionary = GROUP_STYLE.get(group, DEFAULT_STYLE)
	return {
		"group": group,
		"icon": str(ICONS.get(profession, base["icon"])),
		"accent": Color(str(base["accent"])),
		"deep": Color(str(base["deep"])),
		"tag": str(TAGS.get(profession, base["tag"]))
	}


static func parameter_icon(parameter_id: String) -> String:
	return str(PARAMETER_ICONS.get(parameter_id, "note"))


# Each group has a generated portrait illustration: a faceless mannequin in
# profession gear. Textures are loaded on demand and cached by Godot.
static var _textures := {}

static func texture_for(profession: String) -> Texture2D:
	var group := group_of(profession)
	if _textures.has(group):
		return _textures[group]
	var path := "res://assets/professions/" + group + ".jpg"
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[group] = texture
	return texture


# ---------------------------------------------------------------- background

static func draw_background(canvas: CanvasItem, rect: Rect2, look: Dictionary) -> void:
	var deep: Color = look["deep"]
	var accent: Color = look["accent"]
	var steps := 36
	for i in steps:
		var t := float(i) / float(steps - 1)
		var strip := deep.darkened(0.62).lerp(deep.lightened(0.14), t)
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * t,
			rect.size.x, rect.size.y / float(steps) + 1.5), strip)
	# Soft halo behind the emblem, built from translucent circles.
	var center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.40)
	for i in range(14, 0, -1):
		var radius := rect.size.y * (0.10 + i * 0.034)
		canvas.draw_circle(center, radius, Color(accent, 0.013))
	# Paper grain: a bounded dot grid plus sparse scanlines.
	var y := rect.position.y + 10.0
	while y < rect.end.y - 6.0:
		canvas.draw_line(Vector2(rect.position.x + 8, y), Vector2(rect.end.x - 8, y), Color(1, 1, 1, 0.018), 1.0)
		y += 7.0
	var gx := rect.position.x + 9.0
	while gx < rect.end.x - 6.0:
		var gy := rect.position.y + 9.0
		while gy < rect.end.y - 6.0:
			canvas.draw_circle(Vector2(gx, gy), 0.9, Color(1, 1, 1, 0.035))
			gy += 23.0
		gx += 23.0
	# Wider edge shading keeps the eye on the emblem.
	for i in 10:
		var shade := Color(0, 0, 0, 0.035)
		canvas.draw_line(Vector2(rect.position.x, rect.position.y + i * 2.0),
			Vector2(rect.end.x, rect.position.y + i * 2.0), shade, 2.0)
		canvas.draw_line(Vector2(rect.position.x, rect.end.y - i * 2.0),
			Vector2(rect.end.x, rect.end.y - i * 2.0), shade, 2.0)


static func draw_cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var target_ratio := rect.size.x / rect.size.y
	var source_ratio := texture_size.x / texture_size.y
	var region := Rect2(Vector2.ZERO, texture_size)
	if source_ratio > target_ratio:
		var width := texture_size.y * target_ratio
		region = Rect2((texture_size.x - width) * 0.5, 0, width, texture_size.y)
	else:
		var height := texture_size.x / target_ratio
		region = Rect2(0, (texture_size.y - height) * 0.5, texture_size.x, height)
	canvas.draw_texture_rect_region(texture, rect, region)


static func draw_frame(canvas: CanvasItem, rect: Rect2, accent: Color, alpha: float = 0.55) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = Color(accent, alpha)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	canvas.draw_style_box(box, rect)
	var length := 18.0
	var inset := 7.0
	var corners := [
		[rect.position + Vector2(inset, inset), Vector2.RIGHT],
		[rect.position + Vector2(inset, inset), Vector2.DOWN],
		[Vector2(rect.end.x - inset, rect.position.y + inset), Vector2.LEFT],
		[Vector2(rect.end.x - inset, rect.position.y + inset), Vector2.DOWN],
		[rect.position + Vector2(inset, rect.end.y - inset), Vector2.RIGHT],
		[rect.position + Vector2(inset, rect.end.y - inset), Vector2.UP],
		[Vector2(rect.end.x - inset, rect.end.y - inset), Vector2.LEFT],
		[Vector2(rect.end.x - inset, rect.end.y - inset), Vector2.UP]
	]
	for corner in corners:
		canvas.draw_line(corner[0], corner[0] + corner[1] * length, Color(accent, alpha * 0.85), 1.5, true)


static func draw_emblem(canvas: CanvasItem, center: Vector2, radius: float, look: Dictionary) -> void:
	var accent: Color = look["accent"]
	canvas.draw_circle(center, radius * 1.34, Color(accent, 0.045))
	canvas.draw_arc(center, radius * 1.12, 0, TAU, 72, Color(accent, 0.36), 1.5, true)
	canvas.draw_arc(center, radius * 1.32, -0.75, 2.35, 48, Color(accent, 0.20), 1.0, true)
	for i in 28:
		var angle := TAU * float(i) / 28.0
		var inner := radius * (1.19 if i % 4 == 0 else 1.23)
		var outer := radius * (1.29 if i % 4 == 0 else 1.26)
		var direction := Vector2(cos(angle), sin(angle))
		canvas.draw_line(center + direction * inner, center + direction * outer,
			Color(accent, 0.34 if i % 4 == 0 else 0.18), 1.0, true)
	for i in 3:
		var angle := -0.8 + float(i) * 2.3
		var orbit := center + Vector2(cos(angle), sin(angle)) * radius * 1.43
		canvas.draw_circle(orbit, 2.4, Color(accent, 0.55))
	canvas.draw_circle(center, radius * 0.92, Color(0, 0, 0, 0.20))
	canvas.draw_arc(center, radius * 0.92, 0, TAU, 64, Color(accent, 0.55), 1.2, true)
	draw_icon(canvas, center, radius * 0.62, str(look["icon"]), accent.lightened(0.38), maxf(3.0, radius * 0.06))


# --------------------------------------------------------------------- icons

static func draw_icon(canvas: CanvasItem, at: Vector2, r: float, icon: String, color: Color, width: float = 4.0) -> void:
	var t := maxf(1.4, width)
	var faint := Color(color, 0.75)
	match icon:
		"cross":
			canvas.draw_line(at + Vector2(-r * 0.62, 0), at + Vector2(r * 0.62, 0), color, t * 2.1, true)
			canvas.draw_line(at + Vector2(0, -r * 0.62), at + Vector2(0, r * 0.62), color, t * 2.1, true)
		"leaf":
			var leaf := PackedVector2Array([
				at + Vector2(-r * 0.62, r * 0.52), at + Vector2(-r * 0.05, -r * 0.78),
				at + Vector2(r * 0.64, r * 0.18), at + Vector2(-r * 0.08, r * 0.64)])
			canvas.draw_colored_polygon(leaf, Color(color, 0.18))
			var outline := PackedVector2Array([leaf[0], leaf[1], leaf[2], leaf[3], leaf[0]])
			canvas.draw_polyline(outline, color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.48, r * 0.46), at + Vector2(r * 0.42, -r * 0.10), faint, t * 0.7, true)
		"pot":
			canvas.draw_line(at + Vector2(-r * 0.68, -r * 0.24), at + Vector2(r * 0.68, -r * 0.24), color, t, true)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(-r * 0.52, -r * 0.12), at + Vector2(-r * 0.42, r * 0.60),
				at + Vector2(r * 0.42, r * 0.60), at + Vector2(r * 0.52, -r * 0.12)]), color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.30, -r * 0.24), at + Vector2(-r * 0.30, -r * 0.48), faint, t * 0.8, true)
			canvas.draw_arc(at + Vector2(-r * 0.38, -r * 0.58), r * 0.12, PI, TAU, 12, faint, t * 0.6, true)
			canvas.draw_arc(at + Vector2(0, -r * 0.62), r * 0.12, PI, TAU, 12, faint, t * 0.6, true)
			canvas.draw_arc(at + Vector2(r * 0.38, -r * 0.58), r * 0.12, PI, TAU, 12, faint, t * 0.6, true)
		"gear":
			canvas.draw_arc(at, r * 0.48, 0, TAU, 40, color, t, true)
			for i in 8:
				var angle := TAU * float(i) / 8.0
				var direction := Vector2(cos(angle), sin(angle))
				canvas.draw_line(at + direction * r * 0.58, at + direction * r * 0.82, color, t * 1.35, true)
			canvas.draw_circle(at, r * 0.17, Color(color, 0.25))
		"flask":
			canvas.draw_line(at + Vector2(-r * 0.26, -r * 0.62), at + Vector2(r * 0.26, -r * 0.62), color, t, true)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(-r * 0.20, -r * 0.62), at + Vector2(-r * 0.20, -r * 0.10),
				at + Vector2(-r * 0.62, r * 0.58), at + Vector2(r * 0.62, r * 0.58),
				at + Vector2(r * 0.20, -r * 0.10), at + Vector2(r * 0.20, -r * 0.62)]), color, t, true)
			canvas.draw_circle(at + Vector2(-r * 0.18, r * 0.30), r * 0.07, Color(color, 0.8))
			canvas.draw_circle(at + Vector2(r * 0.20, r * 0.42), r * 0.05, Color(color, 0.6))
		"cell":
			canvas.draw_arc(at, r * 0.58, 0, TAU, 40, color, t, true)
			canvas.draw_circle(at + Vector2(-r * 0.16, -r * 0.10), r * 0.14, Color(color, 0.55))
			canvas.draw_circle(at + Vector2(r * 0.20, r * 0.16), r * 0.10, Color(color, 0.4))
			canvas.draw_circle(at + Vector2(r * 0.14, -r * 0.28), r * 0.06, Color(color, 0.8))
		"paw":
			canvas.draw_circle(at + Vector2(0, r * 0.18), r * 0.28, Color(color, 0.22))
			canvas.draw_arc(at + Vector2(0, r * 0.18), r * 0.28, 0, TAU, 24, color, t, true)
			canvas.draw_circle(at + Vector2(-r * 0.42, -r * 0.22), r * 0.13, color)
			canvas.draw_circle(at + Vector2(-r * 0.13, -r * 0.46), r * 0.13, color)
			canvas.draw_circle(at + Vector2(r * 0.18, -r * 0.44), r * 0.13, color)
			canvas.draw_circle(at + Vector2(r * 0.44, -r * 0.16), r * 0.13, color)
		"hammer":
			canvas.draw_line(at + Vector2(-r * 0.34, r * 0.66), at + Vector2(r * 0.16, -r * 0.22), color, t * 1.4, true)
			canvas.draw_line(at + Vector2(-r * 0.20, -r * 0.34), at + Vector2(r * 0.60, -r * 0.02), color, t * 2.0, true)
			canvas.draw_line(at + Vector2(-r * 0.28, -r * 0.48), at + Vector2(-r * 0.12, -r * 0.20), faint, t, true)
		"drop":
			var drop := PackedVector2Array([
				at + Vector2(0, -r * 0.72), at + Vector2(r * 0.44, r * 0.10),
				at + Vector2(r * 0.26, r * 0.52), at + Vector2(0, r * 0.68),
				at + Vector2(-r * 0.26, r * 0.52), at + Vector2(-r * 0.44, r * 0.10)])
			canvas.draw_colored_polygon(drop, Color(color, 0.16))
			var drop_outline := PackedVector2Array([drop[0], drop[1], drop[2], drop[3], drop[4], drop[5], drop[0]])
			canvas.draw_polyline(drop_outline, color, t, true)
			canvas.draw_arc(at + Vector2(-r * 0.10, r * 0.24), r * 0.16, 0.5, 2.4, 12, Color(color, 0.7), t * 0.6, true)
		"radio":
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.56, -r * 0.10), Vector2(r * 1.12, r * 0.66)), Color(color, 0.12))
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.56, -r * 0.10), Vector2(r * 1.12, r * 0.66)), color, false, t)
			canvas.draw_line(at + Vector2(r * 0.34, -r * 0.10), at + Vector2(r * 0.62, -r * 0.76), color, t, true)
			canvas.draw_circle(at + Vector2(-r * 0.30, r * 0.18), r * 0.10, Color(color, 0.8))
			canvas.draw_line(at + Vector2(r * 0.02, r * 0.18), at + Vector2(r * 0.42, r * 0.18), faint, t * 0.6, true)
			canvas.draw_arc(at + Vector2(r * 0.62, -r * 0.76), r * 0.18, -1.2, 0.2, 10, faint, t * 0.5, true)
		"chip":
			canvas.draw_rect(Rect2(at - Vector2(r * 0.48, r * 0.48), Vector2(r * 0.96, r * 0.96)), Color(color, 0.10))
			canvas.draw_rect(Rect2(at - Vector2(r * 0.48, r * 0.48), Vector2(r * 0.96, r * 0.96)), color, false, t)
			canvas.draw_rect(Rect2(at - Vector2(r * 0.20, r * 0.20), Vector2(r * 0.40, r * 0.40)), Color(color, 0.3))
			for i in 3:
				var offset := -r * 0.26 + i * r * 0.26
				canvas.draw_line(at + Vector2(offset, -r * 0.48), at + Vector2(offset, -r * 0.72), color, t * 0.7, true)
				canvas.draw_line(at + Vector2(offset, r * 0.48), at + Vector2(offset, r * 0.72), color, t * 0.7, true)
				canvas.draw_line(at + Vector2(-r * 0.48, offset), at + Vector2(-r * 0.72, offset), color, t * 0.7, true)
				canvas.draw_line(at + Vector2(r * 0.48, offset), at + Vector2(r * 0.72, offset), color, t * 0.7, true)
		"eye":
			canvas.draw_arc(at + Vector2(0, r * 0.52), r * 0.86, -2.10, -1.04, 24, color, t, true)
			canvas.draw_arc(at + Vector2(0, -r * 0.52), r * 0.86, 1.04, 2.10, 24, color, t, true)
			canvas.draw_circle(at, r * 0.24, Color(color, 0.22))
			canvas.draw_arc(at, r * 0.24, 0, TAU, 24, color, t, true)
			canvas.draw_circle(at, r * 0.08, color)
		"book":
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(-r * 0.66, -r * 0.44), at + Vector2(-r * 0.05, -r * 0.56),
				at + Vector2(-r * 0.05, r * 0.50), at + Vector2(-r * 0.66, r * 0.62),
				at + Vector2(-r * 0.66, -r * 0.44)]), color, t, true)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(r * 0.66, -r * 0.44), at + Vector2(r * 0.05, -r * 0.56),
				at + Vector2(r * 0.05, r * 0.50), at + Vector2(r * 0.66, r * 0.62),
				at + Vector2(r * 0.66, -r * 0.44)]), color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.46, -r * 0.18), at + Vector2(-r * 0.18, -r * 0.22), faint, t * 0.6, true)
			canvas.draw_line(at + Vector2(-r * 0.46, r * 0.10), at + Vector2(-r * 0.18, r * 0.06), faint, t * 0.6, true)
			canvas.draw_line(at + Vector2(r * 0.18, -r * 0.22), at + Vector2(r * 0.46, -r * 0.18), faint, t * 0.6, true)
		"flame":
			var flame := PackedVector2Array([
				at + Vector2(0, -r * 0.78), at + Vector2(r * 0.38, -r * 0.10),
				at + Vector2(r * 0.46, r * 0.34), at + Vector2(r * 0.12, r * 0.68),
				at + Vector2(-r * 0.28, r * 0.62), at + Vector2(-r * 0.50, r * 0.22),
				at + Vector2(-r * 0.26, -r * 0.20), at + Vector2(-r * 0.10, -r * 0.44)])
			canvas.draw_colored_polygon(flame, Color(color, 0.18))
			var flame_outline := PackedVector2Array([flame[0], flame[1], flame[2], flame[3], flame[4], flame[5], flame[6], flame[7], flame[0]])
			canvas.draw_polyline(flame_outline, color, t, true)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(r * 0.02, -r * 0.08), at + Vector2(r * 0.18, r * 0.26),
				at + Vector2(r * 0.02, r * 0.46), at + Vector2(-r * 0.16, r * 0.24)]), Color(color, 0.8), t * 0.7, true)
		"shield":
			var shield := PackedVector2Array([
				at + Vector2(0, -r * 0.72), at + Vector2(r * 0.62, -r * 0.42),
				at + Vector2(r * 0.50, r * 0.24), at + Vector2(0, r * 0.72),
				at + Vector2(-r * 0.50, r * 0.24), at + Vector2(-r * 0.62, -r * 0.42)])
			canvas.draw_colored_polygon(shield, Color(color, 0.16))
			var shield_outline := PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[5], shield[0]])
			canvas.draw_polyline(shield_outline, color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.24, 0), at + Vector2(-r * 0.04, r * 0.22), color, t * 0.8, true)
			canvas.draw_line(at + Vector2(-r * 0.04, r * 0.22), at + Vector2(r * 0.28, -r * 0.22), color, t * 0.8, true)
		"compass":
			canvas.draw_arc(at, r * 0.66, 0, TAU, 40, color, t, true)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-r * 0.26, r * 0.34), at + Vector2(0, -r * 0.52),
				at + Vector2(r * 0.14, 0.04 * r), at + Vector2(r * 0.26, -r * 0.34),
				at + Vector2(0, r * 0.52)]), Color(color, 0.30))
			canvas.draw_line(at + Vector2(0, -r * 0.52), at + Vector2(0, r * 0.52), color, t * 0.8, true)
			canvas.draw_circle(at, r * 0.08, color)
		"cloud":
			canvas.draw_circle(at + Vector2(-r * 0.26, -r * 0.10), r * 0.28, Color(color, 0.16))
			canvas.draw_arc(at + Vector2(-r * 0.26, -r * 0.10), r * 0.28, 0, TAU, 24, color, t, true)
			canvas.draw_arc(at + Vector2(r * 0.20, -r * 0.22), r * 0.34, 0, TAU, 24, color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.52, r * 0.26), at + Vector2(r * 0.54, r * 0.26), color, t, true)
			for i in 3:
				var x := -r * 0.34 + i * r * 0.34
				canvas.draw_line(at + Vector2(x, r * 0.44), at + Vector2(x - r * 0.10, r * 0.66), faint, t * 0.6, true)
		"spark":
			var star := PackedVector2Array()
			for i in 8:
				var angle := -PI / 2.0 + TAU * float(i) / 8.0
				var distance := r * (0.78 if i % 2 == 0 else 0.24)
				star.append(at + Vector2(cos(angle), sin(angle)) * distance)
			canvas.draw_colored_polygon(star, Color(color, 0.20))
			star.append(star[0])
			canvas.draw_polyline(star, color, t, true)
		"saw":
			canvas.draw_line(at + Vector2(-r * 0.64, -r * 0.34), at + Vector2(r * 0.64, -r * 0.34), color, t * 1.2, true)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(-r * 0.64, -r * 0.10), at + Vector2(-r * 0.44, r * 0.30),
				at + Vector2(-r * 0.24, -r * 0.10), at + Vector2(-r * 0.04, r * 0.30),
				at + Vector2(r * 0.16, -r * 0.10), at + Vector2(r * 0.36, r * 0.30),
				at + Vector2(r * 0.56, -r * 0.10)]), color, t, true)
			canvas.draw_line(at + Vector2(r * 0.30, -r * 0.34), at + Vector2(r * 0.62, -r * 0.72), faint, t, true)
		"bread":
			var loaf := PackedVector2Array()
			for i in 20:
				var angle := PI + PI * float(i) / 19.0
				loaf.append(at + Vector2(cos(angle) * r * 0.66, sin(angle) * r * 0.34 + r * 0.10))
			for i in 20:
				var angle := PI * float(i) / 19.0
				loaf.append(at + Vector2(cos(angle) * r * 0.66, sin(angle) * r * 0.24 + r * 0.50))
			canvas.draw_colored_polygon(loaf, Color(color, 0.16))
			var loaf_outline := loaf.duplicate()
			loaf_outline.append(loaf[0])
			canvas.draw_polyline(loaf_outline, color, t, true)
			for i in 3:
				var x := -r * 0.28 + i * r * 0.28
				canvas.draw_line(at + Vector2(x - r * 0.08, -r * 0.10), at + Vector2(x + r * 0.08, r * 0.10), faint, t * 0.7, true)
		"crate":
			canvas.draw_rect(Rect2(at - Vector2(r * 0.56, r * 0.46), Vector2(r * 1.12, r * 0.92)), Color(color, 0.14))
			canvas.draw_rect(Rect2(at - Vector2(r * 0.56, r * 0.46), Vector2(r * 1.12, r * 0.92)), color, false, t)
			canvas.draw_line(at + Vector2(-r * 0.56, -r * 0.46), at + Vector2(r * 0.56, r * 0.46), faint, t * 0.8, true)
			canvas.draw_line(at + Vector2(r * 0.56, -r * 0.46), at + Vector2(-r * 0.56, r * 0.46), faint, t * 0.8, true)
			canvas.draw_line(at + Vector2(0, -r * 0.46), at + Vector2(0, r * 0.46), Color(color, 0.4), t * 0.5, true)
		"needle":
			canvas.draw_line(at + Vector2(-r * 0.44, r * 0.56), at + Vector2(r * 0.48, -r * 0.60), color, t * 1.2, true)
			canvas.draw_arc(at + Vector2(-r * 0.44, r * 0.56), r * 0.16, 0.4, 3.0, 16, color, t * 0.8, true)
			canvas.draw_circle(at + Vector2(-r * 0.36, r * 0.48), r * 0.05, color)
			canvas.draw_arc(at + Vector2(r * 0.28, r * 0.36), r * 0.40, 3.4, 5.6, 16, Color(color, 0.55), t * 0.6, true)
		"fan":
			for i in 3:
				var angle := -PI / 2.0 + TAU * float(i) / 3.0
				var tip := at + Vector2(cos(angle), sin(angle)) * r * 0.68
				canvas.draw_line(at, tip, color, t * 1.2, true)
				canvas.draw_circle(tip, r * 0.16, Color(color, 0.35))
			canvas.draw_circle(at, r * 0.14, color)
		"truck":
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.64, -r * 0.34), Vector2(r * 0.72, r * 0.50)), Color(color, 0.14))
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.64, -r * 0.34), Vector2(r * 0.72, r * 0.50)), color, false, t)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(r * 0.08, -r * 0.34), at + Vector2(r * 0.40, -r * 0.34),
				at + Vector2(r * 0.62, -r * 0.02), at + Vector2(r * 0.62, r * 0.16),
				at + Vector2(r * 0.08, r * 0.16)]), color, t, true)
			canvas.draw_circle(at + Vector2(-r * 0.36, r * 0.24), r * 0.14, color)
			canvas.draw_circle(at + Vector2(r * 0.34, r * 0.24), r * 0.14, color)
		"bolt":
			var bolt := PackedVector2Array([
				at + Vector2(-r * 0.14, -r * 0.76), at + Vector2(r * 0.50, -r * 0.76),
				at + Vector2(r * 0.08, -r * 0.05), at + Vector2(r * 0.36, -r * 0.05),
				at + Vector2(-r * 0.30, r * 0.78), at + Vector2(-r * 0.10, r * 0.10),
				at + Vector2(-r * 0.42, r * 0.10)])
			canvas.draw_colored_polygon(bolt, Color(color, 0.20))
			var bolt_outline := PackedVector2Array([bolt[0], bolt[1], bolt[2], bolt[3], bolt[4], bolt[5], bolt[6], bolt[0]])
			canvas.draw_polyline(bolt_outline, color, t, true)
		"speech":
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.68, -r * 0.50), Vector2(r * 0.98, r * 0.58)), Color(color, 0.16))
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.68, -r * 0.50), Vector2(r * 0.98, r * 0.58)), color, false, t)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(-r * 0.40, r * 0.08), at + Vector2(-r * 0.48, r * 0.40),
				at + Vector2(-r * 0.14, r * 0.08)]), color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.44, -r * 0.26), at + Vector2(r * 0.06, -r * 0.26), faint, t * 0.6, true)
			canvas.draw_line(at + Vector2(-r * 0.44, -r * 0.06), at + Vector2(r * 0.14, -r * 0.06), faint, t * 0.6, true)
		"wrench":
			canvas.draw_line(at + Vector2(-r * 0.46, r * 0.62), at + Vector2(r * 0.28, -r * 0.26), color, t * 1.5, true)
			canvas.draw_arc(at + Vector2(r * 0.42, -r * 0.44), r * 0.26, 0.2, 5.6, 24, color, t * 1.3, true)
			canvas.draw_line(at + Vector2(-r * 0.46, r * 0.62), at + Vector2(-r * 0.60, r * 0.74), faint, t * 0.8, true)
		"person":
			canvas.draw_circle(at + Vector2(0, -r * 0.40), r * 0.24, Color(color, 0.20))
			canvas.draw_arc(at + Vector2(0, -r * 0.40), r * 0.24, 0, TAU, 24, color, t, true)
			canvas.draw_arc(at + Vector2(0, r * 0.42), r * 0.52, PI, TAU, 24, color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.52, r * 0.42), at + Vector2(-r * 0.52, r * 0.62), color, t, true)
			canvas.draw_line(at + Vector2(r * 0.52, r * 0.42), at + Vector2(r * 0.52, r * 0.62), color, t, true)
		"star":
			var star5 := PackedVector2Array()
			for i in 10:
				var angle := -PI / 2.0 + TAU * float(i) / 10.0
				var distance := r * (0.78 if i % 2 == 0 else 0.34)
				star5.append(at + Vector2(cos(angle), sin(angle)) * distance)
			canvas.draw_colored_polygon(star5, Color(color, 0.18))
			star5.append(star5[0])
			canvas.draw_polyline(star5, color, t, true)
		"case":
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.60, -r * 0.26), Vector2(r * 1.20, r * 0.82)), Color(color, 0.14))
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.60, -r * 0.26), Vector2(r * 1.20, r * 0.82)), color, false, t)
			canvas.draw_arc(at + Vector2(0, -r * 0.26), r * 0.26, PI, TAU, 16, color, t, true)
			canvas.draw_line(at + Vector2(-r * 0.60, r * 0.10), at + Vector2(r * 0.60, r * 0.10), faint, t * 0.7, true)
			canvas.draw_circle(at, r * 0.08, color)
		"note":
			canvas.draw_rect(Rect2(at + Vector2(-r * 0.48, -r * 0.62), Vector2(r * 0.96, r * 1.24)), color, false, t)
			canvas.draw_polyline(PackedVector2Array([
				at + Vector2(r * 0.20, -r * 0.62), at + Vector2(r * 0.48, -r * 0.34),
				at + Vector2(r * 0.48, -r * 0.62)]), color, t * 0.8, true)
			for i in 3:
				var y := -r * 0.18 + i * r * 0.24
				canvas.draw_line(at + Vector2(-r * 0.28, y), at + Vector2(r * 0.28, y), faint, t * 0.6, true)
		_:
			canvas.draw_arc(at, r * 0.56, 0, TAU, 40, color, t, true)
			canvas.draw_circle(at, r * 0.10, color)


static func draw_lock(canvas: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var half := size * 0.5
	canvas.draw_arc(at + Vector2(0, -size * 0.16), size * 0.26, PI, TAU, 20, color, maxf(1.6, size * 0.11), true)
	canvas.draw_line(at + Vector2(-size * 0.26, -size * 0.16), at + Vector2(-size * 0.26, size * 0.02), color, maxf(1.6, size * 0.11), true)
	canvas.draw_line(at + Vector2(size * 0.26, -size * 0.16), at + Vector2(size * 0.26, size * 0.02), color, maxf(1.6, size * 0.11), true)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.22)
	box.border_color = Color(color, 0.85)
	box.set_border_width_all(maxi(1, int(size * 0.06)))
	box.set_corner_radius_all(int(size * 0.14))
	canvas.draw_style_box(box, Rect2(at + Vector2(-half * 0.72, 0), Vector2(size * 0.72, size * 0.56)))
	canvas.draw_circle(at + Vector2(0, size * 0.20), maxf(1.0, size * 0.06), color)
	canvas.draw_line(at + Vector2(0, size * 0.24), at + Vector2(0, size * 0.36), color, maxf(1.2, size * 0.06), true)
