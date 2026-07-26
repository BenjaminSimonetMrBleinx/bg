# Les trois allures de Walter.
#
#   godot --path game --script res://verifs/test_allures.gd
#
# Trot par defaut, course en maintenant Maj, marche a l'interieur. Trois
# allures qui jouent toutes le meme clip a la meme vitesse ressemblent
# exactement a trois allures qui marchent : on mesure donc l'allure CHOISIE, le
# clip joue, et la distance reellement parcourue.
extends SceneTree

const POSE := 30

var _n := 0
var _erreurs: Array[String] = []
var _monde: Node
var _joueur: Joueur


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


## L'allure et l'animation relevees PENDANT le deplacement, pas apres.
##
## Elles sont lues au milieu de la seconde de mesure : depuis que l'arret
## bascule au repos, les relire une fois la touche relachee ne renvoie plus
## l'allure qu'on croit mesurer.
var _allure_vue := ""
var _anim_vue := ""


# Combien de metres en une seconde, dans la situation demandee.
func _parcourir(sprint: bool, dedans: bool) -> float:
	_joueur.interieur = dedans
		# Au MILIEU de la chaussee, et pas au point de depart : l'Alpine y est
	# garee depuis qu'elle a son lieu nomme, et le joueur demarrait dedans. Il
	# glissait alors contre elle, ce qui donnait exactement la meme distance
	# aux trois allures — un resultat parfaitement stable et parfaitement faux.
	_joueur.global_position = Vector3(8.5, 0.4, -30.0)
	_joueur.rotation = Vector3.ZERO
	_joueur.velocity = Vector3.ZERO
	for i in 12:
		await physics_frame
	var depart := _joueur.global_position
	if sprint:
		Input.action_press("sprint")
	Input.action_press("gaz")
	for i in 60:
		await physics_frame
		if i == 40:
			_allure_vue = _joueur.allure()
			_anim_vue = _joueur.animation()
	Input.action_release("gaz")
	if sprint:
		Input.action_release("sprint")
	return _joueur.global_position.distance_to(depart)


func _scenario() -> void:
	# Sans trafic : une voiture qui vient percuter le joueur pendant la mesure
	# fausse la distance sans rien dire.
	var trafic := _trouver(_monde, "Trafic")
	if trafic != null:
		trafic.free()
	# Sans SCENARIO non plus. La mission fait sonner le telephone cinq secondes
	# apres qu'on met le pied dehors, et un appel entrant bloque le personnage
	# le temps de la conversation — ce qui est le comportement voulu du jeu, et
	# ce qui a rendu ce test rouge de la premiere a la derniere mesure : Walter
	# ne bougeait plus d'un centimetre, le combine a l'oreille.
	var scenario := _trouver(_monde, "Scenario")
	if scenario != null:
		scenario.free()
	_joueur = _trouver(_monde, "Joueur") as Joueur
	if _joueur == null:
		printerr("  ECHEC Joueur introuvable")
		quit(1)
		return

	var reglages := ResourceLoader.load("res://systemes/reglages.tres") as Reglages

	print("\n--- dehors, sans rien : il trottine ---")
	var d_trot := await _parcourir(false, false)
	print("       %.2f m en 1 s, allure '%s', animation '%s'"
			% [d_trot, _allure_vue, _anim_vue])
	_verifier(_allure_vue == "trot", "l'allure par defaut est le trot")
	_verifier(_anim_vue != "", "une animation tourne")

	print("\n--- Maj enfoncee : il court ---")
	var d_course := await _parcourir(true, false)
	print("       %.2f m en 1 s, allure '%s', animation '%s'"
			% [d_course, _allure_vue, _anim_vue])
	_verifier(_allure_vue == "course", "Maj passe a la course")
	_verifier(d_course > d_trot * 1.25,
			"il va nettement plus vite (%.2f m contre %.2f)" % [d_course, d_trot])

	print("\n--- a l'interieur : il marche ---")
	var d_marche := await _parcourir(false, true)
	print("       %.2f m en 1 s, allure '%s', animation '%s'"
			% [d_marche, _allure_vue, _anim_vue])
	_verifier(_allure_vue == "marche", "dedans, il marche")
	_verifier(d_marche < d_trot * 0.9,
			"et plus lentement (%.2f m contre %.2f)" % [d_marche, d_trot])
	# La marche doit jouer un AUTRE clip que la course. C'est le seul des trois
	# controles qui verifie que l'animation suit l'allure et pas seulement la
	# vitesse — sans lui, trois vitesses sur un seul clip passeraient au vert.
	_verifier(_anim_vue != Demarche.COURSE,
			"et pas sur le clip de course ('%s')" % _anim_vue)

	# Maj a l'interieur ne doit RIEN faire : courir dans un salon de sept
	# metres n'a pas de sens, et le laisser faire donne un personnage qui
	# traverse la piece en deux images.
	print("\n--- Maj a l'interieur ne change rien ---")
	var d_dedans_sprint := await _parcourir(true, true)
	_verifier(_allure_vue == "marche", "on marche toujours")
	_verifier(absf(d_dedans_sprint - d_marche) < 0.4,
			"et a la meme vitesse (%.2f contre %.2f)"
					% [d_dedans_sprint, d_marche])

	await _le_repos()
	await _le_saut()
	await _l_accroupissement()

	print("")
	if _erreurs.is_empty():
		print("TEST ALLURES OK")
		quit(0)
	else:
		printerr("TEST ALLURES ECHOUE : %d probleme(s)" % _erreurs.size())
		quit(1)


