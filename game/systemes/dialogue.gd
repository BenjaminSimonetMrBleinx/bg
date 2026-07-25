# Les conversations.
#
# Le texte n'est nulle part dans le code : il vit dans donnees/dialogues.json,
# et Guillaume peut le reecrire sans ouvrir Godot. Ce script ne fait que
# derouler ce qu'il y trouve.
#
# Une seule conversation a la fois. Elle avance replique par replique sur la
# touche d'interaction, et se termine d'elle-meme a la derniere.
class_name Dialogue
extends Node

const FICHIER := "res://donnees/dialogues.json"

signal termine

@export var cadre: NodePath
@export var etiquette_nom: NodePath
@export var etiquette_texte: NodePath

var _donnees: Dictionary = {}
var _repliques: Array = []
var _index: int = 0
var _actif: bool = false

## Combien de fois on a deja parle a chacun. C'est ce compteur qui fait
## tourner les conversations : reparler a quelqu'un ne rejoue pas la meme
## scene, ce qui suffit a donner l'impression que le monde avance.
var _vus: Dictionary = {}

var _cadre: Control
var _nom: Label
var _texte: Label


func _ready() -> void:
	_cadre = get_node_or_null(cadre) as Control
	_nom = get_node_or_null(etiquette_nom) as Label
	_texte = get_node_or_null(etiquette_texte) as Label
	if _cadre != null:
		_cadre.visible = false
	_charger()


func _charger() -> void:
	if not FileAccess.file_exists(FICHIER):
		push_error("dialogue : %s introuvable" % FICHIER)
		return
	var brut := FileAccess.get_file_as_string(FICHIER)
	var lu: Variant = JSON.parse_string(brut)
	if typeof(lu) != TYPE_DICTIONARY:
		# Une virgule en trop dans le JSON et tout le monde devient muet, sans
		# la moindre erreur ailleurs. On le dit fort.
		push_error("dialogue : %s illisible. Verifier les virgules." % FICHIER)
		return
	_donnees = lu
	var gens := 0
	for cle in _donnees:
		if typeof(_donnees[cle]) == TYPE_DICTIONARY:
			gens += 1
	print("DIALOGUE : %d personnage(s) charges" % gens)


func actif() -> bool:
	return _actif


## Ouvre la conversation suivante de ce personnage. Renvoie faux s'il n'a
## rien a dire — l'appelant ne doit alors pas proposer de lui parler.
func demarrer(cle: String) -> bool:
	if _actif or not _donnees.has(cle):
		return false
	var fiche: Dictionary = _donnees[cle]
	var conversations: Array = fiche.get("conversations", [])
	if conversations.is_empty():
		return false

	var tour := int(_vus.get(cle, 0))
	_repliques = conversations[tour % conversations.size()]
	_vus[cle] = tour + 1
	_index = 0
	_actif = true
	if _cadre != null:
		_cadre.visible = true
	_montrer()
	return true


## Passe a la replique suivante, ou ferme si c'etait la derniere.
func avancer() -> void:
	if not _actif:
		return
	_index += 1
	if _index >= _repliques.size():
		_fermer()
		return
	_montrer()


func _montrer() -> void:
	var r: Dictionary = _repliques[_index]
	if _nom != null:
		_nom.text = str(r.get("qui", ""))
	if _texte != null:
		_texte.text = str(r.get("texte", ""))


func _fermer() -> void:
	_actif = false
	_repliques = []
	if _cadre != null:
		_cadre.visible = false
	termine.emit()


## Ce personnage a-t-il une fiche ? Une cle mal orthographiee ne se voit
## autrement qu'en allant lui parler et en le trouvant muet.
func connait(cle: String) -> bool:
	return _donnees.has(cle) and typeof(_donnees[cle]) == TYPE_DICTIONARY


## Nom affichable d'un personnage, pour l'invite « Parler a ... ».
func nom_de(cle: String) -> String:
	if not _donnees.has(cle):
		return cle.capitalize()
	return str((_donnees[cle] as Dictionary).get("nom", cle.capitalize()))
