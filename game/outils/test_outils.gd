# Verifie l'equipement et la roue.
#
#   godot --headless --path game --script res://outils/test_outils.gd
#
# Un objet mal accroche ne provoque aucune erreur : il est simplement au
# mauvais endroit, ou nulle part. Le jeu tourne, la roue s'ouvre, on choisit,
# et rien n'apparait dans la main. Ce test regarde les noeuds reellement
# accroches et leur parent.
extends SceneTree

const POSE := 45

var _n := 0
var _eq: Node
var _roue: Node
var _j: Node
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


func _process(_d: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	_eq = _trouver(root, "Equipement")
	_roue = _trouver(root, "Roue")
	_j = _trouver(root, "Joueur")
	if _eq == null or _roue == null or _j == null:
		printerr("noeuds introuvables (equipement/roue/joueur)")
		quit(1)
		return true

	print("--- objets ---")
	var n: int = _eq.call("nombre")
	_verifier(n >= 4, "%d outil(s) declares dans outils.json" % n)

	for i in n:
		var nom: String = _eq.call("nom_de", i)
		_eq.call("equiper", i)
		# On retrouve l'objet visible, quel que soit l'endroit ou il est
		# accroche : c'est justement ce que le fichier de donnees decide.
		var vu := _visible_sous(_j)
		print("       %d  %-18s -> %s" % [i, nom, vu if vu != "" else "RIEN"])
		_verifier(vu != "", "%s apparait sur le personnage" % nom)

	print("--- ancrages ---")
	for segment in ["MainD", "Tete"]:
		_verifier(_trouver(_j, segment) != null,
				"le segment '%s' existe sur le personnage" % segment)

	print("--- comportement de la roue ---")
	_eq.call("equiper", 0)
	_verifier(_eq.call("actif") == 0, "on equipe le premier outil")
	# Rechoisir le meme range : sans ca, il n'y a aucun moyen d'avoir les
	# mains vides une fois qu'on a pris quelque chose.
	_eq.call("equiper", 0)
	_verifier(_eq.call("actif") == -1, "le rechoisir range l'objet")
	_verifier(_visible_sous(_j) == "", "et plus rien n'est visible")

	_verifier(not _roue.call("ouverte"), "la roue est fermee au repos")
	_roue.call("ouvrir")
	_verifier(_roue.call("ouverte"), "elle s'ouvre")
	_verifier(not is_equal_approx(Engine.time_scale, 1.0),
			"le temps ralentit (x%.2f)" % Engine.time_scale)
	_roue.call("fermer", true)
	_verifier(not _roue.call("ouverte"), "elle se ferme")
	# Un ralenti qui survit a la fermeture est le pire des bugs de ce genre :
	# tout le jeu devient mou et rien n'indique pourquoi.
	_verifier(is_equal_approx(Engine.time_scale, 1.0),
			"et le temps repart a la vitesse normale")

	print("")
	if _erreurs.is_empty():
		print("TEST OUTILS OK")
		quit(0)
	else:
		printerr("TEST OUTILS ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true


# Nom de l'objet reellement affiche sur le personnage.
#
# Il FAUT is_visible_in_tree() et pas visible : en Godot, visible est local.
# Un maillage garde visible = true sous un parent masque, et une premiere
# version de ce test annoncait donc « le revolver apparait » pour les quatre
# outils, y compris quand on avait les mains vides.
const RACINES := ["arme", "meth", "livre", "chapeau"]


func _visible_sous(n: Node) -> String:
	for e in n.get_children():
		if e is Node3D and str(e.name) in RACINES \
				and (e as Node3D).is_visible_in_tree():
			return str(e.name)
		var t := _visible_sous(e)
		if t != "":
			return t
	return ""
