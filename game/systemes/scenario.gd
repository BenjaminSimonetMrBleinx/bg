# Ce qui est PROPRE a la mission 1.
#
# Le controleur sait marcher, conduire, entrer, parler. Il ne sait pas qu'un
# homme de Tuco appelle cinq secondes apres qu'on sort de chez soi, ni que
# tirer sur Skyler termine la partie. Tout cela vit ici.
#
# La separation vaut le fichier de plus. Le controleur fait deja six cents
# lignes et il est le seul endroit ou l'on bascule entre marcher et conduire :
# y verser un scenario reviendrait a melanger ce qui vaudra pour toutes les
# missions avec ce qui ne vaut que pour celle-ci — et la deuxieme mission
# devrait alors demeler les deux.
#
# Ce script ecoute, decide, et redonne la main. Il ne dessine rien et ne
# deplace personne : il annonce des evenements a la mission, joue des sons, et
# demande au controleur de faire ce qu'il sait deja faire.
class_name Scenario
extends Node

## Delai avant l'appel de l'homme de Tuco, une fois sorti de chez Walter.
const AVANT_L_APPEL := 5.0

## Combien de temps Tuco patiente avant de faire tirer, une fois la botte
## secrete decouverte. Le scenario dit une minute.
const PATIENCE_DE_TUCO := 60.0

## Entre deux repliques de menace, quand le joueur ne fait rien.
const ENTRE_DEUX_MENACES := 7.0

## Le silence entre la fin de « this is not meth » et la deflagration, en
## secondes. Court : c'est un temps de suspension, pas une pause.
const APRES_LA_REPLIQUE := 0.45

## L'HEURE DE LA MISSION, lieu par lieu.
##
## Le scenario est explicite : on part en journee, on arrive dans le desert en
## fin d'apres-midi, et il fait le meme jour finissant chez Tuco. Le jeu
## demarrait a l'heure du fichier monde.json — la nuit, par defaut — ce qui
## faisait une mission entiere jouee dans le noir et des references visuelles
## qui ne correspondaient a rien.
##
## Elle est POSEE AUX ARRIVEES, pas avancee en continu : un cycle qui tourne
## ferait finir la scene de Tuco en pleine nuit selon le temps qu'on met a y
## aller, et le crepuscule est ici une intention de mise en scene.
const HEURES := {
	"camping": 17.4,
	"qg": 18.6,
}

@export var mission: NodePath
@export var joueur: NodePath
@export var controleur: NodePath

## L'homme de main qui vient fouiller Walter chez Tuco. C'est l'un des trois
## qui attendent derriere le joueur : celui du milieu.
@export var garde_fouilleur: NodePath

var _mission: Mission
var _joueur: Joueur
var _controleur: Node
var _dialogue: Dialogue
var _telephone: Telephone
var _bourse: Bourse
var _tir: Tir
var _fin: FinDePartie
var _cachette: Cachette
var _equipement: Equipement
var _audio: Audio

## Compte a rebours de l'appel d'ouverture. Negatif = deja passe.
var _appel: float = -1.0
var _sorti_de_chez_lui: bool = false

## La scene finale chez Tuco.
var _patience: float = -1.0
var _menace: float = 0.0

## Les reactions aux tirs. Elles vivent ici plutot qu'en donnees parce
## qu'elles sont des REGLES DE SCENARIO, pas des reglages : « ne tuez pas
## votre femme tout de suite » n'a de sens que dans cette mission-la.
const TIRS := {
	"skyler": "Je sais que c'est tentant, mais ne tuez pas votre femme tout de suite",
	"jesse": "Jesse est mort",
	"mission_jesse_camping": "Jesse est mort",
	"garde": "Il n'etait pas seul",
	"tuco": "Personne ne braque Tuco Salamanca",
}


