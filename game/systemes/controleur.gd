# Bascule entre marcher et conduire.
#
# Un seul endroit decide qui recoit les commandes, qui la camera suit, et ce
# que l'invite affiche. Sans ce point unique, l'etat se disperse dans trois
# scripts et finit par se contredire — le personnage qui marche encore alors
# qu'on roule, la camera qui suit le mauvais sujet.
extends Node

@export var reglages: Reglages
## L'interface qui peut s'approprier la touche d'interaction. Facultatif.
@export var service: NodePath
@export var joueur: NodePath
@export var vehicule: NodePath
@export var camera: NodePath
@export var invite: NodePath

## Toutes les maisons de la carte. Le controleur cherche la plus proche a
## chaque image : a deux maisons c'est gratuit, et le jour ou il y en aura
## trente on passera par des zones de detection.
@export var maisons: NodePath

## Rectangle noir plein ecran servant au fondu de porte.
@export var fondu: NodePath

## Joue les ambiances. Facultatif : sans lui on entre quand meme, en silence.
@export var audio: NodePath

## Deroule les conversations. Facultatif : sans lui les habitants sont muets.
@export var dialogue: NodePath

## La roue des outils. Facultative : sans elle, on joue les mains vides.
@export var roue: NodePath

## Le telephone. Facultatif : sans lui, la touche ne fait rien.
@export var telephone: NodePath

## Les passages entre zones. Le controleur les surveille tous, sans savoir
## lequel mene ou : chacun porte sa destination.
@export var passages: Array[NodePath] = []

## Ou l'on arrive dans le desert. Lu sur la zone elle-meme plutot que recopie :
## deux coordonnees ecrites a deux endroits finissent par diverger, et
## celle-ci deposerait le joueur dans le vide.
@export var desert: NodePath

## La mission, et tout ce qu'elle amene. Tous FACULTATIFS : sans eux, le jeu
## reste le bac a sable qu'il etait, ce qui est exactement ce qu'on veut pour
## la moitie des suites de tests.
@export var scenario: NodePath
@export var tir: NodePath
@export var fin_de_partie: NodePath
@export var cachette: NodePath
@export var ecran: NodePath

## Le menu pause. Facultatif : sans lui, Echap ne fait rien de plus que rendre
## la souris, ce qui est le comportement d'avant.
@export var pause: NodePath

var _scenario: Scenario
var _tir: Tir
var _fin: FinDePartie
var _cachette: Cachette
var _pause: Pause
var _ragdoll: Ragdoll

## LA MAISON OU L'ON COMMENCE LA PARTIE.
##
## Le jeu ouvre DANS le salon de Walter, et pas sur le trottoir. C'est ce que
## demande le scenario : l'homme de Tuco appelle cinq secondes apres qu'on est
## SORTI de chez soi. En demarrant dehors, la condition etait vraie des la
## premiere image et le telephone sonnait sur l'ecran de depart — avant meme
## qu'on ait vu la rue.
##
## Vide = on commence dehors, comme avant. C'est ce que font les suites de
## tests qui mesurent des deplacements en ville.
@export var commencer_chez: NodePath

## Ou le joueur reprend quand il recommence. Fige au premier lancement.
var _depart: Transform3D

## Ou l'on ressort apres l'explosion : dehors, pres de la voiture. Ce n'est PAS
## le point de reprise — celui-la est dans le salon, et y teleporter une
## voiture la poserait dans le canape.
var _depart_dehors: Transform3D
var _voiture_dehors: Vector3

## Duree du blanc qui se retire apres l'explosion, en secondes.
const SOUFFLE_RETOUR := 10.0

## VITESSE CONSERVEE EN ARRIVANT DANS UNE NOUVELLE ZONE, en m/s.
##
## On teleportait la voiture a l'arret. On roule a soixante, l'ecran noircit, et
## l'on se retrouve immobile au milieu d'une piste : le voyage s'arrete au lieu
## de continuer, et il faut relancer une masse d'une tonne et demie a chaque
## passage. Un fondu doit se traverser, pas s'endurer.
##
## Six metres par seconde font une vingtaine de km/h — de quoi rouler au sortir
## du noir sans partir dans le decor sur une trajectoire qu'on n'a pas choisie.
const ELAN_A_L_ARRIVEE := 6.0

enum Etat { A_PIED, AU_VOLANT, DEDANS }

var _etat: int = Etat.A_PIED
var _j: Joueur
var _v: Vehicule
var _c: Camera3D
var _invite: Label
var _fondu: ColorRect
var _audio: Audio
var _dialogue: Dialogue
var _roue: Roue
var _equipement: Equipement
var _telephone: Telephone
var _passages: Array[Passage] = []
var _desert: Node3D

## Le passage dont il faut d'abord sortir avant qu'un franchissement redevienne
## possible. Voir _gerer_les_passages : on atterrit sur la fleche du retour.
var _sortie_attendue: Passage = null
var _maisons: Array[Maison] = []

## Le bandeau de refus, et son compte a rebours. On ne le laisse pas colle a
## l'ecran : un message qui reste est un message qu'on ne lit plus.
var _bandeau: float = 0.0
var _texte_bandeau: String = ""

## La maison dans laquelle on se trouve. Nulle des qu'on est dehors.
var _dedans: Maison = null

## Vrai tant que c'est l'ecran de cachette qui immobilise le joueur. Sans ce
## drapeau on le relacherait aussi quand quelqu'un d'autre l'a bloque — un
## dialogue, la roue — et il se remettrait a marcher en pleine conversation.
var _bloque_par_la_cachette: bool = false

## Vrai tant que c'est un GESTE qui immobilise le joueur. Meme raison que
## ci-dessus : sans ce drapeau, on rendrait la main a quelqu'un que le dialogue
## ou la roue venait de bloquer.
var _geste_en_cours: bool = false

## Vrai pendant le fondu. Tant qu'il dure, plus aucune commande ne passe :
## sans ce verrou, un appui repete sur F pendant le noir enchaine deux
## transitions et depose le joueur dans le decor.
var _transition: bool = false


