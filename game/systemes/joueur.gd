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
var _rayon: float = 0.28
var _gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)

## Diagnostic, lu par les tests : nombre de bordures effectivement franchies,
## et raison du dernier refus. Un franchissement rate est silencieux sinon, et
## on passe son temps a supposer pourquoi.
var franchissements: int = 0
var _refus: String = ""


func raison_refus() -> String:
	return _refus


func _ready() -> void:
	if reglages == null:
		push_error("joueur : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	_cam = get_node_or_null(camera) as Camera3D
	_recenser_membres()

	# Le franchissement doit degager le rayon de la capsule AU-DELA de
	# l'arete, sinon on retombe dedans. On le lit plutot que de le supposer.
	var forme := $Collision as CollisionShape3D
	if forme != null and forme.shape is CapsuleShape3D:
		_rayon = (forme.shape as CapsuleShape3D).radius


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
	_franchir(voulu, delta)

	_orienter(voulu, delta)
	_animer(delta)


# Franchissement des bordures de trottoir.
#
# CharacterBody3D ne monte aucune marche tout seul : il glisse le long des
# obstacles verticaux, quelle que soit leur hauteur. Une bordure de 18 cm
# suffit donc a bloquer net, ce qui est intenable dans une ville.
#
# La methode est celle de tous les moteurs : lever, avancer, reposer. Si rien
# ne se trouve sous les pieds apres l'avancee, on annule — sinon on grimperait
# dans le vide.
func _franchir(voulu: Vector3, delta: float) -> void:
	if voulu.length_squared() < 0.01:
		return
	if not is_on_wall():
		_refus = "pas de mur"
		return
	# Contre une ARETE — le haut d'une bordure — la normale de contact est
	# diagonale, pas horizontale : mesure faite, n.y valait 0,40 sur un
	# trottoir de 18 cm. Une premiere version exigeait n.y proche de zero et
	# rejetait donc exactement le cas a traiter. On ne rejette plus que ce qui
	# est franchement un sol, et on raisonne sur la composante horizontale.
	var normale := get_wall_normal()
	if normale.y > 0.75:
		_refus = "c'est un sol (n.y=%.2f)" % normale.y
		return
	var horizontale := Vector3(normale.x, 0.0, normale.z)
	if horizontale.length() < 0.2:
		_refus = "normale sans composante horizontale"
		return
	horizontale = horizontale.normalized()
	if voulu.dot(-horizontale) < 0.2:
		_refus = "on ne pousse pas dedans (%.2f)" % voulu.dot(-horizontale)
		return

	var pas := reglages.hauteur_marche
	if pas <= 0.0:
		return
	var sauvegarde := global_position

	# Il faut avancer d'au moins un rayon de capsule au-dela de l'arete :
	# une avancee proportionnelle au pas de temps ne suffit jamais, on
	# retombe dans la bordure et on reste bloque.
	var portee := _rayon + 0.26
	global_position += Vector3.UP * (pas + 0.02)
	move_and_collide(voulu.normalized() * portee)
	var gagne := global_position.distance_to(sauvegarde)
	if move_and_collide(Vector3.DOWN * (pas + 0.12)) == null:
		global_position = sauvegarde
		_refus = "rien sous les pieds apres %.2f m" % gagne
	else:
		franchissements += 1
		_refus = ""


## Coupe les commandes sans arreter la physique : pendant un dialogue, le
## personnage doit ralentir et reposer ses pieds normalement. Suspendre le
## traitement le figerait en pleine foulee, une jambe en l'air.
var bloque: bool = false


func _direction_voulue() -> Vector3:
	if bloque:
		return Vector3.ZERO
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
