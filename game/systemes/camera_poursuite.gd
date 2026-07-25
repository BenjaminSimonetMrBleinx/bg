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

## Cadrage resserre pour les interieurs. Le reste du comportement est
## identique : seule la distance change, parce qu'une piece de sept metres
## ne laisse pas la place d'un recul de rue.
var _dedans: bool = false

## Angle vertical, en radians. Commun au vehicule et a la marche.
var _tangage: float = 0.0

## Decalage de cap applique AU VEHICULE seulement. La camera de conduite est
## solidaire de la caisse — c'est ce qui fait qu'elle accompagne les virages —
## donc la visee libre s'ajoute par-dessus et se resorbe, au lieu de
## remplacer le cap comme a pied.
var _orbite: float = 0.0

## Temps restant avant que le recentrage automatique reprenne la main.
## Sans ce delai, la camera ramenerait de force des qu'on lache la souris, et
## regarder de cote en marchant serait impossible.
var _manuel: float = 0.0

## Recul, en proportion du nominal. Regle a la molette.
var _zoom: float = 1.0


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
	if _manuel > 0.0:
		_manuel = maxf(0.0, _manuel - delta)
	elif not _pieton:
		# Au volant, la camera se remet dans l'axe toute seule. A pied, le cap
		# reste ou on l'a laisse : c'est le recentrage sur la marche qui s'en
		# charge, et seulement quand on avance.
		_orbite = move_toward(_orbite, 0.0, reglages.souris_retour * delta)

	if _pieton and _manuel <= 0.0:
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

	global_position = _degager(_position_lissee, _regard_lisse, delta)
	if global_position.distance_squared_to(_regard_lisse) > 0.01:
		look_at(_regard_lisse, Vector3.UP)

	# Le champ de vision ne s'ouvre qu'en vehicule : a pied, l'ecart de
	# vitesse est trop faible pour que ca veuille dire quelque chose.
	if _vehicule != null:
		var t := clampf(_vehicule.vitesse_kmh() / maxf(1.0, reglages.vitesse_max_kmh), 0.0, 1.0)
		fov = lerpf(reglages.fov_arret, reglages.fov_pleine_vitesse, t)
	elif _pieton:
		fov = reglages.fov_arret


# Distance actuellement concedee a un obstacle. Gardee d'une image a l'autre
# pour que le retour au recul normal soit progressif.
var _recul_libre: float = 0.0


# Rapproche la camera si un mur la separe du sujet.
#
# Le clamp est fait APRES le lissage, sur la position finale, et pas sur la
# position visee. Lisser vers une cible deja corrigee laisserait la camera
# traverser le mur pendant qu'elle rattrape — c'est-a-dire exactement au
# moment ou ca se voit.
func _degager(position: Vector3, regard: Vector3, delta: float) -> Vector3:
	if not reglages.camera_collision:
		return position

	var vers := position - regard
	var distance := vers.length()
	if distance < 0.05:
		return position
	var direction := vers / distance

	var espace := get_world_3d().direct_space_state
	var requete := PhysicsRayQueryParameters3D.create(regard, position)
	# Seulement le decor : le sujet suivi est evidemment sur le trajet, et le
	# joueur vit sur sa propre couche pour cette raison.
	requete.collision_mask = 1
	if _cible is CollisionObject3D:
		requete.exclude = [(_cible as CollisionObject3D).get_rid()]

	var touche := espace.intersect_ray(requete)
	var libre := distance
	if not touche.is_empty():
		libre = maxf(0.2, regard.distance_to(touche["position"]) - reglages.camera_marge)

	# Se rapprocher est instantane, s'eloigner est progressif.
	if libre < _recul_libre or _recul_libre <= 0.0:
		_recul_libre = libre
	else:
		_recul_libre = move_toward(_recul_libre, libre, reglages.camera_retour * delta)

	return regard + direction * minf(_recul_libre, distance)


static func _facteur(lissage: float, delta: float) -> float:
	return 1.0 - pow(1.0 - clampf(lissage, 0.001, 0.999), delta * 60.0)