func _ready() -> void:
	_j = get_node_or_null(joueur) as Joueur
	_v = get_node_or_null(vehicule) as Vehicule
	_c = get_node_or_null(camera) as Camera3D
	_invite = get_node_or_null(invite) as Label

	for n in [["joueur", _j], ["vehicule", _v], ["camera", _c]]:
		if n[1] == null:
			push_error("controleur : %s introuvable" % n[0])
			set_process(false)
			return

	_fondu = get_node_or_null(fondu) as ColorRect
	call_deferred("_depart_de_developpement")
	_audio = get_node_or_null(audio) as Audio
	_dialogue = get_node_or_null(dialogue) as Dialogue
	_roue = get_node_or_null(roue) as Roue
	# L'equipement etait retrouve trois fois, a trois endroits, par le meme
	# chemin ecrit a la main. Une fois suffit.
	_equipement = get_node_or_null(NodePath("../Equipement")) as Equipement
	if _equipement != null:
		_equipement.port_demande.connect(_sur_port_demande)
	_telephone = get_node_or_null(telephone) as Telephone
	if _dialogue != null:
		_dialogue.termine.connect(_sur_fin_de_dialogue)
	if _telephone != null:
		_telephone.appel.connect(_sur_appel)
	_desert = get_node_or_null(desert) as Node3D
	for p in passages:
		var n := get_node_or_null(p) as Passage
		if n == null:
			push_error("controleur : passage introuvable (%s)" % p)
			continue
		# Le passage vers le desert n'ecrit pas sa destination : elle vit sur
		# la zone d'arrivee, qui la calcule depuis sa propre position.
		if n.destination == Vector3.ZERO and _desert != null:
			n.destination = _desert.call("arrivee")
			n.cap_degres = _desert.call("cap_arrivee")
		_passages.append(n)
	var racine := get_node_or_null(maisons)
	if racine != null:
		for n in racine.get_children():
			if n is Maison:
				_maisons.append(n as Maison)
		# Les habitants sont crees par la maison, apres son _ready. On leur
		# donne le joueur a surveiller une fois la scene complete.
		call_deferred("_presenter_le_joueur")

	# Souris capturee des le lancement : c'est un jeu a la troisieme personne,
	# le curseur n'y sert a rien. Echap la rend.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_v.quitter_le_volant()
	_c.suivre(_j)
	_c.interieur(false)
	if _fondu != null:
		_fondu.color.a = 0.0
	_afficher("")

	# Le dehors est retenu AVANT d'entrer : c'est la que l'explosion nous
	# recrachera, avec la voiture a cote.
	_depart_dehors = _j.global_transform
	_voiture_dehors = _v.global_position
	_commencer_dedans()
	_depart = _j.global_transform
	_scenario = get_node_or_null(scenario) as Scenario
	_tir = get_node_or_null(tir) as Tir
	_fin = get_node_or_null(fin_de_partie) as FinDePartie
	_cachette = get_node_or_null(cachette) as Cachette
	_pause = get_node_or_null(pause) as Pause
	if _pause != null:
		_pause.recommencer_demande.connect(_sur_recommencer_demande)
	if _tir != null:
		_tir.brancher(_c, _j, _equipement)
	if _fin != null:
		var affichage := get_node_or_null(ecran) as CanvasItem
		if affichage != null:
			_fin.brancher_l_ecran(affichage)
	if _scenario != null:
		_scenario.brancher(_dialogue, _telephone, _tir, _fin, _cachette,
				_equipement)
	# Le ragdoll se construit MAINTENANT, pas a la mort : fabriquer douze corps
	# physiques a l'image precise ou le jeu doit etre le plus lisible se voit.
	var r := Ragdoll.new()
	if r.preparer(_j):
		_ragdoll = r

# UN RACCOURCI DE DEVELOPPEMENT : on demarre ailleurs qu'au debut.
#
#     .g.ps1 jouer -Ou banc
#
# Sert a regarder quelque chose sans refaire le trajet a chaque essai. Le banc
# graphique est au desert, a neuf cents metres : y aller en voiture prend une
# minute, et on le fait vingt fois dans une soiree de reglage.
#
# Ca ne change RIEN a une partie normale : sans l'argument, ce code ne
# s'execute pas.
const DEPARTS := {
	"banc": {"pos": Vector3(825.0, 0.6, -896.0), "cap": 180.0},
	"desert": {"pos": Vector3(874.0, 0.6, -750.0), "cap": 0.0},
	# Devant une porte de maison, trouvee par son habitant. On ne peut pas
	# ecrire ses coordonnees : la ville se regenere, et la maison suit sa
	# parcelle reservee.
	"jesse": {"devant": "Jesse"},
	"walter": {"devant": "Walter"},
	# Au camping-car, face au flanc ou se trouve la porte. On demande sa
	# position au desert plutot que de l'ecrire : c'est tout le sujet du
	# 07/08/2026, ou Jesse et la porte trainaient vingt-neuf metres en arriere
	# parce que deux coordonnees avaient ete recopiees a la main.
	"camping": {"lieu": "camping_car", "ecart": Vector3(0.0, 0.4, 7.0)},
}


func _maison_de(nom: String) -> Node:
	for n in get_tree().get_nodes_in_group("maisons"):
		if str(n.get("nom_affiche")) == nom:
			return n
	return null


func _depart_de_developpement() -> void:
	var args := OS.get_cmdline_user_args()
	var ou := ""
	for i in args.size() - 1:
		if args[i] == "--ou":
			ou = args[i + 1]
	if ou == "" or _j == null:
		return
	if not DEPARTS.has(ou):
		push_warning("controleur : depart '%s' inconnu (%s)"
				% [ou, ", ".join(DEPARTS.keys())])
		return
	var d: Dictionary = DEPARTS[ou]
	sortir_du_batiment()
	if d.has("devant"):
		var maison := _maison_de(str(d["devant"]))
		if maison == null:
			push_warning("controleur : maison '%s' introuvable" % d["devant"])
			return
		# Trois metres devant le seuil, tourne vers la porte.
		var seuil: Vector3 = maison.call("seuil_monde")
		_j.global_position = seuil + Vector3(0.0, 0.4, 3.0)
		_j.velocity = Vector3.ZERO
		_j.rotation.y = PI
		var camd := get_viewport().get_camera_3d()
		if camd != null and camd.has_method("recaler"):
			camd.call("recaler")
		print("controleur : depart de developpement devant chez %s" % d["devant"])
		return
	if d.has("lieu"):
		var desert := Desert.courant(self)
		if desert == null:
			push_warning("controleur : aucun desert dans la scene")
			return
		var p := desert.lieu(str(d["lieu"]))
		if p == Vector3.INF:
			push_warning("controleur : le desert ne publie aucun lieu '%s'"
					% d["lieu"])
			return
		_j.global_position = p + (d.get("ecart", Vector3.UP * 0.4) as Vector3)
		_j.velocity = Vector3.ZERO
		# Cap zero : l'avant d'un noeud Godot est -Z, donc on regarde vers le
		# vehicule pose devant nous.
		_j.rotation.y = 0.0
		var caml := get_viewport().get_camera_3d()
		if caml != null and caml.has_method("recaler"):
			caml.call("recaler")
		print("controleur : depart de developpement au lieu '%s'" % d["lieu"])
		return

	_j.global_position = d["pos"]
	_j.velocity = Vector3.ZERO
	_j.rotation.y = deg_to_rad(float(d["cap"]))
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("recaler"):
		cam.call("recaler")
	print("controleur : depart de developpement '%s'" % ou)



