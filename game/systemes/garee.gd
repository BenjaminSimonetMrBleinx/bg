# Une voiture a l'arret le long d'un trottoir.
#
# ELLE ETAIT TRAVERSABLE. `ville.gd` declarait bien une liste de prefixes
# solides contenant "garee_", et ne s'en servait nulle part : quatre cents
# voitures posees dans les rues, et la caisse du joueur passait au travers de
# chacune. Un commentaire affirmait meme qu'elles portaient deja leur corps
# statique — c'etait faux, un .glb ne transporte aucun corps physique.
#
# POURQUOI UN CORPS RIGIDE GELE, ET PAS UN CORPS STATIQUE.
#
# Un corps statique aurait suffi a ne plus les traverser, mais il aurait rendu
# la rue pire qu'avant : une voiture garee est alors un mur de beton, et taper
# dedans a quarante renvoie le joueur dans le decor. Or ce qu'on veut est
# l'inverse — QUE LE JOUEUR GAGNE LE CHOC.
#
# Un RigidBody3D gele en mode statique ne coute rien de plus qu'un corps
# statique : le serveur physique le traite comme tel tant qu'il dort. Mais on
# peut le REVEILLER, et il devient alors une masse d'une tonne et demie qu'on
# pousse, qui glisse et qui finit par se reposer. Le meme objet fait donc les
# deux, sans qu'on ait a en creer un second au moment de l'impact.
class_name VoitureGaree
extends RigidBody3D

## Masse d'une berline americaine des annees 2000, en kilos. Elle compte : plus
## legere, la voiture part en tonneau au premier contact ; plus lourde, elle ne
## bouge pas et on retombe sur le mur de beton.
const MASSE := 1400.0

## En dessous de cette vitesse, et apres ce delai, on se rendort. Sans ca,
## chaque voiture touchee reste simulee jusqu'a la fin de la partie, et une
## rue traversee en trombe laisse vingt corps actifs derriere elle.
const REPOS_VITESSE := 0.35
const REPOS_DUREE := 2.5

var _immobile_depuis: float = 0.0


func _ready() -> void:
	mass = MASSE
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	# Couche 1 : le joueur, sa voiture et la circulation la percutent. Elle ne
	# scrute rien elle-meme tant qu'elle dort.
	collision_layer = 1
	collision_mask = 1
	# Le centre de gravite bas evite le tonneau au premier coup de pare-chocs.
	# Une voiture poussee doit glisser et pivoter, pas decoller.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.35, 0.0)
	set_physics_process(false)


## Prend le choc. L'impulsion est en kg.m/s, appliquee au point touche pour
## que la voiture pivote au lieu de partir en translation pure.
func reveiller(impulsion: Vector3, ou: Vector3 = Vector3.ZERO) -> void:
	if not freeze:
		return
	freeze = false
	set_physics_process(true)
	_immobile_depuis = 0.0
	if ou == Vector3.ZERO:
		apply_central_impulse(impulsion)
	else:
		apply_impulse(impulsion, ou - global_position)


func _physics_process(delta: float) -> void:
	if freeze:
		return
	if linear_velocity.length() < REPOS_VITESSE \
			and angular_velocity.length() < REPOS_VITESSE:
		_immobile_depuis += delta
		if _immobile_depuis > REPOS_DUREE:
			# On regele SUR PLACE, dans la position ou elle s'est arretee. Elle
			# redevient gratuite, et elle garde sa nouvelle pose de travers.
			freeze = true
			set_physics_process(false)
	else:
		_immobile_depuis = 0.0
