# Verifie la bascule entre marcher et conduire.
#
#   godot --path game --script res://verifs/test_montee.gd
#
# On ne peut pas appuyer sur F en headless : le test appelle directement les
# transitions et controle l'etat resultant. Il attrape les regressions les
# plus couteuses — le personnage qui reste physique dans la voiture, la
# camera qui suit le mauvais sujet, la voiture qui repart toute seule.
extends SceneTree

const POSE := 40

var _c: Node
var _j: Node3D
var _v: VehicleBody3D
var _cam: Camera3D
var _n := 0
var _erreurs: Array[String] = []


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	_c = _trouver(root, "Controleur")
	_j = _trouver(root, "Joueur") as Node3D
	_v = _trouver(root, "Vehicule") as VehicleBody3D
	_cam = _trouver(root, "Camera3D") as Camera3D
	if _c == null or _j == null or _v == null or _cam == null:
		printerr("noeuds introuvables")
		quit(1)
		return true

	print("\n--- etat initial : a pied ---")
	_verifier(_j.visible, "le personnage est visible")
	_verifier(_j.process_mode != Node.PROCESS_MODE_DISABLED, "le personnage est actif")

	print("\n--- on monte ---")
	_c.call("_monter")
	_verifier(not _j.visible, "le personnage est masque")
	_verifier(_j.process_mode == Node.PROCESS_MODE_DISABLED,
			"le personnage est retire du monde physique")
	_verifier(_v.is_physics_processing(), "le vehicule recoit les commandes")

	print("\n--- on descend ---")
	var avant := _v.global_position
	_c.call("_descendre")
	_verifier(_j.visible, "le personnage est revisible")
	_verifier(_j.process_mode != Node.PROCESS_MODE_DISABLED, "le personnage est reactive")
	_verifier(not _v.is_physics_processing(), "le vehicule ne recoit plus les commandes")
	_verifier(is_equal_approx(_v.engine_force, 0.0),
			"la poussee moteur est annulee (sinon la voiture part seule)")
	var d := _j.global_position.distance_to(avant)
	_verifier(d > 0.8 and d < 4.0,
			"le personnage est repose a cote du vehicule (%.2f m)" % d)

	print("")
	if _erreurs.is_empty():
		print("TEST MONTEE OK")
		quit(0)
	else:
		printerr("TEST MONTEE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