# La souris est lue ICI, et pas dans la camera.
#
# La camera vit dans le SubViewport de rendu, ou Godot ne propage aucune
# entree : un _input y serait silencieusement mort. Le controleur, lui, est
# un noeud ordinaire de la scene principale. C'est exactement le piege qui
# avait rendu la roue des outils inutilisable.
func _unhandled_input(evenement: InputEvent) -> void:
	if _c == null or _transition:
		return

	if evenement is InputEventMouseMotion:
		# Pendant que la roue est ouverte, la souris ne bouge pas la camera :
		# on est en train de viser une part, pas de regarder autour.
		if _roue != null and _roue.ouverte():
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_c.tourner((evenement as InputEventMouseMotion).relative)
		return

	if evenement is InputEventMouseButton and evenement.pressed:
		var bouton := (evenement as InputEventMouseButton).button_index
		if bouton == MOUSE_BUTTON_WHEEL_UP:
			_c.zoomer(1.0)
		elif bouton == MOUSE_BUTTON_WHEEL_DOWN:
			_c.zoomer(-1.0)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
				and not (_pause != null and _pause.ouverte()):
			# Un clic dans la fenetre reprend la main apres un Echap — sauf
			# pendant le menu pause, ou le curseur sert a choisir. Sans cette
			# reserve, le premier clic sur « Options » reprenait la souris et
			# le menu devenait injouable a la main.
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# Echap n'est plus traite ici : il ouvre le MENU PAUSE, qui rend le curseur
	# lui-meme. Il se lisait auparavant a deux endroits — ici pour liberer la
	# souris, et dans l'ecran de cachette pour le refermer — et un troisieme
	# lecteur aurait fini par en manger un autre. Voir _gerer_la_pause.


func _process(delta: float) -> void:
	if _bandeau > 0.0:
		_bandeau = maxf(0.0, _bandeau - delta)
	# L'ecran de fin capte tout : plus rien d'autre ne doit repondre pendant
	# qu'on regarde son personnage par terre.
	if _fin != null and _fin.actif():
		return
	if _gerer_la_pause():
		return
	if _transition:
		return
	if _scenario != null:
		_scenario.traiter(delta)
	if _cachette != null and _cachette.ouverte():
		_afficher("")
		# LE JOUEUR NE MARCHE PAS PENDANT QU'IL COMPTE.
		#
		# L'ecran de cachette regle la somme avec les memes touches que
		# l'avance et le recul. Le controleur s'arretait bien la, mais le
		# personnage lit ses commandes lui-meme, dans sa propre physique :
		# chaque tranche de mille dollars faisait donc un pas en avant, et l'on
		# finissait le reglage dans le mur du salon.
		_j.bloque = true
		_bloque_par_la_cachette = true
		return
	# Refermee, il reprend la main. Ici et pas dans la cachette : c'est le
	# controleur qui possede l'etat du joueur, et deux endroits qui le posent
	# finissent par se contredire.
	if _bloque_par_la_cachette:
		_bloque_par_la_cachette = false
		_j.bloque = false
	if _gerer_les_passages():
		return
	if _gerer_le_telephone():
		return
	# Viser passe AVANT la roue et avant les interactions : une arme au poing,
	# la question n'est plus de savoir si l'on peut ouvrir une porte.
	if _tir != null and _tir.traiter(delta):
		_afficher("")
		return
	if _gerer_la_roue():
		return
	if _gerer_le_geste():
		return

	match _etat:
		Etat.AU_VOLANT:
			# UNE CONVERSATION EN COURS CAPTE LA TOUCHE, au volant comme a pied,
			# comme dans une maison et comme au telephone.
			#
			# C'etait le SEUL des quatre etats a ne pas le faire, et personne ne
			# s'en etait apercu parce qu'aucune conversation ne se declenchait
			# encore en conduisant. Le premier appel pris au volant est reste
			# bloque sur sa premiere replique : F ne faisait rien, sinon essayer
			# de faire descendre Walter de sa voiture.
			if _dialogue != null and _dialogue.actif():
				_afficher("F   Suite")
				if Input.is_action_just_pressed("interagir"):
					_dialogue.avancer()
				return
			_afficher("F   Descendre")
			if Input.is_action_just_pressed("klaxon") and _audio != null:
				_audio.bruit_ici("klaxon", _v.global_position)
			# Les phares se commandent, et seulement au volant : c'est la
			# seule place d'ou l'on peut raisonnablement atteindre un
			# interrupteur de tableau de bord.
			if Input.is_action_just_pressed("phares"):
				_v.basculer_phares()
			# ON NE DESCEND PAS QUAND UNE INTERFACE POSSEDE LA TOUCHE. Decrocher
			# un appel au volant se fait avec F, et F veut aussi dire « sortir de
			# la voiture » : sans cette question, repondre a Skyler ejectait
			# Walter sur le bas-cote. Meme mecanisme que pour le menu pause et la
			# cachette — celui qui possede la touche le dit.
			if Input.is_action_just_pressed("interagir") and not _touche_prise():
				_descendre()

		Etat.DEDANS:
			_dans_la_maison()

		_:
			_a_pied()


# LE MENU PAUSE, sur Echap.
#
# Il ne s'ouvre pas par-dessus n'importe quoi : pendant un fondu de porte on
# est a moitie teleporte, et pendant l'ecran de cachette Echap sert deja a
# refermer. Dans les deux cas, un menu de plus par-dessus donnerait deux
# interfaces qui se disputent la meme touche.
#
# Une fois ouvert, il suspend l'arbre et se pilote tout seul : il tourne en
# PROCESS_MODE_ALWAYS, alors que ce controleur, lui, est suspendu comme le
# reste. C'est ce qui rend le menu sur : rien du jeu ne peut plus repondre.
# Une interface a-t-elle pris la touche d'interaction pour elle ? Facultatif :
# sans ServiceTest cable, personne ne la prend et le jeu se comporte comme avant.
func _touche_prise() -> bool:
	var s := get_node_or_null(service)
	if s == null or not s.has_method("absorbe_la_touche"):
		return false
	return bool(s.call("absorbe_la_touche"))


func _gerer_la_pause() -> bool:
	if _pause == null:
		return false
	if _pause.ouverte():
		return true
	# L'image ou le menu vient de se fermer ne compte pas : la touche qui a
	# valide « Reprendre » est encore enfoncee, et elle vaut « interagir » ici.
	if _pause.vient_de_fermer():
		_afficher("")
		return true
	if _transition or (_cachette != null and _cachette.ouverte()):
		return false
	if Input.is_action_just_pressed("ui_cancel"):
		_pause.ouvrir()
		_afficher("")
		return true
	return false