# Derriere et au-dessus, dans le repere du vehicule : la camera accompagne les
# virages au lieu de rester plaquee sur un axe du monde.
# Le cap se replace derriere le personnage DANS TOUTES LES DIRECTIONS.
#
# Ca n'a pas toujours ete possible. Tant que le personnage relisait la camera
# a chaque image pour savoir ou est "la gauche", les deux se poursuivaient :
# aller sur le cote faisait tourner la camera, qui faisait tourner la
# direction, qui faisait tourner la camera. La parade d'alors etait de ne
# recentrer que lorsqu'il s'eloignait franchement — ce qui reglait le cercle
# mais laissait la camera plantee des qu'on allait sur le cote ou en arriere.
#
# Depuis que le personnage fige son repere au moment de l'appui (voir
# joueur.gd), la boucle n'existe plus et cette restriction n'a plus lieu
# d'etre. La camera peut faire son travail.
func _recentrer(delta: float) -> void:
	if not (_cible is CharacterBody3D):
		return
	# On suit son ORIENTATION, pas sa vitesse.
	#
	# Depuis que gauche et droite le font pivoter au lieu de le deplacer, sa
	# direction ne vient plus de la camera : la suivre ne peut plus creer de
	# boucle. Et surtout, suivre la vitesse ferait passer la camera DEVANT
	# lui des qu'il recule — on marcherait a reculons en se voyant de face.
	#
	# Sans seuil de vitesse, non plus : pivoter sur place doit faire tourner
	# la camera, sinon on tourne le dos a l'ecran sans que le cadre bouge.
	_cap = rotate_toward(_cap, _cible.rotation.y,
			reglages.pieton_recentrage * delta)


## Visee libre. Recoit un deplacement de souris en PIXELS.
##
## Les evenements ne sont pas lus ici : cette camera vit dans le SubViewport
## de rendu, et Godot n'y propage aucune entree. C'est le controleur, qui est
## en dehors, qui les recoit et appelle cette methode. Un _input local ne
## serait jamais declenche, sans que rien ne le signale.
func tourner(deplacement: Vector2) -> void:
	# Le signe est NEGATIF, et ce n'est pas arbitraire.
	#
	# _cap designe la direction du sujet VERS la camera. Le regard est donc
	# l'oppose, et son lacet vaut _cap. Or en Godot un lacet positif tourne
	# vers -X, c'est-a-dire vers la GAUCHE quand on regarde vers -Z. Pour que
	# la souris vers la droite fasse tourner la vue a droite, il faut donc
	# diminuer.
	#
	# La premiere version ajoutait, et le test affirmait que c'etait le bon
	# sens : j'avais inscrit le defaut dans sa propre verification.
	# Le signe negatif ne vaut QUE pour l'horizontale. Une premiere version le
	# mettait dans la sensibilite elle-meme, et inversait donc aussi le haut
	# et le bas en corrigeant la gauche et la droite.
	var s := reglages.souris_sensibilite
	if _pieton:
		_cap -= deplacement.x * s
	else:
		_orbite -= deplacement.x * s

	var sens := 1.0 if reglages.souris_inversee else -1.0
	_tangage = clampf(_tangage + deplacement.y * s * sens,
			deg_to_rad(reglages.tangage_min), deg_to_rad(reglages.tangage_max))

	_manuel = reglages.souris_repos


## Rapproche ou eloigne, a la molette.
func zoomer(crans: float) -> void:
	_zoom = clampf(_zoom - crans * reglages.zoom_pas,
			reglages.zoom_min, reglages.zoom_max)


## La camera a-t-elle deja pris sa place ? Le personnage fige son repere de
## deplacement sur elle : tant qu'elle n'est pas posee, il figerait une
## orientation perimee et partirait dans une direction qui n'a rien a voir
## avec ce qu'on voit — pour toute la duree de l'appui.
func pret() -> bool:
	return _initialisee


## Resserre ou relache le cadrage. Appele au passage d'une porte.
func interieur(dedans: bool) -> void:
	_dedans = dedans


## Replace la camera d'un coup, sans lissage. Indispensable apres une
## teleportation : le lissage mettrait plusieurs secondes a traverser les six
## cents metres qui separent la ville des interieurs, et on verrait le vide.
func recaler() -> void:
	_cap = _cible.rotation.y
	_initialisee = false


func _ancrage() -> Vector3:
	var derriere: Vector3
	var recul: float
	var haut: float

	if _pieton:
		derriere = Vector3(sin(_cap), 0.0, cos(_cap))
		recul = reglages.interieur_recul if _dedans else reglages.pieton_recul
		haut = reglages.interieur_hauteur if _dedans else reglages.pieton_hauteur
	else:
		# La direction vient de la caisse, pas d'un axe du monde : c'est ce qui
		# fait que la camera accompagne les virages. L'orbite s'ajoute par
		# dessus et se resorbe.
		derriere = _cible.global_transform.basis.z.rotated(Vector3.UP, _orbite)
		recul = reglages.recul
		haut = reglages.hauteur

	recul *= _zoom

	# Le tangage fait pivoter la camera AUTOUR du sujet : elle monte et se
	# rapproche en meme temps. Se contenter de lever la hauteur donnerait une
	# camera qui plane sans jamais regarder d'en haut.
	return (_cible.global_position
			+ derriere * recul * cos(_tangage)
			+ Vector3.UP * (haut + sin(_tangage) * recul))
