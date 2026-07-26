# Le telephone, de la touche a la fin de l'appel.
#
#   godot --path game --script res://verifs/test_telephone.gd
#
# Ce qui se verifie ici n'est visible sur aucune capture : un enchainement
# d'etats declenches par des touches. Un menu qui s'ouvre mais dont la
# selection ne bouge pas, un appel qui sonne dans le vide, une conversation qui
# se termine en laissant le combine a l'ecran — les trois donnent la meme
# image, et aucun ne produit d'erreur.
extends SceneTree

const POSE := 40

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _tel: Telephone
var _dialogue: Dialogue


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


# Une touche pressee doit etre relachee, sinon is_action_just_pressed reste
# vraie toute l'image suivante et le menu saute deux crans.
func _presser(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await physics_frame
	Input.action_release(action)
	await process_frame


func _process(_d: float) -> bool:
	_n += 1
	if _n != POSE:
		return false
	_scenario()
	return false


func _scenario() -> void:
	_tel = _trouver(_monde, "Telephone") as Telephone
	_dialogue = _trouver(_monde, "Dialogue") as Dialogue
	if _tel == null or _dialogue == null:
		printerr("  ECHEC Telephone ou Dialogue introuvable dans la scene")
		quit(1)
		return

	print("\n--- le repertoire ---")
	# Chaque correspondant doit avoir une fiche. Une cle mal orthographiee
	# donne un appel qui sonne et n'aboutit jamais : rien ne le signale.
	var contacts: Array = _tel.contacts()
	_verifier(not contacts.is_empty(), "le repertoire n'est pas vide")
	for c in contacts:
		var cle := str((c as Dictionary).get("cle", ""))
		_verifier(_dialogue.connait(cle),
				"'%s' a une fiche dans dialogues.json" % cle)

	print("\n--- on sort le combine ---")
	_verifier(not _tel.sorti(), "range au depart")
	await _presser("telephone")
	_verifier(_tel.sorti(), "la touche le sort")
	_verifier(_tel.is_visible_in_tree(), "il est visible a l'ecran")

	print("\n--- on navigue ---")
	# Le menu principal n'a qu'une entree : valider entre dans les contacts.
	await _presser("interagir")
	var avant := _tel.selection()
	await _presser("frein")
	_verifier(_tel.selection() != avant,
			"la selection descend (%d -> %d)" % [avant, _tel.selection()])
	await _presser("gaz")
	_verifier(_tel.selection() == avant, "et remonte")

	print("\n--- on appelle ---")
	await _presser("interagir")
	_verifier(_tel.occupe(), "ca sonne")
	_verifier(not _dialogue.actif(),
			"personne ne parle encore : la sonnerie dure")

	# On laisse s'ecouler la sonnerie. Le reglage la fixe ; on attend un peu
	# plus, plutot qu'un nombre d'images devine.
	var reglages := ResourceLoader.load("res://systemes/reglages.tres") as Reglages
	var attente := reglages.telephone_sonnerie + 0.4
	var t := 0.0
	while t < attente:
		await process_frame
		t += root.get_process_delta_time()

	_verifier(not _tel.occupe(), "la sonnerie s'arrete")
	_verifier(_dialogue.actif(), "le correspondant decroche et parle")

	print("\n--- on raccroche ---")
	# On epuise la conversation : elle doit ranger le combine toute seule.
	var garde := 0
	while _dialogue.actif() and garde < 20:
		_dialogue.avancer()
		garde += 1
	await process_frame
	_verifier(not _dialogue.actif(), "la conversation se termine")
	_verifier(not _tel.sorti(),
			"et le combine se range tout seul avec elle")

	print("")
	if _erreurs.is_empty():
		print("TEST TELEPHONE OK")
		quit(0)
	else:
		printerr("TEST TELEPHONE ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
