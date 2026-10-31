extends HBoxContainer
signal item_selected(index: int)
signal caption_pressed
const Style = preload("res://game/scripts/card_style.gd")
var entries: Array = []
var selected := 0
var wrap := true
var disabled := false:
 set(value):
  disabled = value
  if is_instance_valid(previous) and is_instance_valid(next):
   refresh()
var previous: Button
var next: Button
var caption: Label
var caption_frame: PanelContainer

func _init() -> void:
 set_meta("touch_choice", true)
 custom_minimum_size.y = 64
 size_flags_vertical = Control.SIZE_SHRINK_CENTER
 add_theme_constant_override("separation", 6)
 previous = Button.new()
 previous.text = "‹"
 Style.button(previous, true)
 previous.custom_minimum_size.x = 48
 add_child(previous)
 caption_frame = PanelContainer.new()
 caption_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 caption_frame.add_theme_stylebox_override("panel", Style.panel())
 caption_frame.mouse_filter = Control.MOUSE_FILTER_STOP
 caption_frame.gui_input.connect(_on_caption_input)
 add_child(caption_frame)
 caption = Label.new()
 caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 caption.add_theme_font_size_override("font_size", 17)
 caption_frame.add_child(caption)
 next = Button.new()
 next.text = "›"
 Style.button(next, true)
 next.custom_minimum_size.x = 48
 add_child(next)
 previous.pressed.connect(func(): cycle(-1))
 next.pressed.connect(func(): cycle(1))

func _on_caption_input(event: InputEvent) -> void:
 if disabled:
  return
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  caption_pressed.emit()


func add_item(value: String, id: int = -1) -> void:
 entries.append({"text": value, "id": entries.size() if id == -1 else id})
 refresh()

func select(index: int) -> void:
 selected = clampi(index, 0, maxi(0, entries.size() - 1))
 refresh()

func clear() -> void:
 entries.clear()
 selected = 0
 refresh()

func get_selected_id() -> int:
 return -1 if entries.is_empty() else int(entries[selected]["id"])

func cycle(direction: int) -> void:
 if disabled or entries.is_empty():
  return
 select(posmod(selected + direction, entries.size()) if wrap else clampi(selected + direction, 0, entries.size() - 1))
 item_selected.emit(selected)

func refresh() -> void:
 if is_instance_valid(caption):
  caption.text = "—" if entries.is_empty() else str(entries[selected]["text"])
  previous.disabled = disabled or entries.size() < 2 or (not wrap and selected == 0)
  next.disabled = disabled or entries.size() < 2 or (not wrap and selected == entries.size() - 1)
