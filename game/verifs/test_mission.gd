# La premiere mission, jouee de bout en bout sans y jouer.
#
#   godot --path game --script res://verifs/test_mission.gd
#
# CE QUE CE TEST CHERCHE. Une mission de quinze etapes a une facon de casser
# qui lui est propre : elle ne plante pas, elle se BLOQUE. Un objectif dont
# l'evenement ne sera jamais emis, une etape franchie deux fois, un point
# d'interaction accroche a une etape qui n'existe plus — dans les trois cas le
# jeu tourne parfaitement et le joueur reste devant une porte pour toujours.
#
# On deroule donc la mission entiere en annoncant les evenements attendus, et
# on verifie qu'elle arrive au bout. Puis on verifie ce qui ne se voit
# qu'autrement : que chaque cle citee existe vraiment quelque part.
extends SceneTree

const POSE := 30

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node


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
	return true


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null


func _scenario() -> void:
	var mission := _trouver(_monde, "Mission") as Mission
	var bourse := _trouver(_monde, "Bourse") as Bourse
	var dialogue := _trouver(_monde, "Dialogue") as Dialogue
	var equipement := _trouver(_monde, "Equipement") as Equipement
	if mission == null or bourse == null or dialogue == null:
		printerr("  ECHEC systemes de mission introuvables")
		quit(1)
		return

	print("\n--- l'etat de depart ---")
	print("       %s en poche, %d objet(s)"
			% [Bourse.ecrire(bourse.montant()), equipement.nombre()])
	# Le scenario est explicite : entre cent et deux cents dollars, et NI meth
	# NI revolver. Les deux se gagnent pendant la mission, et les avoir des le
	# depart retirerait son sujet a la moitie des etapes.
	_verifier(bourse.montant() >= 100 and bourse.montant() <= 200,
			"on demarre avec %s" % Bourse.ecrire(bourse.montant()))
	_verifier(not equipement.possede("meth"), "sans la meth")
	_verifier(not equipement.possede("arme"), "et sans le revolver")

	_le_depart()
	_qui_dit_quoi(mission)
	_le_deroule(mission)
	_les_cles(mission, dialogue, equipement)
	_la_cachette(mission, bourse)

	print("")
	if _erreurs.is_empty():
		print("TEST MISSION OK")
		quit(0)
	else:
		printerr("TEST MISSION ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


# LA PARTIE COMMENCE DANS LE SALON DE WALTER.
#
# C'est ce que demande le scenario, et ca n'est pas cosmetique : l'homme de
# Tuco appelle cinq secondes apres qu'on est SORTI de chez soi. En demarrant
# dehors, la condition « il est sorti » etait vraie des la premiere image et le
# telephone sonnait avant meme qu'on ait vu la rue.
func _le_depart() -> void:
	print("\n--- on commence chez Walter ---")
	var controleur := _trouver(_monde, "Controleur")
	var joueur := _trouver(_monde, "Joueur") as Node3D
	if controleur == null or joueur == null:
		_erreurs.append("controleur ou joueur introuvable")
		printerr("  ECHEC controleur ou joueur introuvable")
		return
	var dedans: bool = controleur.call("dedans")
	print("       joueur en %s, dedans = %s"
			% [joueur.global_position.round(), dedans])
	_verifier(dedans, "la partie s'ouvre a l'interieur")
	# L'interieur de la maison de Walter est pose loin du centre-ville, vers
	# (-574, 583). Si le joueur est reste en ville, c'est que rien ne l'a
	# deplace et que le drapeau ment.
	_verifier(joueur.global_position.distance_to(Vector3(-574, 0, 583)) < 12.0,
			"et il est bien dans le salon, pas seulement declare dedans")


# Jesse chez lui doit tenir la conversation de la MISSION a l'etape ou l'on
# vient lui parler de la commande, et sa causette habituelle le reste du temps.
#
# C'est exactement ce qui a rate au premier essai en jeu : on recevait l'appel,
# on courait chez lui, et il repondait « Yo » comme si de rien n'etait. La
# mission ne pouvait plus avancer, et rien n'indiquait pourquoi — l'habitant
# porte une cle unique, il disait donc toujours la meme chose.
func _qui_dit_quoi(mission: Mission) -> void:
	print("\n--- Jesse dit ce que la mission attend ---")
	var scenario := _trouver(_monde, "Scenario") as Scenario
	if scenario == null:
		_erreurs.append("scenario introuvable")
		printerr("  ECHEC scenario introuvable")
		return
	mission.recommencer()
	_verifier(scenario.dialogue_pour("jesse") == "jesse",
			"avant l'appel, il tient sa conversation ordinaire")
	mission.evenement("dialogue:mission_tuco_appel")
	_verifier(mission.a_l_etape("parler_jesse"), "l'appel mene chez Jesse")
	_verifier(scenario.dialogue_pour("jesse") == "mission_jesse_maison",
			"et la, il parle de la commande")
	mission.evenement("dialogue:mission_jesse_maison")
	_verifier(scenario.dialogue_pour("jesse") == "jesse",
			"une fois l'etape passee, il redevient lui-meme")
	mission.recommencer()


# On joue la mission en annoncant, etape apres etape, l'evenement qu'elle
# declare attendre. Si elle arrive au bout, c'est qu'aucune etape n'attend
# quelque chose que rien n'emettra jamais.
#
# La derniere etape n'a pas d'evenement dans la table — c'est « argent_cache »,
# emis par la cachette — donc on s'arrete quand la liste est epuisee.
func _le_deroule(mission: Mission) -> void:
	print("\n--- la mission se deroule en entier ---")
	var garde := 0
	while not mission.finie() and garde < 60:
		garde += 1
		var attendu := str(mission.etape().get("valide_par", ""))
		var cle := mission.cle_etape()
		if attendu == "":
			_erreurs.append("l'etape '%s' n'attend aucun evenement" % cle)
			printerr("  ECHEC l'etape '%s' est un cul-de-sac" % cle)
			return
		if not mission.evenement(attendu):
			_erreurs.append("'%s' n'a pas fait avancer '%s'" % [attendu, cle])
			printerr("  ECHEC '%s' ne franchit pas '%s'" % [attendu, cle])
			return
		print("       %-18s <- %s" % [cle, attendu])
	_verifier(mission.finie(), "les %d etapes s'enchainent" % garde)
	# Un evenement de trop ne doit rien faire. Sans ce controle, une mission
	# terminee continuerait d'avancer dans le vide et le telephone afficherait
	# une etape qui n'existe pas.
	_verifier(not mission.evenement("dialogue:mission_jesse_maison"),
			"et plus rien ne bouge une fois finie")


# Chaque cle citee par la mission doit exister QUELQUE PART.
#
# C'est le controle qui rattrape les fautes de frappe. Une conversation
# manquante ne fait rien planter : le personnage est simplement muet, la
# mission ne s'en apercoit jamais, et on cherche pendant vingt minutes
# pourquoi Jesse ne repond pas.
func _les_cles(mission: Mission, dialogue: Dialogue,
		equipement: Equipement) -> void:
	print("\n--- tout ce que la mission nomme existe ---")
	var manquants: Array[String] = []
	for e in mission.etapes():
		var attendu := str((e as Dictionary).get("valide_par", ""))
		if attendu.begins_with("dialogue:"):
			var cle := attendu.substr(9)
			if not dialogue.connait(cle):
				manquants.append("conversation '%s'" % cle)
		elif attendu.begins_with("objet:"):
			var obj := attendu.substr(6)
			# On demande a l'equipement de le DONNER : c'est la seule facon de
			# savoir qu'il est dans outils.json ET que son modele existe.
			if not equipement.donner(obj) and not equipement.possede(obj):
				manquants.append("objet '%s'" % obj)
	for m in manquants:
		printerr("  ECHEC %s introuvable" % m)
		_erreurs.append(m)
	_verifier(manquants.is_empty(),
			"les %d etapes citent des cles qui existent" % mission.etapes().size())

	# Les points d'interaction accroches a une etape : si l'etape n'existe pas,
	# le point ne s'affichera JAMAIS, sans que rien ne le dise.
	var etapes: Array[String] = []
	for e in mission.etapes():
		etapes.append(str((e as Dictionary).get("cle", "")))
	var orphelins := 0
	var points := root.get_tree().get_nodes_in_group("point")
	for n in points:
		var p := n as Point
		if p.etape != "" and not etapes.has(p.etape):
			printerr("  ECHEC le point '%s' attend l'etape '%s', qui n'existe pas"
					% [p.name, p.etape])
			_erreurs.append("point %s" % p.name)
			orphelins += 1
	print("       %d point(s) d'interaction dans le monde" % points.size())
	_verifier(points.size() >= 6, "les points de la mission sont poses")
	_verifier(orphelins == 0, "et aucun n'attend une etape inexistante")


# La regle de la derniere etape : on ne sort pas de chez soi avec plus de dix
# mille dollars. C'est le seul verrou du jeu qui porte sur un NOMBRE, et il
# est facile de le poser a l'envers.
func _la_cachette(mission: Mission, bourse: Bourse) -> void:
	print("\n--- la cachette ---")
	var plafond := mission.reste_maximum()
	bourse.poser(300000)
	var scenario := _trouver(_monde, "Scenario") as Scenario
	if scenario == null:
		printerr("  ECHEC scenario introuvable")
		_erreurs.append("scenario")
		return
	# On se remet a l'etape « cacher » : le refus n'existe qu'a ce moment-la,
	# sinon on ne pourrait plus jamais ressortir de chez soi de toute la partie.
	mission.recommencer()
	while not mission.a_l_etape("cacher") and not mission.finie():
		if not mission.evenement(str(mission.etape().get("valide_par", ""))):
			break
	_verifier(mission.a_l_etape("cacher"), "on atteint la derniere etape")
	_verifier(scenario.refus_de_sortie() != "",
			"avec %s en poche, la porte refuse" % Bourse.ecrire(300000))

	bourse.poser(plafond - 1)
	_verifier(scenario.refus_de_sortie() == "",
			"avec %s, elle s'ouvre" % Bourse.ecrire(plafond - 1))
	print("       plafond : %s" % Bourse.ecrire(plafond))
