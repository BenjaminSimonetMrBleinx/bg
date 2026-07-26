# Aller au desert, et en revenir.
#
#   godot --path game --script res://verifs/test_desert.gd
#
# Trois choses se verifient ici, et aucune ne se voit sur une image :
#
#   - la zone existe vraiment la ou le passage croit l'envoyer. Une
#     destination fausse depose le joueur dans le vide, il tombe, et le seul
#     symptome est un ecran qui devient bleu.
#   - a pied, on est refuse. Un passage qui laisse passer tout le monde a
#     exactement la meme apparence qu'un passage qui filtre.
#   - en voiture, on arrive POSE. Une masse teleportee garde sa vitesse : elle
#     repart dans le decor a l'arrivee, une seconde apres le fondu, quand plus
#     personne ne regarde le lien de cause a effet.
extends SceneTree

const POSE := 40

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _controleur: Node
var _joueur: Joueur
var _vehicule: Vehicule
var _desert: Node3D


func _initialize() -> void:
	var ps := ResourceLoader.load("res://scenes/monde.tscn") as PackedScene
	_monde = ps.instantiate()
	# ON DEMARRE DEHORS, comme avant la mission.
	#
	# La partie s'ouvre desormais dans le salon de Walter — c'est ce que demande
	# le scenario, l'appel de Tuco arrivant cinq secondes apres qu'on en sort.
	# Ce test-ci mesure autre chose et veut le trottoir. On vide le reglage
	# AVANT d'ajouter la scene a l'arbre : c'est la derniere seconde ou on peut
	# le faire, le controleur le lit dans son _ready.
	var c := _monde.find_child("Controleur", true, false)
	if c != null:
		c.set("commencer_chez", NodePath())
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
		await process_frame