# UN GESTE EN COURS — se coiffer, lire. Il capte tout le temps qu'il dure.
#
# C'est ici que le joueur est RELACHE, et nulle part ailleurs : le geste peut
# se terminer de deux facons, tout seul ou parce qu'on a bouge, et deux
# endroits qui rendent la main finissent toujours par se contredire. Le
# personnage annule ; le controleur constate et debloque.
func _gerer_le_geste() -> bool:
	if _geste_en_cours:
		if _j.geste_en_cours() != "":
			_afficher("")
			return true
		_geste_en_cours = false
		_j.bloque = false
	elif _j.geste_en_cours() != "":
		_geste_en_cours = true
		return true
	return false


# Mettre et enlever jouent LE MEME clip. Le geste est le meme : la main monte
# au crane et redescend. Ce qui differe, c'est ce qui se passe a mi-parcours,
# et l'equipement s'en charge tout seul.
func _sur_port_demande(_cle: String, _mettre: bool) -> void:
	if _j.geste("coiffer") <= 0.0:
		return
	_j.bloque = true
	if _audio != null and _audio.connait("objet_chapeau"):
		_audio.bruit("objet_chapeau")
	_afficher("")


# Renvoie vrai si la roue a pris la main : elle capte alors gauche et droite,
# qui servent a choisir. Sans ce court-circuit, Walter marcherait de cote
# pendant qu'on tourne la roue.
func _gerer_la_roue() -> bool:
	if _roue == null:
		return false

	if _roue.ouverte():
		_afficher("")
		# On valide au RELACHEMENT, pas a l'appui : c'est ce qui fait de la
		# roue un geste continu plutot qu'un menu ou l'on entre et d'ou l'on
		# sort. On garde la touche, on vise, on lache.
		if Input.is_action_just_released("roue"):
			_roue.fermer(true)
			_j.bloque = false
		return true

	var occupe := _dialogue != null and _dialogue.actif()
	if not occupe and Input.is_action_just_pressed("roue"):
		_roue.ouvrir()
		if _roue.ouverte():
			_j.bloque = true
			return true
	return false


# Franchir un passage.
#
# On regarde le corps qui MENE : la voiture quand on conduit, le personnage
# sinon. Ce n'est pas un detail — au volant, le joueur est desactive et retire
# du monde physique, donc il n'entre dans aucune zone. Un declencheur branche
# sur lui ne se serait jamais declenche, et rien ne l'aurait signale.
func _gerer_les_passages() -> bool:
	if _etat == Etat.DEDANS:
		return false
	var au_volant := _etat == Etat.AU_VOLANT
	var corps: Node3D = _v if au_volant else _j

	# On arrive TOUJOURS dans une zone, ou juste a cote : la fleche du retour
	# est posee sur le point d'arrivee, sinon on ne saurait pas qu'on peut
	# repartir. Sans ce verrou, le passage se redeclenche a l'image suivante et
	# renvoie d'ou l'on vient — puis recommence, indefiniment.
	#
	# Un simple delai n'aurait pas suffi : a l'arret sur la fleche, il expire
	# et on repart. Il faut EN SORTIR, ce qui est aussi la regle qu'un joueur
	# comprend sans qu'on la lui dise.
	if _sortie_attendue != null:
		# On la relache quand on en est SORTI, et rien de plus.
		#
		# La marge d'arrivee ne sert qu'a POSER le verrou, pas a le lever :
		# l'appliquer ici aussi obligeait a s'eloigner de dix metres avant de
		# pouvoir repartir, alors que la fleche du retour est justement posee
		# sur le point d'arrivee. On ne pouvait plus quitter le desert.
		if _sortie_attendue.contient(corps):
			return false
		_sortie_attendue = null

	for p in _passages:
		if not p.contient(corps):
			continue
		# Un passage encore ferme par le scenario. On le DIT : un decor qu'on
		# traverse sans effet donne l'impression d'un bug, alors qu'une phrase
		# transforme le mur en consigne.
		if p.etape_minimale != "":
			var m := Mission.courante(self)
			if m != null and not m.passee(p.etape_minimale) \
					and not m.a_l_etape(p.etape_minimale):
				if p.refus_etape != "" and (_texte_bandeau != p.refus_etape
						or _bandeau <= 0.0):
					annoncer(p.refus_etape)
				return false
		if p.exige_vehicule and not au_volant:
			# On refuse, et on le dit UNE FOIS. Sans ce garde le bandeau se
			# reposerait a chaque image tant qu'on reste sur la fleche, et son
			# compte a rebours ne s'ecoulerait jamais.
			if _texte_bandeau != p.refus or _bandeau <= 0.0:
				_texte_bandeau = p.refus
				_bandeau = reglages.bandeau_duree
			return false
		_franchir(p, au_volant)
		return true
	return false


# Le fondu, puis on deplace. La voiture emmene le joueur avec elle : il est
# dedans, donc il n'a pas de position propre a corriger — mais la camera, si.
func _franchir(p: Passage, au_volant: bool) -> void:
	_transition = true
	_afficher("")
	_bandeau = 0.0
	await _noircir(1.0)

	if au_volant:
		# Une masse lancee a soixante qu'on teleporte garde sa vitesse et part
		# dans le decor a l'arrivee. On la repose a l'arret, dans le bon sens.
		# Et on la rend sourde un instant : passer de soixante a zero en une
		# image est exactement la signature d'un mur.
		_v.ignorer_les_chocs()
		_v.linear_velocity = Vector3.ZERO
		_v.angular_velocity = Vector3.ZERO
		_v.global_position = p.destination
		_v.rotation = Vector3(0.0, p.cap(), 0.0)
		# Et on la relance doucement dans le sens ou elle regarde. L'avant d'un
		# noeud Godot est -Z ; la reposer a zero faisait sortir le joueur du
		# fondu a l'arret, moteur eteint, au milieu de nulle part.
		_v.linear_velocity = -_v.global_transform.basis.z * ELAN_A_L_ARRIVEE
	else:
		_j.global_position = p.destination
		_j.velocity = Vector3.ZERO
		_j.rotation.y = p.cap()

	_c.recaler()
	await get_tree().physics_frame

	# La zone d'arrivee est celle dont il faudra sortir. On la cherche APRES le
	# deplacement : c'est seulement la qu'on sait ou l'on a atterri, et c'est
	# souvent le passage du retour, pose expres sur le point d'arrivee.
	# On cherche la zone qui nous CONTIENT, et rien d'autre.
	#
	# Une version elargie a tout ce qui se trouvait a dix metres a ete essayee,
	# pour couvrir le cas de l'elan d'arrivee. Elle rendait le desert
	# inquittable : sa fleche de retour est justement posee a six metres du
	# point d'atterrissage, elle etait donc verrouillee des l'arrivee et il
	# fallait s'en eloigner de dix metres avant de pouvoir repartir.
	#
	# Le vrai remede a l'elan est ailleurs, et il est geometrique : on arrive
	# TOURNE DU BON COTE. Voir le cap du passage vers le QG de Tuco.
	_sortie_attendue = null
	for autre in _passages:
		if autre.contient(_v if au_volant else _j):
			_sortie_attendue = autre
			break

	await _noircir(0.0)
	_transition = false
	# L'ambiance suit la zone : le desert n'a pas la meme nappe que la rue, et
	# c'est ce qui fait qu'on entend qu'on a change d'endroit avant de le voir.
	# Une zone sans fichier d'ambiance garde celle du dehors.
	if _audio != null:
		_audio.ambiance(p.zone)
	if p.zone != "" and _scenario != null:
		_scenario.zone_atteinte(p.zone)


