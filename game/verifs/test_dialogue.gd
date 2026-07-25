# Verifie les habitants et le deroulement d'une conversation.
#
#   godot --headless --path game --script res://verifs/test_dialogue.gd
#
# Le dialogue lit un fichier JSON. Une virgule en trop et tout le monde
# devient muet, sans qu'aucune autre partie du jeu ne signale quoi que ce
# soit — la maison s'ouvre, le personnage est la, il n'a simplement rien a
# dire. Ce test regarde le contenu reellement charge.
extends SceneTree

const POSE := 45

var _n := 0
var _c: Node
var _d: Node
var _j: CharacterBody3D
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


func _process(_delta: float) -> bool:
	_n += 1
	if _n < POSE:
		return false

	_c = _trouver(root, "Controleur")
	_d = _trouver(root, "Dialogue")
	_j = _trouver(root, "Joueur") as CharacterBody3D
	var racine := _trouver(root, "Maisons")
	if _c == null or _d == null or _j == null or racine == null:
		printerr("noeuds introuvables")
		quit(1)
		return true
	_maisons = racine.get_children()

	print("--- habitants ---")
	for m in _maisons:
		var p = m.habitant()
		_verifier(p != null, "%s a un habitant" % m.nom_affiche)
		if p == null:
			continue
		var nom: String = _d.call("nom_de", p.cle)
		print("       %-8s habitant '%s' (%s)" % [m.nom_affiche, p.cle, nom])
		# Un habitant plante a l'origine de la maison au lieu du repere, c'est
		# le signe que le repere Habitant est perdu, comme l'a ete le Seuil.
		var d: float = p.global_position.distance_to(m.place_habitant())
		_verifier(d < 0.5, "%s : il est bien sur son repere" % m.nom_affiche)
		# Une cle absente du JSON ne se voit qu'en essayant de parler.
		_verifier(_d.call("connait", p.cle),
				"%s : sa cle existe dans dialogues.json" % m.nom_affiche)

	print("--- une conversation ---")
	var pnj = _maisons[0].habitant()
	_verifier(not _d.call("actif"), "aucune conversation au repos")
	_verifier(_d.call("demarrer", pnj.cle), "la conversation s'ouvre")
	_verifier(_d.call("actif"), "elle est marquee active")

	var cadre := _trouver(root, "CadreDialogue") as Control
	_verifier(cadre != null and cadre.visible, "le cadre est affiche")
	var texte := _trouver(root, "Texte") as Label
	_verifier(texte != null and texte.text.length() > 0,
			"une replique est affichee : \"%s\"" % (texte.text if texte else ""))

	# On deroule jusqu'au bout. La borne evite la boucle infinie si avancer()
	# cesse un jour de terminer.
	var tours := 0
	while _d.call("actif") and tours < 40:
		_d.call("avancer")
		tours += 1
	_verifier(tours < 40, "elle se termine (%d repliques)" % tours)
	_verifier(cadre != null and not cadre.visible, "le cadre se referme")

	# Reparler doit donner autre chose : sinon les PNJ radotent, et c'est ce
	# qui fait le plus vite sentir qu'un monde est vide.
	var premiere := texte.text
	_d.call("demarrer", pnj.cle)
	var deuxieme := texte.text
	while _d.call("actif"):
		_d.call("avancer")
	_verifier(premiere != deuxieme,
			"la deuxieme visite dit autre chose (\"%s\")" % deuxieme)

	print("")
	if _erreurs.is_empty():
		print("TEST DIALOGUE OK")
		quit(0)
	else:
		printerr("TEST DIALOGUE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)
	return true