func brancher(dialogue: Dialogue, telephone: Telephone, tir: Tir,
		fin: FinDePartie, cachette: Cachette, equipement: Equipement) -> void:
	_dialogue = dialogue
	_telephone = telephone
	_tir = tir
	_fin = fin
	_cachette = cachette
	_equipement = equipement


func _ready() -> void:
	_mission = get_node_or_null(mission) as Mission
	_joueur = get_node_or_null(joueur) as Joueur
	_controleur = get_node_or_null(controleur)
	call_deferred("_commencer")


func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio


func _commencer() -> void:
	_bourse = Bourse.courante(self)
	# Retenue AVANT tout : c'est l'heure du monde au chargement, celle sur
	# laquelle on retombe si la mission n'en impose aucune.
	_heure_de_depart = Reglages.heure
	if _mission == null:
		return
	var voulue := _mission.heure_de_depart()
	if voulue >= 0.0:
		_heure_de_depart = voulue
	if _telephone != null:
		_telephone.suivre(_mission)
	_mission.etape_changee.connect(_sur_etape)
	_mission.accomplie.connect(_sur_victoire)
	if _joueur != null:
		_joueur.mort.connect(_sur_mort)
	if _fin != null:
		_fin.recommence.connect(recommencer)
	if _cachette != null:
		_cachette.range.connect(_sur_argent_cache)
	if _tir != null:
		_tir.touche.connect(_sur_tir_sur_quelqu_un)
	if _dialogue != null:
		_dialogue.effet.connect(_sur_effet)
	_installer()
	# La PREMIERE etape n'emet aucun changement — on y est deja. Son objectif
	# et son conseil ne s'affichaient donc jamais, et la partie s'ouvrait sur un
	# salon sans rien dire de ce qu'on attend du joueur.
	_sur_etape(0)


# L'etat de depart : l'argent du jour, et les mains presque vides.
func _installer() -> void:
	if _bourse != null:
		_bourse.poser(_mission.argent_de_depart())
	if _equipement != null:
		_equipement.definir_inventaire(_mission.objets_de_depart())
	_regler_l_heure(_heure_de_depart)
	_rendre_jesse_a_sa_maison()


## L'HEURE DU LANCEMENT, ET POURQUOI ELLE SE FORCE MAINTENANT.
##
## Elle ne pouvait pas l'etre. Trois choses etaient decidees a la construction
## du monde et n'en bougeaient plus : les vitres allumees, peintes dans la
## texture de facade ; la lumiere de porche, creee ou non selon l'heure ; les
## phares. Poser 12 h 30 apres coup donnait un ciel de midi au-dessus d'une
## facade a porche allume — le defaut exact que le cycle avait ete ecrit pour
## supprimer.
##
## Les trois ont ete reprises depuis : les vitres sont un masque d'emission que
## le jeu module, le porche est cree puis masque, les phares suivent l'heure.
## Une mission peut donc dire l'heure a laquelle elle se joue, et le monde s'y
## pose — voir Mission.heure_de_depart().
##
## Ce qui est retenu ici, c'est l'heure effectivement posee au lancement, pour
## pouvoir y revenir quand on recommence la mission apres etre passe par le
## desert.
var _heure_de_depart: float = -1.0


## Pose l'heure du monde. Le noeud Temps se trouve par son groupe : le scenario
## n'a pas a savoir ou il est declare dans la scene.
func _regler_l_heure(h: float) -> void:
	var t := get_tree().get_first_node_in_group(Temps.GROUPE) as Temps
	if t != null:
		t.regler(h)


func recommencer() -> void:
	_mission.recommencer()
	_appel = -1.0
	_sorti_de_chez_lui = false
	_patience = -1.0
	_menace = 0.0
	_installer()
	if _joueur != null:
		_joueur.ressusciter()
	for n in get_tree().get_nodes_in_group("point"):
		(n as Point).reinitialiser()
	for n in get_tree().get_nodes_in_group(Pnj.GROUPE):
		var p := n as Pnj
		p.abattu = false
		# Le garde de la fouille a traverse le bureau : il reprend sa place
		# sans marcher, sinon on le voit revenir pendant le premier plan.
		p.replacer()
	if _controleur != null:
		_controleur.call("recommencer_la_partie")