# Debout, il doit RESPIRER.
#
# C'est le seul controle du fichier qui ne regarde pas une vitesse, et c'est
# celui qui manquait : un personnage fige sur une image de course et un
# personnage au repos sont tous les deux parfaitement immobiles du point de vue
# du moteur. La seule difference se lit dans le SQUELETTE, qui doit continuer a
# bouger alors que le corps ne se deplace plus.
func _le_repos() -> void:
	print("\n--- immobile : il se repose, et il respire ---")
	_joueur.interieur = false
	Input.action_release("gaz")
	for i in 45:
		await physics_frame

	print("       allure '%s', animation '%s'"
			% [_joueur.allure(), _joueur.animation()])
	_verifier(_joueur.allure() == "repos", "a l'arret, il passe au repos")
	_verifier(_joueur.animation() == Demarche.IMMOBILE,
			"sur le clip '%s'" % Demarche.IMMOBILE)

	var os := _joueur.find_child("Skeleton3D", true, false) as Skeleton3D
	if os == null:
		printerr("  ECHEC pas de squelette")
		_erreurs.append("squelette")
		return
	var tete := os.find_bone("Head")
	_verifier(tete >= 0, "l'os de la tete se trouve")
	if tete < 0:
		return

	# La mesure se fait EN METRES, et relativement au joueur.
	#
	# get_bone_global_pose() rend des coordonnees dans le repere du squelette,
	# qui porte l'echelle du modele importe : une premiere version annoncait
	# 672 mm de respiration pour 16 mm reels, et ce nombre invraisemblable est
	# la seule raison pour laquelle l'erreur a ete vue.
	var repere := _joueur.global_transform.affine_inverse()
	var mini := Vector3.INF
	var maxi := -Vector3.INF
	for i in 120:
		await physics_frame
		var p := repere * (os.global_transform * os.get_bone_global_pose(tete).origin)
		mini = mini.min(p)
		maxi = maxi.max(p)
	var amplitude := (maxi - mini).length() * 1000.0
	print("       la tete se deplace de %.1f mm en 2 s" % amplitude)
	_verifier(amplitude > 0.5, "le personnage n'est pas fige (%.1f mm)" % amplitude)
	# Et il ne doit pas gigoter non plus : le repos est discret, sinon on
	# regarde quelqu'un qui a froid et pas quelqu'un qui attend.
	_verifier(amplitude < 60.0, "et il ne gigote pas (%.1f mm)" % amplitude)

	# LE GESTE DOIT ARRIVER. Une fois par cycle, il remonte ses lunettes : la
	# main gauche passe alors AU-DESSUS de l'epaule, ce qu'elle ne fait jamais
	# autrement. On suit dix secondes, soit un cycle complet et de la marge.
	#
	# Ce controle existe parce que le geste etait present dans le fichier,
	# mesure a sept centimetres devant le visage, et INVISIBLE en jeu. Une
	# animation qui existe et une animation qui se joue sont deux choses.
	var main := os.find_bone("LeftHand")
	var epaule := os.find_bone("LeftShoulder")
	if main < 0 or epaule < 0:
		_erreurs.append("os du bras introuvables")
		printerr("  ECHEC os du bras introuvables")
		return
	var plus_haut := -1000.0
	var a_la_seconde := 0.0
	for i in 620:
		await physics_frame
		var h := os.get_bone_global_pose(main).origin.y \
				- os.get_bone_global_pose(epaule).origin.y
		if h > plus_haut:
			plus_haut = h
			a_la_seconde = i / 60.0
	var echelle := os.global_transform.basis.get_scale().y
	print("       la main gauche monte jusqu'a %.1f cm au-dessus de l'epaule, "
			% (plus_haut * echelle * 100.0) + "a la %.1f e seconde" % a_la_seconde)
	_verifier(plus_haut > 0.0,
			"il remonte ses lunettes une fois par cycle")


