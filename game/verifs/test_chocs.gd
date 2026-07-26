# Les chocs de la voiture.
#
#   godot --path game --script res://verifs/test_chocs.gd
#
# Un detecteur de choc a deux facons de rater, et elles sont opposees :
#
#   - il ne dit rien quand on tape. Le mur arrete la voiture en silence, et on
#     croit que le mecanisme n'existe pas.
#   - il dit tout le temps quelque chose. Un freinage, un dos-d'ane, le simple
#     fait de reposer la caisse au demarrage — et la rue devient une casse.
#
# Le second est le plus dangereux parce qu'il ressemble a un mecanisme qui
# marche. On teste donc les deux sens, et surtout les FAUX POSITIFS.
extends SceneTree

const POSE := 40

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _vehicule: Vehicule
var _controleur: Node
var _chocs: Array = []


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


func _process(_d: float) -> bool:
	_n += 1
	if _n != POSE:
		return false
	_scenario()
	return false


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _scenario() -> void:
	_vehicule = _trouver(_monde, "Vehicule") as Vehicule
	_controleur = _trouver(_monde, "Controleur")
	if _vehicule == null or _controleur == null:
		printerr("  ECHEC Vehicule ou Controleur introuvable")
		quit(1)
		return
	_vehicule.choc.connect(func(f: float) -> void: _chocs.append(f))

	print("\n--- la banque connait les deux familles ---")
	var audio := root.get_tree().get_first_node_in_group(Audio.GROUPE) as Audio
	_verifier(audio != null and audio.connait("choc_leger"), "'choc_leger'")
	_verifier(audio != null and audio.connait("choc_fort"), "'choc_fort'")

	_controleur.call("_monter")
	await _attendre(6)

	# --- FAUX POSITIFS, d'abord. C'est le sens qui compte le plus.
	print("\n--- rouler normalement ne doit rien declencher ---")
	_chocs.clear()
	# Cent images en ligne droite sur la route, gaz a fond puis freinage franc.
	_vehicule.global_position = Vector3(7.0, 0.45, -40.0)
	_vehicule.rotation = Vector3.ZERO
	_vehicule.linear_velocity = Vector3.ZERO
	await _attendre(20)
	_chocs.clear()
	Input.action_press("gaz")
	await _attendre(110)
	Input.action_release("gaz")
	_verifier(_chocs.is_empty(),
			"accelerer en ligne droite : %d choc(s)" % _chocs.size())

	_chocs.clear()
	var v_avant := _vehicule.vitesse_kmh()
	Input.action_press("frein_main")
	await _attendre(40)
	Input.action_release("frein_main")
	print("       freinage de %.0f a %.0f km/h" % [v_avant, _vehicule.vitesse_kmh()])
	_verifier(_chocs.is_empty(),
			"un freinage appuye n'est pas un choc : %d" % _chocs.size())

	# --- LE VRAI CHOC.
	print("\n--- taper un mur doit s'entendre ---")
	_chocs.clear()
	# On lance la voiture DANS une facade. Le premier ilot commence vers
	# x = 17 : on part du milieu de la chaussee et on vise le batiment.
	_vehicule.global_position = Vector3(7.0, 0.45, -40.0)
	_vehicule.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	# On la LANCE au lieu de l'accelerer : le premier ilot n'est qu'a dix
	# metres, et partir a l'arret ne donne pas de quoi taper. Poser la vitesse
	# d'un coup ne compte pas pour un choc — la garde exige d'avoir DEJA roule,
	# et la vitesse precedente est nulle.
	_vehicule.linear_velocity = Vector3(12.0, 0.0, 0.0)
	await _attendre(90)

	_verifier(not _chocs.is_empty(), "le mur a ete entendu (%d choc(s))" % _chocs.size())
	if not _chocs.is_empty():
		var pire := 0.0
		for c in _chocs:
			pire = maxf(pire, float(c))
		print("       plus fort : %.1f m/s perdus d'un coup" % pire)
		var reglages := ResourceLoader.load("res://systemes/reglages.tres") as Reglages
		_verifier(pire >= reglages.choc_seuil,
				"au-dessus du seuil (%.1f)" % reglages.choc_seuil)
		# Le repos empeche qu'un impact unique compte dix fois. Sans lui, un
		# mur pris a soixante en declenchait un par image de contact.
		_verifier(_chocs.size() < 8,
				"le repos evite la rafale (%d, pas des dizaines)" % _chocs.size())

	# --- LA TELEPORTATION, qui a exactement la signature d'un mur.
	print("\n--- une teleportation n'est pas un accident ---")
	_chocs.clear()
	_vehicule.global_position = Vector3(7.0, 0.45, -40.0)
	_vehicule.rotation = Vector3.ZERO
	Input.action_press("gaz")
	await _attendre(60)
	Input.action_release("gaz")
	print("       lancee a %.0f km/h" % _vehicule.vitesse_kmh())
	_chocs.clear()
	_vehicule.ignorer_les_chocs()
	_vehicule.linear_velocity = Vector3.ZERO
	_vehicule.global_position = Vector3(900.0, 0.45, -750.0)
	await _attendre(6)
	_verifier(_chocs.is_empty(),
			"reposer la voiture a l'arret ne fait aucun bruit : %d" % _chocs.size())

	print("")
	if _erreurs.is_empty():
		print("TEST CHOCS OK")
		quit(0)
	else:
		printerr("TEST CHOCS ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