# ------------------------------------------------------------------ le fil


func _sur_etape(_index: int) -> void:
	# Le telephone SORT, montre l'objectif, et se range. C'est ce que demande
	# le scenario, et c'est aussi ce qui evite un bandeau de plus a l'ecran.
	# Pas au LANCEMENT : sortir un telephone sur la premiere image du jeu, dans
	# le salon, avant que quiconque ait appele, annonce une mission qui n'a pas
	# encore commence. L'objectif de depart s'affiche a l'ecran, ca suffit.
	if _telephone != null and not _mission.finie() and _mission.index() > 0:
		_telephone.annoncer()

	# LE CONSEIL ATTEND QU'ON SOIT DEHORS.
	#
	# « Direction le desert, il vous faut la voiture » s'affichait a la seconde
	# ou la conversation avec Jesse se terminait — donc dans son salon, avant
	# meme d'avoir franchi la porte. On dit au joueur de prendre sa voiture
	# alors qu'il est assis chez quelqu'un : le conseil arrive avant la
	# situation qu'il decrit, et il ne sert plus a rien quand elle arrive.
	#
	# On le garde en attente, et il sort au moment ou l'on met le pied dehors.
	_tuto_en_attente = _mission.prendre_le_tuto()
	_livrer_le_tuto()

	# L'etape ou Tuco decouvre la botte secrete : le compte a rebours part.
	if _mission.a_l_etape("fuir"):
		_patience = PATIENCE_DE_TUCO
		_menace = ENTRE_DEUX_MENACES


## Le conseil en attente, s'il y en a un.
var _tuto_en_attente: String = ""


func _livrer_le_tuto() -> void:
	if _tuto_en_attente == "" or _controleur == null:
		return
	if _controleur.call("dedans"):
		return
	_controleur.call("annoncer", _tuto_en_attente)
	_tuto_en_attente = ""


func _sur_victoire() -> void:
	if _son() != null:
		_son().bruit("victoire")
	if _controleur != null:
		_controleur.call("annoncer_longtemps", "MISSION ACCOMPLIE")


## Appele par le controleur a chaque image.
func traiter(delta: float) -> void:
	if _mission == null or _joueur == null:
		return
	_gerer_l_appel(delta)
	_gerer_la_menace(delta)
	_gerer_l_etat_present()
	_livrer_le_tuto()


# CERTAINES ETAPES SONT DEJA REMPLIES QUAND ELLES ARRIVENT.
#
# « Trouver la voiture de Walt » attend qu'on monte au volant. Mais on y est
# souvent DEJA : on prend la voiture pour aller chez Jesse, on lui parle par la
# fenetre ou on redescend une seconde, et l'etape s'ouvre alors qu'on est
# assis dedans. Plus aucun « monter » n'aura lieu, et l'objectif reste affiche
# pour toujours.
#
# Le scenario le disait des le depart : « si le joueur s'est directement dirige
# vers sa voiture, ignorer cette etape et la valider ». Un evenement ne se
# declenche qu'une fois ; un ETAT, on peut le constater a tout moment. On
# regarde donc l'etat present a chaque image, et pas seulement la transition.
func _gerer_l_etat_present() -> void:
	if _controleur == null or _mission.finie():
		return
	if str(_mission.etape().get("valide_par", "")) == "volant" \
			and _controleur.call("au_volant"):
		_mission.evenement("volant")


