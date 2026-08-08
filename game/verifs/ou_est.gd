# Ou se trouvent VRAIMENT les choses dans le camping-car.
#
# Les collisions de mission1.tscn sont posees a la main, la geometrie vient de
# gen_lieux.py : les deux peuvent diverger sans que rien ne le dise. Poser un
# objet d'apres les collisions revient alors a le poser a cote de ce qu'on voit.
#
#     godot --headless --path game --script res://verifs/ou_est.gd
extends SceneTree


func _initialize() -> void:
	var monde := (load("res://scenes/monde.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	await process_frame
	await process_frame

	var cc := monde.find_child("CampingCarInterieur", true, false)
	if cc == null:
		print("CampingCarInterieur introuvable")
		quit()
		return

	print("")
	print("--- le noeud CampingCarInterieur ---")
	print("  position monde  %s" % (cc as Node3D).global_position)

	print("")
	print("--- ce que la GEOMETRIE occupe reellement ---")
	_mesurer(cc)

	print("")
	print("--- les reperes poses a la main ---")
	for nom in ["Verrerie", "Verrerie2", "Atelier", "AtelierLibre", "Marchandise",
			"Sortie", "JesseDedans", "Vapeur"]:
		var n := cc.find_child(nom, true, false)
		if n is Node3D:
			print("  %-14s monde %s" % [nom, (n as Node3D).global_position])

	quit()


# On descend dans les maillages et on imprime l'emprise de chacun, en
# coordonnees MONDE : c'est le seul repere dans lequel une position posee a la
# main veut dire quelque chose.
func _mesurer(racine: Node) -> void:
	var vus: Array[String] = []
	_descendre(racine, vus)


func _descendre(n: Node, vus: Array[String]) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var b := mi.mesh.get_aabb()
			var d := mi.global_transform * b.position
			var f := mi.global_transform * (b.position + b.size)
			var lo := Vector3(minf(d.x, f.x), minf(d.y, f.y), minf(d.z, f.z))
			var hi := Vector3(maxf(d.x, f.x), maxf(d.y, f.y), maxf(d.z, f.z))
			if not vus.has(mi.name):
				vus.append(mi.name)
				print("  %-22s X %6.2f a %6.2f   Y %5.2f a %5.2f   Z %6.2f a %6.2f"
						% [mi.name, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	for e in n.get_children():
		_descendre(e, vus)
