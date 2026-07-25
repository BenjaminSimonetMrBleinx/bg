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

@onready var _avant: Array[VehicleWheel3D] = [$RoueAvantG, $RoueAvantD]
@onready var _arriere: Array[VehicleWheel3D] = [$RoueArriereG, $RoueArriereD]
@onready var _phares: Array[SpotLight3D] = [$PhareG, $PhareD]

var _braquage: float = 0.0
var _regime: float = 0.0


func _ready() -> void:
	if reglages == null:
		push_error("vehicule : aucune ressource Reglages assignee")
		set_physics_process(false)
		return
	appliquer_reglages()


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