## Le bandeau de refus, lu par le HUD. Vide quand il n'y a rien a dire.
func bandeau() -> String:
	return _texte_bandeau if _bandeau > 0.0 else ""


## Son opacite, pour que le HUD le fasse disparaitre en fondu.
func bandeau_opacite() -> float:
	if _bandeau <= 0.0 or reglages == null:
		return 0.0
	return clampf(_bandeau / maxf(0.01, reglages.bandeau_duree * 0.4), 0.0, 1.0)


# Le telephone passe AVANT la roue et avant tout le reste.
#
# Il capte alors l'avant, l'arriere et la touche d'interaction, qui servent a
# naviguer et a valider. Sans ce court-circuit, choisir un correspondant
# ferait marcher Walter dans la rue pendant qu'il compose.
#
# On ne s'en sert pas au volant : composer un numero en conduisant demanderait
# de decider ce qu'il advient de la voiture, et ce n'est pas le sujet du jour.
func _gerer_le_telephone() -> bool:
	if _telephone == null:
		return false

	if _telephone.sorti():
		_afficher("")
		# Pendant que ca sonne, la touche ne raccroche pas : on vient de la
		# presser pour appeler, et elle serait relue dans la meme seconde.
		#
		# Et pendant un appel RECU, elle ne raccroche jamais : l'homme de Tuco
		# est en train de lancer la mission, et raccrocher au milieu laissait le
		# joueur avec une mission dont il n'a pas entendu la consigne.
		if not _telephone.occupe() and not _telephone.impose() \
				and Input.is_action_just_pressed("telephone"):
			if _dialogue != null and _dialogue.actif():
				_dialogue.couper()
			_telephone.ranger()
			_j.relacher_la_pose()
			_j.bloque = false
			return true
		# En ligne, la touche d'interaction fait avancer la conversation.
		if _dialogue != null and _dialogue.actif():
			_afficher("F   Suite" if _telephone.impose()
					else "F   Suite        T   Raccrocher")
			if Input.is_action_just_pressed("interagir"):
				_dialogue.avancer()
		return true

	var libre := _etat == Etat.A_PIED \
			and not (_dialogue != null and _dialogue.actif()) \
			and not (_roue != null and _roue.ouverte())
	if libre and Input.is_action_just_pressed("telephone"):
		_telephone.sortir()
		# Walter porte le combine a l'oreille. La pose ne decrit que le bras
		# droit et le torse : s'il marchait, ses jambes continuent.
		_j.poser("telephoner")
		_j.bloque = true
		return true
	return false


# L'appel aboutit : le correspondant decroche, et c'est le systeme de dialogue
# qui prend la main. Rien de neuf — c'est la meme conversation que chez lui,
# declenchee autrement.
func _sur_appel(cle: String) -> void:
	if _dialogue == null:
		return
	if not _dialogue.demarrer(cle):
		push_warning("telephone : aucune conversation pour '%s'. "
				% cle + "Ajouter une fiche dans donnees/dialogues.json")
		_telephone.ranger()
		_j.relacher_la_pose()
		_j.bloque = false


# Une conversation peut se terminer de deux facons : en face a face, on rend la
# main au joueur ; au telephone, on raccroche d'abord. Sans cette distinction,
# la derniere replique d'un appel laissait Walter libre de marcher avec le
# combine toujours a l'ecran.
func _sur_fin_de_dialogue() -> void:
	if _telephone != null and _telephone.sorti():
		_telephone.ranger()
		_j.relacher_la_pose()
	_j.bloque = false
	if _scenario != null and _dialogue != null:
		_scenario.dialogue_fini(_dialogue.cle_courante())


# ------------------------------------------------------- ce que le scenario
# demande au controleur. Il sait faire ces gestes ; il ne sait pas quand.


# On ouvre la partie dans le salon, sans fondu ni bruit de porte : on n'entre
# pas, on y etait deja. Tout ce qui suit est le meme etat que celui ou l'on se
# trouve apres avoir passe une porte, pose directement.
func _commencer_dedans() -> void:
	var m := get_node_or_null(commencer_chez) as Maison
	if m == null:
		return
	_etat = Etat.DEDANS
	_dedans = m
	_j.global_position = m.entree() + Vector3.UP * 0.1
	_j.rotation.y = m.cap_entree()
	_j.velocity = Vector3.ZERO
	_j.interieur = true
	_c.interieur(true)
	_c.recaler()
	if _audio != null:
		_audio.ambiance(m.nom_affiche)


## Repose le joueur DEHORS, sans fondu ni bruit de porte.
##
## Pour les captures, et pour elles seules. La partie s'ouvre dans le salon de
## Walter depuis qu'il faut en SORTIR pour recevoir l'appel de Tuco : toutes les
## vues qui cadraient le personnage dans la rue se sont mises a montrer une rue
## vide, et le defaut est passe inapercu parce qu'une rue vide reste une image
## plausible. On ne s'en apercoit qu'en cherchant quelqu'un qui n'y est pas.
func sortir_du_batiment() -> void:
	_etat = Etat.A_PIED
	_dedans = null
	_j.interieur = false
	_c.interieur(false)
	_c.recaler()
	if _audio != null:
		_audio.ambiance("")


## Un bandeau, pour dire quelque chose au joueur.
func annoncer(texte: String) -> void:
	_texte_bandeau = texte
	_bandeau = reglages.bandeau_duree


## Le meme, mais qui reste. Pour « MISSION ACCOMPLIE », qu'on veut lire.
func annoncer_longtemps(texte: String) -> void:
	_texte_bandeau = texte
	_bandeau = reglages.bandeau_duree * 3.0