# L'appel d'ouverture. Il part cinq secondes apres qu'on met le pied dehors,
# et pas au lancement : recevoir un coup de fil sur l'ecran-titre ne raconte
# rien, alors que sonner pendant qu'on decouvre la rue installe la mission.
func _gerer_l_appel(delta: float) -> void:
	if not _mission.a_l_etape("appel") or _controleur == null:
		return
	if not _sorti_de_chez_lui:
		if not _controleur.call("dedans"):
			_sorti_de_chez_lui = true
			_appel = AVANT_L_APPEL
		return
	if _appel <= 0.0:
		return
	_appel -= delta
	if _appel <= 0.0:
		_appel = -1.0
		_controleur.call("recevoir_un_appel", "mission_tuco_appel")


# Chez Tuco, apres la fouille. Le joueur est libre de bouger — c'est ce que
# demande le scenario — mais le temps joue contre lui.
func _gerer_la_menace(delta: float) -> void:
	if _patience <= 0.0:
		return
	_patience -= delta
	if _patience <= 0.0:
		_patience = -1.0
		if _tir != null:
			_tir.riposte_mortelle(_joueur)
		return
	_menace -= delta
	if _menace <= 0.0:
		_menace = ENTRE_DEUX_MENACES
		if _dialogue != null and not _dialogue.actif():
			_dialogue.demarrer("mission_tuco_menace")


# ---------------------------------------------------------------- reactions


## QUI DIT QUOI, ET QUAND.
##
## Un habitant porte une cle unique — Jesse chez lui, c'est « jesse » — et il
## raconte donc toujours la meme chose. Pendant une mission, ce n'est pas ce
## qu'on veut : a l'etape ou l'on doit lui parler de la commande, c'est la
## conversation de la MISSION qu'il doit tenir, pas sa causette habituelle.
##
## La table vit ici et pas sur le personnage : c'est le scenario qui sait a
## quel moment quelqu'un a autre chose a dire. Le PNJ, lui, n'a pas a connaitre
## la mission en cours.
const REMPLACEMENTS := {
	"jesse": [["parler_jesse", "mission_jesse_maison"]],
	# Jesse DEVANT le camping-car. Une fois la marchandise en poche il n'a plus
	# rien a dire sur la cuisine : sans cette ligne, on ressortait du
	# camping-car et il proposait encore d'aller cuisiner, ce qui donnait
	# l'impression d'avoir saute une etape.
	"mission_jesse_camping": [["aller_tuco", "mission_jesse_livre"]],
	# Jesse dans le camping-car. Il cuisine, donc il envoie promener — jusqu'a
	# ce que la botte secrete soit sortie de l'atelier. La aussi son noeud
	# porte une cle unique : sans cette ligne il repond « je suis concentre »
	# pour l'eternite, et l'etape suivante ne peut plus etre franchie.
	"mission_jesse_occupe": [["jesse_pret", "mission_jesse_pret"]],
}


## La conversation a jouer pour ce personnage, maintenant. Renvoie la cle
## d'origine s'il n'y a rien de special.
func dialogue_pour(cle: String) -> String:
	if _mission == null or not REMPLACEMENTS.has(cle):
		return cle
	for regle in REMPLACEMENTS[cle]:
		if _mission.a_l_etape(str(regle[0])):
			return str(regle[1])
	return cle


## Une conversation vient de se terminer. Renvoie vrai si elle a fait avancer
## la mission — le controleur n'a alors rien d'autre a faire.
func dialogue_fini(cle: String) -> bool:
	if _mission == null:
		return false
	# L'argent et la fouille NE SONT PLUS ICI : ils se declenchent sur la
	# replique qui les annonce — voir _sur_effet et le champ 'effet' dans
	# donnees/dialogues.json. Les faire a la fin de la conversation les
	# decalait d'une quinzaine de repliques.
	#
	# Jesse a dit qu'il partait devant. Il part donc : rester chez lui
	# pendant que Walter va le retrouver dans le desert fait deux Jesse.
	if cle == "mission_jesse_maison":
		_jesse_quitte_sa_maison()
	# Le garde s'ecarte, et on monte. La teleportation est faite APRES la
	# conversation, sinon on la lirait dans le bureau alors qu'elle se joue
	# sur le trottoir.
	if cle == "mission_garde" and _controleur != null:
		_controleur.call("emmener", QG_INTERIEUR, 0.0, "", true)
	return _mission.evenement("dialogue:" + cle)

