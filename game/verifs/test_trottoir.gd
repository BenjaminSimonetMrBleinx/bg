# Verifie que le personnage monte sur un trottoir au lieu de buter dessus.
#
#   godot --path game --script res://verifs/test_trottoir.gd
#
# CharacterBody3D ne franchit aucune marche par defaut : il glisse le long
# des obstacles verticaux quelle que soit leur hauteur. Une bordure de 18 cm
# bloquait donc net, ce qui est intenable dans une ville ou l'on monte et
# descend des trottoirs en permanence.
extends SceneTree

const POSE := 30
const MARCHE := 200

# Chaussee du couloir 0 : x de 3 a 11, bordure a x = 11, trottoir a y = 0,18.
const DEPART := Vector3(8.6, 0.5, -30.0)
const X_BORDURE := 11.0
const Y_TROTTOIR := 0.18

var _j: CharacterBody3D
var _cam: Camera3D
var _n := 0
var _lance := false
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

	if not _lance:
		_j = _trouver(root, "Joueur") as CharacterBody3D
		_cam = _trouver(root, "Camera3D") as Camera3D
		if _j == null or _cam == null:
			printerr("noeuds introuvables")
			quit(1)
			return true
		_j.global_position = DEPART
		_j.velocity = Vector3.ZERO
		# On oriente la camera pour que "avancer" pointe vers +X, donc vers
		# la bordure. Le cap designe la direction du sujet VERS la camera.
		# On oriente LE PERSONNAGE vers la bordure, pas la camera.
		#
		# Depuis que gauche et droite pivotent au lieu de deplacer, "avancer"
		# suit l'axe du personnage et la camera n'entre plus dans le calcul.
		# Ce test reglait auparavant le cap de la camera, ce qui n'a plus le
		# moindre effet sur la direction prise.
		#
		# L'avant d'un noeud Godot est -Z : un lacet de -90 deg le fait
		# regarder vers +X, donc vers la bordure.
		_j.rotation.y = -PI / 2.0
		_cam.set("_cap", -PI / 2.0)
		# Et on la force a s'y placer d'un coup. Regler le cap ne suffit pas :
		# la camera rejoint sa position en lissage, et "avancer" est calcule a
		# partir de son orientation REELLE, pas du cap voulu. Tant qu'elle est
		# en route, le personnage marche dans une autre direction. Ce test a
		# tenu tant que le point de depart de la partie etait a dix metres
		# d'ici ; en l'eloignant, il s'est mis a echouer sans que le
		# franchissement ait change.
		_cam.set("_initialisee", false)
		Input.action_press("gaz")
		_lance = true
		return false

	if _n < POSE + MARCHE:
		return false

	Input.action_release("gaz")
	var p := _j.global_position

	print("       arrivee %s" % p)
	print("       franchissements %d, dernier refus : %s"
			% [_j.get("franchissements"), _j.call("raison_refus")])
	_verifier(p.x > X_BORDURE + 0.2,
			"a franchi la bordure (x = %.2f)" % p.x)
	_verifier(p.y > Y_TROTTOIR * 0.6,
			"se tient sur le trottoir (y = %.3f)" % p.y)

	print("")
	if _erreurs.is_empty():
		print("TEST TROTTOIR OK")
		quit(0)
	else:
		printerr("TEST TROTTOIR ECHOUE : %d probleme(s)" % _erreurs.size())
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
