# Pose ce noeud sur un LIEU NOMME de la ville.
#
# Le generateur sait ou sont les choses : il les construit. Il publie donc,
# a cote des lampadaires et du mobilier, une liste de lieux nommes — les
# parcelles reservees, la sortie vers le desert — avec leur position et leur
# orientation.
#
# Ce script les lit. Tout ce qui doit se trouver a un endroit precis de la
# ville porte un nom de lieu au lieu de coordonnees.
#
# POURQUOI, ET CE QUE CA A COUTE DE NE PAS L'AVOIR FAIT PLUS TOT.
#
# Le panneau DESERT et sa fleche etaient poses a des coordonnees ecrites a la
# main dans la scene. Le jour ou la chaussee est passee de huit a onze metres —
# pour une raison qui n'avait rien a voir — toute la grille a glisse de trois
# metres, et le panneau s'est retrouve au milieu de la route. Deuxieme fois :
# la premiere, c'etait un elargissement du trottoir.
#
# Un lieu nomme ne peut pas se perimer : il est recalcule a chaque generation.
class_name Ancrage
extends Node3D

## Le nom du lieu, tel que le generateur le publie. Voir la cle "lieux" dans
## assets/ville/ville_lampes.json.
@export var lieu: String = ""

## Applique aussi l'orientation du lieu, pas seulement sa position.
@export var suivre_le_cap: bool = true

## Decalage applique APRES l'ancrage, dans le repere du lieu. Sert a poser
## quelque chose « trois metres a droite de l'ancre » sans connaitre l'ancre.
@export var decalage: Vector3 = Vector3.ZERO

const FICHIER := "res://assets/ville/ville_lampes.json"

## Lu une fois pour toute la scene : plusieurs noeuds peuvent s'ancrer, et le
## fichier ne bouge pas en cours de partie.
static var _lieux: Dictionary = {}
static var _lu: bool = false


func _ready() -> void:
	if lieu == "":
		return
	var fiche := trouver(lieu)
	if fiche.is_empty():
		push_error("ancrage : aucun lieu nomme '%s'. Connus : %s"
				% [lieu, ", ".join(_lieux.keys())])
		return

	var p: Array = fiche.get("pos", [0, 0, 0])
	var cap := float(fiche.get("cap", 0.0))
	if suivre_le_cap:
		rotation = Vector3(0.0, cap, 0.0)
	# Le decalage est exprime DANS le repere du lieu : « trois metres a
	# droite » reste a droite quelle que soit l'orientation de la rue.
	var tourne := decalage.rotated(Vector3.UP, cap if suivre_le_cap else 0.0)
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2])) + tourne


## La fiche d'un lieu, ou un dictionnaire vide.
static func trouver(nom: String) -> Dictionary:
	_charger()
	return _lieux.get(nom, {})


## Tous les lieux nommes, par ordre alphabetique. Sert aux outils de test : une
## liste ou l'on cherche un nom se parcourt, donc elle se trie. L'ordre du
## generateur, lui, est celui de la construction — il change a chaque
## regeneration de la ville.
static func noms() -> Array:
	_charger()
	var sortie: Array = _lieux.keys()
	sortie.sort()
	return sortie


static func _charger() -> void:
	if _lu:
		return
	_lu = true
	if not FileAccess.file_exists(FICHIER):
		push_error("ancrage : %s introuvable" % FICHIER)
		return
	var brut: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(brut) != TYPE_DICTIONARY:
		push_error("ancrage : %s illisible" % FICHIER)
		return
	for l in (brut as Dictionary).get("lieux", []):
		_lieux[str((l as Dictionary).get("nom", ""))] = l
	print("ANCRAGE : %d lieu(x) nomme(s)" % _lieux.size())
