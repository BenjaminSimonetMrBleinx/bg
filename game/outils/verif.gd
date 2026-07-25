# Verification headless du projet.
#
#   godot --headless --path game --script res://outils/verif.gd
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

	print("")
	if erreurs.is_empty():
		print("VERIF OK")
		quit(0)
	else:
		for e in erreurs:
			printerr("ECHEC  " + e)
		print("VERIF ECHOUEE : %d probleme(s)" % erreurs.size())
		quit(1)
