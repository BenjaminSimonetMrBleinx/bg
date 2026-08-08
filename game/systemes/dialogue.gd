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
const VOIX := "res://assets/voix/%s_%s.wav"

## Les voix sortent sur le bus Interface : c'est du hors-champ, comme le
## reste de l'habillage, et ca les met sous le meme curseur de volume.
const BUS_VOIX := "Interface"

## Une voix qui traverse un appareil ne sort pas sur le meme bus.
##
## Le champ 'canal' d'une replique nomme l'appareil qu'elle traverse. Les bus
## correspondants vivent dans default_bus_layout.tres, ils renvoient tous sur
## Interface, et c'est la que se reglent les filtres — pas ici.
##
## SEUL LE CORRESPONDANT PORTE UN CANAL. Walter est le joueur : il est dans la
## piece, sa voix ne traverse rien, meme quand c'est lui qui tient le combine.
const BUS_PAR_CANAL := {
	"telephone": "Telephone",
	"interphone": "Interphone",
}

signal termine

## Emis quand la replique affichee porte un champ 'effet'.
##
## CE QUI SE PASSE DOIT SE PASSER SUR LA PHRASE QUI LE DIT. L'argent de Tuco
## arrivait a la FIN de la conversation, donc vingt repliques apres « compte-les
## si tu veux » — et la fouille du garde, de meme, avait deja eu lieu quand il
## annoncait la trouver. Une scene ou l'action et le texte ne coincident pas se
## lit comme deux scenes.
##
## Le dialogue ne sait pas ce qu'un effet veut dire, et c'est voulu : il porte
## un nom, le scenario decide. Ajouter un moment cle a une conversation est
## donc un mot de plus dans dialogues.json.
signal effet(nom: String)

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
var _lecteur: AudioStreamPlayer

## Personnages deja signales comme muets. Sans ce garde, une voix manquante
## remplit la console d'un avertissement par replique.
var _manquantes: Dictionary = {}


func _ready() -> void:
	_cadre = get_node_or_null(cadre) as Control
	_nom = get_node_or_null(etiquette_nom) as Label
	_texte = get_node_or_null(etiquette_texte) as Label
	if _cadre != null:
		_cadre.visible = false

	# Non positionne : une voix de dialogue ne doit pas baisser quand le
	# joueur tourne la tete. C'est du hors-champ, pas une source du monde.
	_lecteur = AudioStreamPlayer.new()
	_lecteur.name = "Voix"
	_lecteur.bus = BUS_VOIX
	add_child(_lecteur)

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


## Qui vient de parler. Le signal `termine` ne porte pas cette information, et
## la lui ajouter aurait casse tous ceux qui l'ecoutent deja ; une lecture
## apres coup fait le meme travail. C'est par elle que la mission sait quelle
## conversation vient de se finir.
func cle_courante() -> String:
	return _cle

var _cle: String = ""


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
	_cle = cle
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
	_dire(str(r.get("qui", "")), _prononce(r), str(r.get("canal", "")))
	var e := str(r.get("effet", ""))
	if e != "":
		effet.emit(e)


## CE QUI EST PRONONCE, qui n'est plus ce qui est affiche.
##
## Depuis le 08/08/2026 le jeu se joue en VO anglaise sous-titree francais :
## 'vo' est la phrase dite, 'texte' le sous-titre. L'empreinte qui nomme le
## fichier son doit donc porter sur 'vo' — c'est la regle d'origine appliquee
## telle quelle, pas une exception. Elle dit : le nom suit ce qui est ENREGISTRE.
## Reecrire la VO change le fichier ; retoucher une virgule du sous-titre ne
## jette pas une prise qui reste juste.
##
## 'jeu' EST LA DIRECTION D'ACTEUR, et elle compte dans l'empreinte.
##
## Le champ porte une intention — « furious », « exasperated », « quiet, tense »
## — que le moteur de synthese interprete sans la prononcer. Elle fait donc
## partie de ce qui est ENREGISTRE, au meme titre que les mots : la meme phrase
## dite calmement ou en hurlant sont deux prises differentes, et elles ne
## peuvent pas partager un nom de fichier.
##
## Consequence voulue : changer l'intention d'une replique la fait regenerer
## toute seule, et laisser 'jeu' vide rend exactement l'empreinte d'avant. Les
## repliques deja doublees ne bougent donc pas tant qu'on ne les dirige pas.
##
## Une replique sans 'vo' retombe sur 'texte' : c'est le cas des repliques pas
## encore traduites, et elles gardent leur voix francaise en attendant.
static func _prononce(replique: Dictionary) -> String:
	var vo := str(replique.get("vo", ""))
	if vo == "":
		return str(replique.get("texte", ""))
	var jeu := str(replique.get("jeu", ""))
	if jeu == "":
		return vo
	return "[%s] %s" % [jeu, vo]


# Joue l'enregistrement de cette replique, s'il existe.
#
# Le nom du fichier est deduit de CE QUI EST DIT, pas d'un index : l'empreinte
# MD5 des dix premiers caracteres suffit. Reecrire une replique change son
# empreinte, donc son fichier — impossible d'entendre l'ancienne version sur le
# nouveau texte, ce qu'un index numerique aurait permis sans rien signaler.
func _dire(qui: String, texte: String, canal: String = "") -> void:
	if _lecteur == null:
		return
	_lecteur.stop()

	# Le bus se choisit AVANT de jouer : en changer pendant la lecture ne
	# reprend pas le son deja envoye au melangeur, et la premiere syllabe
	# sortirait sur le bus precedent.
	#
	# Un canal inconnu retombe sur la voix normale plutot que de rester muet :
	# une faute de frappe dans dialogues.json doit s'entendre comme une voix
	# non filtree, pas comme un personnage qui a perdu la parole.
	var bus: String = BUS_PAR_CANAL.get(canal, BUS_VOIX)
	if AudioServer.get_bus_index(bus) < 0:
		push_warning("dialogue : bus '%s' introuvable, voix en direct" % bus)
		bus = BUS_VOIX
	_lecteur.bus = bus

	var chemin := VOIX % [_simplifier(qui), texte.md5_text().substr(0, 10)]
	if not ResourceLoader.exists(chemin):
		if not _manquantes.has(qui):
			_manquantes[qui] = true
			push_warning("dialogue : aucune voix pour %s. Generer : .\\bg.ps1 voix"
					% qui)
		return
	_lecteur.stream = ResourceLoader.load(chemin) as AudioStream
	_lecteur.play()


# Doit produire exactement le meme nom que outils/gen_voix.ps1. Les deux
# cotes se rejoignent sur un nom de fichier et rien d'autre : s'ils divergent,
# le jeu cherche un fichier qui n'existe pas et reste muet sans erreur.
static func _simplifier(nom: String) -> String:
	var sortie := ""
	for c in nom.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			sortie += c
	return sortie


## Interrompt la conversation en cours. Raccrocher au milieu d'un appel doit
## couper la voix : sinon le correspondant continue de parler dans le vide,
## combine range.
func couper() -> void:
	if not _actif:
		return
	if _lecteur != null:
		_lecteur.stop()
	_fermer()


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
