# Verifie l'orientation vers une direction de marche.
#
#   godot --headless --path game --script res://verifs/test_marche.gd
#
# Le JOUEUR ne s'oriente plus tout seul : gauche et droite le font pivoter a
# la commande. Mais les passants de la rue, eux, se tournent vers leur
# destination, et le pivot de la voiture garee comme celui des PNJ passent
# tous par lacet_vers().
#
# Cette fonction a coute cher. L'avant d'un noeud Godot est -Z, d'ou deux
# negations : sans elles on obtient l'angle oppose, le personnage marche a
# reculons, la camera ancree derriere lui bascule de l'autre cote, ce qui
# inverse la notion d'avant et le fait pivoter encore. Une toupie, pas un
# simple defaut de signe.
extends SceneTree

const DIRECTIONS := [
	Vector3(0, 0, -1),      # l'avant de Godot
	Vector3(0, 0, 1),
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(1, 0, -1),
	Vector3(-0.4, 0, 0.9),
]

var _erreurs: Array[String] = []


func _initialize() -> void:
	pass


func _verifier(ok: bool, message: String) -> void:
	if ok:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _process(_delta: float) -> bool:
	print("--- lacet_vers : l'angle qui fait regarder dans une direction ---")

	for cible in DIRECTIONS:
		var d: Vector3 = (cible as Vector3).normalized()
		var lacet: float = Joueur.lacet_vers(d)

		# On applique l'angle a une base et on verifie que son avant pointe
		# bien vers la direction demandee. Comparer l'angle a une formule
		# reviendrait a verifier la formule contre elle-meme.
		var base := Basis(Vector3.UP, lacet)
		var avant := -base.z
		avant.y = 0.0
		avant = avant.normalized()

		var ecart := rad_to_deg(avant.angle_to(d))
		_verifier(ecart < 0.5,
				"%s -> %.1f deg (ecart %.2f)" % [d, rad_to_deg(lacet), ecart])

	# Un aller-retour doit redonner la meme direction : c'est ce qui garantit
	# qu'aucun signe ne s'est perdu en chemin.
	print("--- aller-retour ---")
	for cible in DIRECTIONS:
		var d: Vector3 = (cible as Vector3).normalized()
		var retour := -Basis(Vector3.UP, Joueur.lacet_vers(d)).z
		retour.y = 0.0
		_verifier(retour.normalized().distance_to(d) < 0.01,
				"%s survit a l'aller-retour" % d)

	print("")
	if _erreurs.is_empty():
		print("TEST MARCHE OK")
		quit(0)
	else:
		printerr("TEST MARCHE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
