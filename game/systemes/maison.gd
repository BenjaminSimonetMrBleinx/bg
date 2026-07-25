# Une maison : sa facade dans la ville, son interieur a l'ecart du monde.
#
# Les deux ne se touchent jamais. L'interieur est pose plusieurs centaines de
# metres a l'ecart, la ou rien ne peut interferer — pas de lumiere de rue qui
# passe a travers, pas de camera qui accroche un mur exterieur. C'est ainsi
# que faisaient les jeux PS2, et ca reste la reponse la plus simple.
class_name Maison
extends Node3D

@export var nom_affiche: String = "Maison"
@export var geometrie_ext: PackedScene
@export var geometrie_int: PackedScene

## Deplacement applique a l'interieur, en local. Doit etre assez grand pour
## sortir completement de la ville, et different d'une maison a l'autre.
@export var decalage_interieur: Vector3 = Vector3(-600.0, 0.0, 600.0)

## Eclairage de la piece. Un interieur sans source est parfaitement noir :
## le brouillard de rue et les lampadaires ne l'atteignent pas.
@export var lumiere_energie: float = 3.2
@export var lumiere_couleur: Color = Color(1.0, 0.898, 0.769)

var _seuil: Node3D
var _sortie: Node3D
var _habitant: Node3D
var _racine_int: Node3D


func _ready() -> void:
	_poser_exterieur()
	_poser_interieur()


func _poser_exterieur() -> void:
	if geometrie_ext == null:
		push_error("maison %s : aucune geometrie exterieure" % nom_affiche)
		return
	var n := geometrie_ext.instantiate()
	add_child(n)
	_collisionner(n)
	_seuil = n.find_child("Porte", true, false) as Node3D


func _poser_interieur() -> void:
	if geometrie_int == null:
		push_error("maison %s : aucune geometrie interieure" % nom_affiche)
		return
	_racine_int = Node3D.new()
	_racine_int.name = "Interieur"
	_racine_int.position = decalage_interieur
	add_child(_racine_int)

	var n := geometrie_int.instantiate()
	_racine_int.add_child(n)
	_collisionner(n)
	_sortie = n.find_child("Sortie", true, false) as Node3D
	_habitant = n.find_child("Habitant", true, false) as Node3D

	var lampe := OmniLight3D.new()
	lampe.name = "Plafonnier"
	lampe.position = Vector3(0.0, 2.35, 0.0)
	lampe.light_color = lumiere_couleur
	lampe.light_energy = lumiere_energie
	lampe.omni_range = 16.0
	lampe.omni_attenuation = 1.2
	_racine_int.add_child(lampe)


# Les .glb ne contiennent que des maillages. On leur fabrique des corps
# statiques a la volee : la geometrie etant regeneree a chaque changement de
# parametre, des collisions stockees se desynchroniseraient.
func _collisionner(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		(n as MeshInstance3D).create_trimesh_collision()
	for e in n.get_children():
		_collisionner(e)


## Devant la porte, cote rue. C'est la qu'on detecte la proximite et qu'on
## repose le joueur en ressortant.
func seuil() -> Vector3:
	return _seuil.global_position if _seuil != null else global_position


## Ou l'on depose le joueur quand il entre.
func entree() -> Vector3:
	return _sortie.global_position if _sortie != null else _interieur_centre()


## Ou se tient le personnage de la maison.
func place_habitant() -> Vector3:
	return _habitant.global_position if _habitant != null else _interieur_centre()


func _interieur_centre() -> Vector3:
	return _racine_int.global_position if _racine_int != null else global_position
