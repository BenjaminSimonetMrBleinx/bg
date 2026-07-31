# Les passants de la rue.
#
# Ils sont fabriques ici plutot que poses dans la scene : leurs apparences et
# leurs allures viennent du generateur de ville, en meme temps que les
# lampadaires et le mobilier. Une ville regeneree avec une autre graine
# repeuple ses trottoirs toute seule.
#
# Chaque passant est un CharacterBody3D monte a la volee — capsule, maillage,
# script. Une scene .tscn par modele de passant aurait impose d'en creer une
# nouvelle a chaque personnage ajoute au generateur, pour trois lignes de
# difference.
#
# LEUR NOMBRE NE DEPEND PAS DE LA TAILLE DE LA VILLE, ET C'EST LE POINT.
#
# Il en dependait : le generateur ecrivait un trajet par cote d'ilot, donc
# quinze passants sur quatre ilots et deux cent cinquante-cinq sur soixante-
# quatre. Mesure du 30/07/2026, ville de 473 m de cote :
#
#     avec les 255 passants     6 images/seconde
#     sans les passants        55 images/seconde
#
# Tout le reste — 512 lampadaires, 1682 elements de decor, 408 voitures garees,
# douze mille faces — ne coutait rien. Un passant coute 0,6 ms par image a lui
# seul : capsule physique, glissement contre le decor, et une demarche calculee
# os par os.
#
# On en garde donc un NOMBRE FIXE, comme le trafic, et on les recycle autour du
# joueur. Une foule ne se juge pas au total : elle se juge a ce qu'on voit dans
# la rue ou l'on est, et personne ne comptera jamais ceux d'en face.
class_name Foule
extends Node3D

@export var reglages: Reglages
@export var routes_json: String = "res://assets/ville/ville_lampes.json"

const MODELE := "res://assets/personnages/%s.glb"

## Hauteur et rayon de la capsule. Identiques au joueur : c'est le meme
## maillage, il doit occuper la meme place.
const TAILLE := 1.78
const RAYON := 0.28

## Combien de passants existent en meme temps, quelle que soit la surface de la
## ville.
##
## Seize suffisaient a peupler quatre ilots. Repartis dans un anneau de
## quatre-vingt-quinze metres autour du joueur, ils devenaient INVISIBLES :
## trois captures de rue d'affilee n'en montraient pas un seul. Une foule qu'on
## ne croise jamais coute le meme prix qu'une foule qu'on croise.
##
## Vingt-six, dans un rayon plus court et devant soi de preference. Le cout est
## mesure a chaque changement — c'est le systeme qui a deja fait tomber la ville
## a six images par seconde.
##
## A ZERO DEPUIS LE 31/07/2026, ET C'EST TEMPORAIRE. On travaille la ville
## seule : les passants sont ce qui empechait la trame d'etre irreguliere —
## leur voie se calcule avec un ecart de trottoir UNIQUE, valable seulement si
## toutes les rues ont la meme largeur. Mesure : sur vingt-six, six marchaient
## sur la chaussee et trois dans le desert des que les ilots changeaient de
## taille.
##
## Les remettre demande de publier l'ecart PAR TRONCON et de borner la ville
## sur sa geometrie plutot que sur un carre. Voir docs/16-albuquerque.md.
@export_range(0, 120, 1) var combien: int = 0

## Au-dela de cette distance de la camera, un passant est recycle : on le
## replace sur une rue proche au lieu de le laisser marcher pour personne.
##
## Un passant reapparait entre la moitie de cette distance et elle : jamais
## sous le nez du joueur, jamais si loin qu'il faille attendre pour en croiser
## un. De jour on voit a 340 m, donc un recyclage a 95 m est theoriquement
## visible — a cette distance un homme fait quatre pixels de haut sur un rendu
## de 512, et c'est un cout qu'on accepte pour dix fois la fluidite.
@export_range(20.0, 400.0, 5.0) var portee: float = 62.0

## Combien de fois par seconde on regarde qui est trop loin. Une fois suffit :
## a la vitesse d'une voiture on parcourt quinze metres dans l'intervalle, et
## la portee en garde quarante-sept d'avance.
const RYTHME := 1.0

var _passants: Array[Pieton] = []
var _noeuds: Array = []
var _voisins: Dictionary = {}
var _ecart: float = 7.0
var _retrait: float = 8.5
var _etendue: float = 0.0
var _aretes: Array = []
var _rng := RandomNumberGenerator.new()
var _depuis: float = 0.0


