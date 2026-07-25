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


func _ready() -> void:
	_cap_repos = rotation.y
	if geometrie == null:
		push_error("pnj %s : aucune geometrie" % cle)
		return
	add_child(geometrie.instantiate())


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
