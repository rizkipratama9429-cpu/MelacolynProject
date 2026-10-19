extends Node3D
## Generates trimesh static colliders for the imported city.
##
## Attach to the instanced city scene. Emissive meshes (the street-lamp glow
## quads) are skipped: they are light fixtures, not geometry, and colliding
## with them would put invisible walls at head height.

@export var verbose := true


func _ready() -> void:
	var generated := 0
	var skipped := 0

	for node in _collect_meshes(self):
		if _is_glow(node):
			skipped += 1
			continue

		var shape := node.mesh.create_trimesh_shape() as ConcavePolygonShape3D
		if shape == null:
			skipped += 1
			continue

		# Parented to the mesh node so it inherits its transform exactly.
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		node.add_child(body)
		generated += 1

	if verbose:
		print("[City] trimesh colliders: %d generated, %d skipped (glow/empty)" % [generated, skipped])


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_collect_meshes(child))
	return found


func _is_glow(node: MeshInstance3D) -> bool:
	var mat := node.material_override as StandardMaterial3D
	if mat == null:
		mat = node.get_surface_override_material(0) as StandardMaterial3D
	if mat == null and node.mesh.get_surface_count() > 0:
		mat = node.mesh.surface_get_material(0) as StandardMaterial3D
	return mat != null and mat.emission_enabled and mat.emission_energy_multiplier > 1.0
