# Conduite.
#
# Aucun nombre n'est ecrit ici : tout vient de reglages.tres, reglable au
# curseur pendant que le jeu tourne. C'est la verticale ou le jeu devient bon
# ou pas, donc c'est celle ou l'iteration doit etre la plus rapide possible.
#
# Repere : l'avant du vehicule est -Z, la droite est +X, comme partout
# ailleurs dans Godot (Camera3D, look_at, etc.).
#
# ATTENTION, piege verifie a la mesure : le VehicleBody3D de Godot fait
# exception. Une poussee positive deplace la caisse vers +Z, pas vers -Z.
# Mesure faite par outils/test_sens.gd : 9,81 m parcourus a l oppose du nez.
# On corrige avec SENS_POUSSEE plutot que de retourner toute la scene, pour
# ne pas melanger deux conventions dans le meme projet.
class_name Vehicule
extends VehicleBody3D

const SENS_POUSSEE := -1.0

## En dessous de cette vitesse (m/s, signee), une commande de frein bascule
## en marche arriere. Le signe est essentiel : une premiere version comparait
## la vitesse NON signee et oscillait entre freiner et reculer plusieurs fois
## par seconde.
const SEUIL_MARCHE_ARRIERE := 0.8

@export var reglages: Reglages

## Emis a chaque changement de rapport apparent, pour le son moteur.
signal regime_change(regime: float)

## Emis quand la caisse encaisse. La force est la vitesse PERDUE d'un coup, en
## m/s : elle dit tout de suite si on a frotte un trottoir ou pris un mur.
signal choc(force: float)

@onready var _avant: Array[VehicleWheel3D] = [$RoueAvantG, $RoueAvantD]
@onready var _arriere: Array[VehicleWheel3D] = [$RoueArriereG, $RoueArriereD]
@onready var _phares: Array[SpotLight3D] = [$PhareG, $PhareD]

var _braquage: float = 0.0
var _regime: float = 0.0
var _audio: Audio

## Le systeme audio, retrouve A LA DEMANDE et garde ensuite.
##
## Pas dans _ready() : le noeud Audio est declare plus bas dans la scene, donc
## il n'est pas encore dans son groupe quand celui-ci s'initialise. Le chercher
## trop tot donnait null, definitivement, et le silence qui suit ressemble a un
## mecanisme pas encore branche.
func _son() -> Audio:
	if _audio == null:
		_audio = Audio.courant(self)
	return _audio

## Vitesse de l'image precedente, pour mesurer ce qu'un choc en retire.
var _vitesse_avant: Vector3 = Vector3.ZERO
var _repos_choc: float = 0.0

## Nombre d'images pendant lesquelles on ignore les chocs. Un passage vers le
## desert repose la voiture a l'arret : la vitesse tombe de soixante a zero en
## une image, et sans ce garde on entendrait un mur a chaque teleportation.
var _sourd: int = 0


