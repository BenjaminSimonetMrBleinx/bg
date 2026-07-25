# Walter a pied.
#
# La marche est animee par code, pas par un clip. Le personnage exporte est
# une hierarchie de segments rigides, et ce script fait tourner les
# articulations. Trois avantages concrets :
#
#   - la cadence se cale d'elle-meme sur la vitesse reelle, parce que la phase
#     avance avec la DISTANCE parcourue et non avec le temps. Les pieds ne
#     patinent jamais, quel que soit le reglage de vitesse.
#   - tout est au curseur dans reglages.tres : foulee, amplitudes, rebond.
#   - Guillaume peut remplacer les maillages sans toucher a l'animation, tant
#     que les segments gardent leurs noms.
class_name Joueur
extends CharacterBody3D

@export var reglages: Reglages
## Sert a orienter les deplacements : avancer, c'est aller vers ou la camera
## regarde, pas vers -Z du monde.
@export var camera: NodePath

var _phase: float = 0.0
var _cam: Camera3D
var _membres: Dictionary = {}
var _bassin_y: float = 0.0
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)


func _ready() -> void:
	if reglages == null:
		push_error("joueur : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	_cam = get_node_or_null(camera) as Camera3D
	_recenser_membres()


# Les segments sont retrouves par nom plutot que par chemin : la structure
# exacte du .glb importe peut varier d'une version de Godot a l'autre, mais
# les noms viennent du generateur et sont stables.
func _recenser_membres() -> void:
	for nom in ["Bassin", "Torse", "CuisseG", "CuisseD", "TibiaG", "TibiaD",
				"BrasG", "BrasD", "AvantBrasG", "AvantBrasD"]:
		var n := find_child(nom, true, false)
		if n is Node3D:
			_membres[nom] = n
		else:
			push_warning("joueur : segment '%s' introuvable" % nom)
	if _membres.has("Bassin"):
		_bassin_y = (_membres["Bassin"] as Node3D).position.y


func _physics_process(delta: float) -> void:
	var voulu := _direction_voulue()

	if not is_on_floor():
		velocity.y -= _gravite * delta

	var cible := voulu * reglages.marche_vitesse
	var k := clampf(reglages.marche_acceleration * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, cible.x, k)
	velocity.z = lerpf(velocity.z, cible.z, k)

	move_and_slide()

	_orienter(voulu, delta)
	_animer(delta)


func _direction_voulue() -> Vector3:
	var axe := Input.get_vector("gauche", "droite", "gaz", "frein")
	if axe.length_squared() < 0.01:
		return Vector3.ZERO
	var base := _cam.global_transform.basis if _cam != null else global_transform.basis
	var avant := -base.z
	var droite := base.x
	avant.y = 0.0
	droite.y = 0.0
	return (droite * axe.x + avant * -axe.y).normalized()


## Angle de lacet pour qu'un noeud regarde dans la direction donnee.
##
## L'avant d'un noeud Godot est -Z, d'ou les deux negations. Sans elles on
## obtient l'angle oppose : le personnage marche a reculons, la camera ancree
## derriere lui bascule de l'autre cote, ce qui inverse la notion d'avant et
## le fait pivoter encore. Resultat, il tourne en boucle sans jamais se
## stabiliser — une rétroaction, pas un simple defaut d'orientation.
static func lacet_vers(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _orienter(voulu: Vector3, delta: float) -> void:
	if voulu.length_squared() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, lacet_vers(voulu),
			reglages.marche_rotation * delta)


func _animer(delta: float) -> void:
	var au_sol := Vector2(velocity.x, velocity.z).length()

	if au_sol < 0.15:
		# Retour a la position de repos, sans a-coup.
		_phase = lerp_angle(_phase, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		_poser(0.0)
		return

	# La phase avance avec la distance, pas avec le temps.
	_phase = fmod(_phase + (au_sol * delta) / maxf(0.05, reglages.foulee) * TAU, TAU)
	_poser(1.0)


func _poser(intensite: float) -> void:
	var jambe := deg_to_rad(reglages.amplitude_jambe) * intensite
	var genou := deg_to_rad(reglages.amplitude_genou) * intensite
	var bras := deg_to_rad(reglages.amplitude_bras) * intensite
	var coude := deg_to_rad(reglages.amplitude_coude) * intensite

	var s := sin(_phase)
	var so := sin(_phase + PI)

	_tourner("CuisseG", s * jambe)
	_tourner("CuisseD", so * jambe)
	# Le genou ne plie que vers l'arriere : on ne garde que la moitie negative
	# du cycle. Un genou qui plie a l'envers est le defaut le plus visible
	# d'une marche procedurale ratee.
	_tourner("TibiaG", -maxf(0.0, sin(_phase - 0.7)) * genou)
	_tourner("TibiaD", -maxf(0.0, sin(_phase + PI - 0.7)) * genou)

	_tourner("BrasG", so * bras)
	_tourner("BrasD", s * bras)
	_tourner("AvantBrasG", -(0.5 + 0.5 * sin(_phase + PI)) * coude)
	_tourner("AvantBrasD", -(0.5 + 0.5 * sin(_phase)) * coude)

	# Le bassin monte deux fois par foulee, une fois par appui.
	if _membres.has("Bassin"):
		var b: Node3D = _membres["Bassin"]
		b.position.y = _bassin_y + absf(sin(_phase)) * reglages.rebond * intensite

	# Un leger roulis du torse enleve l'impression de pantin.
	if _membres.has("Torse"):
		var t: Node3D = _membres["Torse"]
		t.rotation.z = s * deg_to_rad(reglages.roulis_torse) * intensite


func _tourner(nom: String, angle: float) -> void:
	if _membres.has(nom):
		(_membres[nom] as Node3D).rotation.x = angle


## Vitesse au sol en km/h, pour le HUD et les sons de pas.
func vitesse_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6
