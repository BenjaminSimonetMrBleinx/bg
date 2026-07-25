# Le son du jeu.
#
# Deux responsabilites, et une seule ligne de conduite : rien n'est ecrit en
# dur, tout vient de reglages.tres.
#
#   1. regler les volumes des bus
#   2. jouer la nappe d'ambiance, et fournir un point d'entree unique pour
#      les bruitages ponctuels
#
# Les sons positionnes dans l'espace ne passent PAS par ici : ils vivent sur
# l'objet qui les emet (moteur sur le vehicule, bourdonnement sur le
# lampadaire), sinon ils perdent leur position.
class_name Audio
extends Node

@export var reglages: Reglages

## Nappe jouee en continu a l'exterieur. Stereo, non positionnee.
@export var ambiance_exterieure: AudioStream

## Nappes d'interieur, indexees par nom de maison. Vide pour l'instant.
@export var ambiances_interieures: Dictionary = {}

const BUS_AMBIANCE := "Ambiance"
const BUS_EFFETS := "Effets"
const BUS_INTERFACE := "Interface"

var _ambiance: AudioStreamPlayer
var _fondu: Tween


func _ready() -> void:
	if reglages == null:
		push_error("audio : aucune ressource Reglages assignee")
		return
	appliquer_volumes()
	_preparer_ambiance()


## Relit reglages.tres. Appelable a chaud comme le reste.
func appliquer_volumes() -> void:
	_regler("Master", reglages.volume_maitre)
	_regler(BUS_AMBIANCE, reglages.volume_ambiance)
	_regler(BUS_EFFETS, reglages.volume_effets)
	_regler("Musique", reglages.volume_musique)
	_regler(BUS_INTERFACE, reglages.volume_interface)


func _regler(nom: String, db: float) -> void:
	var index := AudioServer.get_bus_index(nom)
	if index < 0:
		push_warning("audio : bus '%s' introuvable" % nom)
		return
	AudioServer.set_bus_volume_db(index, db)


func _preparer_ambiance() -> void:
	if ambiance_exterieure == null:
		return

	# La boucle se regle sur le flux lui-meme, pas sur le lecteur : une nappe
	# qui se relance depuis le debut a chaque fin s'entend, un flux marque
	# comme boucle ne se coupe jamais.
	if ambiance_exterieure is AudioStreamOggVorbis:
		(ambiance_exterieure as AudioStreamOggVorbis).loop = true
	elif ambiance_exterieure is AudioStreamWAV:
		(ambiance_exterieure as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

	_ambiance = AudioStreamPlayer.new()
	_ambiance.name = "Ambiance"
	_ambiance.stream = ambiance_exterieure
	_ambiance.bus = BUS_AMBIANCE
	add_child(_ambiance)

	# Demarrage en fondu : une nappe qui apparait a plein volume s'entend
	# comme un declic, et c'est la premiere seconde de jeu.
	_ambiance.volume_db = -60.0
	_ambiance.play()
	_fondu = create_tween()
	_fondu.tween_property(_ambiance, "volume_db", 0.0,
			maxf(0.01, reglages.ambiance_fondu))


## Bascule vers l'ambiance d'un interieur, ou revient dehors si le nom est
## vide. Le fondu evite la coupure nette au passage d'une porte.
func ambiance(nom: String = "") -> void:
	if _ambiance == null:
		return
	var flux: AudioStream = ambiances_interieures.get(nom, ambiance_exterieure)
	if flux == _ambiance.stream:
		return
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_fondu = create_tween()
	_fondu.tween_property(_ambiance, "volume_db", -60.0, 0.35)
	_fondu.tween_callback(func() -> void:
		_ambiance.stream = flux
		_ambiance.play())
	_fondu.tween_property(_ambiance, "volume_db", 0.0, 0.6)


## Bruitage ponctuel non positionne : interface, dialogue. Le lecteur se
## supprime tout seul, on n'a pas a le gerer.
func jouer(flux: AudioStream, bus: String = BUS_INTERFACE,
		hauteur: float = 1.0) -> void:
	if flux == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = flux
	p.bus = bus
	p.pitch_scale = hauteur
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
