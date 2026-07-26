# Viser et tirer.
#
# Clic droit vise, clic gauche tire, et ca ne marche que le revolver en main.
# La roue des outils a laisse le clic droit pour ca — elle est passee sur Tab
# seul. Partager la touche selon qu'on tient une arme ou non aurait donne une
# commande dont l'effet depend d'un etat invisible.
#
# LA BALLE N'EST PAS UN PROJECTILE. C'est un rayon, tire dans l'axe de la
# camera, et les cibles sont testees par leur distance a ce rayon plutot que
# par un corps de collision. Deux raisons :
#
#   - aucun PNJ n'a de corps physique, et leur en donner un a tous obligerait
#     a rouvrir chaque scene pour un besoin qui n'existe que dans cette mission
#   - a 512 pixels de large, un homme a vingt metres fait huit pixels. Exiger
#     la precision au centimetre ne rendrait pas le tir difficile, juste casse
#
# Le decor, lui, est bien teste en physique : sans ca on tire a travers les
# murs, ce qui se remarque immediatement au QG de Tuco.
class_name Tir
extends Node

## Emis quand une balle touche quelqu'un. Le controleur decide de la suite —
## la reaction d'un PNJ abattu est une affaire de scenario, pas de balistique.
signal touche(qui: Pnj)
signal tire

## Portee utile, en metres. Au-dela, la balle part dans le vide : on ne joue
## pas au tireur d'elite dans un jeu ou l'on voit a trois cents metres.
const PORTEE := 60.0

## Tolerance angulaire, en metres a la distance de la cible. Voir plus haut.
const RAYON_UTILE := 0.45

## Delai minimal entre deux coups, en secondes. Un revolver a simple action.
const CADENCE := 0.55

@export var reglages: Reglages

var _camera: Camera3D
var _joueur: Joueur
var _equipement: Equipement
var _audio: Audio

var _vise: bool = false
var _repos: float = 0.0
var _actif: bool = true


func brancher(camera: Camera3D, joueur: Joueur, equipement: Equipement) -> void:
	_camera = camera
	_joueur = joueur
	_equipement = equipement


func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio


## Vise-t-on ? Lu par le HUD, qui dessine le reticule, et par la camera.
func vise() -> bool:
	return _vise


## Le revolver est-il en main ? Tout le reste en decoule : sans arme, ni la
## visee ni le tir n'existent, et le clic droit ne fait rien du tout.
func arme_en_main() -> bool:
	return _equipement != null and _equipement.cle_equipee() == "arme"


func suspendre(oui: bool) -> void:
	_actif = not oui
	if oui:
		_vise = false


## A appeler chaque image par le controleur. Renvoie vrai si le tir a pris la
## main — le controleur n'affiche alors pas ses invites habituelles.
func traiter(delta: float) -> bool:
	_repos = maxf(0.0, _repos - delta)
	if not _actif or _camera == null or not arme_en_main():
		_vise = false
		return false

	_vise = Input.is_action_pressed("viser")
	if _vise and Input.is_action_just_pressed("tirer") and _repos <= 0.0:
		_repos = CADENCE
		_faire_feu()
	return _vise


func _faire_feu() -> void:
	tire.emit()
	if _son() != null:
		_son().bruit_ici("coup_de_feu", _joueur.global_position,
				randf_range(0.94, 1.06))

	var depart := _camera.global_position
	var direction := -_camera.global_transform.basis.z

	# Jusqu'ou la balle va avant de rencontrer le decor. On coupe la recherche
	# de cibles a cette distance : tirer a travers un mur se voit tout de suite.
	var bout := depart + direction * PORTEE
	var espace := _camera.get_world_3d().direct_space_state
	var requete := PhysicsRayQueryParameters3D.create(depart, bout)
	requete.exclude = [_joueur.get_rid()]
	var mur: Dictionary = espace.intersect_ray(requete)
	var portee_libre := PORTEE
	if not mur.is_empty():
		portee_libre = depart.distance_to(mur["position"])

	var vise: Pnj = null
	var meilleure := INF
	for n in _joueur.get_tree().get_nodes_in_group(Pnj.GROUPE):
		var p := n as Pnj
		if p == null or p.abattu or not p.is_inside_tree():
			continue
		var vers: Vector3 = p.point_vise() - depart
		var avance := vers.dot(direction)
		if avance <= 0.5 or avance > portee_libre:
			continue
		# Distance du centre de la cible a la ligne de tir. C'est tout le
		# calcul : la composante perpendiculaire de ce qui la separe du canon.
		var ecart := (vers - direction * avance).length()
		if ecart > RAYON_UTILE + p.LARGEUR * 0.0:
			continue
		if avance < meilleure:
			meilleure = avance
			vise = p

	if vise != null:
		vise.abattre()
		touche.emit(vise)


## La fusillade : ca tire de partout, on ne voit personne, et on meurt.
##
## Ce n'est pas un combat, c'est une punition — le prompt la veut expediee en
## une dizaine de coups. On ne modelise donc aucun tireur : un son, des degats
## etales, et c'est fini.
func riposte_mortelle(sur: Joueur) -> void:
	if _son() != null:
		_son().bruit_ici("fusillade", sur.global_position)
	var arbre := sur.get_tree()
	for i in 8:
		await arbre.create_timer(randf_range(0.10, 0.30)).timeout
		if not is_instance_valid(sur) or not sur.vivant():
			return
		if sur.blesser(18.0):
			return
