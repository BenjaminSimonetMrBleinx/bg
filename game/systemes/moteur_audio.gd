# Le son du moteur.
#
# Trois boucles enregistrees a des regimes differents, fondues les unes dans
# les autres selon le regime reel. C'est la methode des jeux de conduite, et
# la raison est simple : un fichier unique dont on fait varier la hauteur
# sonne synthetique des la premiere acceleration. L'oreille reconnait
# immediatement un echantillon etire.
#
# Le son est POSITIONNE : il vit sur le vehicule, pas dans un lecteur global.
# A pied, on doit entendre la voiture venir de sa direction.
class_name MoteurAudio
extends Node3D

@export var reglages: Reglages

@export_group("Couches")
## Boucles, du plus bas au plus haut regime. Deux suffisent, trois sont mieux.
@export var boucle_ralenti: AudioStream
@export var boucle_charge: AudioStream
@export var boucle_haut: AudioStream

@export_group("Ponctuels")
@export var demarrage: AudioStream
@export var arret: AudioStream

@export_group("Roulement")
## Bruit de contact des pneus sur la route, en boucle. C'est ce qui donne son
## POIDS a une voiture — bien plus que le moteur, qu'on entend surtout monter
## en regime. Sans lui, on a l'impression de piloter un moteur, pas un
## vehicule.
@export var roulement: AudioStream
## Crissement, joue quand une roue arriere decroche.
@export var crissement: AudioStream

var _vehicule: Vehicule
var _couches: Array[AudioStreamPlayer3D] = []
var _ponctuel: AudioStreamPlayer3D
var _roulement: AudioStreamPlayer3D
var _crissement: AudioStreamPlayer3D
var _regime_lisse: float = 0.0
var _tourne: bool = false

## Compte a rebours avant d'autoriser un nouveau crissement. Une glissade dure
## plusieurs secondes : sans ce repos, elle en declencherait un par image.
var _repos_crissement: float = 0.0


func _ready() -> void:
	_vehicule = get_parent() as Vehicule
	if _vehicule == null:
		push_error("moteur_audio : doit etre enfant d'un Vehicule")
		set_process(false)
		return

	for flux in [boucle_ralenti, boucle_charge, boucle_haut]:
		if flux == null:
			continue
		# Une boucle non marquee se rejoue depuis le debut a chaque fin, et
		# le trou s'entend. C'est le son le plus present du jeu : il ne peut
		# pas se permettre un raccord audible.
		if flux is AudioStreamWAV:
			(flux as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif flux is AudioStreamOggVorbis:
			(flux as AudioStreamOggVorbis).loop = true
		_couches.append(_creer(flux, true))

	if _couches.is_empty():
		push_warning("moteur_audio : aucune boucle assignee, le moteur sera muet")

	_ponctuel = _creer(null, false)

	if roulement != null:
		if roulement is AudioStreamWAV:
			(roulement as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif roulement is AudioStreamOggVorbis:
			(roulement as AudioStreamOggVorbis).loop = true
		_roulement = _creer(roulement, true)
	if crissement != null:
		_crissement = _creer(null, false)


func _creer(flux: AudioStream, boucle: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = flux
	p.bus = "Effets"
	p.volume_db = -80.0 if boucle else 0.0
	p.unit_size = reglages.moteur_portee if reglages != null else 14.0
	p.max_distance = 60.0
	# Attenuation douce : un moteur reste perceptible de loin, contrairement
	# a un claquement de portiere.
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	if boucle and flux != null:
		p.play()
	return p


## Demarre le moteur : coup de demarreur, puis les boucles montent.
func demarrer() -> void:
	if _tourne:
		return
	_tourne = true
	if demarrage != null:
		_ponctuel.stream = demarrage
		_ponctuel.play()


func couper() -> void:
	if not _tourne:
		return
	_tourne = false
	if arret != null:
		_ponctuel.stream = arret
		_ponctuel.play()


func _process(delta: float) -> void:
	if reglages == null:
		return
	_rouler(delta)
	if _couches.is_empty():
		return

	# Le regime suit la vitesse, mais amorti : sans ce lissage, le moindre
	# a-coup de la physique s'entend comme un hoquet.
	var vise := _vehicule.regime() if _tourne else 0.0
	var k := clampf(reglages.moteur_reactivite * delta, 0.0, 1.0)
	_regime_lisse = lerpf(_regime_lisse, vise, k)

	var n := _couches.size()
	# Position du regime sur l'echelle des couches : 0 = premiere boucle,
	# n-1 = derniere. Chaque couche s'efface a mesure qu'on s'en eloigne.
	var pos := _regime_lisse * float(n - 1)
	for i in n:
		var poids := clampf(1.0 - absf(pos - float(i)), 0.0, 1.0)
		var db := reglages.moteur_volume if poids > 0.001 else -80.0
		if poids > 0.001:
			db += linear_to_db(poids)
		_couches[i].volume_db = db if _tourne else -80.0
		# Une legere variation de hauteur DANS chaque couche affine la
		# progression sans trahir l'echantillon.
		_couches[i].pitch_scale = 1.0 + (_regime_lisse - float(i) / maxf(1.0, n - 1)) \
				* reglages.moteur_variation_hauteur


# Le roulement suit la VITESSE, pas le regime.
#
# La distinction compte : au point mort en descente, le moteur est au ralenti
# et les pneus font pourtant tout le bruit. Un roulement branche sur le regime
# se tairait exactement au moment ou il devrait porter la scene.
#
# Il continue aussi quand personne n'est au volant : une voiture lancee dont
# on descend roule encore, et le silence brutal se remarquerait.
func _rouler(delta: float) -> void:
	_repos_crissement = maxf(0.0, _repos_crissement - delta)

	if _roulement != null:
		var t := clampf(_vehicule.vitesse_kmh()
				/ maxf(1.0, reglages.roulement_plein), 0.0, 1.0)
		# En dessous du pas, on coupe franchement : un roulement qui s'attarde
		# a l'arret est le defaut qu'on entend tout de suite.
		if t < 0.04:
			_roulement.volume_db = -80.0
		else:
			_roulement.volume_db = reglages.roulement_volume + linear_to_db(t)
			_roulement.pitch_scale = 1.0 + t * reglages.roulement_hauteur

	if _crissement == null or _repos_crissement > 0.0:
		return

	# skidinfo vaut 1 quand la roue accroche et tend vers 0 quand elle glisse.
	# On ne regarde que l'essieu arriere : c'est lui qui decroche, et une roue
	# avant qui patine au braquage crisserait en permanence en manoeuvre.
	var glisse := 0.0
	for r in _vehicule.roues_arriere():
		if r.is_in_contact():
			glisse = maxf(glisse, 1.0 - r.get_skidinfo())
	if glisse < 1.0 - reglages.crissement_seuil:
		return
	# Une voiture a l'arret dont les roues patinent ne crisse pas : elle
	# patine. Le crissement est un bruit de vitesse.
	if _vehicule.vitesse_kmh() < 12.0:
		return

	_repos_crissement = reglages.crissement_repos
	_crissement.stream = crissement
	_crissement.volume_db = linear_to_db(clampf(glisse, 0.2, 1.0))
	_crissement.play()
