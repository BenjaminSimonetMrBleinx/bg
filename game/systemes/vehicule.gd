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
		p.visible = reglages.phares_allumes


func _toutes() -> Array[VehicleWheel3D]:
	return _avant + _arriere


func _physics_process(delta: float) -> void:
	var gaz := Input.get_axis("frein", "gaz")
	var direction := Input.get_axis("droite", "gauche")
	var kmh := vitesse_kmh()

	_braquer(direction, kmh, delta)
	_propulser(gaz, kmh)

	var r := clampf(kmh / maxf(1.0, reglages.vitesse_max_kmh), 0.0, 1.0)
	if absf(r - _regime) > 0.02:
		_regime = r
		regime_change.emit(r)


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


func basculer_phares() -> void:
	reglages.phares_allumes = not reglages.phares_allumes
	for p in _phares:
		p.visible = reglages.phares_allumes
