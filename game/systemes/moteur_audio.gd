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

var _vehicule: Vehicule
var _couches: Array[AudioStreamPlayer3D] = []
var _ponctuel: AudioStreamPlayer3D
var _regime_lisse: float = 0.0
var _tourne: bool = false


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
	if _couches.is_empty() or reglages == null:
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
