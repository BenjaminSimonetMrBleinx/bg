# Verifie que la camera ne traverse plus les murs.
#
#   godot --headless --path game --script res://outils/test_camera_murs.gd
#
# On ne peut pas juger ca a l'oeil sur une capture : la camera est DANS le
# mur, donc l'image montre l'interieur du decor sans qu'aucune erreur ne
# soit levee. La seule verification fiable est un rayon du sujet vers la
# camera : s'il touche quelque chose, la camera est du mauvais cote.
extends SceneTree

const POSE := 40
const STABILISATION := 25

var _n := 0
var _etape := 0
var _cam: Camera3D
var _j: CharacterBody3D
var _c: Node
var _maisons: Array = []
var _erreurs: Array[String] = []


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


# Y a-t-il du decor entre le sujet et la camera ?
func _obstrue() -> Dictionary:
	var regard := _j.global_position + Vector3.UP * 1.2
	var espace := _cam.get_world_3d().direct_space_state
	var requete := PhysicsRayQueryParameters3D.create(regard, _cam.global_position)
	requete.collision_mask = 1
	requete.exclude = [_j.get_rid()]
	return espace.intersect_ray(requete)


func _mesurer(ou: String) -> void:
	var d := _j.global_position.distance_to(_cam.global_position)
	var touche := _obstrue()
	print("       %-22s recul %.2f m, obstacle %s"
			% [ou, d, "OUI" if not touche.is_empty() else "non"])
	_verifier(touche.is_empty(), "%s : rien entre le sujet et la camera" % ou)


func _process(_d: float) -> bool:
	_n += 1

	if _etape == 0:
		if _n < POSE:
			return false
		_cam = _trouver(root, "Camera3D") as Camera3D
		_j = _trouver(root, "Joueur") as CharacterBody3D
		_c = _trouver(root, "Controleur")
		_maisons = _trouver(root, "Maisons").get_children()
		if _cam == null or _j == null or _c == null:
			printerr("noeuds introuvables")
			quit(1)
			return true
		print("--- au depart, a decouvert ---")
		_mesurer("rue degagee")

		# LE cas qui compte, et il doit etre construit expres : le joueur
		# devant la facade, et le cap de la camera tourne vers la maison.
		# La position ideale de la camera tombe alors A L'INTERIEUR du
		# batiment. Une premiere version de ce test se contentait de coller
		# le joueur au mur — la camera restait dehors toute seule, le test
		# passait, et il n'aurait jamais rien detecte.
		print("--- camera pointee vers l'interieur d'un batiment ---")
		var m = _maisons[0]
		_j.global_position = m.seuil() + Vector3(0.0, 0.2, 0.6)
		_j.velocity = Vector3.ZERO
		# On tourne LE PERSONNAGE, pas seulement la camera.
		#
		# La camera se recentre desormais en continu sur son orientation, sans
		# seuil de vitesse : poser un cap a la main serait defait en un
		# dixieme de seconde. Il regarde la rue, la camera est donc derriere
		# lui — c'est-a-dire dans la maison, ce qu'on veut mesurer.
		_j.rotation.y = PI
		_cam.call("recaler")
		_cam.set("_cap", PI)
		_etape = 1
		_n = 0
		return false

	if _etape == 1:
		if _n < STABILISATION:
			return false
		_mesurer("camera vers la facade")
		# Elle doit avoir ete RAMENEE : si le recul est reste au nominal,
		# c'est qu'aucun obstacle n'a ete detecte et la mesure ne prouve rien.
		var recul: float = _j.global_position.distance_to(_cam.global_position)
		_verifier(recul < 3.4,
				"elle s'est rapprochee (%.2f m au lieu de %.1f)"
				% [recul, _cam.reglages.pieton_recul])
		print("--- dans un interieur ---")
		_c.call("_entrer", _maisons[0])
		_etape = 2
		_n = 0
		return false

	if _etape == 2:
		# Le fondu de porte dure, on le laisse finir.
		if _n < 90:
			return false
		_mesurer("dans le salon")
		# Un coin de piece est le pire cas : deux murs a la fois.
		var m = _maisons[0]
		_j.global_position = m.entree() + Vector3(2.6, 0.0, -2.6)
		_j.velocity = Vector3.ZERO
		_cam.call("recaler")
		_etape = 3
		_n = 0
		return false

	if _etape == 3:
		if _n < STABILISATION:
			return false
		_mesurer("dans un coin de piece")
		# Le recul doit rester utilisable : une camera collee a la nuque est
		# aussi injouable qu'une camera dans le mur.
		var d := _j.global_position.distance_to(_cam.global_position)
		_verifier(d > 0.5, "elle ne colle pas a la nuque (%.2f m)" % d)

	print("")
	if _erreurs.is_empty():
		print("TEST CAMERA MURS OK")
		quit(0)
	else:
		printerr("TEST CAMERA MURS ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