# Le saut, et surtout : SAUTER EN COURANT PROJETTE EN AVANT.
#
# C'est le seul point qui merite un test. Qu'une impulsion verticale fasse
# monter est difficile a rater ; qu'on garde son elan une fois en l'air, en
# revanche, depend de ce qu'on fait de la vitesse horizontale a chaque image —
# et la recalculer comme au sol arrete net le personnage des qu'on lache la
# commande, suspendu au milieu de son saut.
func _le_saut() -> void:
	print("\n--- le saut ---")
	_joueur.interieur = false
	await _poser()
	var sol := _joueur.global_position.y
	Input.action_press("saut")
	for i in 3:
		await physics_frame
	Input.action_release("saut")
	var plafond := sol
	for i in 70:
		await physics_frame
		plafond = maxf(plafond, _joueur.global_position.y)
	print("       saut sur place : %.2f m de haut" % (plafond - sol))
	_verifier(plafond - sol > 0.35, "il decolle (%.2f m)" % (plafond - sol))

	# Puis le meme saut, en courant, en LACHANT tout des le decollage.
	await _poser()
	var depart := _joueur.global_position
	Input.action_press("gaz")
	for i in 45:
		await physics_frame
	Input.action_press("saut")
	for i in 3:
		await physics_frame
	Input.action_release("saut")
	Input.action_release("gaz")
	var en_l_air := ""
	for i in 40:
		await physics_frame
		if _joueur.allure() == "saut":
			en_l_air = "saut"
	var avancee := Vector2(_joueur.global_position.x - depart.x,
			_joueur.global_position.z - depart.z).length()
	print("       saut en courant : %.2f m parcourus" % avancee)
	_verifier(en_l_air == "saut", "l'allure passe au saut en l'air")
	# Sans conservation de l'elan, il s'arreterait au decollage : la distance
	# se limiterait a celle des trois quarts de seconde de course.
	_verifier(avancee > 3.0, "il avance dans le saut (%.2f m)" % avancee)


func _poser() -> void:
	_joueur.global_position = Vector3(8.5, 0.4, -30.0)
	_joueur.rotation = Vector3.ZERO
	_joueur.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame


func _l_accroupissement() -> void:
	print("\n--- accroupi ---")
	await _poser()
	var haute := (_joueur.get_node("Collision").shape as CapsuleShape3D).height

	Input.action_press("accroupir")
	for i in 20:
		await physics_frame
	var basse := (_joueur.get_node("Collision").shape as CapsuleShape3D).height
	print("       capsule %.2f m -> %.2f m, allure '%s'"
			% [haute, basse, _joueur.allure()])
	_verifier(_joueur.accroupi(), "il s'accroupit")
	# La capsule DOIT suivre. Baisser le modele sans elle ne sert a rien : on
	# bute toujours sur ce sous quoi on vient de se baisser.
	_verifier(basse < haute - 0.3, "et la capsule descend avec lui")

	var avant := _joueur.global_position
	Input.action_press("gaz")
	for i in 60:
		await physics_frame
	var accroupie := _joueur.global_position.distance_to(avant)
	var allure_vue := _joueur.allure()
	Input.action_release("gaz")
	Input.action_release("accroupir")
	for i in 25:
		await physics_frame
	print("       %.2f m en 1 s accroupi, allure '%s'" % [accroupie, allure_vue])
	_verifier(allure_vue == "accroupi_marche", "il se deplace accroupi")
	_verifier(accroupie > 0.4, "il avance vraiment (%.2f m)" % accroupie)
	_verifier(accroupie < 2.2, "et moins vite qu'en marchant (%.2f m)" % accroupie)
	_verifier(not _joueur.accroupi(), "et il se releve en relachant")
	var revenue := (_joueur.get_node("Collision").shape as CapsuleShape3D).height
	_verifier(absf(revenue - haute) < 0.01,
			"la capsule retrouve sa taille (%.2f m)" % revenue)


func _trouver(n: Node, nom: String) -> Node:
	if n.name == nom:
		return n
	for e in n.get_children():
		var t := _trouver(e, nom)
		if t != null:
			return t
	return null
