extends RefCounted
static func apply(avatar: Node3D, palette: int, appearance: String = "") -> void:
 var colors := [Color.WHITE, Color("c9ad85"), Color("8398ac")]
 for mesh in avatar.find_children("*", "MeshInstance3D", true, false):
  if "Body" not in mesh.name or mesh.mesh == null:
   continue
  var original: Material = mesh.mesh.surface_get_material(0)
  if original is StandardMaterial3D:
   var material: StandardMaterial3D = original.duplicate()
   material.albedo_color *= colors[clampi(palette, 0, 2)]
   mesh.material_override = material

 # Alternate silver-haired head texture, preserving the original mesh and rig.
 if appearance == "female_senior":
  for mesh in avatar.find_children("*", "MeshInstance3D", true, false):
   if "Rogue_Head" in mesh.name and mesh.mesh != null:
    var original: Material = mesh.mesh.surface_get_material(0)
    if original is StandardMaterial3D:
     var silver: StandardMaterial3D = original.duplicate()
     silver.albedo_texture = preload("res://assets/kaykit/rogue_silver.png")
     mesh.material_override = silver
