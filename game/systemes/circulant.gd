# Un agent qui circule sur le graphe des rues.
#
# Il sert AUX DEUX : une voiture et un passant ne different que par leur
# vitesse, leur ecart a l'axe de la rue, et le fait de rouler ou de marcher.
# Le reste — choisir une arete, la parcourir, tourner au carrefour — est le
# meme travail, et le dupliquer aurait garanti que les deux divergent.
#
# CE QUE CA REMPLACE, ET POURQUOI.
#
# Les passants faisaient un aller-retour sur un bout de trottoir fixe, pour
# toujours. Ca tient trente secondes : au-dela, on voit que le meme homme
# refait les memes vingt-cinq metres, ne tourne jamais un coin, et n'entre
# nulle part. Le decalage de depart aleatoire masquait le probleme au premier
# coup d'oeil, il ne le resolvait pas.
#
# Et ce n'etait pas transposable aux voitures : une voiture qui fait demi-tour
# au bout d'un troncon et repart en marche arriere est absurde.
#
# SUR GRAPHE, JAMAIS EN PHYSIQUE. C'est l'avertissement retenu, et il est
# juste : la simulation physique avec changement de voie est exactement
# l'endroit ou les projets a deux meurent. Ici un agent suit une ligne, et
# s'arrete si quelque chose la barre. Rien de plus.
class_name Circulant
extends AnimatableBody3D

## Le graphe, partage : tous les agents lisent le meme.
var _noeuds: Array = []
var _voisins: Dictionary = {}

var _de: int = 0
var _vers: int = 0
var _avance: float = 0.0        # 0 au depart de l'arete, 1 a l'arrivee
var _longueur: float = 1.0

## Vitesse de croisiere, en m/s.
var vitesse: float = 8.0

## Ecart a DROITE de l'axe du troncon, en metres. C'est ce qui donne la
## circulation a droite sans doubler le graphe : deux agents en sens inverse
## sur la meme arete se croisent au lieu de se traverser.
var ecart: float = 2.75

## Distance a laquelle on s'arrete derriere ce qui barre la route.
var garde: float = 6.0

## Vitesse instantanee, reduite a zero quand on est bloque. Lue par le son et
## par les tests.
var allure: float = 0.0

var _rayon: RayCast3D


func _ready() -> void:
	# sync_to_physics fait suivre au corps une transformation ANIMEE, en la
	# relisant depuis le serveur physique a chaque image. Poser la position a
	# la main est alors sans effet : le serveur la remet a l'origine a l'image
	# suivante, et les dix voitures restaient empilees en (0, 0, 0).
	#
	# On le coupe. Le corps reste un obstacle solide et pousse ce qu'il touche,
	# ce qui est tout ce qu'on lui demande.
	sync_to_physics = false


func demarrer(noeuds: Array, voisins: Dictionary, de: int, vers: int,
		rng: RandomNumberGenerator) -> void:
	_noeuds = noeuds
	_voisins = voisins
	_de = de
	_vers = vers
	# Chacun demarre a un point different de son troncon, sinon toute la ville
	# part du meme carrefour au meme instant et on voit le peloton.
	_avance = rng.randf()
	_mesurer()
	_poser()


func _mesurer() -> void:
	_longueur = maxf(0.5, _point(_de).distance_to(_point(_vers)))


func _point(i: int) -> Vector3:
	var p: Array = _noeuds[i]
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


## L'axe du troncon, decale a droite. Le decalage suit le SENS de marche :
## faire demi-tour change de cote de la rue, comme il se doit.
func _sur_la_voie(t: float) -> Vector3:
	var a := _point(_de)
	var b := _point(_vers)
	var direction := (b - a).normalized()
	# A droite du sens de marche, dans le plan du sol.
	var droite := Vector3(-direction.z, 0.0, direction.x)
	return a.lerp(b, t) + droite * ecart


func _poser() -> void:
	global_position = _sur_la_voie(_avance)
	var suivant := _sur_la_voie(minf(_avance + 0.01, 1.0))
	var vers := suivant - global_position
	if vers.length_squared() > 0.0001:
		global_rotation.y = atan2(-vers.x, -vers.z)


func _physics_process(delta: float) -> void:
	if _noeuds.is_empty():
		return

	# On s'arrete derriere ce qui barre la route. Pas d'evitement, pas de
	# depassement : un agent qui essaie de contourner finit sur le trottoir ou
	# dans le sens inverse, et personne n'a le temps de regler ca.
	var libre := true
	if _rayon != null:
		_rayon.force_raycast_update()
		libre = not _rayon.is_colliding()
	allure = vitesse if libre else 0.0

	_avance += allure * delta / _longueur
	while _avance >= 1.0:
		_avance -= 1.0
		_choisir_la_suite()
		_mesurer()
	_poser()


# Au carrefour, on tire une rue au sort — mais pas celle d'ou l'on vient, sauf
# impasse. Sans cette regle, un agent sur deux fait demi-tour a chaque
# carrefour et la ville a l'air de bouillir sur place.
func _choisir_la_suite() -> void:
	var possibles: Array = _voisins.get(_vers, [])
	if possibles.is_empty():
		# Impasse : on repart d'ou l'on vient. GDScript n'echange pas deux
		# variables d'une ligne comme Python.
		var ancien := _de
		_de = _vers
		_vers = ancien
		return
	var sans_retour: Array = possibles.filter(func(v: int) -> bool: return v != _de)
	var suite: Array = sans_retour if not sans_retour.is_empty() else possibles
	_de = _vers
	_vers = suite[randi() % suite.size()]


## Installe le detecteur d'obstacle. Fait apres coup parce que sa longueur
## depend de ce qu'on est : une voiture regarde plus loin qu'un passant.
func poser_le_regard(portee: float, masque: int) -> void:
	garde = portee
	_rayon = RayCast3D.new()
	# Le rayon part DEVANT le pare-chocs, pas au milieu de la caisse.
	#
	# Une premiere version le posait a un metre de l'origine, c'est-a-dire a
	# l'interieur de la boite de collision : chaque voiture se voyait elle-meme,
	# se croyait bloquee, et toute la circulation restait a l'arret. Rien ne le
	# signalait — dix voitures immobiles ressemblent exactement a dix voitures
	# garees.
	#
	# L'exception sur soi-meme est mise en plus : la ceinture et les bretelles,
	# parce que le symptome est muet.
	_rayon.position = Vector3(0.0, 0.6, -2.6)
	_rayon.target_position = Vector3(0.0, 0.0, -portee)
	_rayon.collision_mask = masque
	_rayon.enabled = true
	add_child(_rayon)
	_rayon.add_exception(self)
