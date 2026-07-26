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

## Le point n'existe QUE pendant cette etape de la mission. Vide = toujours.
##
## C'est ce qui empeche de cuisiner avant d'etre arrive, et de vider la
## cachette pendant le premier dialogue. Sans lui, chaque point devrait
## interroger la mission lui-meme, et la moitie oublierait.
@export var etape: String = ""

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
