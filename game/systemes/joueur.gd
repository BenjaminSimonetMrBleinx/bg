# Walter a pied.
#
# Ce script ne s'occupe que de ce qui est PROPRE au joueur : lire les touches,
# le faire pivoter et avancer, et franchir les bordures de trottoir.
#
# Les commandes sont celles des jeux de l'epoque : GAUCHE et DROITE font
# PIVOTER sur place, AVANT et ARRIERE deplacent selon l'orientation du
# personnage. La camera n'entre pas dans le calcul.
#
# Ce n'est pas de la nostalgie. Pendant trois versions, la direction se
# lisait sur la camera — et comme la camera suit le personnage, aller sur le
# cote la faisait tourner, ce qui faisait tourner la direction, ce qui la
# faisait tourner encore. On y a repondu en bloquant la camera, puis en
# figeant le repere a l'appui. Les deux marchaient et aucun n'etait franc.
# Ici la boucle n'existe pas : il n'y a rien a casser.
#
# La marche elle-meme vit dans silhouette.gd, partagee avec les pietons de la
# rue. Elle y a ete deplacee parce que le maillage est le meme pour tout le
# monde : la dupliquer aurait garanti que les deux demarches divergent au
# premier reglage.
class_name Joueur
extends CharacterBody3D

@export var reglages: Reglages
## Conserve pour la compatibilite de la scene. Le deplacement ne s'en sert
## plus du tout : c'est precisement ce qui a regle le probleme.
@export var camera: NodePath

var _cam: Camera3D

## La marche procedurale, partagee avec les pietons de la rue.
var _silhouette: Silhouette
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
	_silhouette = Silhouette.new(reglages)
	_silhouette.recenser(self)

	# Le franchissement doit degager le rayon de la capsule AU-DELA de
	# l'arete, sinon on retombe dedans. On le lit plutot que de le supposer.
	var forme := $Collision as CollisionShape3D
	if forme != null and forme.shape is CapsuleShape3D:
		_rayon = (forme.shape as CapsuleShape3D).radius


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravite * delta

	# Gauche et droite PIVOTENT, elles ne deplacent pas. Avant et arriere
	# deplacent selon l'orientation du personnage, jamais selon la camera.
	#
	# C'est la commande des jeux de l'epoque, et elle regle definitivement le
	# probleme qui nous a poursuivis : tant que la direction se lisait sur la
	# camera, aller sur le cote la faisait tourner, ce qui faisait tourner la
	# direction. Ici, la camera n'entre plus dans le calcul du tout.
	var pivot := Input.get_axis("gauche", "droite")
	if not bloque and absf(pivot) > 0.01:
		rotation.y -= pivot * deg_to_rad(reglages.pivot_vitesse) * delta

	var avance := 0.0
	if not bloque:
		avance = Input.get_axis("frein", "gaz")

	var devant := -global_transform.basis.z
	devant.y = 0.0
	devant = devant.normalized()

	# Reculer est plus lent qu'avancer : personne ne court a reculons.
	var allure := reglages.marche_vitesse
	if avance < 0.0:
		allure *= reglages.marche_arriere

	var voulu := devant * avance
	var cible := voulu * allure
	var k := clampf(reglages.marche_acceleration * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, cible.x, k)
	velocity.z = lerpf(velocity.z, cible.z, k)

	move_and_slide()
	_franchir(voulu, delta)

	# Vitesse SIGNEE : la silhouette inverse le cycle de marche quand on
	# recule, sinon il marche a l'endroit en se deplacant a l'envers.
	var au_sol := Vector2(velocity.x, velocity.z).length()
	_silhouette.avancer(au_sol * signf(avance) if absf(avance) > 0.01 else au_sol, delta)


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


# Repere fige au moment ou l'on commence a bouger, et garde tant que la
# touche est tenue.
#
# C'est ce qui casse la poursuite mutuelle. "Aller a gauche" veut dire a
# gauche DE CE QU'ON VOIT ; si on relisait la camera a chaque image pendant
# qu'elle se replace derriere le personnage, la direction tournerait avec
## Angle de lacet pour qu'un noeud regarde dans la direction donnee.
##
## L'avant d'un noeud Godot est -Z, d'ou les deux negations. Sans elles on
## obtient l'angle oppose. Le joueur ne s'en sert plus — il pivote a la
## commande — mais les pietons de la rue, eux, se tournent vers leur
## destination et en ont besoin.
static func lacet_vers(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## Vitesse au sol en km/h, pour le HUD et les sons de pas.
func vitesse_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6