func _scenario() -> void:
	_controleur = _trouver(_monde, "Controleur")
	_joueur = _trouver(_monde, "Joueur") as Joueur
	_vehicule = _trouver(_monde, "Vehicule") as Vehicule
	_desert = _trouver(_monde, "Desert") as Node3D
	for n in [["Controleur", _controleur], ["Joueur", _joueur],
			["Vehicule", _vehicule], ["Desert", _desert]]:
		if n[1] == null:
			printerr("  ECHEC %s introuvable" % n[0])
			quit(1)
			return

	print("\n--- la zone est bien la ---")
	var arrivee: Vector3 = _desert.call("arrivee")
	print("       arrivee attendue %s" % arrivee)
	_verifier(arrivee.distance_to(Vector3.ZERO) > 300.0,
			"le desert est loin de la ville (%.0f m)"
					% arrivee.distance_to(Vector3.ZERO))

	# Il doit y avoir du SOL sous le point d'arrivee. Sans ce controle, une
	# erreur de signe sur l'axe depose le joueur a cote du terrain, et le seul
	# symptome est une chute silencieuse.
	var espace := _joueur.get_world_3d().direct_space_state
	var vers := PhysicsRayQueryParameters3D.create(
			arrivee + Vector3.UP * 6.0, arrivee + Vector3.DOWN * 12.0)
	var touche := espace.intersect_ray(vers)
	_verifier(not touche.is_empty(), "il y a du sol sous le point d'arrivee")
	if not touche.is_empty():
		print("       sol a y = %.2f" % (touche["position"] as Vector3).y)

	var cc := _desert.get_node_or_null("CampingCar")
	_verifier(cc != null, "le camping-car est pose dans la zone")

	# LA MISSION DOIT ETRE ARRIVEE A L'ETAPE DU DESERT.
	#
	# Le passage est desormais ferme tant qu'on n'a pas parle a Jesse : on
	# pouvait auparavant filer au camping-car des la premiere minute et y
	# trouver un Jesse reprochant un retard a une mission pas encore commencee.
	# Ce test-ci ne mesure pas ce verrou, il mesure le voyage — on avance donc
	# la mission jusqu'a l'etape qui ouvre la route, par les memes evenements
	# que le jeu.
	var m := Mission.courante(_monde)
	if m != null:
		m.evenement("dialogue:mission_tuco_appel")
		m.evenement("dialogue:mission_jesse_maison")
		print("       mission a l'etape '%s'" % m.cle_etape())

	print("\n--- a pied, on est refuse ---")
	var zone := _trouver(_monde, "VersDesert").get_node("Zone") as Passage
	_joueur.global_position = zone.global_position + Vector3.DOWN * 0.6
	await _attendre(6)
	var ou_avant := _joueur.global_position
	await _attendre(20)
	_verifier(_joueur.global_position.distance_to(ou_avant) < 12.0,
			"le joueur n'est pas parti au desert")
	var message: String = _controleur.call("bandeau")
	_verifier(message != "", "un bandeau explique pourquoi : « %s »" % message)

	print("\n--- en voiture, on passe ---")
	_joueur.global_position = Vector3(23.5, 0.3, -12.0)
	_vehicule.global_position = zone.global_position + Vector3.DOWN * 0.5
	_vehicule.linear_velocity = Vector3(0.0, 0.0, -14.0)
	# On monte au volant par le meme chemin que le jeu, sinon on testerait un
	# etat que personne n'atteint jamais en jouant.
	_controleur.call("_monter")
	await _attendre(4)
	_verifier(bool(_controleur.call("au_volant")), "on est au volant")

	var garde := 0
	while _vehicule.global_position.distance_to(arrivee) > 30.0 and garde < 260:
		await process_frame
		garde += 1
	_verifier(garde < 260,
			"la voiture est arrivee au desert (%d images)" % garde)
	print("       voiture en %s" % _vehicule.global_position)

	# Elle arrive AU PAS, et c'est un changement voulu.
	#
	# Elle etait reposee a l'arret : on roulait a soixante, l'ecran noircissait,
	# et l'on se retrouvait immobile au milieu d'une piste. Un fondu doit se
	# traverser, pas s'endurer. Elle garde donc un peu d'elan — voir
	# ELAN_A_L_ARRIVEE dans systemes/controleur.gd.
	#
	# Ce qui reste interdit, c'est de garder la vitesse D'AVANT : une masse
	# lancee a soixante qu'on teleporte part dans le decor a l'arrivee, une
	# seconde apres le fondu, quand plus personne ne regarde le lien de cause a
	# effet. La borne haute est donc ce qui compte ici.
	await _attendre(4)
	var elan := _vehicule.linear_velocity.length()
	_verifier(elan < 12.0,
			"elle arrive au pas et non lancee (%.1f m/s)" % elan)
	_verifier(_vehicule.global_position.y > -2.0,
			"elle n'est pas passee sous le terrain (y = %.2f)"
					% _vehicule.global_position.y)

	# LE RETOUR, et c'est le controle qui manquait.
	#
	# On arrive toujours sur ou pres d'une fleche — sinon on ne saurait pas
	# qu'on peut repartir. La zone d'arrivee se redeclenchait donc a l'image
	# suivante et renvoyait d'ou l'on venait, puis recommencait. Le test
	# precedent s'arretait juste avant, et passait au vert.
	print("\n--- on repart, et on RESTE en ville ---")
	var retour := _desert.get_node("RetourVille") as Passage
	_vehicule.global_position = retour.global_position + Vector3.DOWN * 0.5
	_vehicule.linear_velocity = Vector3.ZERO
	garde = 0
	while _vehicule.global_position.distance_to(retour.destination) > 30.0 \
			and garde < 260:
		await process_frame
		garde += 1
	_verifier(garde < 260, "la voiture est revenue en ville (%d images)" % garde)

	# On laisse tourner largement de quoi qu'un rebond se produise.
	var ou_ville := _vehicule.global_position
	await _attendre(90)
	_verifier(_vehicule.global_position.distance_to(arrivee) > 200.0,
			"elle n'est pas repartie toute seule au desert")
	print("       voiture en %s, soit %.0f m du point de retour"
			% [_vehicule.global_position,
			   _vehicule.global_position.distance_to(ou_ville)])

	print("")
	if _erreurs.is_empty():
		print("TEST DESERT OK")
		quit(0)
	else:
		printerr("TEST DESERT ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
