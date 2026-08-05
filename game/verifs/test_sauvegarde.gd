# Sauvegarder une partie, la recharger, et retrouver exactement le meme etat.
#
#   godot --path game --script res://verifs/test_sauvegarde.gd
#
# CE QUE CE TEST CHERCHE. Une sauvegarde qui ecrit un fichier mais le relit mal
# ne plante pas : elle repart avec un etat presque juste, et c'est le pire cas -
# on ne s'en apercoit qu'en comparant, une partie plus tard. On pose donc un
# etat repere (le critere du ticket : 3 000 $, chapeau sur la tete, 21 h), on
# ecrit, on remet tout a zero, on recharge DEPUIS LE FICHIER, et on verifie que
# chaque chose est revenue a l'identique.
extends SceneTree

const POSE := 30

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	_monde = ps.instantiate()
	root.add_child(_monde)


func _verifier(ok: bool, message: String) -> void:
	if ok:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null


func _process(_d: float) -> bool:
	_n += 1
	if _n != POSE:
		return false
	_scenario()
	return true


func _scenario() -> void:
	var sauvegarde := _trouver(_monde, "Sauvegarde") as Sauvegarde
	var bourse := _trouver(_monde, "Bourse") as Bourse
	var temps := _trouver(_monde, "Temps") as Temps
	var equipement := _trouver(_monde, "Equipement") as Equipement
	var mission := _trouver(_monde, "Mission") as Mission
	var joueur := _trouver(_monde, "Joueur") as Node3D
	if (sauvegarde == null or bourse == null or temps == null
			or equipement == null or mission == null or joueur == null):
		printerr("  ECHEC systemes de sauvegarde introuvables")
		quit(1)
		return

	# Table rase : une sauvegarde d'un run precedent fausserait la mesure.
	sauvegarde.effacer()

	var place := Vector3(300.0, 1.0, 1200.0)
	print("\n--- on pose un etat repere ---")
	bourse.poser(3000)
	temps.regler(21.0)
	equipement.restaurer(["arme", "chapeau"], "arme", ["chapeau"])
	joueur.global_position = place
	mission.reprendre(3, ["Sortir de chez soi"])
	print("       3000 $, 21 h, arme en main, chapeau porte, mission etape 3")

	print("\n--- on ecrit, puis on remet tout a zero ---")
	sauvegarde.sauver()
	_verifier(sauvegarde.existe(), "le fichier de sauvegarde est ecrit")
	bourse.poser(0)
	temps.regler(8.0)
	equipement.restaurer([], "", [])
	joueur.global_position = Vector3.ZERO
	mission.reprendre(0, [])
	_verifier(bourse.montant() == 0 and mission.index() == 0,
			"l'etat en memoire est bien efface avant rechargement")

	print("\n--- on recharge depuis le fichier ---")
	sauvegarde._reprendre_si_possible()

	_verifier(bourse.montant() == 3000,
			"l'argent est revenu (%d $)" % bourse.montant())
	_verifier(absf(Reglages.heure - 21.0) < 0.01,
			"l'heure est revenue (%.2f h)" % Reglages.heure)
	_verifier(equipement.cle_equipee() == "arme",
			"le revolver est de nouveau en main ('%s')" % equipement.cle_equipee())
	_verifier(equipement.porte("chapeau"),
			"le chapeau est de nouveau sur la tete")
	_verifier(joueur.global_position.distance_to(place) < 0.05,
			"la position est revenue (ecart %.3f m)"
			% joueur.global_position.distance_to(place))
	_verifier(mission.index() == 3,
			"la mission est revenue a l'etape %d" % mission.index())

	# On ne laisse pas trainer le fichier du test : il ferait reprendre cette
	# partie repere au prochain vrai lancement.
	sauvegarde.effacer()

	if _erreurs.is_empty():
		print("\nTEST SAUVEGARDE OK")
		quit(0)
	else:
		printerr("\nTEST SAUVEGARDE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
