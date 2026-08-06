# La purete du produit — cinq paliers, et une couleur dans la main.
#
# C'est la colonne vertebrale de la progression : un labo, une couleur, un type
# de client, et les trois avancent ensemble.
#
# LE JOUEUR NE VOIT JAMAIS CE NOMBRE. C'est la premiere regle de la direction,
# et elle n'est pas negociable : un pourcentage affiche transforme un choix en
# optimisation. On ne montre pas « 84 % », on montre un cristal qui a change de
# couleur depuis la derniere fois. Rien dans ce fichier ne sort vers le HUD ;
# la seule chose qui en sorte est une teinte, appliquee a l'objet tenu.
#
# CE QU'IL NE FAIT PAS ENCORE : le prix et la demande (#20), qui accepte de
# traiter avec vous (#31), et ce que coute une montee de palier (#28). Les trois
# se brancheront ici — palier() est deja la reponse qu'ils attendent.
class_name Purete
extends Node

## Emis a chaque changement, pour qui veut suivre. Le palier, jamais la valeur
## brute : meme en interne, on se parle en paliers.
signal changee(palier: int)

## Les cinq paliers, dans l'ordre. La couleur est ce que le joueur percoit ;
## le nom ne sert qu'aux journaux et aux tests.
##
## Le brun est celui de la premiere cuisine dans un camping-car, le bleu celui
## de la serie — et c'est le seul qui doive etre immediatement reconnaissable.
## Les trois du milieu doivent surtout se distinguer ENTRE EUX : c'est la que
## le joueur mesure ses progres, et deux teintes voisines ne lui apprendraient
## rien.
const PALIERS := [
	{"nom": "brun", "couleur": Color(0.44, 0.28, 0.15)},
	{"nom": "ambre", "couleur": Color(0.82, 0.51, 0.14)},
	{"nom": "clair", "couleur": Color(0.88, 0.85, 0.72)},
	{"nom": "translucide", "couleur": Color(0.80, 0.93, 0.90)},
	{"nom": "bleue", "couleur": Color(0.24, 0.62, 0.90)},
]

## La couleur MOYENNE de la texture du cristal, telle que gen_textures.py
## l'ecrit : ("cristal", (150, 196, 214)).
##
## Elle sert a calculer un multiplicateur plutot qu'a poser une couleur pleine.
## Peindre l'objet en aplat effacerait le grain et les eclats — on obtiendrait
## un sachet en plastique colore, pas du cristal. En multipliant, la matiere
## reste et seule la teinte se deplace.
const BASE := Color(150.0 / 255.0, 196.0 / 255.0, 214.0 / 255.0)

## Les objets teints par la purete. La botte secrete n'en est pas : c'est un
## cristal blanc, unique, et tout l'enjeu de la scene chez Tuco est qu'on le
## distingue du reste au premier coup d'oeil.
const TEINTS := ["meth"]

@export var equipement: NodePath

var _rang: int = 0
var _equipement: Equipement


func _ready() -> void:
	_equipement = get_node_or_null(equipement) as Equipement
	_appliquer()


## Le palier courant, de 1 a 5. C'est la seule facon de lire cet etat.
func palier() -> int:
	return _rang + 1


func nom() -> String:
	return str(PALIERS[_rang].get("nom", ""))


func couleur() -> Color:
	return PALIERS[_rang].get("couleur", Color.WHITE)


## Pose le palier, de 1 a 5. Sert a la reprise d'une partie, aux outils de test
## et aux captures.
func poser(p: int) -> void:
	var r := clampi(p - 1, 0, PALIERS.size() - 1)
	if r == _rang:
		return
	_rang = r
	_appliquer()
	changee.emit(palier())


## Monte d'un cran, s'il en reste. Renvoie faux au sommet : l'appelant s'en sert
## pour ne pas annoncer une amelioration qui n'a pas eu lieu.
func monter() -> bool:
	if _rang >= PALIERS.size() - 1:
		return false
	poser(palier() + 1)
	return true


# Le multiplicateur qui amene la texture de base a la couleur voulue. Calcule,
# pas ecrit a la main : le jour ou la couleur du cristal change dans
# gen_textures.py, on met a jour BASE et les cinq paliers suivent.
static func multiplicateur(cible: Color) -> Color:
	return Color(
			clampf(cible.r / maxf(BASE.r, 0.01), 0.0, 2.0),
			clampf(cible.g / maxf(BASE.g, 0.01), 0.0, 2.0),
			clampf(cible.b / maxf(BASE.b, 0.01), 0.0, 2.0))


func _appliquer() -> void:
	if _equipement == null:
		return
	var m := multiplicateur(couleur())
	for cle in TEINTS:
		_equipement.teinter(str(cle), m)
