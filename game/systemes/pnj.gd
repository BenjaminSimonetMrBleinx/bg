# Un personnage non joueur, immobile chez lui.
#
# Il ne marche pas et n'a aucune intelligence : il se tourne vers le joueur
# quand celui-ci approche, et c'est tout. A ce stade du projet, se tourner
# suffit a faire la difference entre un decor et quelqu'un.
class_name Pnj
extends Node3D

## Cle dans donnees/dialogues.json. C'est le seul lien entre ce personnage
## et ce qu'il raconte.
@export var cle: String = ""

@export var geometrie: PackedScene

## Vitesse a laquelle il pivote vers le joueur, en radians par seconde.
@export_range(0.2, 12.0, 0.1) var rotation_vitesse: float = 3.0

## Distance a laquelle il remarque le joueur, en metres.
@export_range(0.5, 12.0, 0.1) var attention: float = 4.5

var _cible: Node3D
var _cap_repos: float = 0.0


## Tous les PNJ sont dans ce groupe. C'est ainsi que le tir les trouve, sans
## qu'aucun d'eux n'ait a porter de corps de collision : une balle teste la
## distance du rayon a chaque torse, ce qui suffit largement a la resolution
## du jeu et ne demande de toucher a aucune scene existante.
const GROUPE := "cible"

## Hauteur du torse au-dessus des pieds, en metres. C'est LA qu'on vise, pas
## a l'origine du noeud qui est au sol : viser les pieds oblige a tirer par
## terre pour toucher quelqu'un.
const TORSE := 1.15

## Rayon touchable, en metres. Genereux : le jeu se joue a la souris sur une
## image de 512 pixels de large, ou un personnage a vingt metres fait huit
## pixels. Exiger la precision au centimetre ne rendrait pas le tir difficile,
## juste cassé.
const LARGEUR := 0.45

var abattu: bool = false


func _ready() -> void:
	_cap_repos = rotation.y
	add_to_group(GROUPE)
	if geometrie == null:
		push_error("pnj %s : aucune geometrie" % cle)
		return
	add_child(geometrie.instantiate())


## Le centre de la cible, en coordonnees du monde.
func point_vise() -> Vector3:
	return global_position + Vector3.UP * TORSE


## Il prend une balle. On ne gere aucun point de vie : dans cette mission, tirer
## sur quelqu'un declenche une scene, ce n'est jamais un echange de coups.
func abattre() -> void:
	if abattu:
		return
	abattu = true
	set_process(false)


## Le joueur a surveiller. Passe par la maison, qui sait qui joue.
func observer(n: Node3D) -> void:
	_cible = n
	set_process(n != null)


func _process(delta: float) -> void:
	if _cible == null:
		return
	var vers := _cible.global_position - global_position
	vers.y = 0.0
	# Au-dela de sa portee d'attention il revient a sa pose de repos, sinon un
	# PNJ passe sa vie a fixer un mur dans la direction ou le joueur est sorti.
	var voulu := _cap_repos
	if vers.length() < attention and vers.length() > 0.05:
		voulu = atan2(-vers.x, -vers.z)      # l'avant d'un noeud Godot est -Z
	rotation.y = rotate_toward(rotation.y, voulu, rotation_vitesse * delta)
