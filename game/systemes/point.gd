# Un point d'interaction : « F pour faire ceci ».
#
# UN SEUL script pour l'atelier de chimie, la marchandise de Jesse, le revolver
# de la boite a gants, la botte secrete sur le bureau de Tuco et le volant du
# camping-car. Chacun aurait pu avoir le sien ; ils auraient tous redit la meme
# chose — mesurer une distance, afficher une invite, se declencher une fois —
# et ils auraient diverge au troisieme.
#
# Ce qui les distingue tient en cinq champs poses dans la scene. Ce qui se
# passe ensuite ne regarde pas ce fichier : il annonce un EVENEMENT, et la
# mission decide si ca la fait avancer.
class_name Point
extends Node3D

signal utilise(point: Point)

## Ce qui s'affiche apres le F. Un verbe : « Cuisiner », « Ramasser ».
@export var invite: String = "Utiliser"

## L'evenement annonce a la mission. Vide = on ne lui dit rien, ce qui est le
## cas des points purement decoratifs comme le volant.
@export var evenement: String = ""

## L'objet donne au joueur, s'il y en a un. Sa cle dans outils.json.
@export var donne: String = ""

## CE QUE CA COUTE, en dollars. Zero = gratuit, ce qui reste le cas general.
##
## L'epicerie s'en sert : les courses etaient un bouton qui faisait monter la
## famille sans rien prelever, donc on pouvait le marteler sur place. Un geste
## qui ne coute rien n'est pas un choix — c'est la regle numero deux du projet.
##
## Comme `donne`, ce champ est une DONNEE : le point ne touche pas a la bourse,
## il annonce son prix et le controleur decide. Un point qui saurait retirer de
## l'argent saurait aussi le rendre, et on aurait deux caisses.
@export var coute: int = 0

## Le mecanisme sonore joue quand ca marche. Vide = silencieux.
##
## Un nom de la banque — voir donnees/sons.json — jamais un fichier.
@export var son: String = ""

## CE QU'IL FAUT AVOIR SUR SOI pour que ce point se propose. Vide = rien.
##
## Le pendant exact de `donne` : l'acheteur de marchandise ne s'affiche que si
## l'on a de quoi lui vendre. Sans ce champ, on lit « Livrer la marchandise »
## les mains vides et on appuie pour rien — l'invite promet alors quelque chose
## qu'elle ne peut pas tenir.
##
## Ce n'est PAS le point qui consomme l'objet : il annonce son evenement, et le
## scenario decide. Un point qui viderait l'inventaire saurait aussi le
## remplir, et on aurait deux inventaires.
@export var exige: String = ""

## Le point n'existe QUE pendant cette etape de la mission. Vide = toujours.
##
## C'est ce qui empeche de cuisiner avant d'etre arrive, et de vider la
## cachette pendant le premier dialogue. Sans lui, chaque point devrait
## interroger la mission lui-meme, et la moitie oublierait.
@export var etape: String = ""

## Le point existe A PARTIR de cette etape, et ne disparait plus ensuite.
##
## C'est ce qu'il fallait a la porte du camping-car. Elle portait `etape`, donc
## elle n'existait QUE pendant l'etape « entrer dans le camping-car » : une fois
## dedans l'etape changeait, et ressortir laissait le joueur devant un
## camping-car qu'il ne pouvait plus ouvrir. Une porte qui ne s'ouvre qu'une
## fois n'est pas une porte.
##
## Les deux champs se cumulent quand ils sont poses tous les deux.
@export var etape_minimale: String = ""

## Un refus affiche au lieu d'agir. Le volant du camping-car s'en sert : il
## faut pouvoir appuyer et s'entendre dire non, sinon on croit a un bug.
@export var refus: String = ""

## Une conversation a lancer. La porte du QG s'en sert : on frappe, le garde
## repond, et c'est la conversation qui decide de la suite.
@export var dialogue: String = ""

## Ou l'on ressort, si ce point est une porte. Zero = on ne bouge pas.
##
## Les portes du camping-car et du QG passent par ici plutot que par un
## Passage : un passage se franchit en marchant dessus, et le scenario veut
## qu'on APPUIE sur F devant une porte.
@export var emmene_a: Vector3 = Vector3.ZERO
@export var cap_degres: float = 0.0

## Le nom du lieu ou l'on arrive, annonce a la mission.
@export var zone: String = ""

## Arrive-t-on DANS un endroit clos ?
##
## La camera de poursuite se rapproche alors, et les pas sonnent comme a
## l'interieur. Sans ce reglage, on entre dans un camping-car de deux metres
## quarante de large avec une camera posee quatre metres derriere : elle passe
## a travers la paroi, on ne voit plus que du decor retourne, et le personnage
## parait coince alors qu'il marche normalement.
@export var interieur: bool = false

## Disparait-il une fois utilise ? Vrai pour tout ce qui se ramasse.
@export var une_fois: bool = true

## Distance a laquelle on peut agir, en metres.
@export_range(0.5, 6.0, 0.1) var portee: float = 2.2

## Tous les points sont dans ce groupe, et c'est ainsi que le controleur les
## trouve. La mission en pose une dizaine repartis dans quatre decors : les
## enumerer a la main dans l'inspecteur garantirait d'en oublier un, et un
## point oublie est une etape que rien ne peut plus franchir.
const GROUPE := "point"

var _fait: bool = false


func _ready() -> void:
	add_to_group(GROUPE)


func fait() -> bool:
	return _fait


## Ce point est-il proposable maintenant ? Il faut etre assez pres, ne pas
## l'avoir deja consomme, et etre a la bonne etape.
func offert(joueur: Node3D, mission: Mission) -> bool:
	if _fait and une_fois:
		return false
	if not visible:
		return false
	if joueur == null:
		return false
	if joueur.global_position.distance_to(global_position) > portee:
		return false
	if etape != "" and (mission == null or not mission.a_l_etape(etape)):
		return false
	if etape_minimale != "":
		if mission == null:
			return false
		if not mission.a_l_etape(etape_minimale) \
				and not mission.passee(etape_minimale):
			return false
	return true


func distance(joueur: Node3D) -> float:
	if joueur == null:
		return INF
	return joueur.global_position.distance_to(global_position)


## On s'en sert. Renvoie le refus s'il y en a un — l'appelant l'affiche alors
## en bandeau au lieu de declencher quoi que ce soit.
func declencher() -> String:
	if refus != "":
		return refus
	_fait = true
	if une_fois:
		visible = false
	utilise.emit(self)
	return ""


## Tout remettre en place. Recommencer une partie doit redonner un atelier
## utilisable et une boite a gants pleine.
func reinitialiser() -> void:
	_fait = false
	visible = true