## Ou l'on atterrit dans le bureau de Tuco. La seule coordonnee ecrite dans ce
## fichier, parce qu'elle est la seule a ne pas pouvoir vivre sur un noeud : on
## y arrive a la fin d'une conversation, pas en marchant sur une zone.
##
## AU CENTRE DE LA PIECE, DEBOUT, FACE AU BUREAU. La piece est declaree dans
## scenes/mission1.tscn autour de (-1200, -900) et fait 8,2 m de profondeur ;
## on arrivait a -897, c'est-a-dire colle au mur d'entree, dos a la porte et a
## six metres de Tuco. Toute la scene est construite sur un face-a-face — on la
## commence donc en face.
const QG_INTERIEUR := Vector3(-1200.0, 0.4, -898.7)


# ------------------------------------------------- ce qui arrive PENDANT qu'on
# parle. Le dialogue annonce un effet nomme ; c'est ici qu'on decide ce qu'il
# veut dire.


func _sur_effet(nom: String) -> void:
	match nom:
		"argent":
			_encaisser()
		"fouille":
			_faire_fouiller()


# Tuco paie, et le compteur monte SOUS LES YEUX du joueur pendant qu'il dit
# « compte-les si tu veux ». Le HUD fait defiler la somme en une seconde : c'est
# la seule facon de sentir trois cent mille dollars, et ca n'a de sens qu'a
# l'instant ou la phrase est prononcee.
func _encaisser() -> void:
	if _bourse != null and _mission != null:
		_bourse.ajouter(_mission.montant_de_la_vente())
	if _equipement != null:
		_equipement.retirer("meth")


# LE GARDE VIENT, FOUILLE, ET REPART.
#
# La botte secrete quittait la poche de Walter a la fin de la conversation,
# c'est-a-dire bien apres que le garde ait annonce l'avoir trouvee. On la lui
# retire maintenant, au moment ou Tuco l'ordonne — et le garde se DEPLACE,
# parce qu'une fouille annoncee par un homme qui n'a pas bouge du fond de la
# piece ne raconte rien.
func _faire_fouiller() -> void:
	var garde := get_node_or_null(garde_fouilleur) as Pnj
	if garde != null and _joueur != null:
		# A cote de Walter, pas dessus : deux capsules au meme endroit se
		# poussent l'une l'autre et le joueur part en glissade.
		garde.aller_vers(_joueur.global_position
				+ _joueur.global_transform.basis.x * 0.85)
		await get_tree().create_timer(2.4).timeout
	if _equipement != null:
		_equipement.retirer("botte")
	if _son() != null:
		_son().bruit("roue_cran")
	if garde != null:
		# Il la POSE SUR LE BUREAU. C'est de la qu'on la reprendra a l'etape
		# suivante, et c'est le seul endroit ou le joueur regarde a ce
		# moment-la. Puis il retourne a sa place, derriere.
		garde.aller_vers(QG_INTERIEUR + Vector3(1.5, 0.0, -3.4))
		await get_tree().create_timer(2.6).timeout
		garde.rentrer()


## Un point d'interaction vient d'etre utilise.
func point_utilise(p: Point) -> void:
	if p.donne != "" and _equipement != null:
		# LE NOM DE CE QU'ON VIENT DE PRENDRE, et pas le dernier de la roue.
		# L'annonce lisait le rang « nombre() - 1 », alors que la roue est
		# triee sur l'ordre du catalogue : tout ramassage s'annoncait donc
		# « Porkpie », qui ferme la liste.
		if _equipement.donner(p.donne) and _controleur != null:
			_controleur.call("annoncer", "%s : recupere"
					% _equipement.nom_pour_cle(p.donne))
	# L'atelier lance la conversation de la botte secrete PENDANT qu'on
	# manipule : Walter parle en travaillant, il ne s'arrete pas pour discuter.
	if p.evenement == "objet:botte" and _dialogue != null:
		_dialogue.demarrer("mission_jesse_botte")
	if p.evenement == "action:botte_bureau":
		_faire_exploser()
	if p.evenement != "" and _mission != null:
		_mission.evenement(p.evenement)