## Le telephone sonne, et quelqu'un parle. Meme mecanique qu'un appel sortant,
## dans l'autre sens : c'est le jeu qui compose.
func recevoir_un_appel(cle: String) -> void:
	if _telephone == null or _dialogue == null or _etat != Etat.A_PIED:
		return
	if _telephone.sorti() or _dialogue.actif():
		return
	# On DECROCHE, on n'ouvre pas le menu. Le combine s'ouvrait sur le
	# repertoire pendant qu'on nous parlait, et le joueur pouvait naviguer,
	# rappeler quelqu'un, ou raccrocher au milieu de la consigne de mission.
	_telephone.decrocher(_dialogue.nom_de(cle))
	_j.poser("telephoner")
	_j.bloque = true
	_dialogue.demarrer(cle)


## Le corps s'effondre. Le joueur cesse d'etre pilotable et devient une masse.
func effondrer_le_joueur() -> void:
	_j.bloque = true
	_j.set_physics_process(false)
	if _ragdoll != null:
		# Pousse vers l'arriere : on vient de le cribler de face. Un corps qui
		# tombe droit apres une rafale se lit comme un bug.
		var arriere := _j.global_transform.basis.z
		_ragdoll.lacher(arriere * 2.4 + Vector3.UP * 1.2)


## L'explosion du fulminate : un souffle blanc, et on se reveille en ville.
func souffler_l_explosion() -> void:
	if _transition:
		return
	_transition = true
	_afficher("")
	if _fondu != null:
		# BLANC, et pas noir. Le noir dit « on change de lieu », le blanc dit
		# « quelque chose vient d'exploser a un metre de vous ».
		_fondu.color = Color(1.0, 0.98, 0.94, 0.0)
		var t := create_tween()
		t.tween_property(_fondu, "color:a", 1.0, 0.18)
		await t.finished
	# DEHORS, devant chez lui, avec la voiture a sa place. Le scenario dit
	# « le joueur se retrouve teleporte a Albuquerque, sa voiture est garee
	# pres de chez lui » — et le point de reprise, lui, est dans le salon.
	_etat = Etat.A_PIED
	_dedans = null
	_j.interieur = false
	_c.interieur(false)
	_j.global_transform = _depart_dehors
	_j.velocity = Vector3.ZERO
	_v.global_position = _voiture_dehors
	_v.linear_velocity = Vector3.ZERO
	_v.ignorer_les_chocs()
	if _audio != null:
		_audio.ambiance("")
	_c.recaler()
	await get_tree().physics_frame
	if _scenario != null:
		_scenario.zone_atteinte("albuquerque")
	if _fondu != null:
		# DIX SECONDES DE BLANC QUI SE RETIRE, et pas une seconde et demie.
		#
		# C'est ce que demande le scenario, et c'est aussi ce que la scene
		# exige : on vient de faire sauter le bureau d'un chef de cartel, on se
		# reveille devant chez soi, et il faut le temps de comprendre ou l'on
		# est. Un fondu court enchaine sur la rue comme sur un changement de
		# menu.
		var t2 := create_tween()
		t2.tween_property(_fondu, "color:a", 0.0, SOUFFLE_RETOUR)
		await t2.finished
		_fondu.color = Color(0.0, 0.0, 0.0, 0.0)
	_transition = false


# « Recommencer la mission » depuis le menu pause. C'est exactement ce que
# fait l'ecran de Game Over, et on emprunte donc le meme chemin : le scenario
# remet la mission, l'argent, l'inventaire et les points d'interaction a zero,
# puis nous rappelle pour replacer le joueur.
func _sur_recommencer_demande() -> void:
	if _scenario != null:
		_scenario.recommencer()
	else:
		recommencer_la_partie()


## Tout remettre en place apres un Game Over.
func recommencer_la_partie() -> void:
	if _ragdoll != null:
		_ragdoll.relever()
	if _etat == Etat.AU_VOLANT:
		_descendre()
	_etat = Etat.A_PIED
	_dedans = null
	_j.interieur = false
	_c.interieur(false)
	_j.process_mode = Node.PROCESS_MODE_INHERIT
	_j.visible = true
	_j.set_physics_process(true)
	_v.global_position = _voiture_dehors
	_v.linear_velocity = Vector3.ZERO
	_v.ignorer_les_chocs()
	# On repart d'ou l'on est parti : dans le salon, avant le coup de fil. La
	# mission recommence a zero, donc son declencheur aussi — il attend de nous
	# voir SORTIR, et il faut donc etre rentre.
	_commencer_dedans()
	_j.global_transform = _depart
	_j.velocity = Vector3.ZERO
	_c.suivre(_j)
	_c.recaler()
	_sortie_attendue = null
	_bandeau = 0.0


func _presenter_le_joueur() -> void:
	for m in _maisons:
		var p := m.habitant()
		if p != null:
			p.observer(_j)


# Une conversation en cours capte la touche avant tout le reste : rien ne
# serait plus desagreable que de ressortir de la maison en voulant lire la
# replique suivante.
func _dans_la_maison() -> void:
	if _dialogue != null and _dialogue.actif():
		_afficher("F   Suite")
		if Input.is_action_just_pressed("interagir"):
			_dialogue.avancer()
		return

	# L'habitant peut avoir quitte les lieux — Jesse part rejoindre le
	# camping-car des la fin de sa conversation. Il est alors range plutot que
	# detruit, et c'est sa cle videe qui dit qu'il n'y a plus personne a qui
	# parler ; sans ce garde, on discutait avec une piece vide.
	var p := _dedans.habitant()
	if p != null and p.visible and p.cle != "":
		var d_p := _j.global_position.distance_to(p.global_position)
		if d_p <= reglages.portee_dialogue:
			_afficher("F   Parler a %s" % _nom_de(p))
			if Input.is_action_just_pressed("interagir"):
				_parler(p)
			return

	# Les points d'interaction valent aussi a l'interieur : la cachette de la
	# derniere etape est une latte du mur de chez Walter.
	var point := _point_proche()
	if point != null:
		_afficher("F   %s" % point.invite)
		if Input.is_action_just_pressed("interagir"):
			_utiliser(point)
		return

	var sortable := _j.global_position.distance_to(_dedans.entree()) \
			<= reglages.portee_porte
	_afficher("F   Sortir" if sortable else "")
	if sortable and Input.is_action_just_pressed("interagir"):
		# On ne ressort pas de chez soi avec trois cent mille dollars a la
		# main. C'est le seul verrou de la derniere etape, et il faut qu'il
		# s'explique — sinon la porte a simplement l'air cassee.
		var refus := _scenario.refus_de_sortie() if _scenario != null else ""
		if refus != "":
			annoncer(refus)
			return
		_sortir()


