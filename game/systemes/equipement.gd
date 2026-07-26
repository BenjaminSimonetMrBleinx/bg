# Ce que Walter tient en main, ou porte sur la tete.
#
# Les objets sont charges une fois pour toutes au demarrage et accroches a
# leur segment de corps, puis simplement masques. Les instancier a chaque
# changement provoquerait un temps de chargement au moment precis ou l'on
# tourne la roue — c'est-a-dire au pire moment.
#
# Rien de ce fichier ne connait un objet en particulier : tout vient de
# donnees/outils.json, y compris la liste et l'ordre des parts de la roue.
class_name Equipement
extends Node

const FICHIER := "res://donnees/outils.json"
const DOSSIER := "res://assets/objets/%s.glb"

## Aucun objet en main. Vaut mieux qu'un index nul : « les mains vides » est
## un etat legitime, pas une absence de donnee.
const RIEN := -1

signal change(index: int)

## Le personnage qui porte les objets. Ses segments sont retrouves par nom.
@export var porteur: NodePath

var _fiches: Array = []
var _noeuds: Array[Node3D] = []
var _actif: int = RIEN
var _porteur: Node3D
var _audio: Audio

## Le systeme audio, retrouve A LA DEMANDE et garde ensuite.
##
## Pas dans _ready() : le noeud Audio est declare plus bas dans la scene, donc
## il n'est pas encore dans son groupe quand celui-ci s'initialise. Le chercher
## trop tot donnait null, definitivement, et le silence qui suit ressemble a un
## mecanisme pas encore branche.
func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio


func _ready() -> void:
	_porteur = get_node_or_null(porteur) as Node3D
	if _porteur == null:
		push_error("equipement : porteur introuvable (%s)" % porteur)
		return
	_charger()
	_accrocher()


func _charger() -> void:
	if not FileAccess.file_exists(FICHIER):
		push_error("equipement : %s introuvable" % FICHIER)
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(lu) != TYPE_DICTIONARY:
		push_error("equipement : %s illisible. Verifier les virgules." % FICHIER)
		return
	_fiches = (lu as Dictionary).get("outils", [])


func _accrocher() -> void:
	for fiche in _fiches:
		var cle := str(fiche.get("cle", ""))
		var chemin := DOSSIER % cle
		if not ResourceLoader.exists(chemin):
			push_error("equipement : %s introuvable. Regenerer : " % chemin
					+ "blender -b -P outils/gen_objets.py -- --nom tous")
			_noeuds.append(null)
			continue

		var ancre := _segment(str(fiche.get("ancrage", "MainD")))
		if ancre == null:
			_noeuds.append(null)
			continue

		var n := (ResourceLoader.load(chemin) as PackedScene).instantiate() as Node3D
		n.position = _vecteur(fiche.get("position", [0, 0, 0]))
		var r := _vecteur(fiche.get("rotation", [0, 0, 0]))
		n.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
		n.scale = Vector3.ONE * float(fiche.get("echelle", 1.0))
		n.visible = false
		ancre.add_child(n)
		_noeuds.append(n)

	var manquants := _noeuds.count(null)
	print("EQUIPEMENT : %d objet(s) accroches sur %d" %
			[_noeuds.size() - manquants, _fiches.size()])


## Ou accrocher, quand le personnage a un SQUELETTE au lieu de segments.
##
## Les deux corps coexistent : Walter est rigge, les passants sont encore des
## hierarchies de segments nommes. Plutot que d'imposer un vocabulaire au rig
## livre — ce qui obligerait Guillaume a renommer ses os a chaque fois — on
## traduit ici. Les noms de droite sont ceux de tout rig humanoide.
const OS_DU_RIG := {
	"MainD": "RightHand",
	"MainG": "LeftHand",
	"Tete": "Head",
	"Torse": "Spine02",
	"Bassin": "Hips",
}


# Sur un squelette, un objet ne s'accroche pas a un noeud : il faut un
# BoneAttachment3D, qui suit l'os image par image. Un Node3D pose a cote ne
# bougerait pas d'un pouce pendant que le bras, lui, bouge.
func _segment(nom: String) -> Node3D:
	var squelette := _porteur.find_child("Skeleton3D", true, false) as Skeleton3D
	if squelette != null:
		var os := str(OS_DU_RIG.get(nom, nom))
		if squelette.find_bone(os) < 0:
			push_error("equipement : os '%s' absent du squelette (pour '%s'). "
					% [os, nom] + "Os disponibles : %s"
					% ", ".join(_noms_des_os(squelette)))
			return null
		# Un attache par os, reutilise : quatre objets sur la meme main ne
		# demandent pas quatre attaches.
		var existant := squelette.get_node_or_null(NodePath("Attache_" + os))
		if existant != null:
			return existant as Node3D
		var attache := BoneAttachment3D.new()
		attache.name = "Attache_" + os
		attache.bone_name = os
		squelette.add_child(attache)
		return attache

	var n := _porteur.find_child(nom, true, false)
	if n is Node3D:
		return n as Node3D
	push_error("equipement : ni squelette, ni segment '%s' sur le personnage" % nom)
	return null


static func _noms_des_os(s: Skeleton3D) -> Array:
	var noms := []
	for i in s.get_bone_count():
		noms.append(s.get_bone_name(i))
	return noms


static func _vecteur(v: Variant) -> Vector3:
	var a: Array = v if typeof(v) == TYPE_ARRAY else [0, 0, 0]
	if a.size() < 3:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func nombre() -> int:
	return _fiches.size()


func nom_de(i: int) -> String:
	if i < 0 or i >= _fiches.size():
		return "Rien"
	return str(_fiches[i].get("nom", _fiches[i].get("cle", "?")))


func actif() -> int:
	return _actif


## Equipe l'objet d'indice i, ou RIEN pour ranger. Reequiper celui qu'on a
## deja en main le range : c'est le comportement attendu d'une roue, et ca
## evite d'avoir une part « rien » qui n'aurait servi qu'a ca.
func equiper(i: int) -> void:
	if i == _actif:
		i = RIEN
	for k in _noeuds.size():
		if _noeuds[k] != null:
			_noeuds[k].visible = (k == i)
	_actif = i
	_sonner(i)
	change.emit(i)


# Le nom du son se DEDUIT de la cle de l'objet : « livre » -> « objet_livre ».
# Ajouter un objet qui fait du bruit ne demande donc pas de toucher a ce
# fichier — une entree dans outils.json, une ligne dans sons.json, c'est tout.
#
# Un objet sans son declare est un cas parfaitement normal : l'arme n'en a
# pas. On verifie donc AVANT d'appeler, sinon chaque equipement d'arme
# imprimerait un avertissement pour un comportement voulu.
func _sonner(i: int) -> void:
	if _son() == null or i == RIEN or i >= _fiches.size():
		return
	var nom := "objet_%s" % str(_fiches[i].get("cle", ""))
	if _son().connait(nom):
		_son().bruit(nom)
