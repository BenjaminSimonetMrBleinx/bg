# La zone du desert.
#
# Ce n'est PAS une seconde scene. Elle est posee a neuf cents metres du centre
# ville, dans le meme monde, exactement comme les interieurs de maison le sont
# deja. On y va par un fondu au noir, on en revient pareil, et il n'y a rien a
# sauvegarder puisque rien n'est decharge : la voiture, l'equipement et le
# moment de la journee sont les memes objets, simplement ailleurs.
#
# Une vraie scene aurait demande un mecanisme de transfert d'etat — le premier
# bout d'infrastructure de ce projet qui ne soit pas du decor. On l'a evite
# pour un dixieme du prix. La limite est connue : tout tient en memoire en meme
# temps. A deux zones et deux interieurs c'est gratuit ; a vingt il faudra
# faire le vrai travail, et ce jour-la on saura ce qu'on y met.
extends Node3D

@export var reglages: Reglages

## Le terrain, produit par outils/gen_desert.py.
@export var geometrie: PackedScene

## Le camping-car. Decor : on ne le conduit pas.
@export var camping_car: PackedScene

const DECOR := "res://assets/decor/%s.glb"

## Ou l'on arrive en venant de la ville, et dans quelle direction on regarde.
##
## Cap ZERO, donc face a -Z : on entre DANS la zone. Une premiere version
## arrivait a 180 degres et deposait le joueur au bord du terrain, dos au
## desert, face au vide — et comme la piste s'etend jusqu'au bord, l'image
## etait plausible. Rien ne signalait qu'on regardait dehors.
const ARRIVEE := Vector3(0.0, 0.4, 150.0)
const CAP_ARRIVEE := 0.0

## Le camping-car, a l'ecart de la piste. C'est le seul point de repere de la
## zone : trop loin il ne se voit pas, trop pres il bouche la route.
const CAMPING_CAR := Vector3(-23.0, 0.0, 96.0)
const CAP_CAMPING_CAR := 108.0


func _ready() -> void:
	if geometrie == null:
		push_error("desert : aucune geometrie assignee. Regenerer : "
				+ "blender -b -P outils/gen_desert.py")
		return
	var sol := geometrie.instantiate()
	add_child(sol)
	_ajouter_collisions(sol)

	if camping_car != null:
		var cc := camping_car.instantiate() as Node3D
		cc.name = "CampingCar"
		cc.position = CAMPING_CAR
		cc.rotation.y = deg_to_rad(CAP_CAMPING_CAR)
		add_child(cc)
		_ajouter_collisions(cc)
	else:
		push_warning("desert : pas de camping-car")

	# La fleche du retour, posee sur la piste derriere le point d'arrivee. Elle
	# est le seul indice qu'on peut repartir : sans elle, la zone est un
	# cul-de-sac et on cherche la sortie.
	# La fleche du retour pointe vers la ville, donc vers +Z : un demi-tour par
	# rapport a celle de l'aller. Elle est le seul indice qu'on peut repartir —
	# sans elle, la zone est un cul-de-sac et on cherche la sortie.
	_poser("fleche_sol", ARRIVEE + Vector3(0.0, -0.4, 6.0), 180.0)
	# Le panneau se pose A COTE de la piste, pas dessus : la piste fait douze
	# metres de large, un panneau plante a six metres de son axe est encore
	# dedans, et on le prend en roulant.
	_poser("panneau_desert", ARRIVEE + Vector3(10.5, -0.4, 9.0), 0.0)


# Meme dispositif que pour la ville : les collisions sont fabriquees a la
# volee. Une geometrie regeneree a chaque changement de graine rendrait des
# collisions figees fausses, et une collision fausse ne se voit qu'en tombant
# au travers.
func _ajouter_collisions(noeud: Node) -> void:
	if noeud is MeshInstance3D:
		var mi := noeud as MeshInstance3D
		if mi.mesh != null:
			mi.create_trimesh_collision()
	for enfant in noeud.get_children():
		_ajouter_collisions(enfant)


func _poser(type: String, ou: Vector3, angle: float) -> void:
	var chemin := DECOR % type
	if not ResourceLoader.exists(chemin):
		push_error("desert : %s introuvable. Regenerer : " % chemin
				+ "blender -b -P outils/gen_decor.py -- --nom tous")
		return
	var n := (ResourceLoader.load(chemin) as PackedScene).instantiate() as Node3D
	n.name = type
	n.position = ou
	n.rotation.y = deg_to_rad(angle)
	add_child(n)


## Le point d'arrivee, en coordonnees du monde. Le passage de la ville le lit
## plutot que de porter une copie : deux coordonnees ecrites a deux endroits
## finissent toujours par diverger, et celle-ci depose le joueur dans le vide.
func arrivee() -> Vector3:
	return global_position + ARRIVEE


func cap_arrivee() -> float:
	return CAP_ARRIVEE
