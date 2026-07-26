# Verifie l'equipement et la roue.
#
#   godot --headless --path game --script res://verifs/test_outils.gd
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

## Etape de la sequence d'appuis, qui s'etale sur plusieurs trames.
var _etape := 0
var _depart := 0

## Le rang du chapeau dans la roue, et le plafond de trames qu'on s'accorde
## pour attendre qu'il se pose.
var _chapeau := -1
var _attendre := 0
const ATTENTE := 4000


func _rang_du_chapeau() -> int:
	var n: int = _eq.call("nombre")
	for i in n:
		if str(_eq.call("nom_de", i)) == "Porkpie":
			return i
	return -1


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
	if _etape > 0:
		return _suite()
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
	# LA ROUE MONTRE CE QU'ON POSSEDE, pas le catalogue.
	#
	# Depuis la mission, Walter demarre avec deux objets et gagne les autres en
	# chemin. On donne donc tout ici avant de compter : le sujet de ce test est
	# que chaque objet s'accroche au bon endroit du corps, pas l'inventaire.
	for cle in ["arme", "meth", "botte", "livre", "chapeau"]:
		_eq.call("donner", cle)
	var n: int = _eq.call("nombre")
	_verifier(n >= 4, "%d outil(s) accrochables" % n)

	for i in n:
		var nom: String = _eq.call("nom_de", i)
		# LES OBJETS QU'ON PORTE NE PASSENT PAS PAR LA. Ils ne vont pas en main
		# et n'apparaissent qu'au milieu du geste, une demi-seconde plus tard :
		# les mesurer ici trouvait l'objet PRECEDENT toujours visible et
		# concluait « le Porkpie apparait » alors qu'on regardait le livre.
		if _eq.call("est_porte_par_nature", i):
			print("       %d  %-18s -> se porte, teste plus bas" % [i, nom])
			continue
		_eq.call("equiper", i)
		# On retrouve l'objet visible, quel que soit l'endroit ou il est
		# accroche : c'est justement ce que le fichier de donnees decide.
		var vu := _visible_sous(_j)
		print("       %d  %-18s -> %s" % [i, nom, vu if vu != "" else "RIEN"])
		_verifier(vu != "", "%s apparait sur le personnage" % nom)

	print("--- ancrages ---")
	# Le personnage a maintenant un SQUELETTE, plus une hierarchie de segments
	# nommes. Le point d'accrochage n'est donc plus un noeud « MainD » mais un
	# os « RightHand », et equipement.gd traduit entre les deux.
	#
	# Ce controle exigeait les segments et refusait donc exactement le progres
	# qu'on venait de faire. Il verifie desormais que l'ancrage EXISTE, quel que
	# soit le corps — un objet accroche a un point qui n'existe pas ne se voit
	# nulle part, et rien d'autre ne le signale.
	var squelette := _trouver(_j, "Skeleton3D") as Skeleton3D
	for point in ["MainD", "Tete"]:
		if squelette != null:
			var os := str(Equipement.OS_DU_RIG.get(point, point))
			_verifier(squelette.find_bone(os) >= 0,
					"l'os '%s' existe pour l'ancrage '%s'" % [os, point])
		else:
			_verifier(_trouver(_j, point) != null,
					"le segment '%s' existe sur le personnage" % point)

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

	# La selection se teste sur PLUSIEURS trames.
	#
	# is_action_just_pressed reste vrai jusqu'a la fin de la trame ou la
	# touche a ete enfoncee, meme si on l'a relachee entre-temps. Deux appuis
	# dans la meme trame comptent donc tous les deux pour le premier. Une
	# premiere version de ce test le faisait et concluait que "gauche" ne
	# marchait pas, alors que le fautif etait le test.
	#
	# Le vrai point verifie ici : la roue vit dans le SubViewport, et Godot
	# n'y propage PAS les evenements d'entree. Un _unhandled_input y est
	# silencieusement mort — la roue s'ouvre, s'anime, se ferme, et la
	# selection ne bouge jamais, sans la moindre erreur nulle part.
	_depart = int(_roue.get("_selection"))
	_etape = 1
	Input.action_press("droite")
	return false


func _selection() -> int:
	return int(_roue.get("_selection"))