func _ready() -> void:
	if reglages == null:
		push_error("vehicule : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	appliquer_reglages()


## Ignore les chocs pendant quelques images. A appeler avant de TELEPORTER la
## voiture : la vitesse tombe alors de soixante a zero en une image, ce qui est
## exactement la signature d'un mur.
func ignorer_les_chocs(images: int = 4) -> void:
	_sourd = images
	_vitesse_avant = Vector3.ZERO


## Relit reglages.tres. Appelable a chaud : c'est ce qui permet de bouger un
## curseur et de sentir la difference au tour de roue suivant.
func appliquer_reglages() -> void:
	mass = reglages.masse

	# Centre de gravite abaisse sous l'essieu. Godot le place par defaut au
	# centre du volume, c'est-a-dire a hauteur de portiere : la caisse penche
	# alors assez en virage pour que son flanc touche le sol, ce qui freine
	# net et la fait rebondir en sortie de courbe.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, reglages.centre_gravite, 0.0)

	for r in _toutes():
		r.suspension_travel = reglages.suspension_course
		r.suspension_stiffness = reglages.suspension_raideur
		r.damping_compression = reglages.suspension_amorti
		r.damping_relaxation = reglages.suspension_amorti * 1.4
	for r in _avant:
		r.wheel_friction_slip = reglages.adherence_avant
	for r in _arriere:
		r.wheel_friction_slip = reglages.adherence_arriere
	for p in _phares:
		p.light_energy = reglages.phare_energie
		p.spot_range = reglages.phare_portee
		p.spot_angle = reglages.phare_angle
		p.light_color = reglages.phare_couleur
		# De jour ils ne servent a rien et se voient : un cone de lumiere en
		# plein soleil est le detail qui trahit une scene de nuit eclaircie a
		# la va-vite.
		p.visible = reglages.phares_allumes and not Reglages.est_jour()


func _toutes() -> Array[VehicleWheel3D]:
	return _avant + _arriere


## Les roues motrices. Le son lit leur adherence pour savoir quand ca crisse :
## il a besoin des roues elles-memes, pas d'une valeur pre-machee, parce que
## le seuil est un reglage et qu'il doit rester dans reglages.tres.
func roues_arriere() -> Array[VehicleWheel3D]:
	return _arriere


func _physics_process(delta: float) -> void:
	var gaz := Input.get_axis("frein", "gaz")
	var direction := Input.get_axis("droite", "gauche")
	var kmh := vitesse_kmh()

	_braquer(direction, kmh, delta)
	_propulser(gaz, kmh)
	_anti_roulis()

	var r := clampf(kmh / maxf(1.0, reglages.vitesse_max_kmh), 0.0, 1.0)
	if absf(r - _regime) > 0.02:
		_regime = r
		regime_change.emit(r)

	_ecouter_les_chocs(delta)


# On MESURE la decelaration, on n'ecoute pas les contacts.
#
# Une voiture touche le sol a chaque image et frotte un trottoir sans arret :
# distinguer le vrai choc dans ce flux de contacts demanderait de filtrer sur
# la force, c'est-a-dire de retrouver ce que la vitesse dit directement. Un
# freinage appuye retire environ 0,3 m/s par image ; un mur en prend dix.
#
# Le detour a un autre merite : ca marche contre n'importe quoi, y compris ce
# qui n'a pas de corps physique propre — la geometrie de la ville est un seul
# maillage de collision.
func _ecouter_les_chocs(delta: float) -> void:
	_repos_choc = maxf(0.0, _repos_choc - delta)

	# On ne compte QUE la vitesse horizontale perdue.
	#
	# Une voiture qui retombe perd d'un coup toute sa vitesse verticale, et
	# c'est numeriquement indiscernable d'un mur : une chute de soixante
	# centimetres arrive au sol a plus de trois metres par seconde. La premiere
	# version faisait donc claquer la tole a chaque fois qu'on reposait la
	# caisse — au demarrage, apres une bosse, en sortant d'un trottoir.
	#
	# La distinction est physique et elle est franche : un atterrissage est
	# vertical, un choc est horizontal. On jette simplement l'axe Y.
	var av := Vector2(_vitesse_avant.x, _vitesse_avant.z)
	var ap := Vector2(linear_velocity.x, linear_velocity.z)
	var perdue := (av - ap).length()
	_vitesse_avant = linear_velocity

	if _sourd > 0:
		_sourd -= 1
		return
	if _repos_choc > 0.0 or perdue < reglages.choc_seuil:
		return
	# Une voiture a l'arret qu'on pousse ne "tape" pas : on exige d'avoir ROULE
	# avant. Horizontalement, la aussi.
	if av.length() < reglages.choc_seuil:
		return

	_repos_choc = reglages.choc_repos
	choc.emit(perdue)
	if _son() == null:
		return
	var fort := perdue >= reglages.choc_fort
	# La hauteur descend avec la violence : un gros choc sonne plus grave, et
	# ca suffit a etager quatre variantes en une dizaine de nuances.
	var hauteur := clampf(1.12 - perdue * 0.02, 0.85, 1.12)
	_son().bruit_ici("choc_fort" if fort else "choc_leger",
			global_position, hauteur)


# Barre anti-roulis, essieu par essieu.
#
# Godot n'en fournit pas : ses quatre roues sont independantes, et rien ne
# s'oppose au roulis a part la raideur des ressorts. On la simule en
# comparant la compression des deux roues d'un meme essieu, et en appliquant
# une force verticale opposee au desequilibre.
#
# C'est ce qui manquait apres avoir rendu leur adherence aux roues : plus de
# grip veut dire plus de force laterale, donc plus de roulis. Raidir les
# ressorts aurait durci toute la voiture, y compris en ligne droite, pour
# corriger un defaut qui n'existe qu'en virage.
func _anti_roulis() -> void:
	if reglages.anti_roulis <= 0.0:
		return

	# Au moins trois roues au sol : en l'air, redresser la caisse ferait
	# tourner la voiture autour de rien, et a l'atterrissage elle serait
	# droite comme par magie.
	var au_sol := 0
	for r in _toutes():
		if r.is_in_contact():
			au_sol += 1
	if au_sol < 3:
		return

	# Angle de gite : le flanc droit de la caisse s'eleve ou s'abaisse par
	# rapport a l'horizontale. On ne lit pas les suspensions — Godot n'expose
	# pas leur compression — mais l'assiette de la caisse, qui en est le
	# resultat direct.
	var droite := global_transform.basis.x
	var roulis := asin(clampf(droite.y, -1.0, 1.0))

	# Vitesse de gite, pour amortir : sans elle on ajoute un ressort de plus
	# a une voiture qui rebondit deja, et elle oscille au lieu de se poser.
	var avant := -global_transform.basis.z
	var vitesse_roulis := angular_velocity.dot(avant)

	var k := reglages.anti_roulis * mass * 12.0
	apply_torque(avant * (-roulis * k - vitesse_roulis * k * 0.35))


# Le braquage se resserre avec la vitesse. Sans ca, la voiture pivote sur
# place a 120 km/h et devient injouable — c'est le premier reglage que
# corrigent tous les jeux de conduite.
func _braquer(direction: float, kmh: float, delta: float) -> void:
	var t := clampf(kmh / maxf(1.0, reglages.vitesse_max_kmh), 0.0, 1.0)
	var maxi := deg_to_rad(reglages.braquage_max_deg)
	maxi *= 1.0 - t * reglages.braquage_reduction_vitesse
	var k := clampf(reglages.braquage_reactivite * delta, 0.0, 1.0)
	_braquage = lerpf(_braquage, direction * maxi, k)
	steering = _braquage


func _propulser(gaz: float, kmh: float) -> void:
	if Input.is_action_pressed("frein_main"):
		engine_force = 0.0
		brake = reglages.force_frein * 1.7
		return

	# Vitesse SIGNEE le long du nez : positive en marche avant, negative en
	# marche arriere. C'est ce signe qui permet de distinguer "je freine" de
	# "je recule" — sans lui, les deux etats s'echangent en boucle.
	var avance := -global_transform.basis.z.dot(linear_velocity)

	if gaz > 0.0:
		if avance < -SEUIL_MARCHE_ARRIERE:
			# On roule en arriere : la commande d'avance freine d'abord.
			engine_force = 0.0
			brake = gaz * reglages.force_frein
		else:
			# La resistance fait la vitesse maximale ; on coupe la poussee
			# au-dela plutot que de brider la vitesse, ce qui donnerait une
			# sensation de mur.
			var pousser: bool = kmh < reglages.vitesse_max_kmh
			engine_force = SENS_POUSSEE * gaz * reglages.acceleration if pousser else 0.0
			brake = 0.0
	elif gaz < 0.0:
		if avance > SEUIL_MARCHE_ARRIERE:
			engine_force = 0.0
			brake = -gaz * reglages.force_frein
		else:
			engine_force = SENS_POUSSEE * gaz * reglages.acceleration * 0.45
			brake = 0.0
	else:
		engine_force = 0.0
		brake = reglages.force_frein * 0.05                     # frein moteur


func vitesse_kmh() -> float:
	return linear_velocity.length() * 3.6


## Regime apparent, de 0 a 1. Servira a melanger les boucles moteur.
func regime() -> float:
	return _regime


## Rend la main au conducteur.
func prendre_le_volant() -> void:
	set_physics_process(true)
	var m := get_node_or_null("MoteurAudio")
	if m != null:
		m.call("demarrer")


## Neutralise le vehicule quand on en descend.
##
## Couper le script ne suffit pas : engine_force garde sa derniere valeur et
## la voiture continuerait toute seule pendant qu'on marche. Il faut annuler
## la poussee et serrer le frein explicitement.
func quitter_le_volant() -> void:
	set_physics_process(false)
	engine_force = 0.0
	steering = 0.0
	brake = reglages.force_frein * 2.0
	var m := get_node_or_null("MoteurAudio")
	if m != null:
		m.call("couper")


func basculer_phares() -> void:
	reglages.phares_allumes = not reglages.phares_allumes
	for p in _phares:
		# De jour ils ne servent a rien et se voient : un cone de lumiere en
		# plein soleil est le detail qui trahit une scene de nuit eclaircie a
		# la va-vite.
		p.visible = reglages.phares_allumes and not Reglages.est_jour()
