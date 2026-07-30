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
##
## CETTE VALEUR EST UN SECOURS, PAS LA SOURCE. La position vraie est publiee
## par le generateur dans desert_lieux.json, parce que lui seul sait ou passe
## la piste — elle serpente, et deux constantes recopiees a la main se sont
## retrouvees AU MILIEU de la chaussee a la premiere courbe. On ne garde
## celle-ci que pour un terrain jamais regenere.
const CAMPING_CAR := Vector3(-23.0, 0.0, 96.0)
const CAP_CAMPING_CAR := 108.0

## Les lieux publies par outils/gen_desert.py : le camping-car, le fosse de la
## mission 1, les mesas, le passage de l'arroyo.
const LIEUX := "res://assets/desert/desert_lieux.json"

var _lieux: Dictionary = {}


## Un lieu du desert, en coordonnees du MONDE. Vector3.INF si inconnu — les
## missions demandent par nom et ne recopient jamais de coordonnees.
func lieu(nom: String) -> Vector3:
	if not _lieux.has(nom):
		return Vector3.INF
	var p: Array = _lieux[nom]
	return global_position + Vector3(float(p[0]), float(p[1]), float(p[2]))


func _charger_les_lieux() -> void:
	if not FileAccess.file_exists(LIEUX):
		push_warning("desert : %s absent, positions de secours. Regenerer : "
				% LIEUX + "blender -b -P outils/gen_desert.py")
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIEUX))
	if typeof(lu) != TYPE_DICTIONARY:
		push_error("desert : %s illisible" % LIEUX)
		return
	_lieux = (lu as Dictionary).get("lieux", {})
	print("desert : %d lieu(x) nomme(s)" % _lieux.size())


func _ready() -> void:
	if geometrie == null:
		push_error("desert : aucune geometrie assignee. Regenerer : "
				+ "blender -b -P outils/gen_desert.py")
		return
	var sol := geometrie.instantiate()
	add_child(sol)
	_ajouter_collisions(sol)

	_charger_les_lieux()

	if camping_car != null:
		var cc := camping_car.instantiate() as Node3D
		cc.name = "CampingCar"
		# La position publiee l'emporte : elle tient compte du relief et de la
		# courbe de la piste, que la constante ignore.
		var pose := lieu("camping_car")
		cc.position = (pose - global_position) if pose != Vector3.INF else CAMPING_CAR
		cc.rotation.y = deg_to_rad(CAP_CAMPING_CAR)
		add_child(cc)
		_encaisser(cc)
	else:
		push_warning("desert : pas de camping-car")

	# La fleche du retour, posee sur la piste derriere le point d'arrivee. Elle
	# est le seul indice qu'on peut repartir : sans elle, la zone est un
	# cul-de-sac et on cherche la sortie.
	# La fleche du retour pointe vers la ville, donc vers +Z : un demi-tour par
	# rapport a celle de l'aller. Elle est le seul indice qu'on peut repartir —
	# sans elle, la zone est un cul-de-sac et on cherche la sortie.
	# Fleche et panneau se posent RELATIVEMENT au point d'arrivee reel, pas a
	# la constante : la piste serpente, et l'ancienne arrivee ecrite en dur
	# tombait vingt-six metres a cote de la chaussee.
	var ici := arrivee() - global_position
	_poser("fleche_sol", ici + Vector3(0.0, -0.4, 6.0), 180.0)
	# Le panneau se pose A COTE de la piste, pas dessus : la piste fait douze
	# metres de large, un panneau plante a six metres de son axe est encore
	# dedans, et on le prend en roulant.
	#
	# Il annonce ALBUQUERQUE, pas DESERT. C'est le panneau du RETOUR, pose sur
	# le point d'arrivee : il dit ou mene la route qu'il signale, et il disait
	# donc au joueur deja dans le desert qu'il allait au desert.
	_poser("panneau_albuquerque", ici + Vector3(10.5, -0.4, 9.0), 0.0)


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


# LE CAMPING-CAR EST UNE CAISSE, PAS UN MAILLAGE.
#
# Il avait la meme collision que le terrain : une trimesh calquee sur la
# geometrie. Sur un sol c'est ce qu'il faut ; sur un vehicule dont la carrosserie
# a des creux — le passage de roue, le renfoncement de la porte, la jupe sous la
# cellule — la capsule du joueur se glisse dedans, se retrouve coincee entre
# deux faces, et il ne reste plus qu'a recharger. Sauter contre le flanc suffit
# a s'y loger.
#
# Une seule boite calquee sur l'encombrement supprime la cause : il n'y a plus
# de creux ou entrer. On perd la forme exacte, ce qui ne se voit pas — personne
# ne longe un camping-car en frottant la tole pour verifier son galbe.
#
# L'encombrement est MESURE sur la geometrie, pas ecrit ici : le modele est
# regenere par outils/gen_desert.py, et des cotes recopiees a la main
# divergeraient au premier changement.
func _encaisser(noeud: Node3D) -> void:
	var boite := AABB()
	var premier := true
	for mi in _maillages(noeud):
		if mi.mesh == null:
			continue
		# Dans le repere du camping-car, pas dans celui du maillage : un modele
		# assemble de plusieurs morceaux decales donnerait sinon une boite
		# centree sur le mauvais element.
		var locale := noeud.global_transform.affine_inverse() \
				* mi.global_transform
		var part := locale * mi.mesh.get_aabb()
		boite = part if premier else boite.merge(part)
		premier = false
	if premier:
		push_warning("desert : camping-car sans maillage, aucune collision")
		return

	var corps := StaticBody3D.new()
	corps.name = "Coque"
	var forme := CollisionShape3D.new()
	var caisse := BoxShape3D.new()
	caisse.size = boite.size
	forme.shape = caisse
	forme.position = boite.get_center()
	corps.add_child(forme)
	noeud.add_child(corps)


func _maillages(n: Node) -> Array[MeshInstance3D]:
	var trouves: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		trouves.append(n as MeshInstance3D)
	for e in n.get_children():
		trouves.append_array(_maillages(e))
	return trouves


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
	var pose := lieu("arrivee")
	return pose if pose != Vector3.INF else global_position + ARRIVEE


func cap_arrivee() -> float:
	return CAP_ARRIVEE