func _suite() -> bool:
	match _etape:
		1:
			Input.action_release("droite")
			_verifier(_selection() != _depart,
					"droite change la selection (%d -> %d)"
					% [_depart, _selection()])
			_etape = 2
			return false
		2:
			Input.action_press("gauche")
			_etape = 3
			return false
		3:
			Input.action_release("gauche")
			_verifier(_selection() == _depart,
					"gauche revient en arriere (%d)" % _selection())
			_roue.call("fermer", true)
			_verifier(not _roue.call("ouverte"), "elle se ferme")
			_verifier(_eq.call("actif") == _depart,
					"l'outil vise est bien celui qu'on equipe")
			# Un ralenti qui survit a la fermeture est le pire bug de ce
			# genre : tout le jeu devient mou et rien n'indique pourquoi.
			_verifier(is_equal_approx(Engine.time_scale, 1.0),
					"et le temps repart a la vitesse normale")
			print("--- le chapeau se porte ---")
			_chapeau = _rang_du_chapeau()
			if _chapeau < 0:
				_verifier(false, "le chapeau est dans la roue")
				_etape = 9
				return false
			_eq.call("equiper", _chapeau)
			# IL N'EST PAS ENCORE SUR LA TETE, et c'est le comportement voulu :
			# la main doit d'abord y arriver.
			_verifier(not _est_visible("chapeau", _j),
					"il n'apparait pas avant que la main y soit")
			_attendre = ATTENTE
			_etape = 4
			return false
		4:
			# On attend que le port bascule, avec un PLAFOND de trames.
			#
			# Pas un nombre de trames fixe : le minuteur compte des secondes et
			# le mode sans fenetre tourne aussi vite qu'il peut, donc le nombre
			# de trames dans une demi-seconde depend de la machine. Attendre une
			# condition marche partout ; attendre un compteur marche sur la
			# mienne.
			_attendre -= 1
			if _attendre > 0 and not _eq.call("porte", "chapeau"):
				return false
			_verifier(_eq.call("porte", "chapeau"), "il finit sur la tete")
			_verifier(_est_visible("chapeau", _j), "et il se voit")
			# OU EST-IL, EN METRES.
			#
			# « Visible dans l'arbre » ne veut pas dire « sur la tete » : un
			# objet accroche a un os dont l'axe local n'est pas celui qu'on
			# croit part a un metre de la, et l'arbre le declare visible tout
			# du long. La premiere capture montrait un Walter tete nue avec ce
			# meme test au vert.
			var noeud := _noeud("chapeau", _j) as Node3D
			var crane := _hauteur_du_crane()
			var attache := _noeud("Attache_Head", _j) as Node3D
			if attache != null:
				var b := attache.global_transform.basis
				print("       l'os Tete : haut local -> %s, echelle %s"
						% [(b * Vector3.UP).normalized(), b.get_scale()])
			if noeud != null and crane > 0.0:
				var h: float = noeud.global_position.y
				print("       chapeau a %.2f m, sommet du crane a %.2f m, "
						% [h, crane] + "ecart lateral %.2f m"
						% noeud.global_position.distance_to(
								Vector3(_j.global_position.x, h,
										_j.global_position.z)))
				_verifier(absf(h - crane) < 0.12,
						"il est POSE sur le crane (%.2f m contre %.2f m)"
						% [h, crane])
			# ON LE REPREND EN MAIN : un chapeau porte ne doit pas empecher de
			# tenir autre chose. C'est toute la difference avec le reste de la
			# roue, et c'est ce qui se cassait quand les deux etats n'en
			# faisaient qu'un.
			_eq.call("equiper", 0)
			_verifier(_est_visible("chapeau", _j),
					"et il y reste quand on equipe autre chose")
			_eq.call("equiper", _chapeau)
			_attendre = ATTENTE
			_etape = 5
			return false
		5:
			_attendre -= 1
			if _attendre > 0 and _eq.call("porte", "chapeau"):
				return false
			_verifier(not _eq.call("porte", "chapeau"),
					"on l'enleve en le rechoisissant")

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
const RACINES := ["arme", "meth", "botte", "livre", "chapeau"]


# Cet objet-ci est-il visible ? _visible_sous rend le PREMIER trouve, ce qui
# suffit tant qu'un seul objet peut etre affiche a la fois. Le chapeau casse
# cette hypothese : il se porte pendant qu'on tient autre chose, et la question
# n'est plus « lequel voit-on » mais « voit-on celui-la ».
func _est_visible(nom: String, n: Node) -> bool:
	for e in n.get_children():
		if e is Node3D and str(e.name) == nom and (e as Node3D).is_visible_in_tree():
			return true
		if _est_visible(nom, e):
			return true
	return false


# Le noeud lui-meme, pour pouvoir le MESURER et pas seulement le compter.
func _noeud(nom: String, n: Node) -> Node:
	for e in n.get_children():
		if str(e.name) == nom:
			return e
		var t := _noeud(nom, e)
		if t != null:
			return t
	return null


# Le sommet du crane, en metres, lu sur le squelette. C'est la seule reference
# qui vaille : la taille du personnage vient du modele, pas d'une constante.
func _hauteur_du_crane() -> float:
	var s := _trouver(_j, "Skeleton3D") as Skeleton3D
	if s == null:
		return 0.0
	var os := s.find_bone("head_end")
	if os < 0:
		os = s.find_bone("Head")
	if os < 0:
		return 0.0
	return (s.global_transform * s.get_bone_global_pose(os)).origin.y


func _visible_sous(n: Node) -> String:
	for e in n.get_children():
		if e is Node3D and str(e.name) in RACINES \
				and (e as Node3D).is_visible_in_tree():
			return str(e.name)
		var t := _visible_sous(e)
		if t != "":
			return t
	return ""
