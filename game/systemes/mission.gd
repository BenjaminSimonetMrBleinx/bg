# La mission en cours.
#
# Une liste d'etapes, un curseur, et un seul verbe : evenement(). Les systemes
# du jeu annoncent ce qui vient d'arriver — une conversation finie, une zone
# atteinte, un objet ramasse — et la mission regarde si c'est ce qu'elle
# attendait. Si oui, elle avance.
#
# C'EST VOLONTAIREMENT DANS CE SENS. L'inverse — une mission qui surveille le
# monde — obligerait ce fichier a connaitre le nom des zones, la position des
# maisons et la cle des dialogues, c'est-a-dire a savoir de quoi la mission
# parle. Il ne le sait pas, et c'est ce qui permettra d'en ecrire une deuxieme
# sans le rouvrir.
#
# Le deroule vit dans donnees/mission1.json.
class_name Mission
extends Node

## Emis quand on passe a l'etape suivante. L'index est celui de la NOUVELLE
## etape ; il vaut le nombre d'etapes quand la mission est finie.
signal etape_changee(index: int)
signal accomplie

const GROUPE := "mission"

@export var fichier: String = "res://donnees/mission1.json"

var _donnees: Dictionary = {}
var _etapes: Array = []
var _index: int = 0
var _finie: bool = false

## Les etapes deja franchies, pour l'ecran du telephone. On garde la trace
## plutot que de la recalculer : le joueur veut voir ce qu'il a fait, pas
## seulement ce qu'il lui reste.
var _faites: Array[String] = []


## La mission de la scene courante, retrouvee par son groupe.
##
## Comme Audio.courant() et pour la meme raison : le noeud peut etre declare
## n'importe ou dans la scene, et le chercher par chemin depuis cinq endroits
## differents garantit qu'un des cinq se trompera.
static func courante(depuis: Node) -> Mission:
	if depuis == null or not depuis.is_inside_tree():
		return null
	return depuis.get_tree().get_first_node_in_group(GROUPE) as Mission


func _ready() -> void:
	add_to_group(GROUPE)
	_charger()


func _charger() -> void:
	if not FileAccess.file_exists(fichier):
		push_error("mission : %s introuvable" % fichier)
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(fichier))
	if typeof(lu) != TYPE_DICTIONARY:
		push_error("mission : %s illisible. Verifier les virgules." % fichier)
		return
	_donnees = lu
	_etapes = _donnees.get("etapes", [])
	print("MISSION : '%s', %d etape(s)" % [titre(), _etapes.size()])


func titre() -> String:
	return str(_donnees.get("titre", "Mission"))


func etapes() -> Array:
	return _etapes


func index() -> int:
	return _index


func finie() -> bool:
	return _finie


## L'etape en cours, ou un dictionnaire vide si la mission est finie.
func etape() -> Dictionary:
	if _finie or _index >= _etapes.size():
		return {}
	return _etapes[_index]


func cle_etape() -> String:
	return str(etape().get("cle", ""))


func objectif() -> String:
	return str(etape().get("objectif", ""))


## Le texte d'aide de l'etape courante, s'il y en a un. Il n'est rendu QU'UNE
## FOIS : un conseil qui reste affiche n'est plus un conseil.
func prendre_le_tuto() -> String:
	var t := str(etape().get("tuto", ""))
	if t == "" or _tuto_vu.has(cle_etape()):
		return ""
	_tuto_vu[cle_etape()] = true
	return t

var _tuto_vu: Dictionary = {}


## Ce qui est deja fait, dans l'ordre. Pour l'ecran du telephone.
func faites() -> Array[String]:
	return _faites


## Le monde annonce quelque chose. Renvoie vrai si ca a fait avancer la
## mission — utile aux tests, et a personne d'autre : un appelant ne doit pas
## avoir a savoir si son evenement comptait.
func evenement(nom: String) -> bool:
	if _finie or _index >= _etapes.size():
		return false
	if str(etape().get("valide_par", "")) != nom:
		return false
	_faites.append(objectif())
	_index += 1
	if _index >= _etapes.size():
		_finie = true
		accomplie.emit()
	etape_changee.emit(_index)
	return true


## Repositionne la mission a l'etat d'une sauvegarde : on saute directement a
## l'etape `i`, avec la liste des objectifs deja franchis. Sert au chargement,
## pour reprendre une partie sans rejouer la mission depuis le debut.
func reprendre(i: int, faits: Array) -> void:
	_index = clampi(i, 0, _etapes.size())
	_faites.clear()
	for f in faits:
		_faites.append(str(f))
	_finie = _index >= _etapes.size()
	etape_changee.emit(_index)


## Sommes-nous a cette etape ? Lu par les points d'interaction qui ne doivent
## exister qu'a un moment precis — l'atelier de chimie avant d'avoir cuisine,
## la cachette a la toute fin.
func a_l_etape(cle: String) -> bool:
	return not _finie and cle_etape() == cle


## Cette etape est-elle DEJA passee ? Un objet qu'on peut ramasser apres coup
## ne doit pas disparaitre parce que la mission a avance.
func passee(cle: String) -> bool:
	for i in mini(_index, _etapes.size()):
		if str((_etapes[i] as Dictionary).get("cle", "")) == cle:
			return true
	return false


func argent_de_depart() -> int:
	var d: Dictionary = _donnees.get("depart", {})
	var bas := int(d.get("argent_min", 100))
	var haut := int(d.get("argent_max", 200))
	return randi_range(mini(bas, haut), maxi(bas, haut))


func objets_de_depart() -> Array:
	return (_donnees.get("depart", {}) as Dictionary).get("objets", [])


## L'heure a laquelle la mission commence, de 0 a 24. NEGATIF si elle n'en
## impose aucune — et c'est le cas par defaut.
##
## Une mission qui se joue de nuit ne peut pas se contenter d'esperer qu'il
## fasse nuit : l'heure avance maintenant toute seule, donc lancer la meme
## mission deux fois donnerait deux ambiances, et un rendez-vous a trois heures
## du matin se jouerait a midi une fois sur deux. Elle le DIT, et le monde se
## pose a cette heure-la.
func heure_de_depart() -> float:
	var d: Dictionary = _donnees.get("depart", {})
	if not d.has("heure"):
		return -1.0
	return clampf(float(d["heure"]), 0.0, 24.0)


func montant_de_la_vente() -> int:
	return int((_donnees.get("vente", {}) as Dictionary).get("montant", 0))


func reste_maximum() -> int:
	return int((_donnees.get("cachette", {}) as Dictionary).get(
			"reste_maximum", 10000))


func refus_sortie() -> String:
	return str((_donnees.get("cachette", {}) as Dictionary).get(
			"refus_sortie", "Vous ne pouvez pas sortir avec tout cet argent"))


## Tout reprendre a zero. Appele par l'ecran de Game Over : le prompt demande
## que l'on revienne au debut de la mission, objets et argent reinitialises.
func recommencer() -> void:
	_index = 0
	_finie = false
	_faites.clear()
	_tuto_vu.clear()
	etape_changee.emit(0)
