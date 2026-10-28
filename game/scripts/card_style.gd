extends RefCounted

static func button(node: Button, compact: bool = false) -> void:
 node.set_meta("card_control", true)
 node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 48 if compact else 72)
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_size_override("font_size", 16 if compact else 18)
 var primary := node.text.begins_with("Начать") or node.text.begins_with("Продолжить") or node.text.begins_with("Применить")
 for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
  var box := StyleBoxFlat.new()
  box.bg_color = Color("b58a52") if primary else Color("142f3b")
  if state in ["hover", "focus", "hover_pressed"]:
   box.bg_color = Color("d0a66c") if primary else Color("274c5b")
  if state == "pressed":
   box.bg_color = Color("8c663b") if primary else Color("1c424b")
  if state == "disabled":
   box.bg_color = Color("192a32")
  box.border_color = Color("d7b581") if primary else Color("4b6a75")
  box.set_border_width_all(1)
  box.set_corner_radius_all(12)
  box.content_margin_left = 12
  box.content_margin_right = 12
  box.content_margin_top = 9
  box.content_margin_bottom = 9
  node.add_theme_stylebox_override(state, box)
 node.add_theme_color_override("font_color", Color("192c32") if primary else Color("edf1e8"))
 node.add_theme_color_override("font_disabled_color", Color("82949a"))

static func panel() -> StyleBoxFlat:
 var box := StyleBoxFlat.new()
 box.bg_color = Color("102833")
 box.border_color = Color("3a5965")
 box.set_border_width_all(1)
 box.set_corner_radius_all(12)
 for edge in ["left", "right", "top", "bottom"]:
  box.set("content_margin_" + edge, 12)
 return box

static func animate(node: Control) -> void:
 if not node.is_inside_tree():
  return
 # Respect persisted accessibility preferences everywhere, including dialogs.
 var profile := preload("res://game/scripts/local_profile.gd").new()
 if profile.reduced_motion:
  return
 node.modulate.a = 0.0
 node.create_tween().tween_property(node, "modulate:a", 1.0, 0.22)