func _parler(p: Pnj) -> void:
	if _dialogue == null:
		return
	# La mission peut avoir mieux a faire dire a ce personnage que sa
	# conversation habituelle. C'est elle qui tranche, pas lui.
	var cle := p.cle
	if _scenario != null:
		cle = _scenario.dialogue_pour(cle)
	if _dialogue.demarrer(cle):
		# Immobilise sans suspendre la physique : il finit son pas au lieu de
		# se figer une jambe en l'air.
		_j.bloque = true


func _nom_de(p: Pnj) -> String:
	return _dialogue.nom_de(p.cle) if _dialogue != null else p.cle.capitalize()


# A pied, deux interactions se disputent la meme touche. On tranche par la
# distance plutot que par un ordre fixe : garer la voiture devant chez soi est
# exactement ce qu'on fera tout le temps, et il faut que F fasse alors la
# chose la plus proche, pas la premiere testee.
func _a_pied() -> void:
	# Une conversation en cours capte la touche. Chez Tuco, le joueur reste
	# libre de ses mouvements pendant qu'on lui parle : la scene se joue autour
	# de lui, pas a sa place.
	if _dialogue != null and _dialogue.actif():
		_afficher("F   Suite")
		if Input.is_action_just_pressed("interagir"):
			_dialogue.avancer()
		return

	var d_v := _j.global_position.distance_to(_v.global_position)
	var portee_v := reglages.portee_interaction + 1.4

	var maison := _maison_proche()
	var d_m := INF
	if maison != null:
		d_m = _j.global_position.distance_to(maison.seuil())

	# LES POINTS ET LES GENS passent avant la voiture et les portes.
	#
	# Ils sont plus rares et plus precis : on gare rarement sa voiture SUR
	# l'atelier de chimie, mais on parle tres souvent a quelqu'un qui se tient
	# devant une porte. Faire gagner le plus proche donnerait « Entrer chez
	# Jesse » alors qu'on est plante devant Jesse.
	var point := _point_proche()
	if point != null:
		_afficher("F   %s" % point.invite)
		if Input.is_action_just_pressed("interagir"):
			_utiliser(point)
		return

	var gens := _pnj_proche()
	if gens != null:
		_afficher("F   Parler a %s" % _nom_de(gens))
		if Input.is_action_just_pressed("interagir"):
			_parler(gens)
		return

	if maison != null and d_m <= reglages.portee_porte and d_m < d_v:
		_afficher("F   Entrer chez %s" % maison.nom_affiche)
		if Input.is_action_just_pressed("interagir"):
			_entrer(maison)
		return

	var proche := d_v <= portee_v
	if proche:
		_afficher("F   Monter")
		if Input.is_action_just_pressed("interagir"):
			_monter()
		return

	# LIRE, en dernier recours.
	#
	# Le livre passe apres tout le reste, et c'est le bon ordre : on tient le
	# livre en permanence une fois ramasse, et il ne doit jamais voler la touche
	# a une porte, a une conversation ou a une voiture. Quand plus rien d'autre
	# n'est a portee, F lit.
	if _equipement != null and _equipement.cle_equipee() == "livre":
		_afficher("F   Lire")
		if Input.is_action_just_pressed("interagir"):
			_lire()
		return
	_afficher("")


# Lire le livre. Le joueur est bloque le temps du geste ; bouger l'annule, et
# c'est le personnage qui s'en charge — lui seul lit encore les commandes
# pendant qu'il est bloque.
func _lire() -> void:
	var duree := _j.geste("lire")
	if duree <= 0.0:
		return
	_j.bloque = true
	if _audio != null and _audio.connait("objet_livre"):
		_audio.bruit("objet_livre")


# Le point d'interaction le plus proche parmi ceux qui sont offerts. Ils se
# declarent dans un groupe : la mission en pose une dizaine, repartis dans
# quatre decors, et les enumerer a la main dans l'inspecteur garantirait d'en
# oublier un.
func _point_proche() -> Point:
	var m := Mission.courante(self)
	var meilleur: Point = null
	var mini := INF
	for n in get_tree().get_nodes_in_group("point"):
		var p := n as Point
		if p == null or not p.offert(_j, m):
			continue
		var d := p.distance(_j)
		if d < mini:
			mini = d
			meilleur = p
	return meilleur


# Les PNJ hors maison : Jesse devant le camping-car, le garde, Tuco. Ceux des
# maisons sont geres par la maison elle-meme et ne sont pas dans ce groupe
# quand on est dehors — ils sont a six cents metres.
func _pnj_proche() -> Pnj:
	var m := Mission.courante(self)
	var meilleur: Pnj = null
	var mini := reglages.portee_dialogue
	for n in get_tree().get_nodes_in_group(Pnj.GROUPE):
		var p := n as Pnj
		if p == null or not p.offert(m):
			continue
		if _dialogue == null or not _dialogue.connait(p.cle):
			continue
		var d := _j.global_position.distance_to(p.global_position)
		if d < mini:
			mini = d
			meilleur = p
	return meilleur


func _utiliser(p: Point) -> void:
	# ON VERIFIE L'ARGENT AVANT, ON LE PRELEVE APRES.
	#
	# Les deux moities comptent, et pour deux raisons opposees :
	#
	#   - verifier avant, parce que declencher() CONSOMME le point — il se marque
	#     fait, disparait s'il est a usage unique, et emet son signal. Payer
	#     ensuite laisserait un point consomme pour un achat qu'on refuse ;
	#   - prelever apres, parce qu'un point peut refuser de lui-meme, et il rend
	#     alors son refus SANS se consommer. L'argent, lui, serait deja parti :
	#     on aurait paye pour s'entendre dire non.
	var caisse: Bourse = null
	if p.coute > 0:
		caisse = Bourse.courante(self)
		if caisse == null or caisse.montant() < p.coute:
			annoncer("Il vous faut %s" % Bourse.ecrire(p.coute))
			return

	var refus := p.declencher()
	if refus != "":
		annoncer(refus)
		return

	if caisse != null:
		caisse.retirer(p.coute)

	# LE SON EST EMIS DEPUIS LE POINT, pas dans l'oreille du joueur. Une caisse
	# enregistreuse s'entend au comptoir : c'est ce qui fait qu'on a agi QUELQUE
	# PART plutot qu'appuye sur une touche.
	if p.son != "":
		var audio := Audio.courant(self)
		if audio != null:
			audio.bruit_ici(p.son, p.global_position)

	if p.evenement == "action:cachette":
		if _scenario != null:
			_scenario.ouvrir_la_cachette()
		return
	if p.dialogue != "" and _dialogue != null and _dialogue.demarrer(p.dialogue):
		# On ne bloque PAS le joueur : chez Tuco, la scene se joue autour de
		# lui pendant qu'il peut encore marcher, et c'est ce qui la rend
		# tendue plutot que regardee.
		pass
	if p.emmene_a != Vector3.ZERO:
		await emmener(p.emmene_a, deg_to_rad(p.cap_degres), p.zone, p.interieur)
		return
	if _scenario != null:
		_scenario.point_utilise(p)