## On est arrive quelque part. Le controleur l'annonce apres chaque passage.
func zone_atteinte(nom: String) -> void:
	# L'heure du lieu, s'il en impose une. Voir HEURES : le desert et le QG se
	# jouent en fin d'apres-midi, quelle que soit l'heure a laquelle on y va.
	if HEURES.has(nom):
		_regler_l_heure(float(HEURES[nom]))
	if _mission != null:
		_mission.evenement("zone:" + nom)


# ------------------------------------------------------------------- Jesse
#
# IL N'EST PLUS CHEZ LUI UNE FOIS QU'IL EN EST PARTI.
#
# Sa derniere replique est « le camping-car, dans le desert, j'y vais devant ».
# Il restait pourtant plante dans son salon, et l'on pouvait donc lui reparler
# a Albuquerque pendant qu'il nous attendait a neuf cents metres de la. Deux
# Jesse au meme moment, c'est le genre de detail qui defait tout le reste.
#
# On le RANGE plutot que de le supprimer : la partie se recommence, et un
# personnage detruit ne revient pas.

var _jesse_maison: Pnj
var _jesse_cle: String = ""


func _jesse_chez_lui() -> Pnj:
	if _jesse_maison != null and is_instance_valid(_jesse_maison):
		return _jesse_maison
	for n in get_tree().get_nodes_in_group(Pnj.GROUPE):
		var p := n as Pnj
		# Sa cle d'origine, celle de l'habitant — pas celles de la mission, qui
		# designent les Jesse du desert.
		if p != null and p.cle == "jesse":
			_jesse_maison = p
			_jesse_cle = p.cle
			return p
	return null


## IL SORT, ET ON LE VOIT SORTIR.
##
## Il disparaissait a la seconde ou la conversation se terminait : le probleme
## des deux Jesse etait regle, mais sa derniere phrase — « le camping-car dans
## le desert, j'y vais devant » — n'etait suivie d'aucun geste. Quelqu'un qui
## s'evapore dans son salon ne part pas, il cesse d'exister.
##
## Il marche donc jusqu'a sa porte, et c'est en la franchissant qu'il quitte la
## piece. La porte est celle du repere de sortie de la maison : la meme que
## celle du joueur, donc elle ne peut pas etre ailleurs.
func _jesse_quitte_sa_maison() -> void:
	var p := _jesse_chez_lui()
	if p == null:
		return
	if _jesse_cle == "":
		_jesse_cle = p.cle
	# Muet des maintenant : on ne le retient pas par la manche pendant qu'il
	# traverse la piece.
	p.cle = ""

	var chez_lui := _maison_de(p)
	if chez_lui != null:
		p.aller_vers(chez_lui.entree())
		# On attend qu'il ARRIVE, pas un delai : la piece peut changer de
		# taille, et un compte a rebours le ferait disparaitre en chemin.
		while not p.arrive() and is_instance_valid(p):
			await get_tree().process_frame
		if not is_instance_valid(p):
			return
		if _son() != null:
			_son().bruit_ici("porte_ouvre", p.global_position)
			await get_tree().create_timer(0.35).timeout
			if not is_instance_valid(p):
				return
			_son().bruit_ici("porte_ferme", p.global_position)
	p.visible = false


# La maison qui contient ce personnage. On remonte l'arbre plutot que de la
# passer par l'inspecteur : l'habitant est cree par la maison elle-meme, il est
# donc toujours sous elle, et un NodePath de plus serait un NodePath de plus a
# tenir a jour.
func _maison_de(p: Node) -> Maison:
	var n := p.get_parent()
	while n != null:
		if n is Maison:
			return n as Maison
		n = n.get_parent()
	return null
	# La cle videe plus haut le rend muet : c'est ainsi que le controleur
	# decide a qui l'on peut parler, et le rendre invisible seul aurait laisse
	# une voix sortir d'une piece vide.


