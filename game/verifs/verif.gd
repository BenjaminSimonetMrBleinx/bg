# Verification headless du projet.
#
#   godot --headless --path game --script res://verifs/verif.gd
#
# Sort en 0 si tout charge, en 1 sinon. C'est le filet qui garantit qu'un
# commit pousse est au minimum chargeable, meme quand personne n'a ouvert
# l'editeur. Godot en headless n'affiche rien, mais il execute et il rale.
extends SceneTree

const A_VERIFIER := {
	"reglages": "res://systemes/reglages.tres",
	"scene principale": "res://scenes/monde.tscn",
}

func _init() -> void:
	var erreurs: Array[String] = []

	for nom in A_VERIFIER:
		var chemin: String = A_VERIFIER[nom]
		if not ResourceLoader.exists(chemin):
			erreurs.append("%s : introuvable (%s)" % [nom, chemin])
			continue
		var res := ResourceLoader.load(chemin)
		if res == null:
			erreurs.append("%s : echec de chargement (%s)" % [nom, chemin])
		else:
			print("  ok  %-18s %s" % [nom, chemin])

	# Les reglages sont le coeur du dispositif : on verifie le type, pas
	# seulement que le fichier existe.
	var r := ResourceLoader.load("res://systemes/reglages.tres")
	if r != null:
		if not (r is Reglages):
			erreurs.append("reglages.tres n'est pas une ressource Reglages")
		elif r.largeur_rendu <= 0 or r.hauteur_rendu <= 0:
			erreurs.append("resolution de rendu invalide dans reglages.tres")
		else:
			print("  ok  rendu interne     %d x %d" % [r.largeur_rendu, r.hauteur_rendu])

	# La scene principale doit s'instancier, pas seulement se charger.
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	if ps != null:
		var noeud := ps.instantiate()
		if noeud == null:
			erreurs.append("scene principale : instanciation impossible")
		else:
			print("  ok  instanciation    %s" % noeud.name)
			noeud.free()

	# Le joueur, lui, se verifie SEGMENT PAR SEGMENT.
	#
	# Godot degrade en silence : quand l'import du .glb echoue, l'ext_resource
	# de joueur.tscn devient introuvable, le maillage disparait — et la scene
	# se charge quand meme, sans erreur fatale. Le jeu se lance, on marche, on
	# conduit, et le personnage est simplement invisible.
	#
	# C'est arrive. Un .import perime reclamait un PNG que Godot avait extrait
	# du .glb lors d'un import precedent ; un commit a supprime ce PNG, et rien
	# ne l'a signale. Verifier que la scene "charge" ne suffisait pas : on
	# compte donc les os.
	var pj := ResourceLoader.load("res://scenes/joueur.tscn") as PackedScene
	if pj == null:
		erreurs.append("joueur.tscn : echec de chargement")
	else:
		var j := pj.instantiate()
		var manquants: Array[String] = []
		for nom in Silhouette.SEGMENTS:
			if j.find_child(nom, true, false) == null:
				manquants.append(nom)
		if manquants.is_empty():
			print("  ok  personnage       %d segments" % Silhouette.SEGMENTS.size())
		else:
			erreurs.append("personnage : segment(s) absent(s) — %s. Le maillage "
					% ", ".join(manquants)
					+ "ne s'est pas charge. Repare l'import : .\\bg.ps1 reparer")
		j.free()

	# La version doit etre lisible et non nulle. Un numero reste a 0.0.0 parce
	# que personne ne l'a bouge est un numero qui ne sert a rien : autant que la
	# verification le dise plutot que de decouvrir la chose sur une capture
	# d'ecran envoyee par quelqu'un.
	var v := Version.numero()
	if v == "0.0.0" or v == "":
		erreurs.append("version : '%s'. La regler dans project.godot." % v)
	else:
		print("  ok  version          %s" % Version.texte())

	print("")
	if erreurs.is_empty():
		print("VERIF OK")
		quit(0)
	else:
		for e in erreurs:
			printerr("ECHEC  " + e)
		print("VERIF ECHOUEE : %d probleme(s)" % erreurs.size())
		quit(1)