## Emmene le joueur ailleurs, par un fondu. Meme geste qu'une porte de maison,
## et c'est bien le meme : entrer dans le camping-car ou dans le QG n'est pas
## un autre mecanisme, juste une autre destination.
func emmener(ou: Vector3, cap: float, zone: String = "",
		clos: bool = false) -> void:
	if _transition:
		return
	var depart := _j.global_position
	await _passer_la_porte(ou, cap, depart)
	# La camera se rapproche dans un endroit clos, et les pas changent de son.
	# C'est le meme geste que pour une maison ; il manquait ici, et un couloir
	# de deux metres quarante avec une camera a quatre metres derriere donne
	# une image ou l'on ne reconnait plus rien.
	_j.interieur = clos
	_c.interieur(clos)
	_c.recaler()
	if zone != "" and _scenario != null:
		_scenario.zone_atteinte(zone)


func _maison_proche() -> Maison:
	var meilleure: Maison = null
	var mini := INF
	for m in _maisons:
		var d := _j.global_position.distance_to(m.seuil())
		if d < mini:
			mini = d
			meilleure = m
	return meilleure


func _monter() -> void:
	_etat = Etat.AU_VOLANT
	_j.set_physics_process(false)
	_j.visible = false
	# La capsule doit disparaitre du monde physique, sinon la voiture bute
	# dedans en demarrant.
	_j.process_mode = Node.PROCESS_MODE_DISABLED
	_v.prendre_le_volant()
	_c.suivre(_v)
	_geste_portiere(true)
	# La mission attend ce moment : « trouver la voiture de Walt ». Personne ne
	# l'annoncait, donc l'etape n'etait JAMAIS franchie — et tout ce qui suit,
	# le desert, Jesse, le camping-car, restait hors d'atteinte. Le jeu tournait
	# parfaitement et la mission etait morte a sa troisieme etape.
	if _scenario != null:
		_scenario.signaler("volant")


func _descendre() -> void:
	_etat = Etat.A_PIED
	_v.quitter_le_volant()
	_geste_portiere(false)

	# On repose Walter a la portiere conducteur, dans le repere du vehicule :
	# il sort du bon cote quel que soit le sens de la voiture.
	var marque := _v.get_node_or_null("SortieConducteur") as Node3D
	var pos := marque.global_position if marque != null else \
			_v.global_position - _v.global_transform.basis.x * 1.7
	pos.y = _v.global_position.y + 0.1

	_j.process_mode = Node.PROCESS_MODE_INHERIT
	_j.global_position = pos
	_j.velocity = Vector3.ZERO
	# Il regarde dans le meme sens que la voiture, ce qui evite un demi-tour
	# desagreable des le premier appui sur une touche.
	_j.rotation.y = _v.rotation.y
	_j.visible = true
	_j.set_physics_process(true)
	_c.suivre(_j)


# Ouvrir, s'asseoir, refermer. Les trois sons sont ESPACES : joues ensemble
# ils se superposent en un seul bruit confus, alors qu'echelonnes ils
# racontent un geste. Les delais sont courts — on ne veut pas faire attendre
# le joueur, juste eviter la bouillie.
#
# Le son suit la voiture et non le joueur : c'est la portiere qui claque.
func _geste_portiere(monte: bool) -> void:
	if _audio == null:
		return
	var ou := _v.global_position
	_audio.bruit_ici("portiere_ouvre", ou)
	if monte:
		await get_tree().create_timer(0.35).timeout
		_audio.bruit_ici("assise", ou)
	await get_tree().create_timer(0.45).timeout
	# La voiture a pu rouler entre-temps : on relit sa position plutot que de
	# faire claquer une portiere la ou elle etait.
	_audio.bruit_ici("portiere_ferme", _v.global_position)


func _entrer(m: Maison) -> void:
	var seuil := m.seuil()
	await _passer_la_porte(m.entree(), m.cap_entree(), seuil)
	_etat = Etat.DEDANS
	_dedans = m
	_j.interieur = true
	_c.interieur(true)
	if _audio != null:
		_audio.ambiance(m.nom_affiche)
	# Entrer chez quelqu'un est une arrivee comme une autre. Le nom du lieu se
	# DEDUIT de celui de la maison : « Walter » donne « maison_walter », et
	# ajouter une maison ne demande donc rien de plus a la mission.
	if _scenario != null:
		_scenario.zone_atteinte("maison_" + m.nom_affiche.to_lower())


func _sortir() -> void:
	var m := _dedans
	await _passer_la_porte(m.seuil(), m.cap_sortie(), m.entree())
	_etat = Etat.A_PIED
	_dedans = null
	_j.interieur = false
	_c.interieur(false)
	if _audio != null:
		_audio.ambiance("")


# Noir, on deplace, on rouvre. Le deplacement se fait au creux du fondu :
# c'est la seule image ou le saut de six cents metres est invisible.
#
# La porte s'ouvre AVANT le noir et se referme APRES, chacune a sa place
# reelle : on entend la poignee la ou on etait, et le battant la ou on
# arrive. Jouer les deux au meme endroit trahissait le saut.
func _passer_la_porte(destination: Vector3, cap: float, depart: Vector3) -> void:
	_transition = true
	_afficher("")
	if _audio != null:
		_audio.bruit_ici("porte_ouvre", depart)
	await _noircir(1.0)

	_j.global_position = destination + Vector3.UP * 0.1
	_j.velocity = Vector3.ZERO
	_j.rotation.y = cap
	if _audio != null:
		_audio.bruit_ici("porte_ferme", destination)
	# La camera doit sauter avec lui. Sans ce recalage elle rattraperait la
	# distance en lissant, et on verrait defiler le vide entre les deux.
	_c.recaler()
	# Une image complete pour que la physique repose le personnage et que la
	# camera se replace avant qu'on rouvre.
	await get_tree().physics_frame

	await _noircir(0.0)
	_transition = false


func _noircir(alpha: float) -> void:
	if _fondu == null:
		return
	var t := create_tween()
	t.tween_property(_fondu, "color:a", alpha, reglages.fondu_porte)
	await t.finished


## Est-on au volant ? Le HUD s'en sert pour n'afficher le compteur que la ou
## il veut dire quelque chose. Une methode plutot qu'une lecture directe de
## l'etat : deux sources de verite finissent toujours par diverger.
func au_volant() -> bool:
	return _etat == Etat.AU_VOLANT


## Est-on a l'interieur d'une maison ?
func dedans() -> bool:
	return _etat == Etat.DEDANS


func _afficher(texte: String) -> void:
	if _invite != null:
		_invite.text = texte
		var casse := 1
