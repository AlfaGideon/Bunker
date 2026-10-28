extends HBoxContainer
signal item_selected(index: int)
const Style = preload("res://game/scripts/card_style.gd")
var entries: Array = []
var selected := 0
var disabled := false:
 set(value):
  disabled = value
  if is_instance_valid(previous):
   previous.disabled = value
   next.disabled = value
var previous: Button
var next: Button
var caption: Label

func _init() -> void:
 custom_minimum_size.y = 64
 add_theme_constant_override("separation", 6)
 previous = Button.new()
 previous.text = "‹"
 Style.button(previous, true)
 previous.custom_minimum_size.x = 48
 add_child(previous)
 var frame := PanelContainer.new()
 frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 frame.add_theme_stylebox_override("panel", Style.panel())
 add_child(frame)
 caption = Label.new()
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 caption.add_theme_font_size_override("font_size", 17)
 frame.add_child(caption)
 next = Button.new()
 next.text = "›"
 Style.button(next, true)
 next.custom_minimum_size.x = 48
 add_child(next)
 previous.pressed.connect(func(): cycle(-1))
 next.pressed.connect(func(): cycle(1))

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
 select(posmod(selected + direction, entries.size()))
 item_selected.emit(selected)

func refresh() -> void:
 if is_instance_valid(caption):
  caption.text = "—" if entries.is_empty() else str(entries[selected]["text"])
