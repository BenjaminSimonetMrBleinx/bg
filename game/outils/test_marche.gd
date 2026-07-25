# Verifie que le personnage s'oriente dans le sens ou il marche, et qu'il s'y
# stabilise.
#
#   godot --path game --script res://outils/test_marche.gd
#
# Ecrit apres un bug ou Walter tournait en boucle : l'angle de lacet etait
# calcule a 180 degres pres, la camera ancree derriere lui basculait, ce qui
# inversait la direction voulue et le faisait pivoter sans fin. Une erreur
# d'orientation devenue une retroaction.
extends SceneTree

const POSE := 40
const ITERATIONS := 240
const DIRECTIONS := [
	Vector3(0, 0, -1),      # nord
	Vector3(1, 0, 0),       # est
	Vector3(0, 0, 1),       # sud
	Vector3(-0.707, 0, -0.707),
]

var _j: Node3D
var _n := 0
var _erreurs: Array[String] = []


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	root.add_child(ps.instantiate())


func _verifier(ok: bool, message: String) -> void:
	if ok:
		print("  ok   " + message)
	else:
		_erreurs.append(message)
		printerr("  ECHEC " + message)


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	_j = _trouver(root, "Joueur") as Node3D
	if _j == null:
		printerr("Joueur introuvable")
		quit(1)
		return true

	for cible in DIRECTIONS:
		var d: Vector3 = cible.normalized()
		# On applique l'orientation en boucle, comme le ferait la marche.
		for i in ITERATIONS:
			_j.call("_orienter", d, 1.0 / 60.0)

		var avant := -_j.global_transform.basis.z
		avant.y = 0.0
		avant = avant.normalized()
		var ecart := rad_to_deg(avant.angle_to(d))
		_verifier(ecart < 2.0,
				"oriente vers %s (ecart %.2f deg)" % [d, ecart])

		# Stabilite : apres convergence, dix pas de plus ne doivent presque
		# rien changer. C'est ce test qui aurait attrape la toupie.
		var av := _j.rotation.y
		for i in 10:
			_j.call("_orienter", d, 1.0 / 60.0)
		var derive := rad_to_deg(absf(angle_difference(av, _j.rotation.y)))
		_verifier(derive < 0.5,
				"reste stable une fois oriente (derive %.3f deg)" % derive)

	print("")
	if _erreurs.is_empty():
		print("TEST MARCHE OK")
		quit(0)
	else:
		printerr("TEST MARCHE ECHOUE : %d probleme(s)" % _erreurs.size())
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
