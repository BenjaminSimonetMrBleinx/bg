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

## Cap de la camera a pied, en radians. C'est une variable A PART ENTIERE,
## surtout pas deduite de l'orientation du personnage.
##
## Si la camera se placait derriere lui pendant que ses deplacements sont
## calcules par rapport a la camera, les deux se poursuivraient : avancer
## converge par hasard, mais reculer ou aller sur le cote n'a aucun point
## d'equilibre et le personnage tourne en rond sans fin. Rendre ce cap
## independant est la seule facon de casser la boucle.
var _cap: float = 0.0


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
	_cap = n.rotation.y          # on demarre derriere le sujet
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _pieton:
		_recentrer(delta)
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
# Le cap ne se replace derriere le personnage que s'il S'ELOIGNE de la
# camera. Quand il vient vers elle ou passe sur le cote, le cap tient bon :
# c'est ce qui empeche la poursuite mutuelle, et c'est aussi le comportement
# des cameras de suivi de l'epoque.
func _recentrer(delta: float) -> void:
	if not (_cible is CharacterBody3D):
		return
	var v: Vector3 = (_cible as CharacterBody3D).velocity
	v.y = 0.0
	if v.length() < 0.4:
		return

	var direction := v.normalized()
	var vers_camera := Vector3(sin(_cap), 0.0, cos(_cap))   # du sujet vers la camera
	# Seuil volontairement franc. A 0,15 on est trop pres de la
	# perpendiculaire : un deplacement lateral le franchit par intermittence,
	# le cap se met a bouger, et la poursuite mutuelle repart.
	if direction.dot(-vers_camera) <= 0.5:
		return                                              # il ne s'eloigne pas franchement

	var voulu := atan2(-direction.x, -direction.z)          # derriere lui
	_cap = rotate_toward(_cap, voulu, reglages.pieton_recentrage * delta)


func _ancrage() -> Vector3:
	if _pieton:
		var derriere := Vector3(sin(_cap), 0.0, cos(_cap))
		return (_cible.global_position
				+ derriere * reglages.pieton_recul
				+ Vector3.UP * reglages.pieton_hauteur)
	var base := _cible.global_transform.basis
	return (_cible.global_position
			+ base.z * reglages.recul
			+ Vector3.UP * reglages.hauteur)