func _rendre_jesse_a_sa_maison() -> void:
	var p := _jesse_chez_lui()
	if p == null:
		return
	p.visible = true
	if _jesse_cle != "":
		p.cle = _jesse_cle


## Un evenement de jeu, sans categorie. Pour ceux qui n'ont ni zone, ni objet,
## ni conversation — monter dans la voiture, par exemple.
func signaler(nom: String) -> void:
	if _mission != null:
		_mission.evenement(nom)


## Peut-on ouvrir la cachette maintenant ? Et avec quel argent.
func ouvrir_la_cachette() -> void:
	if _cachette == null or _bourse == null or _mission == null:
		return
	_cachette.ouvrir(_bourse.montant(), _mission.reste_maximum())


func _sur_argent_cache(somme: int) -> void:
	if _bourse == null:
		return
	_bourse.retirer(somme)
	if _bourse.montant() <= _mission.reste_maximum():
		_mission.evenement("argent_cache")


## Peut-on sortir de chez Walter avec ce qu'on a sur soi ? Renvoie le refus,
## ou "" si la porte s'ouvre.
func refus_de_sortie() -> String:
	if _mission == null or _bourse == null:
		return ""
	if not _mission.a_l_etape("cacher"):
		return ""
	if _bourse.montant() <= _mission.reste_maximum():
		return ""
	return _mission.refus_sortie()


# La botte secrete jetee au sol. Le fulminate de mercure : ca n'est pas de la
# meth, et Tuco l'apprend a ses depens.
func _faire_exploser() -> void:
	_patience = -1.0
	if _son() == null:
		if _controleur != null:
			_controleur.call("souffler_l_explosion")
		return
	# LA REPLIQUE D'ABORD, ENTIERE, l'explosion ensuite. C'est tout le sens de
	# la scene : Walt annonce ce qu'il tient avant de le lancer.
	#
	# L'attente etait de 1,15 s, ecrite a la main. La replique dure plus, et la
	# deflagration lui coupait donc la parole a chaque fois. On lit maintenant
	# la DUREE REELLE du son, plus un souffle : le jour ou la prise est
	# reenregistree, le minutage suit tout seul.
	_son().bruit("pas_de_meth")
	await get_tree().create_timer(
			_son().duree("pas_de_meth") + APRES_LA_REPLIQUE).timeout
	if not is_instance_valid(_joueur):
		return
	_son().bruit_ici("explosion", _joueur.global_position)
	if _controleur != null:
		_controleur.call("souffler_l_explosion")


# Tirer sur quelqu'un. Dans cette mission ce n'est jamais un combat : c'est
# une scene, et elle se termine mal a chaque fois.
func _sur_tir_sur_quelqu_un(qui: Pnj) -> void:
	var cle := qui.cle
	if TIRS.has(cle):
		if cle == "garde" or cle == "tuco":
			# On ne voit personne, et on meurt vite. C'est une punition, pas
			# un echange de coups — le scenario est explicite.
			if _tir != null:
				_tir.riposte_mortelle(_joueur)
			return
		perdre(TIRS[cle])
		return
	# Un passant quelconque : rien de scenarise, mais on ne laisse pas passer
	# ca sans un mot.
	if _controleur != null:
		_controleur.call("annoncer", "Ce n'etait pas necessaire")


func _sur_mort() -> void:
	perdre("Vous etes mort")


## Termine la partie avec ce titre. Public : le controleur s'en sert aussi.
func perdre(titre: String) -> void:
	if _fin == null or _fin.actif():
		return
	if _controleur != null:
		_controleur.call("effondrer_le_joueur")
	_fin.declencher(titre)
