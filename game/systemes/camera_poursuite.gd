# Camera de poursuite.
#
# Deux lissages independants — position et rotation — parce qu'ils ne
# produisent pas la meme sensation. Une camera qui suit vite en position mais
# tourne lentement donne de la lourdeur ; l'inverse donne de la nervosite.
# C'est le reglage qui change le plus la perception de vitesse, donc il est au
# curseur comme le reste.
extends Camera3D

@export var reglages: Reglages
@export var cible: NodePath

var _cible: Node3D
var _vehicule: Vehicule
var _pieton: bool = false
var _position_lissee: Vector3
var _regard_lisse: Vector3
var _initialisee: bool = false


func _ready() -> void:
	if reglages == null:
		push_error("camera_poursuite : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	var n := get_node_or_null(cible) as Node3D
	if n == null:
		push_warning("camera_poursuite : cible introuvable (%s)" % cible)
		set_physics_process(false)
		return
	suivre(n)
	fov = reglages.fov_arret


## Change de sujet. Appele au moment ou l'on monte dans le vehicule ou l'on
## en descend : le cadrage n'est pas le meme a pied qu'au volant, et la
## camera se replace sans transition brutale grace au lissage.
func suivre(n: Node3D) -> void:
	_cible = n
	_vehicule = n as Vehicule
	_pieton = n is Joueur
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var voulue := _ancrage()
	var vise := _cible.global_position + Vector3.UP * reglages.cible_hauteur

	if not _initialisee:
		_position_lissee = voulue
		_regard_lisse = vise
		_initialisee = true

	# Lissage independant du framerate : a 30 comme a 144 images/s, la camera
	# met le meme temps reel a rattraper. Sans ca, tout reglage trouve sur une
	# machine serait faux sur l'autre.
	var lissage := reglages.pieton_lissage if _pieton else reglages.lissage_position
	_position_lissee = _position_lissee.lerp(voulue, _facteur(lissage, delta))
	_regard_lisse = _regard_lisse.lerp(vise, _facteur(reglages.lissage_rotation, delta))

	global_position = _position_lissee
	if _position_lissee.distance_squared_to(_regard_lisse) > 0.01:
		look_at(_regard_lisse, Vector3.UP)

	# Le champ de vision ne s'ouvre qu'en vehicule : a pied, l'ecart de
	# vitesse est trop faible pour que ca veuille dire quelque chose.
	if _vehicule != null:
		var t := clampf(_vehicule.vitesse_kmh() / maxf(1.0, reglages.vitesse_max_kmh), 0.0, 1.0)
		fov = lerpf(reglages.fov_arret, reglages.fov_pleine_vitesse, t)
	elif _pieton:
		fov = reglages.fov_arret


static func _facteur(lissage: float, delta: float) -> float:
	return 1.0 - pow(1.0 - clampf(lissage, 0.001, 0.999), delta * 60.0)


# Derriere et au-dessus, dans le repere du vehicule : la camera accompagne les
# virages au lieu de rester plaquee sur un axe du monde.
func _ancrage() -> Vector3:
	var base := _cible.global_transform.basis
	var recul := reglages.pieton_recul if _pieton else reglages.recul
	var hauteur := reglages.pieton_hauteur if _pieton else reglages.hauteur
	return _cible.global_position + base.z * recul + Vector3.UP * hauteur