func _ready() -> void:
	if reglages == null:
		push_error("foule : aucune ressource Reglages assignee")
		return
	if not FileAccess.file_exists(routes_json):
		return

	var data = JSON.parse_string(FileAccess.get_file_as_string(routes_json))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var routes: Array = data.get("pietons", [])
	if routes.is_empty():
		return
	_etendue = float(data.get("etendue", 0.0))

	# Le graphe des rues, s'il existe. Les passants le suivent au lieu de faire
	# un aller-retour sur leur segment : ils tournent aux carrefours et ne
	# repassent plus au meme endroit. Voir l'en-tete de pieton.gd.
	var graphe: Dictionary = data.get("graphe", {})
	_noeuds = graphe.get("noeuds", [])
	_aretes = graphe.get("aretes", [])
	_ecart = float(graphe.get("ecart_trottoir", 7.0))
	_retrait = float(graphe.get("retrait_carrefour", 8.5))
	for i in _noeuds.size():
		_voisins[i] = []
	for a in _aretes:
		_voisins[int(a[0])].append(int(a[1]))
		_voisins[int(a[1])].append(int(a[0]))

	_rng.seed = 20082010          # les annees de la serie, et une graine stable

	var modeles := {}
	var poses := 0
	for i in mini(combien, routes.size()):
		# Les trajets du generateur ne servent plus a placer : ils servent a
		# VARIER. On y pioche une apparence et une allure, et le placement se
		# fait sur le graphe, autour du joueur.
		var route: Dictionary = routes[_rng.randi() % routes.size()]
		var nom := str(route.get("modele", "passant_a"))
		if not modeles.has(nom):
			var chemin := MODELE % nom
			modeles[nom] = (ResourceLoader.load(chemin) as PackedScene
					if ResourceLoader.exists(chemin) else null)
		if modeles[nom] == null:
			push_error("foule : %s introuvable. Regenerer : " % (MODELE % nom)
					+ "blender -b -P outils/gen_personnage.py -- --nom tous")
			continue
		var p := _poser(modeles[nom], route, poses)
		_passants.append(p)
		poses += 1

	# Le premier placement se fait DIFFERE. La camera n'a pas encore pris sa
	# position au premier _ready du monde : tout le monde serait ne autour de
	# l'origine, c'est-a-dire au coin sud-ouest de la ville.
	call_deferred("_repartir")
	print("foule : %d passant(s), %d modeles, %d carrefours"
			% [poses, modeles.size(), _noeuds.size()])


func _process(delta: float) -> void:
	_depuis += delta
	if _depuis < RYTHME:
		return
	_depuis = 0.0
	_recycler()


## Tous les passants, pour les tests. Une foule qui ne bouge pas ressemble
## exactement a une foule qui n'existe pas.
func passants() -> Array[Pieton]:
	return _passants


# LE POINT DE VUE, PAS LE JOUEUR.
#
# On suit la camera et non le personnage : au volant, le joueur est desactive
# et sa capsule retiree du monde physique — sa position n'est plus celle de ce
# qu'on regarde. Une foule accrochee a lui resterait garee devant la maison
# pendant qu'on traverse la ville.
func _oeil() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


func _recycler() -> void:
	if _aretes.is_empty() or _passants.is_empty():
		return
	var oeil := _oeil()
	var loin: Array[Pieton] = []
	for p in _passants:
		if oeil.distance_to(p.global_position) > portee:
			loin.append(p)
	if loin.is_empty():
		return
	# La liste des rues acceptables se calcule UNE FOIS pour tout le tour, pas
	# une fois par passant : c'est la meme liste, et cinq cents distances
	# recalculees seize fois par seconde finiraient par se voir.
	# Aucune rue a portee : ON NE FAIT RIEN, et c'est le cas le plus frequent
	# du jeu. Le joueur passe son temps dans un salon, dans le camping-car ou
	# au desert — tous poses a des centaines de metres de la ville, dans le
	# meme repere. Y ramener la foule entasserait seize passants sur le seul
	# troncon le moins loin, et ils s'y pietineraient jusqu'a ce qu'on ressorte.
	# Les laisser marcher ou ils sont ne coute rien : personne ne les voit.
	var proches := _rues_proches(oeil)
	if proches.is_empty():
		return
	# UNE RUE PAR PASSANT TANT QU'IL Y EN A. On melange la liste et on la
	# parcourt, au lieu de tirer au sort a chaque fois : sur six rues et vingt
	# passants, le tirage independant en met regulierement quatre sur la meme.
	proches.shuffle()
	var i := 0
	for p in loin:
		_replacer(p, proches, i)
		i += 1


# Le premier placement. Si le joueur commence hors de la ville — c'est le cas
# de la mission 1, qui s'ouvre dans le salon de Walter — on laisse les passants
# sur les trajets du generateur, qui sont de vrais bouts de trottoir. Ils se
# regrouperont autour de lui a la seconde ou il mettra le nez dehors.
func _repartir() -> void:
	var proches := _rues_proches(_oeil())
	if proches.is_empty():
		return
	proches.shuffle()
	var i := 0
	for p in _passants:
		_replacer(p, proches, i)
		i += 1


