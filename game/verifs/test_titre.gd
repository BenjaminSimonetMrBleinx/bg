# L'ecran-titre : le bon menu selon qu'une partie existe, et la confirmation
# avant d'ecraser.
#
#   godot --path game --script res://verifs/test_titre.gd
#
# CE QUE CE TEST CHERCHE. Un menu qui propose « Reprendre » sans qu'il y ait
# rien a reprendre envoie sur une partie vide ; un « Nouvelle partie » qui
# efface sans demander perd une soiree de jeu sur un clic. Les deux se voient a
# l'oeil, mais une fois - ici on les verrouille.
extends SceneTree

const POSE := 5

var _n := 0
var _erreurs: Array[String] = []
var _titre: Titre


func _initialize() -> void:
	# Table rase : une sauvegarde trainante fausserait le premier cas.
	if FileAccess.file_exists(Sauvegarde.FICHIER):
		DirAccess.remove_absolute(Sauvegarde.FICHIER)
	var ps := ResourceLoader.load("res://scenes/titre.tscn") as PackedScene
	_titre = ps.instantiate() as Titre
	root.add_child(_titre)


func _verifier(ok: bool, message: String) -> void:
	if ok:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _process(_d: float) -> bool:
	_n += 1
	if _n != POSE:
		return false
	_scenario()
	return true


func _ecrire_une_sauvegarde() -> void:
	var f := FileAccess.open(Sauvegarde.FICHIER, FileAccess.WRITE)
	f.store_string('{"version":1,"argent":100}')
	f.close()


func _scenario() -> void:
	print("\n--- sans sauvegarde ---")
	_titre._reconstruire()
	_verifier(not ("Reprendre" in _titre.options()),
			"pas de « Reprendre » quand il n'y a rien a reprendre")
	_verifier(_titre.options() == ["Nouvelle partie", "Quitter"],
			"le menu est Nouvelle partie / Quitter")

	print("\n--- avec une sauvegarde ---")
	_ecrire_une_sauvegarde()
	_titre._reconstruire()
	_verifier("Reprendre" in _titre.options(),
			"« Reprendre » apparait quand une sauvegarde existe")

	print("\n--- Nouvelle partie demande confirmation ---")
	_titre._choix = _titre.options().find("Nouvelle partie")
	_titre.valider()
	_verifier(_titre.options() == ["Non", "Oui"],
			"« Nouvelle partie » ouvre la confirmation d'ecrasement")

	print("\n--- effacer supprime bien la sauvegarde ---")
	_titre.effacer_sauvegarde()
	_verifier(not FileAccess.file_exists(Sauvegarde.FICHIER),
			"la sauvegarde est supprimee")

	# On ne laisse rien trainer.
	if FileAccess.file_exists(Sauvegarde.FICHIER):
		DirAccess.remove_absolute(Sauvegarde.FICHIER)

	if _erreurs.is_empty():
		print("\nTEST TITRE OK")
		quit(0)
	else:
		printerr("\nTEST TITRE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
