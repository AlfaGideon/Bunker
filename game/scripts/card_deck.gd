extends VBoxContainer
const Style = preload("res://game/scripts/card_style.gd")
var card_nodes: Array[Control] = []
var eligibility := {}
var pages: Array = []
var page_index := 0
var columns := 2
var page_height := 420.0
var grid: GridContainer
var navigation: HBoxContainer
var previous: Button
var next: Button
var counter: Label
var exit_button: Button
var queued := false

func _init() -> void:
 add_theme_constant_override("separation", 10)
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 grid = GridContainer.new()
 grid.columns = columns
 grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
 grid.add_theme_constant_override("h_separation", 10)
 grid.add_theme_constant_override("v_separation", 10)
 add_child(grid)
 navigation = HBoxContainer.new()
 navigation.add_theme_constant_override("separation", 8)
 add_child(navigation)
 previous = nav_button("← Назад")
 counter = Label.new()
 counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 navigation.add_child(counter)
 next = nav_button("Далее →")
 exit_button = nav_button("В меню")
 exit_button.visible = false
 previous.pressed.connect(func(): turn(-1))
 next.pressed.connect(func(): turn(1))
 resized.connect(schedule)

func nav_button(value: String) -> Button:
 var node := Button.new()
 node.text = value
 Style.button(node, true)
 node.custom_minimum_size.x = 75
 navigation.add_child(node)
 return node

func set_exit(action: Callable) -> void:
 exit_button.visible = true
 exit_button.pressed.connect(action)

func clear_cards() -> void:
 for node in card_nodes:
  if is_instance_valid(node):
   grid.remove_child(node)
   node.queue_free()
 card_nodes.clear()
 eligibility.clear()
 pages.clear()
 page_index = 0
 schedule()

func add_info(value: String, font_size: int = 18) -> void:
 # Long rules become several readable cards, never a clipped giant paragraph.
 var rest := value
 while rest.length() > 320:
  var split := rest.rfind(" ", 320)
  if split < 100:
   split = 320
  add_info_piece(rest.substr(0, split), font_size)
  rest = rest.substr(split).strip_edges()
 add_info_piece(rest, font_size)

func add_info_piece(value: String, font_size: int) -> void:
 var label := Label.new()
 label.text = value
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", font_size)
 add_card(label)

func add_card(control: Control) -> void:
 if control is Label and control.text.length() > 320:
  var remaining: String = control.text
  var split: int = remaining.rfind(" ", 320)
  if split < 100:
   split = 320
  control.text = remaining.substr(0, split)
  add_card(control)
  add_info(remaining.substr(split).strip_edges(), control.get_theme_font_size("font_size"))
  return
 var node: Control = control
 if control is Label:
  var frame := PanelContainer.new()
  frame.add_theme_stylebox_override("panel", Style.panel())
  frame.add_child(control)
  node = frame
  node.set_meta("card_label", control)
 elif control is Button:
  Style.button(control)
 elif control is LineEdit or control is HSlider:
  var frame := PanelContainer.new()
  frame.add_theme_stylebox_override("panel", Style.panel())
  frame.add_child(control)
  frame.custom_minimum_size.y = 80
  node = frame
 node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 grid.add_child(node)
 card_nodes.append(node)
 eligibility[node] = true
 node.minimum_size_changed.connect(schedule)
 schedule()

func set_card_shown(node: Control, value: bool) -> void:
 eligibility[node] = value
 schedule()

func schedule() -> void:
 if queued or not is_inside_tree():
  return
 queued = true
 call_deferred("rebuild")

func _ready() -> void:
 schedule()

func rebuild() -> void:
 queued = false
 grid.columns = columns
 var width := maxf(180, (size.x - 10 * (columns - 1)) / columns)
 var active: Array = []
 for node in card_nodes:
  if is_instance_valid(node) and eligibility.get(node, true):
   active.append(node)
 pages.clear()
 var page: Array = []
 var height := 0.0
 for start in range(0, active.size(), columns):
  var row: Array = active.slice(start, mini(start + columns, active.size()))
  var row_height := 0.0
  for node in row:
   # Wrapped text can report a huge transient native minimum before its
   # first width assignment. Never bake that temporary height into a card.
   var estimate: float = maxf(64, node.custom_minimum_size.y)
   if node.has_meta("touch_choice") and not node.entries.is_empty():
    var caption: String = node.entries[node.selected]["text"]
    estimate = maxf(64, 24 + ceili(caption.length() / maxf(12, (width - 132) / 9)) * 21)
   elif node is GridContainer:
    var rows: int = ceili(float(node.get_child_count()) / node.columns)
    estimate = rows * 52 + maxi(0, rows - 1) * node.get_theme_constant("v_separation")
   if node.has_meta("card_label"):
    var label: Label = node.get_meta("card_label")
    var font: int = label.get_theme_font_size("font_size")
    var lines: int = ceili(float(label.text.length()) / maxf(14, width / (font * 0.57))) + label.text.count("\n")
    estimate = maxf(50, 28 + maxf(1, lines) * (font + 4))
   elif node is Button:
    var lines: int = ceili(float(node.text.length()) / maxf(14, width / 10)) + node.text.count("\n")
    estimate = maxf(72, 24 + maxf(1, lines) * 22)
   node.custom_minimum_size.y = estimate
   row_height = maxf(row_height, estimate)
  if not page.is_empty() and height + row_height + 10 > page_height:
   pages.append(page)
   page = []
   height = 0
  page.append_array(row)
  height += row_height + 10
 if not page.is_empty():
  pages.append(page)
 page_index = clampi(page_index, 0, maxi(0, pages.size() - 1))
 for node in card_nodes:
  var shown: bool = not pages.is_empty() and node in pages[page_index]
  node.visible = shown
  if shown and not node.has_meta("card_entered"):
   node.set_meta("card_entered", true)
   Style.animate(node)
 counter.text = "%d / %d" % [page_index + 1, maxi(1, pages.size())]
 previous.disabled = page_index == 0
 next.disabled = page_index >= pages.size() - 1
 custom_minimum_size.y = page_height + 62

func turn(direction: int) -> void:
 page_index = clampi(page_index + direction, 0, maxi(0, pages.size() - 1))
 rebuild()
 if not pages.is_empty():
  for node in pages[page_index]:
   Style.animate(node)

func show_last() -> void:
 rebuild()
 page_index = maxi(0, pages.size() - 1)
 rebuild()
