# Verifie qu'on entre dans les maisons et qu'on en ressort.
#
#   godot --path game --script res://outils/test_maison.gd
#
# La porte est une teleportation masquee par un fondu : quand elle se trompe,
# elle ne plante pas, elle depose le joueur dans un mur ou dans le vide, et
# l'ecran est noir pendant l'erreur. Rien ne se voit. D'ou ce test, qui
# mesure des positions plutot que de regarder.
extends SceneTree

const POSE := 45
const ATTENTE := 140          # de quoi couvrir les deux moities du fondu

var _n := 0
var _c: Node
var _j: CharacterBody3D
var _maisons: Array = []
var _erreurs: Array[String] = []
var _etape := 0
var _depart: Vector3
var _sol_entree := 0.0


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _verifier(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   " + msg)
	else:
		_erreurs.append(msg)
		printerr("  ECHEC " + msg)


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
	if _n < POSE:
		return false

	if _c == null:
		_c = _trouver(root, "Controleur")
		_j = _trouver(root, "Joueur") as CharacterBody3D
		var racine := _trouver(root, "Maisons")
		if _c == null or _j == null or racine == null:
			printerr("noeuds introuvables")
			quit(1)
			return true
		_maisons = racine.get_children()

		print("--- geometrie ---")
		_verifier(_maisons.size() == 2, "%d maison(s) posees" % _maisons.size())
		for m in _maisons:
			var s: Vector3 = m.seuil()
			var e: Vector3 = m.entree()
			var h: Vector3 = m.place_habitant()
			print("       %-8s seuil %s" % [m.nom_affiche, str(s.round())])
			print("                entree %s   habitant %s"
					% [str(e.round()), str(h.round())])
			# Le seuil doit etre DEVANT la maison, pas sur son origine : c'est
			# le symptome exact du repere perdu a l'export glTF.
			_verifier(s.distance_to(m.global_position) > 2.0,
					"%s : le seuil est bien devant la porte" % m.nom_affiche)
			# L'interieur doit etre hors de la ville, qui s'etend sur 122 m.
			_verifier(e.distance_to(m.global_position) > 300.0,
					"%s : l'interieur est a l'ecart du monde" % m.nom_affiche)
		# Deux interieurs qui se chevauchent, c'est un mur de salon dans
		# l'autre salon — et on ne s'en apercoit qu'en jouant.
		if _maisons.size() == 2:
			var d: float = _maisons[0].entree().distance_to(_maisons[1].entree())
			_verifier(d > 60.0, "les deux interieurs sont separes (%.0f m)" % d)

		print("--- on entre chez Walter ---")
		_depart = _maisons[0].seuil()
		_j.global_position = _depart
		_etape = 1
		_n = 0
		return false

	# Etape 1 : pose sur le seuil, on declenche l'entree.
	if _etape == 1:
		_c.call("_entrer", _maisons[0])
		_etape = 2
		_n = 0
		return false

	if _n < ATTENTE:
		return false

	if _etape == 2:
		var p := _j.global_position
		print("       joueur en %s" % str(p.round()))
		_verifier(p.distance_to(_maisons[0].entree()) < 2.0,
				"le joueur est arrive dans le salon")
		# Le sol de la piece est a l'altitude de la maison : s'il tombe, c'est
		# que la collision de l'interieur n'a pas ete generee.
		_verifier(p.y > _maisons[0].global_position.y - 1.0,
				"il tient sur le sol de la piece (y = %.2f)" % p.y)
		_sol_entree = p.y
		print("--- on ressort ---")
		_c.call("_sortir")
		_etape = 3
		_n = 0
		return false

	if _etape == 3:
		var p := _j.global_position
		print("       joueur en %s" % str(p.round()))
		_verifier(p.distance_to(_depart) < 2.5,
				"il est ressorti devant la bonne porte")
		_verifier(p.y > -1.0, "il n'est pas passe sous la carte (y = %.2f)" % p.y)

	print("")
	if _erreurs.is_empty():
		print("TEST MAISON OK")
		quit(0)
	else:
		printerr("TEST MAISON ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
