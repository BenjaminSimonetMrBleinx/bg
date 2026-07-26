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

@export var mission: NodePath
@export var joueur: NodePath
@export var controleur: NodePath

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
	if _mission == null:
		return
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
	_installer()


# L'etat de depart : l'argent du jour, et les mains presque vides.
func _installer() -> void:
	if _bourse != null:
		_bourse.poser(_mission.argent_de_depart())
	if _equipement != null:
		_equipement.definir_inventaire(_mission.objets_de_depart())


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
		(n as Pnj).abattu = false
	if _controleur != null:
		_controleur.call("recommencer_la_partie")


# ------------------------------------------------------------------ le fil


func _sur_etape(_index: int) -> void:
	# Le telephone SORT, montre l'objectif, et se range. C'est ce que demande
	# le scenario, et c'est aussi ce qui evite un bandeau de plus a l'ecran.
	if _telephone != null and not _mission.finie():
		_telephone.annoncer()
	var aide := _mission.prendre_le_tuto()
	if aide != "" and _controleur != null:
		_controleur.call("annoncer", aide)

	# L'etape ou Tuco decouvre la botte secrete : le compte a rebours part.
	if _mission.a_l_etape("fuir"):
		_patience = PATIENCE_DE_TUCO
		_menace = ENTRE_DEUX_MENACES


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
	# La vente rapporte, et c'est le seul endroit du jeu ou l'on gagne autant.
	if cle == "mission_tuco_vente" and _bourse != null:
		_bourse.ajouter(_mission.montant_de_la_vente())
		if _equipement != null:
			_equipement.retirer("meth")
			# Le garde la trouve sur lui : elle passe de la poche au bureau.
			_equipement.retirer("botte")
	# Le garde s'ecarte, et on monte. La teleportation est faite APRES la
	# conversation, sinon on la lirait dans le bureau alors qu'elle se joue
	# sur le trottoir.
	if cle == "mission_garde" and _controleur != null:
		_controleur.call("emmener", QG_INTERIEUR, 0.0, "", true)
	return _mission.evenement("dialogue:" + cle)

## Ou l'on atterrit dans le bureau de Tuco. La seule coordonnee ecrite dans ce
## fichier, parce qu'elle est la seule a ne pas pouvoir vivre sur un noeud : on
## y arrive a la fin d'une conversation, pas en marchant sur une zone.
const QG_INTERIEUR := Vector3(-1200.0, 0.4, -897.0)


## Un point d'interaction vient d'etre utilise.
func point_utilise(p: Point) -> void:
	if p.donne != "" and _equipement != null:
		if _equipement.donner(p.donne) and _controleur != null:
			_controleur.call("annoncer", "%s : recupere"
					% _equipement.nom_de(_equipement.nombre() - 1))
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
	if _mission != null:
		_mission.evenement("zone:" + nom)


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
	# LA REPLIQUE D'ABORD, l'explosion ensuite. C'est tout le sens de la scene :
	# Walt annonce ce qu'il tient avant de le lancer. Les jouer ensemble ferait
	# de la phrase un bruit parmi deux autres.
	_son().bruit("pas_de_meth")
	await get_tree().create_timer(1.15).timeout
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