# LES RUES OU L'ON PEUT REAPPARAITRE : ni sous le nez du joueur, ni hors de vue.
#
# La premiere version tirait vingt troncons au hasard et gardait le premier qui
# tombait dans la couronne, sinon le dernier tire. Elle ratait souvent : sur
# une ville de cinq cent quarante troncons, la couronne n'en contient que deux
# ou trois pour cent, donc deux recyclages sur trois reposaient le passant
# n'IMPORTE OU — souvent a trois cents metres, donc immediatement trop loin,
# donc recycle a nouveau la seconde suivante. La foule passait son temps a se
# teleporter : mesure du test, 199 m parcourus par passant en quelques
# secondes, pour une marche a 1,3 m/s.
#
# On parcourt donc la liste en entier. Cinq cent quarante distances une fois
# par seconde ne se mesurent pas.
func _rues_proches(oeil: Vector3) -> Array:
	# ON MESURE LA DISTANCE A LA RUE, PAS AU CARREFOUR.
	#
	# La premiere version comparait la distance aux extremites du troncon. Les
	# carrefours sont a cinquante-sept metres les uns des autres : une rue qui
	# passe a dix metres devant le joueur n'etait donc pas candidate si ses deux
	# bouts etaient loin. Mesure du 31/07/2026, camera posee dans une rue :
	# DEUX rues d'accueil pour vingt-six passants, tous entasses hors du champ.
	var cam := get_viewport().get_camera_3d()
	var devant := -cam.global_transform.basis.z if cam != null else Vector3.ZERO
	devant.y = 0.0
	devant = devant.normalized()

	var vues: Array = []
	var autres: Array = []
	for a in _aretes:
		var p0 := _point(int(a[0]))
		var p1 := _point(int(a[1]))
		if _distance_au_troncon(oeil, p0, p1) > portee:
			continue
		# DEVANT SOI D'ABORD. Un passant repose derriere le joueur ne sera
		# jamais vu : il marchera cinquante metres dans son dos, puis sera
		# recycle. A effectif egal, ne peupler que ce qu'on regarde double ce
		# qu'on croise.
		var vers := (p0 + p1) * 0.5 - oeil
		vers.y = 0.0
		if devant != Vector3.ZERO and vers.normalized().dot(devant) > -0.15:
			vues.append(a)
		else:
			autres.append(a)
	# Les rues de dos servent de repli : au fond d'une impasse, tout est
	# derriere, et mieux vaut un passant mal place que pas de passant.
	return vues if not vues.is_empty() else autres


## La distance d'un point au SEGMENT, pas a la droite qui le porte : une rue a
## deux bouts, et au-dela on est dans la rue d'a cote.
static func _distance_au_troncon(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# Repose un passant sur une rue proche du point de vue. On tire au sort parmi
# les troncons plutot que de prendre le plus proche : sinon les seize se
# retrouvent tous dans la meme rue.
func _replacer(p: Pieton, proches: Array, rang: int = 0) -> void:
	if proches.is_empty():
		return
	var choisie: Array = proches[rang % proches.size()]
	var de := int(choisie[0])
	var vers := int(choisie[1])
	# On part du bout le PLUS ELOIGNE du point de vue, donc on marche vers le
	# joueur. Deux gains pour la meme ligne : personne n'apparait sous son nez,
	# et on croise des visages plutot que des dos.
	var oeil := _oeil()
	if oeil.distance_to(_point(de)) < oeil.distance_to(_point(vers)):
		var t := de
		de = vers
		vers = t
	p.etendue = _etendue
	# ET A UNE PLACE DIFFERENTE LE LONG DE LA RUE. Deux passants sur le meme
	# troncon partent d'endroits differents, donc ils ne se suivent pas.
	p.sur_le_graphe(_noeuds, _voisins, de, vers, _ecart, _retrait,
			_rng.randf_range(0.0, 0.85))
	# Une allure retiree au hasard a chaque replacement, et non une fois pour
	# toutes : deux personnes qui marchent exactement a la meme vitesse restent
	# cote a cote indefiniment, meme parties de loin.
	p.allure = _rng.randf_range(0.62, 1.18)
	p.pause = _rng.randf_range(0.4, 2.4)
	p.global_position = p.depart


func _point(i: int) -> Vector3:
	var v: Array = _noeuds[i]
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


func _poser(modele: PackedScene, route: Dictionary, index: int) -> Pieton:
	var p := Pieton.new()
	p.name = "Passant_%02d" % index
	p.reglages = reglages
	p.depart = _vec(route.get("depart", [0, 0, 0]))
	p.arrivee = _vec(route.get("arrivee", [0, 0, 0]))
	p.allure = float(route.get("allure", 1.0))
	# Couche 2 comme le joueur : ils ne doivent pas bloquer le rayon de la
	# camera, sinon elle se colle a la nuque des qu'un passant la croise.
	p.collision_layer = 2
	p.collision_mask = 1

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RAYON
	capsule.height = TAILLE
	forme.shape = capsule
	forme.position.y = TAILLE / 2.0
	p.add_child(forme)

	p.add_child(modele.instantiate())
	add_child(p)
	p.global_position = p.depart
	return p


static func _vec(v: Variant) -> Vector3:
	var a: Array = v if typeof(v) == TYPE_ARRAY else []
	if a.size() < 3:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
