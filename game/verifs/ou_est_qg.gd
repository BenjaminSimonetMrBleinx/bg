# Qui se trouve VRAIMENT dans le bureau de Tuco, et ou.
#
#     godot --headless --path game --script res://verifs/ou_est_qg.gd
#
# Trois hommes ont ete poses le 08/08/2026, et il s'en voit CINQ en jouant :
# deux derriere Tuco et trois contre le mur du fond, dans le dos du joueur. Deux
# viennent donc d'ailleurs, et « ailleurs » ne se devine pas depuis la scene :
# un personnage peut arriver d'un generateur, d'un systeme de foule, ou d'une
# scene instanciee dont on n'a pas lu la liste.
#
# On liste donc TOUT ce qui porte le script de PNJ sous le QG, avec sa position
# et d'ou il vient. C'est le meme principe que verifs/ou_est.gd : on regarde ce
# que la scene contient une fois chargee, pas ce que le fichier dit.
extends SceneTree


func _initialize() -> void:
	var monde := (load("res://scenes/monde.tscn") as PackedScene).instantiate()
	root.add_child(monde)
	await process_frame
	await process_frame

	var qg := monde.find_child("QgInterieur", true, false)
	if qg == null:
		print("ECHEC QgInterieur introuvable")
		quit(1)
		return

	print("")
	print("--- qui est dans le bureau de Tuco ---")
	var trouves: Array = []
	_recenser(qg, qg, trouves)
	for t in trouves:
		print("  %-16s %7.2f %7.2f %7.2f   chemin %s"
				% [t["nom"], t["pos"].x, t["pos"].y, t["pos"].z, t["chemin"]])
	print("")
	print("  %d personnage(s) dans la piece" % trouves.size())

	# Et la foule, qui peut deposer des figurants n'importe ou.
	var foule := monde.find_child("Foule", true, false)
	if foule != null:
		var proches := 0
		for n in foule.get_children():
			if n is Node3D and (n as Node3D).global_position.distance_to(
					(qg as Node3D).global_position) < 30.0:
				proches += 1
		print("  %d figurant(s) de la foule a moins de 30 m du bureau" % proches)
	quit()


func _recenser(n: Node, racine: Node, sortie: Array) -> void:
	var s: Variant = n.get_script()
	if s != null and str(s.resource_path).ends_with("pnj.gd"):
		sortie.append({
			"nom": n.name,
			"pos": (n as Node3D).global_position,
			"chemin": str(racine.get_path_to(n)),
		})
	for e in n.get_children():
		_recenser(e, racine, sortie)
